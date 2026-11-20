#!/usr/bin/env bats
#
# research web — the research extension's page and routes: the research card, the Workspaces tab, Recipe ↗ links,
# the ws and research routes. The server setup: tests/web.bash; the extension runs from a copy outside the checkout.

load helper
load web
load research

setup() {
  web_env
  research_ext
  web_start
}

@test "page.js in a headless browser: an old page reads stale at load; a field in use holds only its block, the rest swaps; a research card fits the panel" {
  local b a=20261104-080000-proj-a c=20261104-080001-proj-c
  b="${VIBE_TEST_BROWSER:-$(command -v chrome-headless-shell chromium chromium-browser google-chrome google-chrome-stable | head -n 1 || true)}"
  [ -n "$b" ] || skip "no headless browser (VIBE_TEST_BROWSER)"
  qjob "$a" blocked
  printf '{"type":"system"}\n' >"$Q/queue/$a/log"
  echo "exit 1" >"$Q/queue/$a/gate.log"
  echo "blocked: which port does the bridge use?" >"$Q/queue/$a/note"
  qjob "$c" blocked
  printf 'repo=%s/proj\nbranch=task-c\n' "$BATS_TEST_TMPDIR" >"$Q/queue/$c/job"
  # A running, a done and a queued job, each on its own branch: every section of the list has a row.
  for j in 070000-run:running 060000-pr:done 090000-next:; do
    qjob "20261104-${j%:*}" "${j#*:}"
    printf 'repo=%s/proj\nbranch=%s\n' "$BATS_TEST_TMPDIR" "${j%:*}" >"$Q/queue/20261104-${j%:*}/job"
  done
  printf '{"type":"system"}\n' >"$Q/queue/20261104-070000-run/log"
  date '+%F %T' >"$Q/queue/20261104-070000-run/started"
  echo https://example.com/pull/9 >"$Q/queue/20261104-060000-pr/pr"
  research_fixture "$Q/queue" "$BATS_TEST_TMPDIR/proj"
  # dq: drained by Stop now while its coordinator's run lives. lv: a live run on vast with steps, an ETA and a box end.
  local d="$Q/queue/20261117-110000-proj-research-dq" l="$Q/queue/20261117-120000-proj-research-lv" st t
  rjob "$Q/queue" "${d##*/}" gpu "$BATS_TEST_TMPDIR/proj" research/dq "research=dq" card=research "question=Does dropout help?" "usd=20"
  mkdir -p "$d/run" && echo now >"$d/drain"
  rjob "$Q/queue" "${l##*/}" gpu "$BATS_TEST_TMPDIR/proj" research/lv "research=lv" card=research "question=Is the tray noise from the fan?" "usd=35"
  mkdir -p "$l/run" && echo vast >"$l/run/place"
  st="$Q/workspaces/research-${l##*/}" t=$(($(date +%s) + 3600))
  mkdir -p "$st" && echo "$t" >"$st/limit" && echo 0.40 >"$st/price" && echo $((t - 7200)) >"$st/started"
  printf 'PROGRESS {"done":100,"total":1000,"at":%s,"run":"seed42-warmup-cosine"}\nPROGRESS {"done":200,"total":1000,"at":%s,"run":"seed42-warmup-cosine"}\n' \
    $((t - 3700)) $((t - 3600)) >"$st/log"
  echo https://github.com/o/r >"$STUBS/origin"
  "$REPO_ROOT/bin/vibe" queue page
  run python3 "$BATS_TEST_DIRNAME/page_check.py" "$b" "$Q/web" "$a" "$c" lr dq lv
  echo "$output"
  [ "$status" -ne 77 ] || skip "$output"
  [ "$status" -eq 0 ]
}

@test "vibe queue page: Workspaces from the state files alone: a card per service, Start or a place and hours form, Open UI, Stop and time left when up; a card per run tool with its live job and no last run; a tab dot while one runs" {
  local w="$BATS_TEST_TMPDIR/workspaces" st="$Q/workspaces" f="$Q/web/index.html" now a="$Q/archive/2026-11/20261103-080000-proj-loop1"
  printf '#!/bin/sh\necho "$*" >>"%s/docker.log"\n' "$STUBS" >"$STUBS/docker"
  chmod +x "$STUBS/docker"
  wsfold
  mkdir -p "$w/one" "$w/loop"
  printf '%s\n' kind=service places=turing "role=One place." >"$w/one/workspace.conf"
  printf '%s\n' label=Loop kind=run places=turing result=folder "role=Runs a loop." >"$w/loop/workspace.conf"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<a class="tw" href="#workspaces">Workspaces</a>' "$f"
  grep -qF '<div class="wrow" id="ws-svc"><div class="t"><span class="why"><i class="lamp l-off"></i>Off</span><b>Svc</b><span class="role">Serves one thing.</span><span class="meta">Runs on: turing, runpod · 4 h</span></div><div class="jacts" data-name="svc"><span class="ask"><label>Place<select name="place"><option>turing</option><option>runpod</option></select></label><label>Hours<input name="hours" type="number" min="1" value="4"></label><button data-act="ws-start" data-verb="Starting…">Start</button></span></div></div>' "$f"
  grep -qF '<div class="wrow" id="ws-one"><div class="t"><span class="why"><i class="lamp l-off"></i>Off</span><b>one</b><span class="role">One place.</span><span class="meta">Runs on: turing</span></div><span class="jacts p" data-name="one"><button data-act="ws-start" data-verb="Starting…">Start</button></span></div>' "$f"
  grep -qF '<section class="sec" aria-label="Tools that run as a job"><h2>Tools that run as a job <span>a session queues one</span></h2><div class="cards"><div class="wrow" id="ws-loop"><div class="t"><span class="why"><i class="lamp l-off"></i>Idle</span><b>Loop</b><span class="role">Runs a loop.</span><span class="meta">Runs on: turing</span></div></div></div></section>' "$f"
  # A run tool: its live job, else Idle; an ended job, live or archived, adds no last-run text.
  qjob 20261104-080000-proj-loop running
  echo tool=loop >>"$Q/queue/20261104-080000-proj-loop/job"
  mkdir -p "$a" && printf 'repo=%s/proj\nbranch=loop1\ntool=loop\n' "$BATS_TEST_TMPDIR" >"$a/job" && echo "done" >"$a/status" && echo "done: wrote 3 files" >"$a/note"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<span class="why"><i class="lamp l-ok"></i>Running · loop</span><b>Loop</b>' "$f"
  grep -qF '<a class="tw" href="#workspaces">Workspaces <i class="lamp l-ok"></i></a>' "$f"
  rm -r "$Q/queue/20261104-080000-proj-loop"
  # No hours= in the conf: an optional Hours field; page.js sends no hours, the start has no limit.
  sed -i.bak '/^hours=/d' "$w/svc/workspace.conf"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<span class="meta">Runs on: turing, runpod</span>' "$f"
  grep -qF '<label>Hours<input name="hours" type="number" min="1" data-opt placeholder="no limit"></label><button data-act="ws-start" data-verb="Starting…">Start</button>' "$f"
  grep -qF '<a class="tw" href="#workspaces">Workspaces</a>' "$f"
  grep -qF '<span class="why"><i class="lamp l-off"></i>Idle</span><b>Loop</b>' "$f"
  run grep -c 'last run\|no run yet' "$f"
  [ "$output" = 0 ]
  printf '%s\n' label=Svc "role=Serves one thing." kind=service gpu=no places=turing,runpod hours=4 ports=8080 >"$w/svc/workspace.conf"
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
  grep -qF '<span class="why"><i class="lamp l-ok"></i>Up on runpod · 0:35 · <span class="warn">20m left</span></span><b>Svc</b>' "$f"
  grep -qF '</div><a class="btn ui" href="http://100.64.0.1:8080" target="_blank" rel="noopener">Open UI ↗</a><span class="jacts p" data-name="svc"><button data-act="ws-stop" data-verb="Stopping…" data-confirm>Stop</button></span></div>' "$f"
  grep -qF '<span class="why"><i class="lamp l-off"></i>Off · <span class="bad">vibe: start of one failed — it is down again</span></span><b>one</b>' "$f"
  grep -qF '<a class="tw" href="#workspaces">Workspaces <i class="lamp l-ok"></i></a>' "$f"
  echo $((now + 7230)) >"$st/svc/limit"
  echo c2 >"$st/one/id"
  echo $((now - 60)) >"$st/one/limit"
  echo 'javascript:alert(1)' >"$st/one/url"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<span class="why"><i class="lamp l-ok"></i>Up on runpod · 0:35 · 2h' "$f"
  grep -qF '<div class="wrow" id="ws-one"><div class="t"><span class="why"><i class="lamp l-bad"></i>Past its limit on turing: the next tick stops it</span><b>one</b><span class="role">One place.</span><span class="meta">Runs on: turing</span></div><span class="jacts p" data-name="one"><button data-act="ws-stop" data-verb="Stopping…" data-confirm>Stop</button></span></div>' "$f"
  [ "$(grep -c 'javascript:' "$f")" = 0 ]
  [ ! -e "$STUBS/docker.log" ]
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

@test "page: a research card has Stop question and Stop now; a worker in paste has a Copy per step and a field that answers it" {
  local f="$Q/web/index.html" c="$Q/queue/20261117-100000-proj-research-lr"
  research_fixture "$Q/queue" "$BATS_TEST_TMPDIR/proj"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<div class="jacts" data-slug="lr"><button data-act="research-stop" data-verb="Stopping…" title="No new worker: each run finishes">Stop question</button><hr><button data-act="research-stop-now" data-verb="Stopping…" data-confirm title="Cut every run now">Stop now</button></div>' "$f"
  grep -qF '<div class="paste"><ol><li><code>git fetch the commit</code><button type="button" data-copy>Copy</button></li><li><code>sbatch runs/h3/job.sbatch</code><button type="button" data-copy>Copy</button></li><li><code>print the RESULT line</code><button type="button" data-copy>Copy</button></li></ol><div class="jacts" data-id="20261117-100300-proj-research-lr-h3"><span class="ask"><label>The RESULT line from the cluster: the worker closes its run with it<textarea name="text" rows="3"></textarea></label><button data-act="answer">Send answer</button></span></div></div>' "$f"
  [ "$(grep -o 'data-copy' "$f" | wc -l)" -eq 3 ]
  run grep -c 'research-archive' "$f"
  [ "$output" = 0 ]
  # A finished question has Archive, no stop buttons, and a worker with no paste has no panel.
  echo "done" >"$Q/queue/20261117-100300-proj-research-lr-h3/status"
  echo "done" >"$Q/queue/20261117-100200-proj-research-lr-h2/status"
  "$REPO_ROOT/bin/vibe" queue page
  run grep -c 'research-stop\|data-copy' "$f"
  [ "$output" = 0 ]
  grep -qF '<div class="jacts" data-slug="lr"><button data-act="research-archive" data-verb="Archiving…" data-confirm>Archive</button></div>' "$f"
}

@test "page: a blocked research worker with no paste.md has the answer field of its own job" {
  local f="$Q/web/index.html"
  research_fixture "$Q/queue" "$BATS_TEST_TMPDIR/proj"
  rm "$Q/queue/20261117-100300-proj-research-lr-h3/paste.md"
  "$REPO_ROOT/bin/vibe" queue page
  grep -qF '<span class="n">Has a question · slurm</span>' "$f"
  grep -qF '<div class="jacts" data-id="20261117-100300-proj-research-lr-h3"><span class="ask"><label>Your answer: the job runs again with it<textarea name="text" rows="3"></textarea></label><button data-act="answer">Send answer</button></span></div></div>' "$f"
  run grep -c 'class="paste"' "$f"
  [ "$output" = 0 ]
}

@test "route research-archive: vibe queue archive --research <slug>; a bad slug is 400" {
  run act research-archive '{"slug": "lr"}'
  grep -q $'\tvibe queue archive --research lr\t[0-9]*$' "$Q/actions.log"
  run act research-archive '{"slug": "-x"}'
  [ "${lines[1]}" = 400 ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 1 ]
}

@test "route research-stop: vibe queue stop --research <slug>; a bad slug or none is 400" {
  run act research-stop '{"slug": "lr"}'
  grep -q $'\tvibe queue stop --research lr\t[0-9]*$' "$Q/actions.log"
  run act research-stop '{"slug": "-x"}'
  [ "${lines[1]}" = 400 ]
  run act research-stop '{"slug": "../lr"}'
  [ "${lines[1]}" = 400 ]
  run act research-stop '{}'
  [ "${lines[1]}" = 400 ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 1 ]
}

@test "route research-stop-now: vibe queue stop --research <slug> --now" {
  run act research-stop-now '{"slug": "lr"}'
  grep -q $'\tvibe queue stop --research lr --now\t[0-9]*$' "$Q/actions.log"
  run act research-stop-now '{"slug": "lr x"}'
  [ "${lines[1]}" = 400 ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 1 ]
}
@test "vibe queue page: Recipe ↗ links the GitHub origin in each of its three forms; no link for another host, a credential or no origin" {
  local f="$Q/web/index.html" u
  for u in git@github.com:o/r.git ssh://git@github.com/o/r.git https://github.com/o/r.git https://github.com/o/r; do
    echo "$u" >"$STUBS/origin"
    VIBE_WORKSPACES="$REPO_ROOT/workspaces" "$REPO_ROOT/bin/vibe" queue page
    grep -qF '<a class="rcp" href="https://github.com/o/r/blob/HEAD/docs/workspaces/kapso.md" target="_blank" rel="noopener">Recipe ↗</a>' "$f"
  done
  for u in https://me:tok@github.com/o/r.git https://gitlab.com/o/r.git https://github.com/o/r/x none; do
    rm -f "$STUBS/origin"
    if [ "$u" != none ]; then echo "$u" >"$STUBS/origin"; fi
    VIBE_WORKSPACES="$REPO_ROOT/workspaces" "$REPO_ROOT/bin/vibe" queue page
    run grep -c 'Recipe ↗\|me:tok' "$f"
    [ "$output" = 0 ]
  done
}

@test "vibe queue ready: refuses RESEARCH.md in the diff, the extension's wip file" {
  local url=https://github.com/o/proj/pull/7
  echo SUCCESS >"$STUBS/checks"
  printf 'a.txt\nRESEARCH.md\n' >"$STUBS/files"
  run "$REPO_ROOT/bin/vibe" queue ready "$url"
  [ "$status" -eq 1 ]
  [[ "$output" == *"still holds RESEARCH.md"* ]] || false
  run grep -c 'pr ready' "$STUBS/gh.log"
  [ "$output" = 0 ]
}
