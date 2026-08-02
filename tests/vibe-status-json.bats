#!/usr/bin/env bats
#
# vibe status --json — the document a cross-machine monitor polls over ssh.
#
# It is a published contract, not incidental output: a client renders whatever
# it says and cannot ask a follow-up question. So the assertions here are about
# what a *wrong* answer would cost — a killed loop reported as running, an
# unreachable-looking host that is merely tmux-less, a detached HEAD passed off
# as a branch named "HEAD".

bats_require_minimum_version 1.5.0

load helper

setup() { git_env; }

# task_block PATH — the lines of the task object whose "path" is PATH, so a
# per-task assertion cannot be satisfied by some other task in the array.
# Plain awk rather than a JSON parser: the suite must run where python3 does
# not, and the document is pretty-printed at fixed indentation.
task_block() {
  awk -v want="\"path\": \"$1\"," '
    /^    \{$/ { buf = ""; keep = 0 }
    { buf = buf $0 "\n" }
    index($0, want) { keep = 1 }
    /^    \}/ { if (keep) printf "%s", buf }
  '
}

# A tmux stub that reports every session as live, so the git-derived state
# words (which are reached only past the "is anything running here" gate) can
# be tested at all. Echoes the directory to put on PATH.
tmux_stub_live() {
  local dir="$BATS_TEST_TMPDIR/tmuxbin-live"
  mkdir -p "$dir"
  cat >"$dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  has-session) exit 0 ;;
  ls) echo "vibe-proj-task-a: 1 windows"; exit 0 ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"
  printf '%s' "$dir"
}

# ---------------------------------------------------------------------------
# Shape: the document parses, and it is host-scoped
# ---------------------------------------------------------------------------
@test "status --json: emits a document that actually parses" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  cd "$(make_repo proj)"
  run_vibe start "task j" >/dev/null

  run run_vibe status --json
  [ "$status" -eq 0 ]
  run python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
assert d["schema"] == 1, d["schema"]
assert isinstance(d["tasks"], list), "tasks must be a list"
assert d["host"]["scope"] == "repo", d["host"]["scope"]
assert d["host"]["hostname"], "hostname must not be empty"
assert d["host"]["environment"] in ("local", "server"), d["host"]["environment"]
print("ok")
' <<<"$output"
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

@test "status --json: --all widens the scan and works from outside any repo" {
  cd "$(make_repo proj)"
  run_vibe start "task a" >/dev/null
  run_vibe start "task b" >/dev/null

  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  cd "$BATS_TEST_TMPDIR/elsewhere"
  run run_vibe status --all --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"scope": "all"'* ]]
  [[ "$output" == *"worktrees/proj/task-a"* ]]
  [[ "$output" == *"worktrees/proj/task-b"* ]]
}

@test "status --json: accepts the flags in either order" {
  cd "$(make_repo proj)"
  run run_vibe status --json --all
  [ "$status" -eq 0 ]
  [[ "$output" == *'"scope": "all"'* ]]
}

@test "status --json: an unknown option still names both flags" {
  cd "$(make_repo proj)"
  run run_vibe status --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"--all"* ]]
  [[ "$output" == *"--json"* ]]
}

# A machine with nothing running must still answer. If an idle host produced
# an error or a truncated document, a client could only report it the same way
# it reports a host that did not answer at all — which is the one failure that
# makes a monitor worse than no monitor.
@test "status --json: a host with no tasks emits an empty array, not an error" {
  cd "$BATS_TEST_TMPDIR"
  mkdir -p "$BATS_TEST_TMPDIR/nowhere"
  cd "$BATS_TEST_TMPDIR/nowhere"
  run run_vibe status --all --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"tasks": ['* ]]
  [[ "$output" == *'"hostname"'* ]]
  # nothing between the brackets
  [[ "$output" == *$'"tasks": [\n  ]'* ]]
}

# The colored dot is never in the document, so a client that cannot ask "was
# tmux even installed?" would read every null session as an idle machine.
@test "status --json: reports tmux absence as a fact of its own" {
  cd "$(make_repo proj)"
  run_vibe start "task nt" >/dev/null
  local notmux
  notmux="$(path_without tmux)"

  run env PATH="$notmux" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" status --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"tmux": false'* ]]
  [[ "$output" == *'"tmux_session": null'* ]]
}

# JSON is data, never a terminal painting. Forcing color must not reach it.
@test "status --json: carries no ANSI escapes even with color forced" {
  cd "$(make_repo proj)"
  run_vibe start "task c" >/dev/null
  run env CLICOLOR_FORCE=1 \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" status --json
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\033['* ]]
}

# ---------------------------------------------------------------------------
# Per-task fields
# ---------------------------------------------------------------------------
@test "status --json: a task with no loop state reports loop null" {
  cd "$(make_repo proj)"
  run_vibe start "task nl" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-nl"
  [ ! -f "$wt/.vibe-loop.state" ]

  run run_vibe status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$wt")"
  [[ "$block" == *'"loop": null'* ]]
  [[ "$block" == *'"kind": "task"'* ]]
}

@test "status --json: reports dirty, unpushed and upstream per task" {
  cd "$(make_repo proj)"
  run_vibe start "task d" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-d"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "handoff"
  echo scratch >"$wt/x.txt"

  run run_vibe status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$wt")"
  [[ "$block" == *'"dirty": true'* ]]
  # never pushed: every commit on the branch is unpushed, and there is no
  # upstream to be behind
  [[ "$block" == *'"unpushed": 1'* ]]
  [[ "$block" == *'"upstream": "none"'* ]]
  [[ "$block" == *'"handoff_age"'* ]]
  [[ "$block" != *'"handoff_age": null'* ]]
}

@test "status --json: a pushed branch reports its upstream and a zero count" {
  cd "$(make_repo proj)"
  run_vibe start "task up" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-up"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "handoff"
  git -C "$wt" push -q -u origin task-up

  run run_vibe status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$wt")"
  [[ "$block" == *'"upstream": "ok"'* ]]
  [[ "$block" == *'"unpushed": 0'* ]]
  [[ "$block" == *'"behind": 0'* ]]
  [[ "$block" == *'"dirty": false'* ]]
}

# 'upstream gone' with nothing unpushed is a merged PR — the signal that
# 'vibe done' can clean the task up, and the only reason a monitor would show
# a task as finished rather than stalled.
@test "status --json: a deleted remote branch reports upstream gone and state merged" {
  cd "$(make_repo proj)"
  run_vibe start "task g" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-g"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "handoff"
  git -C "$wt" push -q -u origin task-g
  # What a merged PR really leaves behind, and 'nothing unpushed' depends on
  # both halves: the work reachable from a remote ref, then the branch deleted
  # and pruned. Deleting the branch alone would make every commit on it
  # unpushed again, which is a stalled task, not a finished one.
  git -C "$BATS_TEST_TMPDIR/proj" merge -q --no-ff task-g -m "merge task-g"
  git -C "$BATS_TEST_TMPDIR/proj" push -q origin main
  git -C "$wt" push -q origin --delete task-g
  git -C "$wt" fetch -q --prune

  local livetmux
  livetmux="$(tmux_stub_live)"
  run env PATH="$livetmux:$PATH" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$wt")"
  [[ "$block" == *'"upstream": "gone"'* ]]
  [[ "$block" == *'"state": "merged"'* ]]
}

# With no session for a task, 'state' is idle whatever git says — the same
# gate the dim ○ has always had. Asserted here so the word and the dot cannot
# be given different meanings later.
@test "status --json: state is idle when no session is running for the task" {
  cd "$(make_repo proj)"
  run_vibe start "task i" >/dev/null
  run run_vibe status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$BATS_TEST_TMPDIR/worktrees/proj/task-i")"
  [[ "$block" == *'"state": "idle"'* ]]
  [[ "$block" == *'"tmux_session": null'* ]]
}

@test "status --json: a worktree whose directory is gone reports state missing" {
  cd "$(make_repo proj)"
  run_vibe start "task m" >/dev/null
  rm -rf "$BATS_TEST_TMPDIR/worktrees/proj/task-m"

  # A monitor renders this document and cannot ask a follow-up question. Judged
  # by git alone the vanished worktree is clean and in sync, so without a state
  # of its own it shows up as a healthy task on a machine where it no longer
  # exists — and a live session for it would even read as work in progress.
  local livetmux
  livetmux="$(tmux_stub_live)"
  run env PATH="$livetmux:$PATH" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$BATS_TEST_TMPDIR/worktrees/proj/task-m")"
  [[ "$block" == *'"state": "missing"'* ]]
}

@test "status --json: a live session is named, and a dirty tree says so" {
  cd "$(make_repo proj)"
  run_vibe start "task a" >/dev/null
  local livetmux
  livetmux="$(tmux_stub_live)"
  run env PATH="$livetmux:$PATH" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$BATS_TEST_TMPDIR/worktrees/proj/task-a")"
  [[ "$block" == *'"tmux_session": "vibe-proj-task-a"'* ]]
  [[ "$block" == *'"state": "dirty"'* ]]
}

# ---------------------------------------------------------------------------
# Detached HEAD — the two scopes discover it by different means
# ---------------------------------------------------------------------------
@test "status --json: a detached HEAD has a null branch, not a branch called HEAD" {
  cd "$(make_repo proj)"
  run_vibe start "task det" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-det"
  git -C "$wt" checkout -q --detach

  run run_vibe status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$wt")"
  [[ "$block" == *'"branch": null'* ]]
  [[ "$block" == *'"detached": true'* ]]
}

@test "status --all --json: a detached HEAD is detached in the --all scan too" {
  # --all walks directories instead of 'git worktree list', so it learns this
  # from symbolic-ref rather than from a porcelain 'detached' line.
  cd "$(make_repo proj)"
  run_vibe start "task deta" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-deta"
  git -C "$wt" checkout -q --detach

  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  cd "$BATS_TEST_TMPDIR/elsewhere"
  run run_vibe status --all --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$wt")"
  [[ "$block" == *'"branch": null'* ]]
  [[ "$block" == *'"detached": true'* ]]
}

# ---------------------------------------------------------------------------
# Kind — a monitor must not offer 'vibe done' on something vibe does not own
# ---------------------------------------------------------------------------
@test "status --json: labels the main checkout and unmanaged worktrees by kind" {
  cd "$(make_repo proj)"
  run_vibe start "task k" >/dev/null
  local main_phys stray
  main_phys="$(cd "$BATS_TEST_TMPDIR/proj" && pwd -P)"
  stray="$BATS_TEST_TMPDIR/stray-wt"
  git -C "$BATS_TEST_TMPDIR/proj" worktree add -q -b stray "$stray"
  stray="$(cd "$stray" && pwd -P)"

  run run_vibe status --json
  [ "$status" -eq 0 ]
  local main_block stray_block
  main_block="$(printf '%s\n' "$output" | task_block "$main_phys")"
  stray_block="$(printf '%s\n' "$output" | task_block "$stray")"
  [[ "$main_block" == *'"kind": "main"'* ]]
  [[ "$stray_block" == *'"kind": "unmanaged"'* ]]
  # the main checkout carries no handoff, which is null rather than "none"
  [[ "$main_block" == *'"handoff_age": null'* ]]
}

# ---------------------------------------------------------------------------
# Loop state — the correction that matters most to a monitor
# ---------------------------------------------------------------------------

# write_loop_state DIR KEY=VALUE... — a loop state file, without running a
# loop. The file is left untracked on purpose (a real one is git-excluded by
# 'vibe loop'), so these tests never assert on dirtiness.
write_loop_state() {
  local dir="$1"
  shift
  printf '%s\n' "$@" >"$dir/.vibe-loop.state"
}

@test "status --json: reports a loop's iteration, bound and last result" {
  cd "$(make_repo proj)"
  run_vibe start "task lp" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-lp"
  write_loop_state "$wt" \
    STATUS=maxed ITER=3 MAX=10 LAST=fail UPDATED=2026-07-30T19:02:11Z

  run run_vibe status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$wt")"
  [[ "$block" == *'"status": "maxed"'* ]]
  # numbers, not strings — a client should not have to parse them back
  [[ "$block" == *'"iter": 3,'* ]]
  [[ "$block" == *'"max": 10,'* ]]
  [[ "$block" == *'"last": "fail"'* ]]
  [[ "$block" == *'"updated": "2026-07-30T19:02:11Z"'* ]]
}

# A killed runner leaves STATUS=running behind with a dead PID. Reported
# verbatim, a monitor shows a crashed loop as healthy forever — the exact
# failure the text status line was already fixed for, and the reason both now
# read the status through loop_effective_status.
@test "status --json: a running loop with a dead runner reports interrupted" {
  cd "$(make_repo proj)"
  run_vibe start "task dead" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-dead" dead
  true &
  dead=$!
  wait "$dead"
  write_loop_state "$wt" STATUS=running "PID=$dead" ITER=1 MAX=2

  run run_vibe status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$wt")"
  [[ "$block" == *'"status": "interrupted"'* ]]
  [[ "$block" != *'"status": "running"'* ]]
}

# An empty PID is the launch window — the state file is written before tmux
# has started the runner — and must still read as running.
@test "status --json: a loop with no recorded PID yet still reports running" {
  cd "$(make_repo proj)"
  run_vibe start "task young" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-young"
  write_loop_state "$wt" STATUS=running PID= ITER=0 MAX=2

  run run_vibe status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$wt")"
  [[ "$block" == *'"status": "running"'* ]]
}

# MAX is absent for an unbounded loop, and a hand-edited state file can hold
# anything. Either way a client gets null rather than a document it cannot
# parse.
@test "status --json: a missing or non-numeric loop bound becomes null" {
  cd "$(make_repo proj)"
  run_vibe start "task nb" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-nb"
  write_loop_state "$wt" STATUS=running ITER=1 MAX=

  run run_vibe status --json
  [ "$status" -eq 0 ]
  local block
  block="$(printf '%s\n' "$output" | task_block "$wt")"
  [[ "$block" == *'"max": null'* ]]
  [[ "$block" == *'"iter": 1,'* ]]
}

# LAST is free text — it can carry whatever the --until command printed. An
# unescaped quote in it would corrupt the whole document, not just one field.
@test "status --json: escapes quotes, backslashes and tabs in a value" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  cd "$(make_repo proj)"
  run_vibe start "task esc" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-esc"
  printf 'STATUS=stalled\nLAST=%s\n' 'he said "hi" \ then	quit' >"$wt/.vibe-loop.state"

  run run_vibe status --json
  [ "$status" -eq 0 ]
  run python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
last = [t["loop"]["last"] for t in d["tasks"] if t["loop"]]
assert last == ["he said \"hi\" \\ then\tquit"], last
print("ok")
' <<<"$output"
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}
