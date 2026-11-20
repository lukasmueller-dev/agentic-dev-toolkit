#!/usr/bin/env bats
#
# research tool jobs — a tool= job runs a workspaces/ tool, a closing session checks its result; the page's
# GPU holder. The queue setup: tests/queue.bash; the extension runs from a copy outside the checkout.

load helper
load queue
load research

setup() {
  queue_setup
  research_ext
  research_modes
}

# tool NAME RESULT [CONF-LINE...] — a kind=run workspace NAME on the real turing place, runs=host: no docker.
# Its scripts run in the instance's state dir and log to $STUBS/tool.log. $STUBS/tool-sleep: the run waits
# 30 s first; tool-fail: it exits 4 with no result; tool-failed: its result is failed: out of memory; tool-branch: the ref name it writes; tool-config: its commit
# adds .claude/settings.json; tool-link: out/branch links to $STUBS/secret; tool-fifo: out/branch is a FIFO; tool-nobundle: no repo.bundle;
# steer-exit: steer's exit.
tool() {
  local w="$BATS_TEST_TMPDIR/workspaces"
  export VIBE_WORKSPACES="$w" VIBE_WS_POLL=0.1
  mkdir -p "$w/_places" "$w/$1" "$GPU_QUEUE_DIR"
  cp "$REPO_ROOT/workspaces/_places/turing" "$w/_places/turing"
  printf '%s\n' kind=run runs=host places=turing hours=2 "result=$2" "${@:3}" >"$w/$1/workspace.conf"
  cat >"$w/$1/run" <<EOF
#!/usr/bin/env bash
set -e
echo "run hours=\$WS_HOURS" >>"$STUBS/tool.log"
cp in/brief.md in/args "$STUBS/" 2>/dev/null || true
L="$GPU_QUEUE_DIR/gpu.lock"
if command -v flock >/dev/null; then flock -n "\$L" true && echo free || echo held; else [ -d "\$L.d" ] && echo held || echo free; fi >"$STUBS/lock"
if [ -e "$STUBS/tool-sleep" ]; then touch "$STUBS/tool-up" && sleep 30; fi
if [ -e "$STUBS/tool-fail" ]; then echo "tool: out of memory" >&2 && exit 4; fi
if [ -e "$STUBS/tool-failed" ]; then echo "failed: out of memory" >out/result && exit 0; fi
if [ "$2" = folder ]; then
  mkdir -p out/files && echo a,b >out/files/table.csv && echo "done: one table" >out/result
  exit 0
fi
git clone -q in/repo work && cd work && git checkout -q -b tool/try
echo tool >tool.txt && git add tool.txt
if [ -e "$STUBS/tool-config" ]; then mkdir -p .claude && echo '{}' >.claude/settings.json && git add .claude; fi
git commit -q -m "feat: tool change"
[ -e "$STUBS/tool-nobundle" ] || git bundle create ../out/repo.bundle tool/try 2>/dev/null
cd .. && echo 0.91 >out/score && echo "done: score 0.91" >out/result
cat "$STUBS/tool-branch" 2>/dev/null >out/branch || echo tool/try >out/branch
if [ -e "$STUBS/tool-link" ]; then ln -sf "$STUBS/secret" out/branch; fi
if [ -e "$STUBS/tool-fifo" ]; then rm -f out/branch && mkfifo out/branch; fi
EOF
  cat >"$w/$1/stop" <<EOF
#!/usr/bin/env bash
if [ -s id ]; then echo "stop while up" >>"$STUBS/tool.log"; else echo "stop while down" >>"$STUBS/tool.log"; fi
EOF
  cat >"$w/$1/steer" <<EOF
#!/usr/bin/env bash
echo "steer \$1" >>"$STUBS/tool.log"
exit "\$(cat "$STUBS/steer-exit" 2>/dev/null || echo 0)"
EOF
  chmod +x "$w/_places/turing" "$w/$1/run" "$w/$1/stop" "$w/$1/steer"
}

# tooljob ID REPO BRANCH [JOB-LINE...] — a tool=stub job with in/brief.md and in/args; the closing session is the stub's close.
tooljob() {
  mkjob "$1" "$2" "$3" close tool=stub "${@:4}"
  mkdir -p "$Q/$1/in"
  echo "Lower the loss." >"$Q/$1/in/brief.md"
  echo metric=loss >"$Q/$1/in/args"
}

# toolwait — the runner in the background as $runner, until the stub tool's run is up.
toolwait() {
  touch "$STUBS/tool-sleep"
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/runner.log" 2>&1 3>&- &
  runner=$!
  for _ in $(seq 100); do
    if [ -e "$STUBS/tool-up" ]; then return 0; fi
    sleep 0.1
  done
  return 1
}

@test "tool: a branch result ends as commits on the job's branch and a pr.md; the closing prompt ends with tool-run.md" {
  local r o="$BATS_TEST_TMPDIR/proj.git" st="$XDG_STATE_HOME/vibe/workspaces/stub-01-a" tr="$REPO_ROOT/skills/fill-queue/references/tool-run.md"
  r="$(make_repo proj)"
  tool stub branch
  tooljob 01-a "$r" tool-x hours=3
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(git -C "$o" log -n 1 --format=%s tool-x)" = "feat: tool change" ]
  grep -q 'pr create .*--title feat: tool branch' "$STUBS/gh.log"
  [ "$(cat "$Q/01-a/tool-exit")" = 0 ]
  [ "$(cat "$Q/01-a/out/score")" = 0.91 ]
  [ "$(cat "$STUBS/brief.md")" = "Lower the loss." ]
  [ "$(cat "$STUBS/args")" = metric=loss ]
  [ "$(cat "$STUBS/lock")" = free ]
  [ "$(cat "$STUBS/tool.log")" = "run hours=3" ]
  [ ! -e "$st" ]
  [ "$(head -n 2 "$STUBS/close-prompt")" = "$(printf 'Do the task.\nMODE=close')" ]
  [ "$(tail -n "$(grep -c '' "$tr")" "$STUBS/close-prompt")" = "$(cat "$tr")" ]
}

@test "tool: a folder result ends as a report job; the files stay in the job dir; no push, no PR" {
  local r
  r="$(make_repo proj)"
  tool stub folder
  tooljob 01-a "$r" tool-y
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  grep -qx output=report "$Q/01-a/job"
  [ "$(cat "$Q/01-a/report.md")" = "# One table" ]
  [ "$(cat "$Q/01-a/out/files/table.csv")" = a,b ]
  [ "$(cat "$STUBS/tool.log")" = "run hours=2" ]
  run git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/tool-y
  [ "$status" -ne 0 ]
  run grep -c 'pr create' "$STUBS/gh.log"
  [ "$output" = 0 ] || [ "$status" -eq 2 ]
}

@test "tool: vibe queue stop ends the run with its stop script, then down; no closing session" {
  local r runner st="$XDG_STATE_HOME/vibe/workspaces/stub-01-a"
  r="$(make_repo proj)"
  tool stub branch
  tooljob 01-a "$r" tool-x
  toolwait
  [ -s "$st/id" ]
  run "$VIBE" queue stop 01-a
  [ "$status" -eq 0 ]
  SECONDS=0
  wait "$runner"
  [ "$SECONDS" -lt 15 ] # the run sleeps 30 s: the stop ended it
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/01-a/note")" = stopped ]
  [ "$(cat "$STUBS/tool.log")" = "$(printf 'run hours=2\nstop while up')" ]
  [ ! -e "$st" ]
  [ ! -e "$STUBS/claude.log" ]
}

@test "tool: vibe queue steer hands its text to steer; exit 3 from steer prints not supported" {
  local r runner
  r="$(make_repo proj)"
  tool stub branch
  tooljob 01-a "$r" tool-x
  mkjob 02-b "$r" task-b ok
  run "$VIBE" queue steer 02-b "go on"
  [ "$status" -ne 0 ]
  [[ "$output" == *"02-b takes no steer now"* ]] || false
  run "$VIBE" queue steer 01-a "go on"
  [ "$status" -ne 0 ]
  [[ "$output" == *"the tool of 01-a does not run now"* ]] || false
  toolwait
  run "$VIBE" queue steer 01-a "try a smaller step"
  [ "$status" -eq 0 ]
  [ "$output" = "steered stub-01-a" ]
  echo 3 >"$STUBS/steer-exit"
  run "$VIBE" queue steer 01-a "again"
  [ "$status" -ne 0 ]
  [[ "$output" == *"stub: steer not supported"* ]] || false
  "$VIBE" queue stop 01-a >/dev/null
  wait "$runner"
  [ "$(grep '^steer' "$STUBS/tool.log")" = "$(printf 'steer try a smaller step\nsteer again')" ]
}

@test "page: a running tool job's block has a Message field and a Tool log link, not the log; no field for a steer that exits 3; after the run, its out/ links" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" w="$BATS_TEST_TMPDIR/workspaces"
  r="$(make_repo proj)"
  tool stub folder label=Stub
  tooljob 01-a "$r" tool-y
  echo running >"$Q/01-a/status"
  {
    printf 'line %s\n' 1 2 3 4
    printf '\033[32mline 5\033[0m\n'
    printf 'line %s <b>\n' 6 7 8 9 10 11 12
    printf 'bar 10%%\rbar 50%%\n\n'
  } >"$Q/01-a/tool.log"
  "$VIBE" queue page >/dev/null
  [ "$(grep -c 'line 12' "$f")" = 0 ]
  grep -qF '<span class="ask"><label>Message to Stub: it reads the text at its next step<textarea name="text" rows="3"></textarea></label><button data-act="steer">Send</button></span>' "$f"
  grep -qF "href=\"/queue/api/job/01-a/tool.log\">Tool log</a>" "$f"
  printf '#!/usr/bin/env bash\n# no steer\nexit 3\n' >"$w/stub/steer"
  "$VIBE" queue page >/dev/null
  [ "$(grep -c 'data-act="steer"' "$f")" = 0 ]
  echo 0 >"$Q/01-a/tool-exit"
  mkdir -p "$Q/01-a/out/files"
  echo "# Report" >"$Q/01-a/out/report.md"
  "$VIBE" queue page >/dev/null
  grep -qF '<a href="/queue/api/job/01-a/out/report.md">Tool report</a><a href="/queue/api/job/01-a/out/files">Output files</a>' "$f"
}

# gpu_hold — the GPU lock held by `gpu-queue lock` in its own process group ($holdpid) until gpu_free.
gpu_hold() {
  local l="$GPU_QUEUE_DIR/gpu.lock"
  mkdir -p "$GPU_QUEUE_DIR"
  set -m
  "$REPO_ROOT/bin/gpu-queue" lock -- sleep 30 </dev/null >/dev/null 2>&1 3>&- &
  holdpid=$!
  set +m
  for _ in $(seq 50); do
    if { command -v flock >/dev/null && [ -e "$l" ] && ! flock -n "$l" true; } || [ -d "$l.d" ]; then return 0; fi
    sleep 0.1
  done
  return 1
}
gpu_free() { kill -TERM -- "-$holdpid" 2>/dev/null || true; }

@test "page: the header names the GPU holder, first match: gpu job, outside run, workspace, tool job, else busy; none while the lock is free" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" w="$BATS_TEST_TMPDIR/workspaces" st="$XDG_STATE_HOME/vibe/workspaces" holdpid other own
  r="$(make_repo proj)"
  tool stub folder gpu=yes label=Stub
  mkdir -p "$w/gsv" "$w/two" "$st/gsv"
  printf '%s\n' label=GSV kind=service gpu=yes places=turing >"$w/gsv/workspace.conf"
  printf '%s\n' kind=service gpu=yes places=turing,runpod hours=2 >"$w/two/workspace.conf"
  tooljob 04-d "$r" tool-y
  echo running >"$Q/04-d/status"
  "$VIBE" queue page >/dev/null
  grep -qF '1 of 4 jobs run<span class="more"></span>' "$f"
  grep -qF '<option>turing</option><option>runpod</option>' "$f"
  gpu_hold
  rm "$Q/04-d/status"
  "$VIBE" queue page >/dev/null
  grep -qF '0 of 4 jobs run<span class="more"> · GPU busy</span>' "$f"
  grep -qF '<option value="turing">turing — waits for the GPU</option><option>runpod</option>' "$f"
  echo running >"$Q/04-d/status"
  "$VIBE" queue page >/dev/null
  grep -qF '1 of 4 jobs run<span class="more"> · GPU busy: Stub · 04-d</span>' "$f"
  grep -qF '<option value="turing">turing — waits: Stub · 04-d holds the GPU</option>' "$f"
  # A workspace whose holder holds the lock: its command ends in `ws hold <instance>`; while it waits, it holds nothing.
  echo turing >"$st/gsv/place"
  echo c1 >"$st/gsv/id"
  sh -c 'sleep 30; :' _ ws hold gsv 3>&- &
  other=$!
  echo "$other" >"$st/gsv/holder"
  echo "vibe: holds the GPU" >"$st/gsv/hold.log"
  : >"$st/gsv/waits"
  "$VIBE" queue page >/dev/null
  grep -qF 'GPU busy: Stub · 04-d</span>' "$f"
  rm "$st/gsv/waits"
  "$VIBE" queue page >/dev/null
  grep -qF 'GPU busy: GSV</span>' "$f"
  gpuq running train "$BATS_TEST_TMPDIR" >/dev/null
  "$VIBE" queue page >/dev/null
  grep -qF 'GPU busy: train</span>' "$f"
  mkjob 01-a "$r" task-a ok
  echo gpu >"$Q/01-a/status"
  own="$(gpuq running own "$BATS_TEST_TMPDIR")"
  echo "$own" >"$Q/01-a/gpu-job"
  "$VIBE" queue page >/dev/null
  grep -qF 'GPU busy: 01-a</span>' "$f"
  gpu_free
  kill "$other"
  sleep 0.3
  "$VIBE" queue page >/dev/null
  [ "$(grep -c 'GPU busy' "$f")" = 0 ]
}

@test "tool: a gpu=yes run on turing holds the GPU lock for the whole run" {
  local r
  r="$(make_repo proj)"
  tool stub folder gpu=yes
  tooljob 01-a "$r" tool-y
  drain
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(cat "$STUBS/lock")" = held ]
}

@test "tool: vibe queue add and a retry write the GPU slot of a gpu=yes tool job before any runner pass" {
  local r n="$BATS_TEST_TMPDIR/new"
  r="$(make_repo proj)"
  tool stub folder gpu=yes
  mkdir -p "$n"
  printf 'repo=%s\nbranch=b\ntool=stub\n' "$r" >"$n/job"
  echo 'Do it.' >"$n/prompt.md"
  "$VIBE" queue add "$n" >/dev/null
  [ "$(cat "$Q"/*-proj-b/slot)" = gpu ]
  mv "$Q"/*-proj-b "$Q/01-b"
  echo failed >"$Q/01-b/status"
  "$VIBE" queue retry 01-b >/dev/null
  [ "$(cat "$Q"/*-proj-b/slot)" = gpu ]
}

@test "tool: a second gpu=yes tool job stays queued, not in a slot, while the first runs its tool" {
  local r runner
  r="$(make_repo proj)"
  tool stub folder gpu=yes
  tooljob 01-a "$r" tool-a
  tooljob 02-b "$r" tool-b
  toolwait
  sleep 1 # five runner passes
  [ "$(cat "$Q/01-a/status")" = running ]
  [ ! -e "$Q/02-b/status" ] || [ "$(cat "$Q/02-b/status")" = queued ]
  [ ! -e "$Q/02-b/pid" ]
  rm "$STUBS/tool-sleep"
  "$VIBE" queue stop 01-a >/dev/null
  wait "$runner"
  [ "$(cat "$Q/01-a/note")" = stopped ]
  [ "$(cat "$Q/02-b/status")" = "done" ]
}

@test "tool: a gpu=yes tool job that fails at start holds back no other; the drain runs it" {
  local r w="$BATS_TEST_TMPDIR/workspaces"
  r="$(make_repo proj)"
  tool stub folder gpu=yes
  mkdir -p "$w/keyed"
  printf '%s\n' kind=run places=turing result=folder hours=1 gpu=yes secrets=API_KEY >"$w/keyed/workspace.conf"
  mkjob 01-a "$r" t-a close tool=keyed
  tooljob 02-b "$r" tool-b
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/02-b/status")" = "done" ]
}

@test "tool: a job whose tool cannot run fails with the reason, before its worktree" {
  local r w="$BATS_TEST_TMPDIR/workspaces"
  r="$(make_repo proj)"
  tool stub branch
  mkdir -p "$w/svc" "$w/keyed" "$w/far"
  printf '%s\n' kind=service places=turing >"$w/svc/workspace.conf"
  printf '%s\n' kind=run places=turing result=folder hours=1 secrets=API_KEY >"$w/keyed/workspace.conf"
  printf '%s\n' kind=run places=runpod,turing result=folder hours=1 >"$w/far/workspace.conf"
  mkjob 01-a "$r" t-a close tool=nope
  mkjob 02-b "$r" t-b close tool=svc
  mkjob 03-c "$r" t-c close tool=stub place=vast
  mkjob 04-d "$r" t-d close tool=stub hours=0
  mkjob 05-e "$r" t-e close tool=keyed
  mkjob 06-f+x "$r" t-f close tool=stub
  mkjob 07-g "$r" t-g close tool=far
  drain
  [ "$(cat "$Q/01-a/note")" = "no workspace 'nope' — vibe ws list" ]
  [ "$(cat "$Q/02-b/note")" = "svc is kind=service — vibe ws start svc" ]
  [ "$(cat "$Q/03-c/note")" = "stub has no place 'vast' — places=turing" ]
  [ "$(cat "$Q/04-d/note")" = "hours=0: a whole number above 0, in the job or $w/stub/workspace.conf" ]
  [[ "$(cat "$Q/05-e/note")" == "keyed needs API_KEY: write KEY=VALUE lines to "* ]] || false
  [ "$(cat "$Q/06-f+x/note")" = "instance 'stub-06-f+x': letters, digits, . _ - only — the repo folder or the branch breaks it" ]
  [ "$(cat "$Q/07-g/note")" = "no place script 'runpod' in $w/_places — place= names another" ]
  for j in 01-a 02-b 03-c 04-d 05-e 06-f+x 07-g; do
    [ "$(cat "$Q/$j/status")" = failed ]
  done
  [ ! -e "$r/.claude/worktrees" ] || [ -z "$(ls "$r/.claude/worktrees")" ]
  [ ! -e "$STUBS/tool.log" ]
}

@test "tool: no out/result, a failed: result, a bad branch name, a link, a FIFO, agent config, no bundle or no close.md fails the job; no closing session" {
  local r o="$BATS_TEST_TMPDIR/proj.git"
  r="$(make_repo proj)"
  tool stub branch
  touch "$STUBS/tool-fail"
  tooljob 01-a "$r" tool-x
  drain
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/01-a/note")" = "no out/result, tool exit 4 — tool.log: tool: out of memory" ]
  rm "$STUBS/tool-fail"
  touch "$STUBS/tool-failed"
  tooljob 01-b "$r" tool-y
  drain
  [ "$(cat "$Q/01-b/status")" = failed ]
  [ "$(cat "$Q/01-b/note")" = "failed: out of memory" ]
  rm "$STUBS/tool-failed"
  echo "x:refs/heads/main" >"$STUBS/tool-branch"
  tooljob 02-b "$r" tool-z
  drain
  [ "$(cat "$Q/02-b/status")" = failed ]
  [ "$(cat "$Q/02-b/note")" = "out/repo.bundle: no branch 'x:refs/heads/main' — tool.log" ]
  [ "$(git -C "$r/.claude/worktrees/tool-z" log -n 1 --format=%s)" = "$(git -C "$r" log -n 1 --format=%s main)" ]
  run git -C "$o" rev-parse -q --verify refs/heads/tool-z
  [ "$status" -ne 0 ]
  rm "$STUBS/tool-branch"
  echo "secret-line" >"$STUBS/secret"
  touch "$STUBS/tool-link"
  tooljob 03-c "$r" tool-l
  drain
  [ "$(cat "$Q/03-c/note")" = "out/repo.bundle: no branch '' — tool.log" ]
  [ ! -L "$Q/03-c/out/branch" ]
  [ -f "$Q/03-c/out/score" ]
  rm "$STUBS/tool-link"
  touch "$STUBS/tool-fifo"
  tooljob 03-f "$r" tool-f
  drain
  [ "$(cat "$Q/03-f/note")" = "out/repo.bundle: no branch '' — tool.log" ]
  [ ! -p "$Q/03-f/out/branch" ]
  rm "$STUBS/tool-fifo"
  touch "$STUBS/tool-config"
  tooljob 04-d "$r" tool-c
  drain
  [ "$(cat "$Q/04-d/note")" = "out/repo.bundle changes .claude/settings.json: agent and git config stay out of a tool's commits" ]
  [ "$(git -C "$r/.claude/worktrees/tool-c" log -n 1 --format=%s)" = "$(git -C "$r" log -n 1 --format=%s main)" ]
  rm "$STUBS/tool-config"
  touch "$STUBS/tool-nobundle"
  tooljob 06-f "$r" tool-n
  drain
  [ "$(cat "$Q/06-f/status")" = failed ]
  [ "$(cat "$Q/06-f/note")" = "out/result is done: but there is no out/repo.bundle — tool.log" ]
  rm "$STUBS/tool-nobundle"
  tooljob 05-e "$r" tool-e
  mkdir "$Q/05-e/close.md"
  drain
  [ "$(cat "$Q/05-e/status")" = failed ]
  [ "$(cat "$Q/05-e/note")" = "close.md not written — runner.log" ]
  [ ! -e "$STUBS/claude.log" ]
}

@test "tool: retry runs the tool again with in/; fix and a GPU follow-up run no tool" {
  local r n
  r="$(make_repo proj)"
  tool stub branch
  touch "$STUBS/tool-fail"
  tooljob 01-a "$r" tool-x
  drain
  [ "$(cat "$Q/01-a/status")" = failed ]
  rm "$STUBS/tool-fail" "$STUBS/brief.md"
  "$VIBE" queue retry 01-a >/dev/null
  drain
  n="$(ls "$Q")"
  [ "$(cat "$Q/$n/status")" = "done" ]
  [ "$(cat "$STUBS/brief.md")" = "Lower the loss." ]
  [ "$(grep -c '^run' "$STUBS/tool.log")" -eq 2 ]
  "$VIBE" queue fix "$(cat "$Q/$n/pr")" "rename tool.txt" >/dev/null
  GPUQ_EXIT=0 "$VIBE" queue follow "$Q/$n" >/dev/null
  [ "$(find "$Q" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 3 ]
  [ "$(grep -l '^tool=' "$Q"/*/job)" = "$Q/$n/job" ]
  drain
  [ "$(grep -c '^run' "$STUBS/tool.log")" -eq 2 ]
  for f in "$Q"/*/status; do [ "$(cat "$f")" = "done" ]; done
}

@test "tool: a job process that died after the run checks and merges its result again; no new run" {
  local r c="$BATS_TEST_TMPDIR/toolwork" o="$BATS_TEST_TMPDIR/proj.git"
  r="$(make_repo proj)"
  tool stub branch
  tooljob 01-a "$r" tool-x
  git clone -q "$o" "$c"
  git -C "$c" checkout -q -b tool/try
  echo tool >"$c/tool.txt" && git -C "$c" add tool.txt && git -C "$c" commit -q -m "feat: tool change"
  mkdir -p "$Q/01-a/out"
  git -C "$c" bundle create "$Q/01-a/out/repo.bundle" tool/try 2>/dev/null
  echo tool/try >"$Q/01-a/out/branch"
  echo "done: score 0.91" >"$Q/01-a/out/result"
  echo 0 >"$Q/01-a/tool-exit"
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(git -C "$o" log -n 1 --format=%s tool-x)" = "feat: tool change" ]
  [ ! -e "$STUBS/tool.log" ]
}

@test "tool: answer to a blocked closing session closes the same run again; no new run" {
  local r n
  r="$(make_repo proj)"
  tool stub branch
  touch "$STUBS/close-blocked"
  tooljob 01-a "$r" tool-x
  drain
  [ "$(cat "$Q/01-a/status")" = blocked ]
  rm "$STUBS/close-blocked"
  "$VIBE" queue answer 01-a "use make eval" >/dev/null
  n="$(ls "$Q")"
  [ "$(cat "$Q/$n/out/score")" = 0.91 ]
  drain
  [ "$(cat "$Q/$n/status")" = "done" ]
  [ "$(grep -c '^run' "$STUBS/tool.log")" -eq 1 ]
  [[ "$(cat "$r/.claude/worktrees/tool-x/HANDOFF.md")" == *"Answer: use make eval"* ]] || false
  [ "$(git -C "$r/.claude/worktrees/tool-x" log --format=%s | grep -c 'feat: tool change')" -eq 1 ]
}
