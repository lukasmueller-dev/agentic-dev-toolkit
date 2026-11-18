#!/usr/bin/env bats
#
# vibe-web — the queue page's write endpoint. Each test starts the server on a
# free port and talks to it with curl, as tailscale serve would.

load helper

setup() {
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  mkdir -p "$HOME/.config/vibe" "$XDG_CONFIG_HOME/vibe" && echo server >"$HOME/.config/vibe/role"
  Q="$XDG_STATE_HOME/vibe"
  PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
  printf 'web_port=%s\nweb_login=me@example.com\n' "$PORT" >"$XDG_CONFIG_HOME/vibe/queue.conf"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"
  printf '#!/bin/sh\necho "$*" >>"%s/systemctl.log"\n[ ! -f "%s/hang" ] || exec sleep 30\n' "$STUBS" "$STUBS" >"$STUBS/systemctl"
  # gh: logs its args; per PR number N (the URL tail) prints STUBS/state-N, checks-N, files-N, else state, checks, files.
  cat >"$STUBS/gh" <<EOF
#!/bin/sh
echo "\$*" >>"$STUBS/gh.log"
n="\${3##*/}"
f() { cat "$STUBS/\$1-\$n" 2>/dev/null || cat "$STUBS/\$1" 2>/dev/null || true; }
case "\$1 \$2 \$*" in
  "pr view "*statusCheckRollup*) f checks ;;
  "pr view "*state*) f state ;;
  "pr diff "*) f files ;;
  "pr list "*) cat "$STUBS/prs" ;;
esac
EOF
  chmod +x "$STUBS/systemctl" "$STUBS/gh"
  PATH="$STUBS:$PATH"
  git_env
  export VIBE_WEB_TIMEOUT=3 VIBE_ROOT="$BATS_TEST_TMPDIR"
  web_start
}

# web_start — the server on $PORT, with the current environment; its pid in web.pid.
web_start() {
  "$REPO_ROOT/bin/vibe-web" 2>>"$BATS_TEST_TMPDIR/web.log" &
  echo $! >"$BATS_TEST_TMPDIR/web.pid"
  curl -s -o /dev/null --retry 30 --retry-connrefused --retry-delay 1 "http://127.0.0.1:$PORT/"
}

teardown() {
  kill "$(cat "$BATS_TEST_TMPDIR/web.pid")" 2>/dev/null || true
}

# req METHOD PATH [CURL ARG...] — the HTTP code, then the body.
req() {
  local m="$1" p="$2"
  shift 2
  curl -s -w '\n%{http_code}' -X "$m" "$@" "http://127.0.0.1:$PORT$p"
}

# post PATH [CURL ARG...] — a write as the page sends it, by the right login.
post() {
  local p="$1"
  shift
  req POST "$p" -H 'Tailscale-User-Login: me@example.com' -H "Origin: https://127.0.0.1:$PORT" \
    -H 'Content-Type: application/json' -d '{}' "$@"
}

@test "vibe-web: the right login pauses and resumes; one log line per write; the page shows it" {
  run post /queue/api/pause
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  [ -e "$Q/paused" ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 1 ]
  grep -q $'\tme@example.com\tvibe queue pause\t0$' "$Q/actions.log"
  grep -q 'data-act="resume"' "$Q/web/index.html"
  grep -q 'vibe queue pause' "$Q/web/index.html"
  run post /resume
  [ "${lines[1]}" = 200 ]
  [ ! -e "$Q/paused" ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 2 ]
  grep -q 'data-act="pause"' "$Q/web/index.html"
}

@test "vibe-web: a wrong or absent login, a foreign Origin, a non-JSON body get 403 and change nothing" {
  run req POST /queue/api/pause -H 'Tailscale-User-Login: other@example.com' -H "Origin: https://127.0.0.1:$PORT" -H 'Content-Type: application/json' -d '{}'
  [ "${lines[1]}" = 403 ]
  run req POST /queue/api/pause -H "Origin: https://127.0.0.1:$PORT" -H 'Content-Type: application/json' -d '{}'
  [ "${lines[1]}" = 403 ]
  run req POST /queue/api/pause -H 'Tailscale-User-Login: me@example.com' -H 'Origin: https://evil.example.com' -H 'Content-Type: application/json' -d '{}'
  [ "${lines[1]}" = 403 ]
  run post /queue/api/pause -H 'Origin: https://evil.example.com'
  [ "${lines[1]}" = 403 ]
  run req POST /queue/api/pause -H 'Tailscale-User-Login: me@example.com' -H 'Content-Type: application/json' -d '{}'
  [ "${lines[1]}" = 403 ]
  run req POST /queue/api/pause -H 'Tailscale-User-Login: me@example.com' -H "Origin: https://127.0.0.1:$PORT" -d 'a=1'
  [ "${lines[1]}" = 403 ]
  run post /queue/api/pause -d 'not json'
  [ "${lines[1]}" = 403 ]
  run post /queue/api/pause -d '[1]'
  [ "${lines[1]}" = 403 ]
  run req GET /queue/api/pause -H 'Tailscale-User-Login: me@example.com'
  [ "${lines[1]}" = 404 ]
  [ ! -e "$Q/paused" ]
  [ ! -e "$Q/actions.log" ]
}

@test "vibe-web: no web_login in queue.conf: 403 for everyone" {
  printf 'web_port=%s\n' "$PORT" >"$XDG_CONFIG_HOME/vibe/queue.conf"
  run post /queue/api/pause
  [ "${lines[1]}" = 403 ]
  run req GET /queue/api/whoami -H 'Tailscale-User-Login: me@example.com'
  [ "${lines[1]}" = 403 ]
  [ ! -e "$Q/paused" ]
}

@test "vibe-web: GET whoami returns the login, with and without the mount prefix" {
  run req GET /queue/api/whoami -H 'Tailscale-User-Login: me@example.com'
  [ "${lines[0]}" = '{"login": "me@example.com"}' ]
  [ "${lines[1]}" = 200 ]
  run req GET /whoami -H 'Tailscale-User-Login: me@example.com'
  [ "${lines[1]}" = 200 ]
  run req GET /queue/api/whoami
  [ "${lines[1]}" = 403 ]
}

@test "vibe-web: an unknown route is 404 and runs nothing" {
  run post /queue/api/nope
  [ "${lines[1]}" = 404 ]
  [ ! -e "$Q/actions.log" ]
}

@test "vibe-web: the unit runs only on a server; a restart keeps the detached ws commands" {
  grep -q '^ExecStart=%h/bin/vibe-web$' "$REPO_ROOT/claude/systemd/vibe-web.service"
  grep -q '^ExecCondition=.*grep -qx server %h/.config/vibe/role' "$REPO_ROOT/claude/systemd/vibe-web.service"
  grep -q '^KillMode=process$' "$REPO_ROOT/claude/systemd/vibe-web.service"
}

@test "vibe queue page: writes the page; buttons hidden until whoami" {
  run "$REPO_ROOT/bin/vibe" queue page
  [ "$status" -eq 0 ]
  grep -q 'data-act="pause"' "$Q/web/index.html"
  grep -q "fetch(api + 'whoami'" "$Q/web/page.js"
  grep -qF "if (!document.body.classList.contains('can')) who();" "$Q/web/page.js"
  grep -qF "if (busy || \$('button.armed')) return;" "$Q/web/page.js"
  # Raw HTML in a .md can repeat any id or class chain: a guard compares nodes, and no .md button works.
  grep -qF "main.contains(b) || blocks.contains(b) || b.closest('.prows')?.parentNode === pbody" "$Q/web/page.js"
  grep -qF "b.closest('.md') ||" "$Q/web/page.js"
  run grep -F "'#queue " "$Q/web/page.js"
  [ "$status" -eq 1 ]
  # The panel after main: the column right of the list.
  [ "$(grep -n '<dialog id="panel"' "$Q/web/index.html" | cut -d: -f1)" -gt "$(grep -n '<div id="queue" class="page">' "$Q/web/index.html" | cut -d: -f1)" ]
  # The poll writes only to nodes held at load, found in the fetched page by a path from body: a .md can hold any class.
  grep -qF "const [s, live, was] = p, h = \$(s, n).innerHTML;" "$Q/web/page.js"
  grep -qF "live.innerHTML = h; p[2] = h;" "$Q/web/page.js"
  grep -qF "const parts = ['body > nav > .q > .n', 'body > main > .head > .stat', 'body > main > .head > .jacts', 'body > main > #queue', 'body > main > #config', 'body > #panel > .pblocks', 'body > nav > .wsl', 'body > main > #workspaces']" "$Q/web/page.js"
  [ "$(grep -oE '[$][(][^)]*, n[)]' "$Q/web/page.js" | grep -vcF -e "\$(s, n)" -e "\$('body > ")" = 0 ]
  grep -qF "if (busy) again = true; else await poll();" "$Q/web/page.js"
  # The page's age comes from the server's clock alone (Date header minus data-t): a skewed browser clock cannot fake it.
  grep -qF "base = Date.now() - (d - \$('.updated', parts[1][1]).dataset.t * 1000);" "$Q/web/page.js"
  run grep -c 'Date.now() / 1000' "$Q/web/page.js"
  [ "$output" = 0 ]
  grep -qF "if (v !== view) return;" "$Q/web/page.js"
  grep -qF "e.target === panel && (e.clientY < r.top" "$Q/web/page.js"
  grep -q '<dialog id="panel"' "$Q/web/index.html"
  grep -q 'body.can .jacts' "$Q/web/index.html"
}

@test "vibe queue page: the panel shows the block the hash names; j/k move it; fields replace prompt(); the swap skips a part in use" {
  local js="$Q/web/page.js"
  run "$REPO_ROOT/bin/vibe" queue page
  [ "$status" -eq 0 ]
  if command -v node >/dev/null; then node --check "$js"; fi
  run grep -c 'prompt(' "$js"
  [ "$output" = 0 ]
  # The hash names the block; its row is marked; another block drops the output.
  grep -qF "for (const b of blocks.children) { b.hidden = b.id !== id; if (!b.hidden) blk = b; }" "$js"
  grep -qF "r.classList.toggle('sel', 'job-' + r.dataset.k === id)" "$js"
  grep -qF "addEventListener('hashchange', show);" "$js"
  # Wide: a CSS column, never show(), which would take the focus; narrow: a modal only for a block or an output.
  grep -qF "wide = matchMedia('(min-width: 1200px)')" "$js"
  grep -qF "else if (!panel.open) panel.showModal();" "$js"
  run grep -c 'panel.show()' "$js"
  [ "$output" = 0 ]
  # j/k only select; the one key that sends needs ⌘ or Ctrl.
  grep -qF "(e.key !== 'j' && e.key !== 'k')) return;" "$js"
  [ "$(grep -c '\.click()' "$js")" = 1 ]
  grep -qF "if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); \$('button[data-act]', f.closest('.ask') || f)?.click(); }" "$js"
  grep -qF "else if (e.key === 'Escape' && f.value && f.tagName !== 'SELECT') { e.preventDefault(); f.value = ''; }" "$js"
  # Args: each named field of the button's .ask after the card's data; an empty field sends nothing.
  grep -qF "const fields = box ? [...box.querySelectorAll('[name]')] : [], vals = {};" "$js"
  grep -qF "if (!v && 'opt' in x.dataset) continue;" "$js"
  grep -qF "if (!v) { x.focus(); return; }" "$js"
  grep -qF "const args = Object.assign({}, card && card.dataset, vals);" "$js"
  # The swap leaves a part alone while a field in it has focus or a value other than its default, and tries again next poll.
  grep -qF "const held = n => [...n.querySelectorAll('input, textarea, select')].some(f => f === document.activeElement || (f.tagName === 'SELECT' ? f.options[f.selectedIndex] !== dflt(f) : f.value !== f.defaultValue));" "$js"
  # A send resets a select to its default option too, so its part swaps again.
  grep -qF "if (done) fields.forEach(x => { if (x.tagName !== 'SELECT') x.value = x.defaultValue; else if (dflt(x)) dflt(x).selected = true; });" "$js"
  grep -qF "if (held(live)) { if (swapIn(live, \$(s, n))) kept = true; else p[2] = h; continue; }" "$js"
  grep -qF "if (r.ok && !kept) last = t;" "$js"
  # The roadmap rows get a Branch slug field, not a prompt.
  grep -qF "ask('branch', 'Branch slug', action('Queue', 'roadmap-new', {}))" "$js"
  # The panel: Close, the empty note, the blocks with New job last, the output.
  grep -qF '<dialog id="panel" aria-label="Details"><button class="close" type="button">Close</button><p class="pnone">Pick a row: its details show here.</p><div class="pblocks">' "$Q/web/index.html"
  # From 1200 px Close shows only with a button's output: the column itself never closes.
  grep -qF '#panel:has(> .pout[hidden]) > .close { display: none; }' "$Q/web/index.html"
  grep -qF '<div class="blk" id="new" hidden><div class="bh"><h2>New job</h2></div>' "$Q/web/index.html"
  grep -qF '</div><div class="pout" hidden><div class="ph"><strong></strong><span></span></div><p class="pmsg"></p><div class="pbody"></div></div></dialog>' "$Q/web/index.html"
  grep -qF '<a class="btn new" href="#new">New job</a>' "$Q/web/index.html"
}

@test "page.js in a headless browser: an old page reads stale at load; a field in use holds only its block, the rest swaps; a research card fits the panel" {
  local b a=20261104-080000-proj-a c=20261104-080001-proj-c
  b="${VIBE_TEST_BROWSER:-$(command -v chrome-headless-shell chromium chromium-browser google-chrome google-chrome-stable | head -n 1 || true)}"
  [ -n "$b" ] || skip "no headless browser (VIBE_TEST_BROWSER)"
  qjob "$a" blocked
  qjob "$c" blocked
  printf 'repo=%s/proj\nbranch=task-c\n' "$BATS_TEST_TMPDIR" >"$Q/queue/$c/job"
  research_fixture "$Q/queue" "$BATS_TEST_TMPDIR/proj"
  "$REPO_ROOT/bin/vibe" queue page
  run python3 "$BATS_TEST_DIRNAME/page_check.py" "$b" "$Q/web" "$a" "$c" lr
  echo "$output"
  [ "$status" -ne 77 ] || skip "$output"
  [ "$status" -eq 0 ]
}

@test "vibe queue page: CSP allows only page.js, so HTML in a note runs no script" {
  run "$REPO_ROOT/bin/vibe" queue page
  [ "$status" -eq 0 ]
  grep -q "Content-Security-Policy\" content=\"default-src 'self'; script-src 'self';" "$Q/web/index.html"
  # A panel .md keeps raw tags: no frame of the live page; only listed attributes, so no refresh and no style.
  grep -q "frame-src 'none'; object-src 'none';" "$Q/web/index.html"
  grep -qF "d.querySelectorAll('style')" "$Q/web/page.js"
  grep -qF "/^(href|src|alt|title|type|checked|start)\$/" "$Q/web/page.js"
  grep -q '<script src="/queue/page.js"></script>' "$Q/web/index.html"
  [ "$(grep -c '<script' "$Q/web/index.html")" = 1 ]
  run grep -q "script-src[^;]*unsafe" "$Q/web/index.html"
  [ "$status" -eq 1 ]
}

@test "vibe queue page: Workspaces page and rail from the state files alone: Start, or a place and hours form; Open UI, Stop and time left when up; run tools in one line" {
  local w="$BATS_TEST_TMPDIR/workspaces" st="$Q/workspaces" f="$Q/web/index.html" now
  printf '#!/bin/sh\necho "$*" >>"%s/docker.log"\n' "$STUBS" >"$STUBS/docker"
  chmod +x "$STUBS/docker"
  wsfold
  mkdir -p "$w/one" "$w/loop"
  printf '%s\n' kind=service places=turing "role=One place." >"$w/one/workspace.conf"
  printf '%s\n' label=Loop kind=run places=turing result=folder >"$w/loop/workspace.conf"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<a class="w" href="#workspaces">Workspaces</a><div class="wsl"><a href="#ws-one"><i class="lamp l-off"></i>one</a><a href="#ws-svc"><i class="lamp l-off"></i>Svc</a></div><a class="c" href="#config">Config</a>' "$f"
  grep -qF '<div class="wrow" id="ws-svc"><i class="lamp l-off"></i><div class="t"><b>Svc <span class="role">· Serves one thing.</span></b><span class="why">Off · places: turing, runpod · default 4 h</span></div><div class="jacts" data-name="svc"><span class="ask"><label>Place<select name="place"><option>turing</option><option>runpod</option></select></label><label>Hours<input name="hours" type="number" min="1" value="4"></label><button data-act="ws-start">Start</button></span></div></div>' "$f"
  grep -qF '<span class="why">Off · places: turing</span></div><span class="jacts p" data-name="one"><button data-act="ws-start">Start</button></span></div>' "$f"
  grep -qF '<p class="note">Loop run as queue jobs.</p>' "$f"
  # No hours= in the conf: an optional Hours field; page.js sends no hours, the start has no limit.
  sed -i.bak '/^hours=/d' "$w/svc/workspace.conf"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<span class="why">Off · places: turing, runpod</span>' "$f"
  grep -qF '<label>Hours<input name="hours" type="number" min="1" data-opt placeholder="no limit"></label><button data-act="ws-start">Start</button>' "$f"
  printf '%s\n' label=Svc "role=Serves one thing." kind=service gpu=no places=turing,runpod hours=4 ports=8080 >"$w/svc/workspace.conf"
  grep -qF '<h1><span class="hq">Queue</span><span class="hw">Workspaces</span><span class="hc">Config</span></h1>' "$f"
  now="$(date +%s)"
  mkdir -p "$st/svc" "$st/one"
  echo runpod >"$st/svc/place"
  echo c1 >"$st/svc/id"
  echo $((now - 2100)) >"$st/svc/started"
  echo $((now + 1250)) >"$st/svc/limit"
  echo http://100.64.0.1:8080 >"$st/svc/url"
  echo turing >"$st/one/place"
  echo "vibe: start of one failed — it is down again" >"$st/one/hold.log"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<a href="#ws-svc"><i class="lamp l-ok"></i>Svc</a>' "$f"
  grep -qF '<span class="why">runpod · up 0:35 · <span class="warn">20m left</span></span></div><a class="btn ui" href="http://100.64.0.1:8080" target="_blank" rel="noopener">Open UI ↗</a><span class="jacts p" data-name="svc"><button data-act="ws-stop" data-confirm>Stop</button></span></div>' "$f"
  grep -qF '<span class="why">Off · places: turing · <span class="bad">vibe: start of one failed — it is down again</span></span>' "$f"
  echo $((now + 7230)) >"$st/svc/limit"
  echo c2 >"$st/one/id"
  echo $((now - 60)) >"$st/one/limit"
  echo 'javascript:alert(1)' >"$st/one/url"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<span class="why">runpod · up 0:35 · 2h' "$f"
  grep -qF '<div class="wrow" id="ws-one"><i class="lamp l-bad"></i><div class="t"><b>one <span class="role">· One place.</span></b><span class="why">turing · past limit: the next tick stops it</span></div><span class="jacts p" data-name="one"><button data-act="ws-stop" data-confirm>Stop</button></span></div>' "$f"
  [ "$(grep -c 'javascript:' "$f")" = 0 ]
  [ "$(grep -c '## Tools' "$f")" = 0 ]
  [ ! -e "$STUBS/docker.log" ]
}

@test "vibe-web: a bad Content-Length gets 403; a stalled client blocks nobody" {
  run post /queue/api/pause -H 'Content-Length: -1' --max-time 5
  [ "${lines[1]}" = 403 ]
  run post /queue/api/pause -H 'Content-Length: 70000' --max-time 5
  [ "${lines[1]}" = 403 ]
  python3 -c '
import socket, sys, time
s = socket.create_connection(("127.0.0.1", int(sys.argv[1])))
s.sendall(b"POST /pause HTTP/1.1\r\n")
time.sleep(5)' "$PORT" &
  sleep 0.5
  run req GET /queue/api/whoami -H 'Tailscale-User-Login: me@example.com' --max-time 2
  [ "${lines[1]}" = 200 ]
  [ ! -e "$Q/paused" ]
  kill $! 2>/dev/null || true
}

@test "vibe queue page: two writers at once leave a whole page and no tmp file" {
  local i pids=()
  for i in 1 2 3 4 5 6; do
    "$REPO_ROOT/bin/vibe" queue page >/dev/null &
    pids+=($!)
  done
  for i in "${pids[@]}"; do wait "$i"; done # each must exit 0; a bare wait also waits on the server
  grep -q '</html>' "$Q/web/index.html"
  [ "$(find "$Q/web" -name '*.tmp*' -o -name '*.js.*' | wc -l | tr -d ' ')" = 0 ]
  cmp -s "$REPO_ROOT/templates/queue-page.js" "$Q/web/page.js"
}

# act ROUTE BODY [CURL ARG...] — a write by the right login with a JSON BODY.
act() {
  local r="$1" b="$2"
  shift 2
  req POST "/queue/api/$r" -H 'Tailscale-User-Login: me@example.com' -H "Origin: https://127.0.0.1:$PORT" \
    -H 'Content-Type: application/json' -d "$b" "$@"
}

# qjob ID STATUS — a job dir in the queue; STATUS empty: queued.
qjob() {
  mkdir -p "$Q/queue/$1"
  printf 'repo=%s/proj\nbranch=task\n' "$BATS_TEST_TMPDIR" >"$Q/queue/$1/job"
  echo task >"$Q/queue/$1/prompt.md"
  if [ -n "$2" ]; then echo "$2" >"$Q/queue/$1/status"; fi
}

ID=20261104-080000-proj-task

@test "route conf: sets a key; vibe refuses an unknown key; a newline in the value is 400" {
  run act conf '{"set": "slots=2"}'
  [ "${lines[1]}" = 200 ]
  grep -qx slots=2 "$XDG_CONFIG_HOME/vibe/queue.conf"
  grep -q $'\tvibe queue conf slots=2\t0$' "$Q/actions.log"
  run act conf '{"set": "web_port=1"}'
  [[ "${lines[0]}" == *'"code": 1'* ]] || false
  grep -q $'\tvibe queue conf web_port=1\t1$' "$Q/actions.log"
  grep -qx "web_port=$PORT" "$XDG_CONFIG_HOME/vibe/queue.conf"
  run act conf '{"set": "slots=2\nweb_login=evil@example.com"}'
  [ "${lines[1]}" = 400 ]
  grep -qx web_login=me@example.com "$XDG_CONFIG_HOME/vibe/queue.conf"
  run grep -c evil "$XDG_CONFIG_HOME/vibe/queue.conf"
  [ "$output" = 0 ]
}

@test "route restart: systemctl restarts vibe-queue" {
  run act restart '{}'
  [ "${lines[1]}" = 200 ]
  [ "$(cat "$STUBS/systemctl.log")" = "--user restart vibe-queue" ]
  grep -q $'\tsystemctl --user restart vibe-queue\t0$' "$Q/actions.log"
}

@test "routes: a hung command is killed after the timeout and blocks no later write" {
  touch "$STUBS/hang"
  run act restart '{}'
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 124'* ]] || false
  run act pause '{}' --max-time 10
  [ "${lines[1]}" = 200 ]
  [ -e "$Q/paused" ]
}

@test "route unlimit: the usage limit goes" {
  mkdir -p "$Q"
  echo $(($(date +%s) + 3600)) >"$Q/limit"
  run act unlimit '{}'
  [ "${lines[1]}" = 200 ]
  [ ! -e "$Q/limit" ]
}

@test "route now and noreview: the queued job gets now=1 and after=; the card shows the buttons" {
  qjob "$ID"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -q "data-id=\"$ID\"><button data-act=\"now\">" "$Q/web/index.html"
  grep -q 'data-act="noreview"' "$Q/web/index.html"
  run act now "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 200 ]
  grep -qx now=1 "$Q/queue/$ID/job"
  run act noreview "{\"id\": \"$ID\"}"
  grep -qx after= "$Q/queue/$ID/job"
  run grep -c 'data-act="now"\|data-act="noreview"' "$Q/web/index.html"
  [ "$output" = 0 ]
}

@test "route retry: a failed job is queued again, the old one archived" {
  qjob "$ID" failed
  run act retry "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  [ -d "$Q/archive/$(date +%Y-%m)/$ID" ]
  [ "$(find "$Q/queue" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = 1 ]
}

@test "route cancel: a queued job ends skipped; the card asks for a second tap" {
  qjob "$ID"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -q 'data-act="cancel" data-confirm' "$Q/web/index.html"
  run act cancel "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 200 ]
  [ "$(cat "$Q/queue/$ID/status")" = skipped ]
}

@test "route stop: a running job gets the stop file" {
  qjob "$ID" running
  run act stop "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 200 ]
  [ -s "$Q/queue/$ID/stop" ]
}

@test "route steer: the text reaches the running job's steer FIFO; no text is 400" {
  local d="$Q/queue/$ID"
  qjob "$ID" running
  mkfifo "$d/steer"
  cat "$d/steer" >"$BATS_TEST_TMPDIR/got" &
  local cat=$!
  run act steer "{\"id\": \"$ID\", \"text\": \"keep fp16\"}"
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *"steered $ID"* ]] || false
  wait "$cat"
  [ "$(tr '\0' '\n' <"$BATS_TEST_TMPDIR/got")" = "keep fp16" ]
  grep -q $'\tvibe queue steer '"$ID"$' \'keep fp16\'\t0$' "$Q/actions.log"
  run act steer "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 400 ]
}

# wsfold — a workspaces folder with the service svc (places turing,runpod, hours=4) on stub places that log
# "<verb> hours=<WS_HOURS>" to $STUBS/place.log; vibe-web restarted to see it.
wsfold() {
  local w="$BATS_TEST_TMPDIR/workspaces" p
  mkdir -p "$w/_places" "$w/svc"
  printf '%s\n' label=Svc "role=Serves one thing." kind=service gpu=no places=turing,runpod hours=4 ports=8080 >"$w/svc/workspace.conf"
  for p in turing runpod; do
    cat >"$w/_places/$p" <<EOF
#!/bin/sh
echo "\$1 hours=\$WS_HOURS" >>"$STUBS/place.log"
case "\$1" in
  up) echo c1 >"\$WS_STATE/id" ;;
  url) echo http://100.64.0.1:8080 ;;
  down) rm -f "\$WS_STATE/id" ;;
esac
EOF
    chmod +x "$w/_places/$p"
  done
  export VIBE_WORKSPACES="$w"
  kill "$(cat "$BATS_TEST_TMPDIR/web.pid")"
  web_start
}

@test "routes ws-start and ws-stop: place and hours when given, else the conf's; the stop detaches; a bad name, place or hours is 400" {
  wsfold
  run act ws-start '{"name": "svc", "place": "runpod", "hours": "2"}'
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'*'svc up \u2014 http://100.64.0.1:8080'* ]] || false
  [ "$(cat "$Q/workspaces/svc/place")" = runpod ]
  grep -qx 'up hours=2' "$STUBS/place.log"
  grep -q $'\tvibe ws start svc --place=runpod --hours=2\t0$' "$Q/actions.log"
  run act ws-stop '{"name": "svc"}'
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *"svc stops"* ]] || false
  for _ in $(seq 50); do
    if [ ! -e "$Q/workspaces/svc/stops" ]; then break; fi
    sleep 0.1
  done
  [ ! -e "$Q/workspaces/svc/stops" ]
  grep -q "^down " "$STUBS/place.log"
  run act ws-start '{"name": "svc"}'
  [ "${lines[1]}" = 200 ]
  [ "$(cat "$Q/workspaces/svc/place")" = turing ]
  [ "$(grep '^up ' "$STUBS/place.log" | tail -n 1)" = "up hours=4" ]
  grep -q $'\tvibe ws start svc\t0$' "$Q/actions.log"
  for body in '{}' '{"name": "../x"}' '{"name": "svc", "place": "Turing"}' '{"name": "svc", "place": ""}' \
    '{"name": "svc", "hours": "0"}' '{"name": "svc", "hours": 2}' '{"name": "svc", "hours": "1 --place=vast"}'; do
    run act ws-start "$body"
    [ "${lines[1]}" = 400 ]
  done
  run act ws-stop '{"name": "-x"}'
  [ "${lines[1]}" = 400 ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 3 ]
}

@test "route hold: the note lands in held" {
  qjob "$ID" blocked
  run act hold "{\"id\": \"$ID\", \"note\": \"test it on the robot\"}"
  [ "${lines[1]}" = 200 ]
  [ "$(cat "$Q/queue/$ID/held")" = "test it on the robot" ]
}

@test "route archive: an ended job moves to the archive" {
  qjob "$ID" "done"
  run act archive "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 200 ]
  [ -d "$Q/archive/$(date +%Y-%m)/$ID" ]
}

@test "routes: an absent, non-string or bad id is 400 and runs nothing" {
  qjob "$ID"
  for body in '{}' '{"id": 1}' '{"id": "../x"}' '{"id": "20261104-080000-a/../b"}' '{"id": "--help"}'; do
    run act cancel "$body"
    [ "${lines[1]}" = 400 ]
  done
  run act hold "{\"id\": \"$ID\", \"note\": \"a\tb\"}"
  [ "${lines[1]}" = 400 ]
  [ ! -e "$Q/actions.log" ]
  [ ! -e "$Q/queue/$ID/status" ]
}

# --- M3: review and feature actions -------------------------------------------

# lanejob ID STATUS ITEM [SIDE] — qjob in the lane `ctx` on branch task as ITEM; SIDE: its side branch.
lanejob() {
  qjob "$1" "$2"
  printf 'lane=ctx\nitem=%s\n' "$3" >>"$Q/queue/$1/job"
  printf '# Agent job\n\n## Task\n\nDo %s.\n\n## Rules\n\n1. Obey.\n' "$3" >"$Q/queue/$1/prompt.md"
  if [ -n "${4:-}" ]; then
    echo "$4" >"$Q/queue/$1/side"
    echo abc123 >"$Q/queue/$1/start"
  fi
}

ID2=20261104-070000-proj-task
URL=https://github.com/o/proj/pull/7

# newjob — the one queue dir that is neither $ID nor $ID2.
newjob() { find "$Q/queue" -mindepth 1 -maxdepth 1 ! -name "$ID" ! -name "$ID2"; }

@test "route answer: the answer replaces next action and blockers in HANDOFF.md; commit, push, follow-up queued, original archived" {
  local r wt n
  r="$(make_repo proj)" wt="$BATS_TEST_TMPDIR/wt"
  git -C "$r" worktree add -q -b task "$wt"
  printf '# Handoff\n\n## Next action\n\nPick a plan.\n\n## Blockers\n\nPlan A or B?\n\n## Gotchas\n\n- keep me\n' >"$wt/HANDOFF.md"
  git -C "$wt" add HANDOFF.md && git -C "$wt" commit -q -m "docs: handoff" && git -C "$wt" push -q origin task
  qjob "$ID" blocked
  echo "$wt" >"$Q/queue/$ID/worktree"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<textarea name="text" rows="3"></textarea></label><button data-act="answer">Send answer</button>' "$Q/web/index.html"
  run act answer "{\"id\": \"$ID\", \"text\": \"Plan B.\"}"
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  [ "$(sed -n '/^## Next action/,/^## Gotchas/p' "$wt/HANDOFF.md")" = "$(printf '## Next action\n\nAnswer: Plan B.\n\n## Blockers\n\nAnswer: Plan B.\n\n## Gotchas')" ]
  grep -qx -- '- keep me' "$wt/HANDOFF.md"
  [ "$(git -C "$wt" log -1 --format=%s)" = "docs(handoff): $ID unblocked" ]
  [ "$(git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse task)" = "$(git -C "$wt" rev-parse HEAD)" ]
  [ -d "$Q/archive/$(date +%Y-%m)/$ID" ]
  n="$(newjob)"
  grep -qx branch=task "$n/job"
  [ "$(cat "$n/worktree")" = "$wt" ]
}

@test "vibe queue answer: a relative core.hooksPath runs no hook of the job's tree on the commit and the push" {
  local r wt m="$BATS_TEST_TMPDIR/hooked"
  r="$(make_repo proj)" wt="$BATS_TEST_TMPDIR/wt"
  hook_files "$r" "$m" pre-commit commit-msg post-commit pre-push
  git -C "$r" config core.hooksPath .githooks
  git -C "$r" worktree add -q -b task "$wt"
  printf '# Handoff\n\n## Next action\n\nPick a plan.\n' >"$wt/HANDOFF.md"
  git -C "$wt" add HANDOFF.md && git -C "$wt" -c core.hooksPath=/dev/null commit -q -m "docs: handoff"
  git -C "$wt" -c core.hooksPath=/dev/null push -q origin task
  qjob "$ID" blocked
  echo "$wt" >"$Q/queue/$ID/worktree"
  run "$REPO_ROOT/bin/vibe" queue answer "$ID" "Plan B."
  [ "$status" -eq 0 ]
  [ "$(git -C "$wt" log -1 --format=%s)" = "docs(handoff): $ID unblocked" ]
  [ "$(git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse task)" = "$(git -C "$wt" rev-parse HEAD)" ]
  [ ! -e "$m" ]
}

@test "vibe queue answer: refuses a done job, a queued job on the branch, and a job without HANDOFF.md" {
  qjob "$ID" "done"
  run "$REPO_ROOT/bin/vibe" queue answer "$ID" yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"answer takes blocked, failed or timeout"* ]] || false
  echo blocked >"$Q/queue/$ID/status"
  qjob 20261104-090000-proj-task
  run "$REPO_ROOT/bin/vibe" queue answer "$ID" yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"is queued — wait until it ends"* ]] || false
  rm -rf "$Q/queue/20261104-090000-proj-task"
  run "$REPO_ROOT/bin/vibe" queue answer "$ID" yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"no HANDOFF.md"* ]] || false
  [ "$(find "$Q/queue" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = 1 ]
}

@test "vibe queue answer: lane side job, lane PR merged → <branch>-<item>-retry out of the lane; the prompt names the earlier try" {
  local n
  lanejob "$ID2" "done" alpha
  echo "$URL" >"$Q/queue/$ID2/pr"
  lanejob "$ID" blocked beta task-beta
  echo MERGED >"$STUBS/state"
  run "$REPO_ROOT/bin/vibe" queue answer "$ID" Use the cache.
  [ "$status" -eq 0 ]
  grep -qF -- "pr view $URL --json state" "$STUBS/gh.log"
  n="$(newjob)"
  grep -qx branch=task-beta-retry "$n/job"
  run grep -cE '^(lane=|item=|branch=task$)' "$n/job"
  [ "$output" = 0 ]
  [ "$(sed -n '/^## Task/,/^## Rules/p' "$n/prompt.md")" = "$(printf '## Task\n\nDo beta.\n\nEarlier try: git diff abc123..task-beta. Do not merge it.\nAnswer: Use the cache.\n\n## Rules')" ]
  [ ! -e "$n/worktree" ]
  [ -d "$Q/archive/$(date +%Y-%m)/$ID" ]
}

@test "vibe queue answer: lane side job, lane PR open → the item joins the lane again" {
  local n
  lanejob "$ID2" "done" alpha
  echo "$URL" >"$Q/queue/$ID2/pr"
  lanejob "$ID" failed beta task-beta
  echo OPEN >"$STUBS/state"
  run "$REPO_ROOT/bin/vibe" queue answer "$ID" Use the cache.
  [ "$status" -eq 0 ]
  n="$(newjob)"
  grep -qx branch=task "$n/job"
  grep -qx item=beta "$n/job"
  grep -qx lane=ctx "$n/job"
  grep -qx 'Answer: Use the cache.' "$n/prompt.md"
}

@test "route fix: a follow-up job on the PR's branch, also from an archived job; refuses while one is queued or running" {
  local n
  qjob "$ID" "done"
  echo "$URL" >"$Q/queue/$ID/pr"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -qF "data-pr=\"$URL\"><span class=\"ask\"><label>Fix job: what to change on the PR<textarea name=\"text\" rows=\"3\"></textarea></label><button data-act=\"fix\">" "$Q/web/index.html"
  "$REPO_ROOT/bin/vibe" queue archive "$ID" >/dev/null
  run act fix "{\"pr\": \"$URL\", \"text\": \"Rename foo to bar.\"}"
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  n="$(newjob)"
  grep -qx branch=task "$n/job"
  grep -qF "Fix on $URL (the task above is done; do only this): Rename foo to bar." "$n/prompt.md"
  run "$REPO_ROOT/bin/vibe" queue fix "$URL" again
  [ "$status" -eq 1 ]
  [[ "$output" == *"is queued — wait until it ends"* ]] || false
  echo running >"$n/status"
  run "$REPO_ROOT/bin/vibe" queue fix "$URL" again
  [ "$status" -eq 1 ]
  [[ "$output" == *"is running — wait until it ends"* ]] || false
  run "$REPO_ROOT/bin/vibe" queue fix https://github.com/o/proj/pull/99 x
  [ "$status" -eq 1 ]
  [[ "$output" == *"no job has PR"* ]] || false
  run act fix '{"pr": "https://evil.example.com/pull/7", "text": "x"}'
  [ "${lines[1]}" = 400 ]
}

@test "vibe queue ready: refuses a failing check and SPEC.md, RESEARCH.md or HANDOFF.md in the diff; then marks no PR ready" {
  printf 'SUCCESS\nFAILURE\n' >"$STUBS/checks"
  run "$REPO_ROOT/bin/vibe" queue ready "$URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"has a failing check"* ]] || false
  echo SUCCESS >"$STUBS/checks"
  printf 'a.txt\nSPEC.md\n' >"$STUBS/files"
  run "$REPO_ROOT/bin/vibe" queue ready "$URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"still holds SPEC.md, RESEARCH.md or HANDOFF.md"* ]] || false
  printf 'RESEARCH.md\n' >"$STUBS/files"
  run "$REPO_ROOT/bin/vibe" queue ready "$URL"
  [ "$status" -eq 1 ]
  printf 'HANDOFF.md\n' >"$STUBS/files-8"
  printf 'templates/HANDOFF.md\n' >"$STUBS/files"
  run "$REPO_ROOT/bin/vibe" queue ready "$URL" https://github.com/o/proj/pull/8
  [ "$status" -eq 1 ]
  run grep -c 'pr ready' "$STUBS/gh.log"
  [ "$output" = 0 ]
  printf 'PENDING\nSKIPPED\n' >"$STUBS/checks"
  run "$REPO_ROOT/bin/vibe" queue ready "$URL"
  [ "$status" -eq 0 ]
  grep -qx "pr ready $URL" "$STUBS/gh.log"
}

@test "route feature-ready: each member PR checked, then ready, then the feature; refuses a failing member" {
  mkdir -p "$Q/features"
  printf '# Feature\n\n**Context:** c\n\n## Members\n\n- /x/a sticks %s\n- /x/b pad https://github.com/o/b/pull/3\n' "$URL" >"$Q/features/teleop.md"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -q 'data-feature="teleop"><button data-act="feature-ready" data-confirm' "$Q/web/index.html"
  echo FAILURE >"$STUBS/checks-3"
  run act feature-ready '{"feature": "teleop"}'
  [[ "${lines[0]}" == *'"code": 1'* ]] || false
  [ ! -e "$Q/features/teleop.ready" ]
  rm "$STUBS/checks-3"
  run act feature-ready '{"feature": "teleop"}'
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  grep -qx "pr ready $URL" "$STUBS/gh.log"
  grep -qx "pr ready https://github.com/o/b/pull/3" "$STUBS/gh.log"
  [ -e "$Q/features/teleop.ready" ]
  grep -q 'data-act="feature-archive" data-confirm' "$Q/web/index.html"
  run act feature-ready '{"feature": "teleop"}'
  [[ "${lines[0]}" == *"is merge"* ]] || false
}

@test "route feature-archive: refuses an open member PR; archives once none is open" {
  mkdir -p "$Q/features"
  printf '# Feature\n\n## Members\n\n- /x/a sticks %s\n- /x/b pad https://github.com/o/b/pull/3\n' "$URL" >"$Q/features/teleop.md"
  echo MERGED >"$STUBS/state"
  echo OPEN >"$STUBS/state-3"
  run act feature-archive '{"feature": "teleop"}'
  [[ "${lines[0]}" == *'"code": 1'* ]] || false
  [[ "${lines[0]}" == *"pull/3 is open"* ]] || false
  [ -f "$Q/features/teleop.md" ]
  echo CLOSED >"$STUBS/state-3"
  run act feature-archive '{"feature": "teleop"}'
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  [ -f "$Q/archive/$(date +%Y-%m)/features/teleop.md" ]
  run act feature-archive '{"feature": "../teleop"}'
  [ "${lines[1]}" = 400 ]
}

@test "page: a research card has Stop question and Stop now; a worker in paste has a Copy per step and a field that answers it" {
  local f="$Q/web/index.html" c="$Q/queue/20261117-100000-proj-research-lr"
  research_fixture "$Q/queue" "$BATS_TEST_TMPDIR/proj"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<div class="jacts" data-research="lr"><button data-act="research-stop" title="No new worker: each run finishes">Stop question</button><hr><button data-act="research-stop-now" data-confirm title="Cut every run now">Stop now</button></div>' "$f"
  grep -qF '<div class="paste"><ol><li><code>git fetch the commit</code><button type="button" data-copy>Copy</button></li><li><code>sbatch runs/h3/job.sbatch</code><button type="button" data-copy>Copy</button></li><li><code>print the RESULT line</code><button type="button" data-copy>Copy</button></li></ol><div class="jacts" data-id="20261117-100300-proj-research-lr-h3"><span class="ask"><label>The RESULT line from the cluster: the worker closes its run with it<textarea name="text" rows="3"></textarea></label><button data-act="answer">Send answer</button></span></div></div>' "$f"
  [ "$(grep -o 'data-copy' "$f" | wc -l)" -eq 3 ]
  run grep -c 'research-archive' "$f"
  [ "$output" = 0 ]
  # A finished question has Archive, no stop buttons, and a worker with no paste has no panel.
  echo done >"$Q/queue/20261117-100300-proj-research-lr-h3/status"
  echo done >"$Q/queue/20261117-100200-proj-research-lr-h2/status"
  "$REPO_ROOT/bin/vibe" queue page
  run grep -c 'research-stop\|data-copy' "$f"
  [ "$output" = 0 ]
  grep -qF '<div class="jacts" data-research="lr"><button data-act="research-archive" data-confirm>Archive</button></div>' "$f"
}

@test "page: a blocked research worker with no paste.md has the answer field of its own job" {
  local f="$Q/web/index.html"
  research_fixture "$Q/queue" "$BATS_TEST_TMPDIR/proj"
  rm "$Q/queue/20261117-100300-proj-research-lr-h3/paste.md"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<span class="n">blocked · slurm</span>' "$f"
  grep -qF '<div class="jacts" data-id="20261117-100300-proj-research-lr-h3"><span class="ask"><label>Your answer: the job runs again with it<textarea name="text" rows="3"></textarea></label><button data-act="answer">Send answer</button></span></div></div>' "$f"
  run grep -c 'class="paste"' "$f"
  [ "$output" = 0 ]
}

@test "route research-archive: vibe queue archive --research <slug>; a bad slug is 400" {
  run act research-archive '{"research": "lr"}'
  grep -q $'\tvibe queue archive --research lr\t[0-9]*$' "$Q/actions.log"
  run act research-archive '{"research": "-x"}'
  [ "${lines[1]}" = 400 ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 1 ]
}

@test "route research-stop: vibe queue stop --research <slug>; a bad slug or none is 400" {
  run act research-stop '{"research": "lr"}'
  grep -q $'\tvibe queue stop --research lr\t[0-9]*$' "$Q/actions.log"
  run act research-stop '{"research": "-x"}'
  [ "${lines[1]}" = 400 ]
  run act research-stop '{"research": "../lr"}'
  [ "${lines[1]}" = 400 ]
  run act research-stop '{}'
  [ "${lines[1]}" = 400 ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 1 ]
}

@test "route research-stop-now: vibe queue stop --research <slug> --now" {
  run act research-stop-now '{"research": "lr"}'
  grep -q $'\tvibe queue stop --research lr --now\t[0-9]*$' "$Q/actions.log"
  run act research-stop-now '{"research": "lr x"}'
  [ "${lines[1]}" = 400 ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 1 ]
}

@test "route merge-order: smallest first; each PR names the later ones that share a file; a bad repo is 400" {
  local r b
  r="$(make_repo proj)"
  printf '30\t12\n5\t14\n100\t15\n' >"$STUBS/prs"
  printf 'a.txt\nb.txt\n' >"$STUBS/files-12"
  printf 'a.txt\n' >"$STUBS/files-14"
  printf 'c.txt\n' >"$STUBS/files-15"
  run "$REPO_ROOT/bin/vibe" queue merge-order "$r"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '1. #14 — 5 lines — can conflict: #12\n2. #12 — 30 lines\n3. #15 — 100 lines')" ]
  grep -q -- '^pr list --state open --limit 1000 ' "$STUBS/gh.log"
  qjob "$ID" "done"
  echo https://github.com/o/proj/pull/12 >"$Q/queue/$ID/pr"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -qF "<div class=\"jacts\" data-repo=\"$r\"><button data-act=\"merge-order\">" "$Q/web/index.html"
  run act merge-order "{\"repo\": \"$r\"}"
  [[ "${lines[0]}" == *'1. #14'* ]] || false
  for b in '{"repo": "rel/path"}' '{"repo": "/a/../b"}' '{"repo": "/-x"}'; do
    run act merge-order "$b"
    [ "${lines[1]}" = 400 ]
  done
  : >"$STUBS/prs"
  run "$REPO_ROOT/bin/vibe" queue merge-order "$r"
  [ "$output" = "no ready PR in proj" ]
}

@test "vibe queue fix: from a review round, an agent job with the base job's timeout, no review=" {
  local n
  qjob "$ID" "done"
  echo timeout=3h >>"$Q/queue/$ID/job"
  qjob "$ID-review2" "done"
  printf 'timeout=1h\nfollow=1\nreview=2\n' >>"$Q/queue/$ID-review2/job"
  echo "$URL" >"$Q/queue/$ID-review2/pr"
  run "$REPO_ROOT/bin/vibe" queue fix "$URL" Rename foo.
  [ "$status" -eq 0 ]
  n="$(find "$Q/queue" -mindepth 1 -maxdepth 1 ! -name "$ID" ! -name "$ID-review2")"
  grep -qx timeout=3h "$n/job"
  run grep -cE '^(review|follow|timeout=1h)' "$n/job"
  [ "$output" = 0 ]
}

# --- M4: new work and recurring jobs -------------------------------------------

# qnew — the one queue dir there is.
qnew() { find "$Q/queue" -mindepth 1 -maxdepth 1; }

# no_slot PROMPT — true when no slot of job-prompt.md (title, `## Task`, the two templates) is left in PROMPT.
no_slot() {
  local s
  while IFS= read -r s; do
    if sed '/^## Output templates/q' "$1" | grep -qF -- "$s"; then
      echo "slot left: $s"
      return 1
    fi
  done < <(awk 'NR == 1 || /^## Task/ { on = 1 } /^## Rules/ { on = 0 } on' "$REPO_ROOT/skills/fill-queue/references/job-prompt.md" | grep -o '<[^>]*>')
  ! grep -q '<the .* template, verbatim>' "$1"
}

@test "vibe queue new: every slot filled; refuses no done-when and a queued branch" {
  local r n
  r="$(make_repo proj)"
  run "$REPO_ROOT/bin/vibe" queue new "$r" feat-x "" Add x.
  [ "$status" -ne 0 ]
  [[ "$output" == *"no done-when"* ]] || false
  [ ! -d "$Q/queue" ] || [ -z "$(qnew)" ]
  run "$REPO_ROOT/bin/vibe" queue new "$r" feat-x 'bats tests/x.bats passes' Add the x feature.
  [ "$status" -eq 0 ]
  n="$(qnew)"
  no_slot "$n/prompt.md"
  grep -qx "repo=$r" "$n/job"
  grep -qx branch=feat-x "$n/job"
  grep -qx 'context=Add the x feature.' "$n/job"
  grep -qx 'Add the x feature.' "$n/prompt.md"
  grep -qxF -- '- **Done when:** bats tests/x.bats passes' "$n/prompt.md"
  grep -qxF -- '- **Source:** new' "$n/prompt.md"
  grep -qxF '**Decisions/risks:** <risks>' "$n/prompt.md"
  run "$REPO_ROOT/bin/vibe" queue new "$r" feat-x 'it works' Again.
  [ "$status" -ne 0 ]
  [[ "$output" == *"feat-x is queued"* ]] || false
  [ "$(qnew | wc -l | tr -d ' ')" = 1 ]
}

@test "route new: queues the job; an absent done-when or a bad branch is 400" {
  local r
  r="$(make_repo proj)"
  run act new "{\"repo\": \"$r\", \"branch\": \"feat-y\", \"done\": \"grep -q y y.txt\", \"task\": \"Write y.\"}"
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  grep -qx branch=feat-y "$(qnew)/job"
  run act new "{\"repo\": \"$r\", \"branch\": \"feat-z\", \"done\": \"\", \"task\": \"Write z.\"}"
  [ "${lines[1]}" = 400 ]
  run act new "{\"repo\": \"$r\", \"branch\": \"-x\", \"done\": \"d\", \"task\": \"t\"}"
  [ "${lines[1]}" = 400 ]
  [ "$(qnew | wc -l | tr -d ' ')" = 1 ]
}

# shellcheck disable=SC2016  # Markdown backticks, not expansions
@test "vibe queue roadmap: without --full each item is its title, a long one cut at 80; a bad flag is refused" {
  local r long
  r="$(make_repo proj)"
  long="$(printf 'x%.0s' {1..90})"
  printf -- '- [ ] **Item one** — do it.\n      Done when `make check` passes.\n- [ ] %s\n' "$long" >"$r/PROJECT_ROADMAP.md"
  git -C "$r" add PROJECT_ROADMAP.md && git -C "$r" commit -q -m roadmap && git -C "$r" push -q origin main
  run "$REPO_ROOT/bin/vibe" queue roadmap "$r"
  [ "$status" -eq 0 ]
  [ "$output" = "1: Item one"$'\n'"3: ${long:0:80}…" ]
  run "$REPO_ROOT/bin/vibe" queue roadmap --all "$r"
  [ "$status" -ne 0 ]
  [[ "$output" == *'usage: vibe queue roadmap [--full] <repo>'* ]] || false
}

# shellcheck disable=SC2016  # Markdown backticks, not expansions
@test "route roadmap: the open items of origin's PROJECT_ROADMAP.md with their line; roadmap-new queues one" {
  local r n
  r="$(make_repo proj)"
  printf '# Roadmap\n\n## Items\n\n- [ ] **Item one** — do it.\n      Done when `make check` passes.\n- [x] **Old** — gone.\n- [ ] Item two has no done-when.\n' >"$r/PROJECT_ROADMAP.md"
  git -C "$r" add PROJECT_ROADMAP.md && git -C "$r" commit -q -m roadmap && git -C "$r" push -q origin main
  printf '# Roadmap\n\n- [ ] **Local only** — not pushed.\n' >"$r/PROJECT_ROADMAP.md"
  git -C "$r" commit -q -am local
  run act roadmap "{\"repo\": \"$r\"}"
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'5: **Item one** '*'Done when `make check` passes.\n8: Item two has no done-when.'* ]] || false
  [[ "${lines[0]}" != *'Local only'* ]] || false
  run act roadmap-new "{\"repo\": \"$r\", \"line\": \"8\", \"branch\": \"item-two\"}"
  [[ "${lines[0]}" == *'"code": 1'*'no done-when'* ]] || false
  run act roadmap-new "{\"repo\": \"$r\", \"line\": \"5\", \"branch\": \"item-one\"}"
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  n="$(qnew)"
  no_slot "$n/prompt.md"
  grep -qxF -- '- **Source:** `PROJECT_ROADMAP.md:5`' "$n/prompt.md"
  grep -qxF -- '- **Done when:** `make check` passes.' "$n/prompt.md"
  grep -qx 'context=Item one' "$n/job"
  run act roadmap-new "{\"repo\": \"$r\", \"line\": \"0\", \"branch\": \"x\"}"
  [ "${lines[1]}" = 400 ]
}

# optin REPO JOB — REPO opts into the catalogue JOB, committed.
optin() {
  mkdir -p "$1/.vibe-jobs"
  printf -- '---\n---\n\nCheck it.\n' >"$1/.vibe-jobs/$2.md"
  git -C "$1" add .vibe-jobs && git -C "$1" commit -q -m "opt in $2"
}

@test "vibe job reset and route reset: the fails file goes; the page shows Reset only for a stopped job" {
  local r f="$Q/jobs/proj/codebase-health/fails"
  r="$(make_repo proj)"
  optin "$r" codebase-health
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF "data-job=\"codebase-health\"><button data-act=\"run\">codebase-health</button></div>" "$Q/web/index.html"
  mkdir -p "${f%/*}" && echo 2 >"$f"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<button data-act="reset">Reset codebase-health</button>' "$Q/web/index.html"
  run "$REPO_ROOT/bin/vibe" job list "$r"
  [[ "$output" == *"vibe job reset proj codebase-health"* ]] || false
  run "$REPO_ROOT/bin/vibe" job reset proj codebase-health
  [ "$status" -eq 0 ]
  [ ! -e "$f" ]
  echo 2 >"$f"
  run act reset "{\"repo\": \"$r\", \"job\": \"codebase-health\"}"
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  [ ! -e "$f" ]
  run act reset "{\"repo\": \"$r\", \"job\": \"../x\"}"
  [ "${lines[1]}" = 400 ]
}

@test "route run: one recurring job queued now" {
  local r
  r="$(make_repo proj)"
  optin "$r" codebase-health
  run act run "{\"repo\": \"$r\", \"job\": \"codebase-health\"}"
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  grep -qx branch=jobs/codebase-health "$(qnew)/job"
  grep -qx recurring=codebase-health "$(qnew)/job"
}

@test "route triage: vibe job triage writes its lines" {
  local r
  r="$(make_repo proj)"
  printf '7\037%s\037task\037main\037MERGEABLE\037lint\0370\n' "$URL" >"$STUBS/prs"
  run act triage '{}'
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  grep -q 'CI red: lint' "$Q/triage.md"
  grep -q '^pr list --label agent' "$STUBS/gh.log"
  grep -q '<button data-act="triage">' "$Q/web/index.html"
}

# shellcheck disable=SC2016  # a literal $PWD in the prompt
@test "route opt-in: a new job on opt-in-<job> that runs vibe job add; refuses an unknown or opted-in job" {
  local r n
  r="$(make_repo proj)"
  run act opt-in "{\"repo\": \"$r\", \"job\": \"stale-state\"}"
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  n="$(qnew)"
  grep -qx branch=opt-in-stale-state "$n/job"
  grep -qF 'vibe job add "$PWD" stale-state' "$n/prompt.md"
  no_slot "$n/prompt.md"
  run act opt-in "{\"repo\": \"$r\", \"job\": \"nosuch\"}"
  [[ "${lines[0]}" == *'"code": 1'*"no recurring job 'nosuch'"* ]] || false
  optin "$r" lean-audit
  run act opt-in "{\"repo\": \"$r\", \"job\": \"lean-audit\"}"
  [[ "${lines[0]}" == *'"code": 1'*'already has'* ]] || false
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF "<option value=\"$r\">proj</option></select></label><label>Task<textarea name=\"task\" rows=\"3\"></textarea></label><label>Done when: a command that checks it<input name=\"done\"></label><label>Branch slug<input name=\"branch\"></label><button data-act=\"new\">Queue job</button>" "$Q/web/index.html"
  grep -qF "<div class=\"jacts\" data-repo=\"$r\"><span class=\"lbl\">proj</span><button data-act=\"roadmap\">Roadmap</button><span class=\"ask\"><label>Recurring job<select name=\"job\">" "$Q/web/index.html"
  grep -qF '<option>stale-state</option>' "$Q/web/index.html"
  run grep -qF '<option>lean-audit</option>' "$Q/web/index.html"
  [ "$status" -eq 1 ]
}

# shellcheck disable=SC2016  # Markdown backticks, not expansions
@test "roadmap-new: takes the item you listed, at its line on origin now; refuses one changed since" {
  local r n
  r="$(make_repo proj)"
  printf -- '- [ ] **A** — a. Done when `a` passes.\n- [ ] **B** — b. Done when `b` passes.\n' >"$r/PROJECT_ROADMAP.md"
  git -C "$r" add PROJECT_ROADMAP.md && git -C "$r" commit -q -m roadmap && git -C "$r" push -q origin main
  run act roadmap "{\"repo\": \"$r\"}"
  [[ "${lines[0]}" == *'1: **A** '*'2: **B** '* ]] || false
  # A merged PR deletes the finished item A: B moves up to line 1.
  printf -- '- [ ] **B** — b. Done when `b` passes.\n' >"$r/PROJECT_ROADMAP.md"
  git -C "$r" commit -q -am "drop A" && git -C "$r" push -q origin main
  run act roadmap-new "{\"repo\": \"$r\", \"line\": \"2\", \"branch\": \"item-b\"}"
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  n="$(qnew)"
  grep -qx 'context=B' "$n/job"
  grep -qxF -- '- **Source:** `PROJECT_ROADMAP.md:1`' "$n/prompt.md"
  printf -- '- [ ] **B** — b, changed. Done when `b` passes.\n' >"$r/PROJECT_ROADMAP.md"
  git -C "$r" commit -q -am "change B" && git -C "$r" push -q origin main
  run act roadmap-new "{\"repo\": \"$r\", \"line\": \"2\", \"branch\": \"item-b2\"}"
  [[ "${lines[0]}" == *'"code": 1'*'changed or left origin'* ]] || false
  [ "$(qnew | wc -l | tr -d ' ')" = 1 ]
}

@test "routes: a long output keeps its first and its last lines" {
  local r i
  r="$(make_repo proj)"
  for i in $(seq 1 400); do printf -- '- [ ] Item %03d %s\n' "$i" "$(printf '%070d' 0)"; done >"$r/PROJECT_ROADMAP.md"
  git -C "$r" add PROJECT_ROADMAP.md && git -C "$r" commit -q -m roadmap && git -C "$r" push -q origin main
  run act roadmap "{\"repo\": \"$r\"}"
  [[ "${lines[0]}" == *'"out": "1: Item 001 '* ]] || false
  [[ "${lines[0]}" == *'400: Item 400 '* ]] || false
}

@test "queue.conf: a trailing # comment, as in the docs, is no part of the value" {
  kill "$(cat "$BATS_TEST_TMPDIR/web.pid")" && wait "$(cat "$BATS_TEST_TMPDIR/web.pid")" || true
  printf 'slots=2   # two\nweb_port=%s      # the page endpoint\nweb_login=me@example.com   # your login\n' "$PORT" >"$XDG_CONFIG_HOME/vibe/queue.conf"
  web_start
  run curl -s -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:$PORT/whoami"
  [ "$output" = '{"login": "me@example.com"}' ]
  run "$REPO_ROOT/bin/vibe" queue status
  [[ "${lines[0]}" == *"· 2 slots" ]] || false
}

@test "route retry: a failed review round comes back as an agent job: no review= or follow=, the base job's timeout" {
  local n
  qjob "$ID" "done"
  echo timeout=3h >>"$Q/queue/$ID/job"
  qjob "$ID-review1" failed
  printf 'timeout=1h\nfollow=1\nreview=1\n' >>"$Q/queue/$ID-review1/job"
  run act retry "{\"id\": \"$ID-review1\"}"
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  n="$(find "$Q/queue" -mindepth 1 -maxdepth 1 ! -name "$ID")"
  grep -qx timeout=3h "$n/job"
  run grep -cE '^(review|follow|timeout=1h)' "$n/job"
  [ "$output" = 0 ]
}

@test "queue.conf: after=review with a trailing # comment still reviews; the card shows No review" {
  printf 'web_port=%s\nweb_login=me@example.com\nafter=review   # review every job\n' "$PORT" >"$XDG_CONFIG_HOME/vibe/queue.conf"
  qjob "$ID"
  "$REPO_ROOT/bin/vibe" queue page
  grep -q 'data-act="noreview"' "$Q/web/index.html"
  printf 'web_port=%s\nweb_login=me@example.com\nafter=   # off\n' "$PORT" >"$XDG_CONFIG_HOME/vibe/queue.conf"
  "$REPO_ROOT/bin/vibe" queue page
  run grep -c 'data-act="noreview"' "$Q/web/index.html"
  [ "$output" = 0 ]
}

@test "route gpu-cancel: the GPU run goes; the job ends failed with no follow-up; the card asks for a second tap" {
  local g
  qjob "$ID" gpu
  g="$("$REPO_ROOT/bin/gpu-queue" submit --name x --dir "$BATS_TEST_TMPDIR" --then "$REPO_ROOT/bin/vibe queue follow $Q/queue/$ID" -- true)"
  echo "$g" >"$Q/queue/$ID/gpu-job"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -q "data-gpu=\"$g\"><button data-act=\"gpu-cancel\" data-confirm>" "$Q/web/index.html"
  run act gpu-cancel '{"gpu": "../x"}'
  [ "${lines[1]}" = 400 ]
  run act gpu-cancel "{\"gpu\": \"$g\"}"
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  [ "$(cat "$Q/queue/$ID/status")" = failed ]
  [ "$(cat "$Q/queue/$ID/note")" = "GPU run cancelled" ]
  [ ! -e "$Q/queue/$ID-gpu" ]
}

@test "routes servers and server-restart: systemctl restarts claude-rc@<name>; a glob or option is 400" {
  run act servers '{}'
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'*"role: server"* ]] || false
  run act server-restart '{"server": "agentic-dev-toolkit"}'
  [ "${lines[1]}" = 200 ]
  grep -qx -- '--user restart claude-rc@agentic-dev-toolkit' "$STUBS/systemctl.log"
  for body in '{"server": "*"}' '{"server": "-x"}' '{"server": "a b"}' '{}'; do
    run act server-restart "$body"
    [ "${lines[1]}" = 400 ]
  done
  [ "$(grep -c restart "$STUBS/systemctl.log")" = 1 ]
  run "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<span class="ask"><label>Server to restart (Servers lists them)<input name="server"></label><button data-act="server-restart" data-confirm>Restart server</button></span>' "$Q/web/index.html"
}

@test "routes worktrees and worktree-remove: a merged one goes; dirty, unpushed and locked stay" {
  local r w
  r="$(make_repo proj)"
  w="$r/.claude/worktrees"
  for b in merged dirty unpushed locked; do git -C "$r" worktree add -q -b "$b" "$w/$b"; done
  echo x >"$w/dirty/x.txt"
  git -C "$w/unpushed" commit -q --allow-empty -m "local work"
  git -C "$r" worktree lock "$w/locked"
  run act worktrees "{\"repo\": \"$r\"}"
  [ "${lines[1]}" = 200 ]
  for b in merged dirty unpushed locked; do
    [[ "${lines[0]}" == *"$b\\t$w/$b"* ]] || false
  done
  for b in dirty unpushed locked; do
    run act worktree-remove "{\"path\": \"$w/$b\"}"
    [ "${lines[1]}" = 200 ]
    [[ "${lines[0]}" == *'"code": 1'*"skip $w/$b: $b"* ]] || false
    [ -d "$w/$b" ]
  done
  run act worktree-remove "{\"path\": \"$w/merged\"}"
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  [ ! -e "$w/merged" ]
  run act worktree-remove "{\"path\": \"$w/../../x\"}"
  [ "${lines[1]}" = 400 ]
  echo "$r" >"$XDG_CONFIG_HOME/vibe/repos"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -qF "action('Remove', 'worktree-remove', { confirm: '' })" "$Q/web/page.js"
  grep -qF "<label>Repo<select name=\"repo\"><option value=\"$r\">proj</option></select></label><button data-act=\"worktrees\">Worktrees</button>" "$Q/web/index.html"
}

@test "route sync: vibe sync --all pushes a worktree's new branch" {
  local r
  r="$(make_repo proj)"
  git -C "$r" worktree add -q -b feat "$r/.claude/worktrees/feat"
  git -C "$r/.claude/worktrees/feat" commit -q --allow-empty -m "feat work"
  run act sync '{}'
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'*pushed*feat* ]] || false
  git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/feat
  grep -q $'\tvibe sync --all\t0$' "$Q/actions.log"
}

@test "route update-toolkit: pulls, installs; a changed endpoint is not restarted under the request" {
  local t o
  t="$(make_repo kit)"
  printf '#!/bin/sh\necho "install $*" >>"%s/install.log"\n' "$STUBS" >"$t/install.sh"
  chmod +x "$t/install.sh"
  git -C "$t" add install.sh && git -C "$t" commit -q -m installer && git -C "$t" push -q origin main
  o="$(clone_repo kit kit-other)"
  mkdir -p "$o/bin" && echo new >"$o/bin/vibe-web"
  git -C "$o" add bin && git -C "$o" commit -q -m endpoint && git -C "$o" push -q origin main
  kill "$(cat "$BATS_TEST_TMPDIR/web.pid")" && wait "$(cat "$BATS_TEST_TMPDIR/web.pid")" || true
  VIBE_TOOLKIT="$t" web_start
  run act update-toolkit '{}'
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'*"page endpoint restarts after this reply"* ]] || false
  [ "$(git -C "$t" rev-parse HEAD)" = "$(git -C "$o" rev-parse HEAD)" ]
  [ "$(cat "$STUBS/install.log")" = "$(printf 'install \ninstall doctor')" ]
  run grep vibe-web "$STUBS/systemctl.log"
  [ "$status" -ne 0 ]
  run "$REPO_ROOT/bin/vibe" queue page
  grep -q 'data-act="update-toolkit" data-confirm' "$Q/web/index.html"
}

# get PATH [CURL ARG...] — a read by the right login: the body, then the HTTP code.
get() {
  local p="$1"
  shift
  req GET "$p" -H 'Tailscale-User-Login: me@example.com' "$@"
}

@test "route job/<id>/<file>: only the listed files, as plain text; the log's tail; no ../, other file or symlink" {
  local d="$Q/queue/$ID"
  qjob "$ID" "done"
  echo "# the report" >"$d/report.md"
  echo "gate ok" >"$d/gate.log"
  ln -s "$d/job" "$d/pr.md"
  python3 -c 'import sys; [print("line %06d %s" % (i, "x" * 90)) for i in range(2000)]' >"$d/log"
  run get "/queue/api/job/$ID/report.md"
  [ "${lines[0]}" = "# the report" ]
  [ "${lines[1]}" = 200 ]
  run curl -s -D - -o /dev/null -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:$PORT/job/$ID/gate.log"
  [[ "$output" == *"Content-Type: text/plain; charset=utf-8"*"X-Content-Type-Options: nosniff"* ]] || false
  run get "/job/$ID/log"
  [ "${lines[2000 - 1]-}" = "" ] # the tail only
  [[ "$output" == *$'\nline 001999 '*$'\n200' ]] || false
  [ "${#output}" -le 65540 ]
  for p in "job/$ID/job" "job/$ID/pr.md" "job/$ID/../$ID/note" "job/$ID/.." "job/../queue/$ID/note" "job/$ID/missing/note"; do
    run get "/queue/api/$p" --path-as-is
    [[ "$output" == *$'\n404' ]] || false
  done
  run req GET "/job/$ID/report.md"
  [ "${lines[1]}" = 403 ]
  run "$REPO_ROOT/bin/vibe" queue page
  grep -q "href=\"/queue/api/job/$ID/report.md\">report.md</a>" "$Q/web/index.html"
  grep -q "href=\"/queue/api/job/$ID/log\">log</a>" "$Q/web/index.html"
}

@test "route job/<id>/tool.log, out/report.md, out/files: the log's tail, the report, the file list; a link out of the job dir is 404" {
  local d="$Q/queue/$ID"
  qjob "$ID" running
  printf 'tool=kapso\n' >>"$d/job"
  python3 -c 'import sys; [print("step %06d %s" % (i, "x" * 90)) for i in range(2000)]' >"$d/tool.log"
  run get "/queue/api/job/$ID/tool.log"
  [[ "$output" == *$'\nstep 001999 '*$'\n200' ]] || false
  [ "${#output}" -le 65540 ]
  mkdir -p "$d/out/files/sub" "$BATS_TEST_TMPDIR/secret"
  echo "# Tool report" >"$d/out/report.md"
  echo a,b >"$d/out/files/table.csv"
  echo x >"$d/out/files/sub/b.txt"
  run get "/queue/api/job/$ID/out/report.md"
  [ "${lines[0]}" = "# Tool report" ]
  run get "/queue/api/job/$ID/out/files/"
  [ "$output" = "$(printf 'table.csv\nsub/b.txt\n\n200')" ]
  # A name that is not UTF-8 (Linux; APFS refuses it): a ? in the list, not a dropped connection.
  if touch "$d/out/files/caf$(printf '\351').txt" 2>/dev/null; then
    run get "/queue/api/job/$ID/out/files/"
    [ "${lines[0]}" = "caf?.txt" ]
    [ "${lines[3]}" = 200 ]
    rm "$d/out/files/caf"*
  fi
  # gate.log is no log tail: the first line, the command, stays.
  { echo '$ make test' && python3 -c 'print("x" * 100000)'; } >"$d/gate.log"
  run get "/queue/api/job/$ID/gate.log"
  [ "${lines[0]}" = '$ make test' ]
  "$REPO_ROOT/bin/vibe" queue page
  grep -q "href=\"/queue/api/job/$ID/tool.log\">tool.log</a>" "$Q/web/index.html"
  grep -q "href=\"/queue/api/job/$ID/out/report.md\">out/report.md</a>" "$Q/web/index.html"
  grep -q "href=\"/queue/api/job/$ID/out/files\">out/files/</a>" "$Q/web/index.html"
  echo hidden >"$BATS_TEST_TMPDIR/secret/report.md"
  rm -rf "$d/out/files"
  ln -s "$BATS_TEST_TMPDIR/secret" "$d/out/files"
  for p in out/files out/job out/report.md/x; do
    run get "/queue/api/job/$ID/$p"
    [[ "$output" == *$'\n404' ]] || false
  done
  rm -rf "$d/out"
  ln -s "$BATS_TEST_TMPDIR/secret" "$d/out"
  run get "/queue/api/job/$ID/out/report.md"
  [[ "$output" == *$'\n404' ]] || false
}

@test "route job/<id>/<file>?html: a .md through pandoc under the API's CSP; without pandoc escaped; other files stay text" {
  local d="$Q/queue/$ID" bin="$BATS_TEST_TMPDIR/nopandoc"
  qjob "$ID" "done"
  printf '# the report\n\n<i>raw</i> **bold**\n' >"$d/report.md"
  echo "gate ok" >"$d/gate.log"
  run get "/queue/api/job/$ID/report.md?html"
  [[ "$output" == *'<h1>the report</h1>'*'<strong>bold</strong>'*$'\n200' ]] || false
  run curl -s -D - -o /dev/null -H 'Tailscale-User-Login: me@example.com' "http://127.0.0.1:$PORT/job/$ID/report.md?html"
  [[ "$output" == *"Content-Type: text/html; charset=utf-8"*"nosniff"*"Content-Security-Policy: default-src 'none'"* ]] || false
  run get "/job/$ID/gate.log?html"
  [ "${lines[0]}" = "gate ok" ]
  run req GET "/job/$ID/report.md?html"
  [ "${lines[1]}" = 403 ]
  kill "$(cat "$BATS_TEST_TMPDIR/web.pid")"
  mkdir -p "$bin"
  printf '#!/bin/sh\nexit 1\n' >"$bin/pandoc"
  chmod +x "$bin/pandoc"
  PATH="$bin:$PATH" web_start
  run get "/job/$ID/report.md?html"
  [[ "$output" == '<pre># the report'*'&lt;i&gt;raw&lt;/i&gt; **bold**'*'</pre>'$'\n200' ]] || false
}

@test "routes: output that is not UTF-8 still gets a reply and a log line" {
  printf '#!/bin/sh\nprintf "bad \\377 byte\\n"\n' >"$STUBS/systemctl"
  run act restart '{}'
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'*'bad '?'ufffd byte'* ]] || false
  grep -q $'\tsystemctl --user restart vibe-queue\t0$' "$Q/actions.log"
}
