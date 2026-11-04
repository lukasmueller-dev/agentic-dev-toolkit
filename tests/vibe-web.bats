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
  export VIBE_WEB_TIMEOUT=3
  "$REPO_ROOT/bin/vibe-web" 2>"$BATS_TEST_TMPDIR/web.log" &
  WEB_PID=$!
  curl -s -o /dev/null --retry 30 --retry-connrefused --retry-delay 1 "http://127.0.0.1:$PORT/"
}

teardown() {
  kill "$WEB_PID" 2>/dev/null || true
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

@test "vibe-web: the unit runs only on a server" {
  grep -q '^ExecStart=%h/bin/vibe-web$' "$REPO_ROOT/claude/systemd/vibe-web.service"
  grep -q '^ExecCondition=.*grep -qx server %h/.config/vibe/role' "$REPO_ROOT/claude/systemd/vibe-web.service"
}

@test "vibe queue page: writes the page; buttons hidden until whoami" {
  run "$REPO_ROOT/bin/vibe" queue page
  [ "$status" -eq 0 ]
  grep -q 'data-act="pause"' "$Q/web/index.html"
  grep -q "fetch(api + 'whoami'" "$Q/web/page.js"
  grep -qF "if (!document.body.classList.contains('can')) who();" "$Q/web/page.js"
  grep -qF "if (busy || \$('#queue .armed')) return;" "$Q/web/page.js"
  grep -qF "closest('#queue button[data-act]')" "$Q/web/page.js"
  grep -q 'body.can .acts' "$Q/web/index.html"
}

@test "vibe queue page: CSP allows only page.js, so HTML in a note runs no script" {
  run "$REPO_ROOT/bin/vibe" queue page
  [ "$status" -eq 0 ]
  grep -q "Content-Security-Policy\" content=\"default-src 'self'; script-src 'self';" "$Q/web/index.html"
  grep -q '<script src="/queue/page.js"></script>' "$Q/web/index.html"
  [ "$(grep -c '<script' "$Q/web/index.html")" = 1 ]
  run grep -q "script-src[^;]*unsafe" "$Q/web/index.html"
  [ "$status" -eq 1 ]
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

@test "route answer: the answer replaces the blockers in HANDOFF.md; commit, push, follow-up queued, original archived" {
  local r wt n
  r="$(make_repo proj)" wt="$BATS_TEST_TMPDIR/wt"
  git -C "$r" worktree add -q -b task "$wt"
  printf '# Handoff\n\n## Next action\n\nPick a plan.\n\n## Blockers\n\nPlan A or B?\n\n## Gotchas\n\n- keep me\n' >"$wt/HANDOFF.md"
  git -C "$wt" add HANDOFF.md && git -C "$wt" commit -q -m "docs: handoff" && git -C "$wt" push -q origin task
  qjob "$ID" blocked
  echo "$wt" >"$Q/queue/$ID/worktree"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -q 'data-act="answer" data-ask="text" data-confirm' "$Q/web/index.html"
  run act answer "{\"id\": \"$ID\", \"text\": \"Plan B.\"}"
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  [ "$(sed -n '/^## Blockers/,/^## Gotchas/p' "$wt/HANDOFF.md")" = "$(printf '## Blockers\n\nAnswer: Plan B.\n\n## Gotchas')" ]
  grep -qx -- '- keep me' "$wt/HANDOFF.md"
  [ "$(git -C "$wt" log -1 --format=%s)" = "docs(handoff): $ID unblocked" ]
  [ "$(git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse task)" = "$(git -C "$wt" rev-parse HEAD)" ]
  [ -d "$Q/archive/$(date +%Y-%m)/$ID" ]
  n="$(newjob)"
  grep -qx branch=task "$n/job"
  [ "$(cat "$n/worktree")" = "$wt" ]
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
  grep -q "data-pr=\"$URL\"><button data-act=\"fix\" data-ask=\"text\"" "$Q/web/index.html"
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

@test "vibe queue ready: refuses a failing check and SPEC.md or HANDOFF.md in the diff; then marks no PR ready" {
  printf 'SUCCESS\nFAILURE\n' >"$STUBS/checks"
  run "$REPO_ROOT/bin/vibe" queue ready "$URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"has a failing check"* ]] || false
  echo SUCCESS >"$STUBS/checks"
  printf 'a.txt\nSPEC.md\n' >"$STUBS/files"
  run "$REPO_ROOT/bin/vibe" queue ready "$URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"still holds SPEC.md or HANDOFF.md"* ]] || false
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
  qjob "$ID"
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
