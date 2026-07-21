#!/usr/bin/env bats
#
# vibe loop — the unattended agent loop: stop conditions, resume, divergence,
# and the guards other verbs grew around it. Every test drives a STUB agent on
# PATH; none invokes a real agent.

# 'run !' (asserting a command fails) needs 1.5.0.
bats_require_minimum_version 1.5.0

load helper

setup() { git_env; }

# ---------------------------------------------------------------------------
# A stub agent, controlled at call time by $STUB_MODE:
#   change (default) — append a line to progress.txt each round (real work,
#                      which the loop commits)
#   noop             — exit without changing anything
# The loop hands the prompt as the final argument (like `vibe park`), so the
# stub ignores its args. It counts invocations in $STUB_COUNT so an --until
# check can watch it, and — when $STUB_ARGS is set — records the argv it was
# handed, one argument per line, so a test can assert which configured flag
# sets reached the agent.
# ---------------------------------------------------------------------------
stub_agent() {
  local path="$BATS_TEST_TMPDIR/agent.sh"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
n=$(($(cat "$STUB_COUNT" 2>/dev/null || echo 0) + 1))
echo "$n" >"$STUB_COUNT"
if [ -n "${STUB_ARGS:-}" ]; then printf '%s\n' "$@" >>"$STUB_ARGS"; fi
[ "${STUB_MODE:-change}" = noop ] && exit 0
echo "iteration $n" >>progress.txt
exit 0
EOF
  chmod +x "$path"
  echo "$path"
}

# Run vibe with the stub agent and an isolated worktree root. STUB_MODE,
# VIBE_NTFY_TOPIC and PATH are taken from the caller's environment.
loop_vibe() {
  VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD="$BATS_TEST_TMPDIR/agent.sh" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    STUB_COUNT="$BATS_TEST_TMPDIR/count" \
    STUB_MODE="${STUB_MODE-}" \
    STUB_ARGS="${STUB_ARGS-}" \
    VIBE_NTFY_TOPIC="${VIBE_NTFY_TOPIC-}" \
    VIBE_LOOP_SANDBOX_ARGS="${VIBE_LOOP_SANDBOX_ARGS-}" \
    "$VIBE" "$@"
}

wt() { echo "$BATS_TEST_TMPDIR/worktrees/proj/$1"; }
loop_state() { sed -n "s/^$2=//p" "$(wt "$1")/.vibe-loop.state" | tail -1; }

# Rewrite one KEY=VALUE line in a state file, portably (no sed -i: BSD needs an
# arg, GNU does not).
set_state() {
  local f="$1" k="$2" v="$3"
  awk -v k="$k" -v v="$v" '{ if (index($0, k"=") == 1) print k"="v; else print }' \
    "$f" >"$f.t" && mv "$f.t" "$f"
}

# ---------------------------------------------------------------------------
# Stop conditions
# ---------------------------------------------------------------------------
@test "loop: stops when --until passes" {
  cd "$(make_repo proj)"
  stub_agent
  # shellcheck disable=SC2016  # this is a literal command string for the loop
  run loop_vibe loop "until task" \
    --until '[ -f progress.txt ] && [ "$(wc -l <progress.txt)" -ge 2 ]' --max 10
  [ "$status" -eq 0 ]
  [[ "$output" == *"stop check passed on iteration 2"* ]]
  [ "$(loop_state until-task STATUS)" = success ]
  [ "$(loop_state until-task ITER)" = 2 ]
}

@test "loop: stops at --max without passing" {
  cd "$(make_repo proj)"
  stub_agent
  run loop_vibe loop "max task" --until false --max 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"hit max 3 iterations"* ]]
  [ "$(loop_state max-task STATUS)" = maxed ]
  [ "$(loop_state max-task ITER)" = 3 ]
}

@test "loop: detects a stall (two rounds with no change)" {
  cd "$(make_repo proj)"
  stub_agent
  STUB_MODE=noop run loop_vibe loop "stall task" --max 10
  [ "$status" -eq 0 ]
  [[ "$output" == *"stalled"* ]]
  [ "$(loop_state stall-task STATUS)" = stalled ]
  [ "$(loop_state stall-task ITER)" = 2 ]
}

# ---------------------------------------------------------------------------
# The state file is runtime-only: gitignored, never dirtying the tree
# ---------------------------------------------------------------------------
@test "loop: keeps the worktree clean (state file is gitignored)" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "clean task" --until false --max 2
  [ -f "$(wt clean-task)/.vibe-loop.state" ]
  # no untracked/modified files: the state file must not show up
  [ -z "$(git -C "$(wt clean-task)" status --porcelain)" ]
}

# ---------------------------------------------------------------------------
# The agent's own output goes to a log, never onto the loop's terminal, where
# it would collide with the spinner (and, from a real CLI agent, arrive as
# echoed terminal-colour replies rather than text).
# ---------------------------------------------------------------------------
@test "loop: captures the agent's output in a log instead of the terminal" {
  cd "$(make_repo proj)"
  local path="$BATS_TEST_TMPDIR/agent.sh"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
echo "AGENT-CHATTER-STDOUT"
echo "AGENT-CHATTER-STDERR" >&2
echo work >>progress.txt
exit 0
EOF
  chmod +x "$path"

  run loop_vibe loop "quiet task" --until false --max 1
  [ "$status" -eq 0 ]
  [[ "$output" != *AGENT-CHATTER* ]]

  local log
  log="$(git -C "$(wt quiet-task)" rev-parse --absolute-git-dir)/vibe-agent.log"
  [ -f "$log" ]
  grep -q AGENT-CHATTER-STDOUT "$log"
  grep -q AGENT-CHATTER-STDERR "$log"
  # the log lives outside the working tree, so it cannot dirty it
  [ -z "$(git -C "$(wt quiet-task)" status --porcelain)" ]
}

# ---------------------------------------------------------------------------
# Resume: a killed runner picks up from the state file, not from zero
# ---------------------------------------------------------------------------
@test "loop: resumes from saved state after a kill" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "resume task" --until false --max 2
  local sf
  sf="$(wt resume-task)/.vibe-loop.state"
  [ "$(loop_state resume-task ITER)" = 2 ]
  [ "$(wc -l <"$(wt resume-task)/progress.txt")" -eq 2 ]

  # Simulate a kill mid-run: STATUS=running with a PID that is not alive.
  set_state "$sf" STATUS running
  set_state "$sf" PID 99999999

  run loop_vibe loop "resume task" --until false --max 4
  [ "$status" -eq 0 ]
  [[ "$output" == *"resuming loop"* ]]
  # continued at 3 and 4, did not restart at 1
  [ "$(loop_state resume-task ITER)" = 4 ]
  [ "$(wc -l <"$(wt resume-task)/progress.txt")" -eq 4 ]
}

@test "loop: refuses to start a second runner while one is live" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "busy task" --until false --max 1
  local sf live
  sf="$(wt busy-task)/.vibe-loop.state"
  # a genuinely live runner: mark running, point PID at a real sleeping process
  sleep 30 &
  live=$!
  set_state "$sf" STATUS running
  set_state "$sf" PID "$live"

  run loop_vibe loop "busy task" --until false --max 4
  kill "$live" 2>/dev/null || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"already running"* ]]
}

# ---------------------------------------------------------------------------
# --push: divergence stops the loop, like sync
# ---------------------------------------------------------------------------
@test "loop: --push stops when the remote has diverged" {
  cd "$(make_repo proj)"
  stub_agent
  # first round pushes, establishing an upstream for the branch
  loop_vibe loop "div task" --until false --max 1 --push
  git -C "$(wt div-task)" rev-parse '@{u}' >/dev/null 2>&1

  # a second clone pushes a diverging commit onto the same branch
  local other
  other="$(clone_repo proj other)"
  git -C "$other" fetch -q origin div-task
  git -C "$other" checkout -q -b div-task origin/div-task
  echo theirs >"$other/theirs.txt"
  git -C "$other" add -A
  git -C "$other" commit -q -m theirs
  git -C "$other" push -q origin div-task

  # resume with push: our new commit + their commit = divergence at push time
  local sf
  sf="$(wt div-task)/.vibe-loop.state"
  set_state "$sf" STATUS running
  set_state "$sf" PID 99999999
  run loop_vibe loop "div task" --until false --max 4 --push
  [ "$status" -eq 0 ]
  [[ "$output" == *"diverged"* ]]
  [ "$(loop_state div-task STATUS)" = stopped ]
}

# ---------------------------------------------------------------------------
# Notifications: silent no-op when the topic is unset
# ---------------------------------------------------------------------------
@test "loop: ntfy is a silent no-op when the topic is unset" {
  cd "$(make_repo proj)"
  stub_agent
  # a fake curl that would leave a marker if it were ever called
  mkdir -p "$BATS_TEST_TMPDIR/fakebin"
  {
    echo '#!/usr/bin/env bash'
    echo "touch '$BATS_TEST_TMPDIR/curl-was-called'"
  } >"$BATS_TEST_TMPDIR/fakebin/curl"
  chmod +x "$BATS_TEST_TMPDIR/fakebin/curl"

  VIBE_NTFY_TOPIC="" PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" \
    run loop_vibe loop "quiet task" --until false --max 2
  [ "$status" -eq 0 ]
  [ ! -f "$BATS_TEST_TMPDIR/curl-was-called" ]
}

# ---------------------------------------------------------------------------
# Fit with the other verbs
# ---------------------------------------------------------------------------
@test "loop: done refuses while the loop is running" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "guard task" --until false --max 1
  local sf live
  sf="$(wt guard-task)/.vibe-loop.state"
  sleep 30 &
  live=$!
  set_state "$sf" STATUS running
  set_state "$sf" PID "$live"

  run loop_vibe "done" "guard task"
  kill "$live" 2>/dev/null || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"still running"* ]]
  [ -d "$(wt guard-task)" ]
}

@test "loop: done --stop --force clears a running loop and removes it" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "stopme task" --until false --max 1
  local sf live
  sf="$(wt stopme-task)/.vibe-loop.state"
  sleep 30 &
  live=$!
  set_state "$sf" STATUS running
  set_state "$sf" PID "$live"

  run loop_vibe "done" --stop --force "stopme task"
  kill "$live" 2>/dev/null || true
  [ "$status" -eq 0 ]
  [ ! -d "$(wt stopme-task)" ]
}

@test "done: refuses while LOOP.md is still on the branch" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "brief task" --until false --max 1 --push
  run loop_vibe "done" "brief task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"LOOP.md"* ]]
  [ -d "$(wt brief-task)" ]
}

@test "done: --keep-brief removes the worktree, brief stays in history" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "keep brief" --until false --max 1 --push
  run loop_vibe "done" --keep-brief "keep brief"
  [ "$status" -eq 0 ]
  [ ! -d "$(wt keep-brief)" ]
  git show keep-brief:LOOP.md >/dev/null
}

@test "done: passes once the brief is deleted and synced" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "del brief" --until false --max 1 --push
  git -C "$(wt del-brief)" rm -q LOOP.md
  git -C "$(wt del-brief)" commit -q -m "chore: drop loop brief"
  git -C "$(wt del-brief)" push -q
  run loop_vibe "done" "del brief"
  [ "$status" -eq 0 ]
  [ ! -d "$(wt del-brief)" ]
}

@test "loop: --no-attach refuses on local before creating anything" {
  cd "$(make_repo proj)"
  stub_agent
  run loop_vibe loop "det task" --no-attach --max 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"server"* ]]
  [ ! -d "$(wt det-task)" ]
}

@test "loop: attach notes an active loop instead of touching the branch" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "watch task" --until false --max 1
  local sf live
  sf="$(wt watch-task)/.vibe-loop.state"
  sleep 30 &
  live=$!
  set_state "$sf" STATUS running
  set_state "$sf" PID "$live"

  run loop_vibe attach "watch task"
  kill "$live" 2>/dev/null || true
  [ "$status" -eq 0 ]
  [[ "$output" == *"loop is active"* ]]
}

# ---------------------------------------------------------------------------
# status shows loop tasks inline in the worktree listing
# ---------------------------------------------------------------------------
@test "loop: status shows the loop's iteration and last result" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "shown task" --until false --max 2
  run loop_vibe status
  [ "$status" -eq 0 ]
  [[ "$output" == *"loop iter 2/2"* ]]
  [[ "$output" == *"maxed"* ]]
}

# ---------------------------------------------------------------------------
# LOOP.md is rendered from the template, tokens all substituted
# ---------------------------------------------------------------------------
@test "loop: seeds LOOP.md from the shared template" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "Doc Task" --until false --max 1
  local f
  f="$(wt doc-task)/LOOP.md"
  [ -f "$f" ]
  grep -q "^# Loop — proj / doc-task$" "$f"
  grep -q "Doc Task" "$f"
  run grep -qE '<(repo|branch|worktree|goal|until|max|date|machine)>' "$f"
  [ "$status" -ne 0 ]
}

@test "loop: --prompt substitutes a custom brief" {
  cd "$(make_repo proj)"
  stub_agent
  printf '# Custom brief for <branch>\n\nDo the thing.\n' >"$BATS_TEST_TMPDIR/brief.md"
  loop_vibe loop "custom task" --prompt "$BATS_TEST_TMPDIR/brief.md" --until false --max 1
  local f
  f="$(wt custom-task)/LOOP.md"
  grep -q "Custom brief for custom-task" "$f"
}

@test "loop: adopts a branch that exists only on origin instead of shadowing it" {
  cd "$(make_repo proj)"
  stub_agent
  # the "other machine": pushes a branch carrying a hand-written brief
  local other
  other="$(clone_repo proj other)"
  git -C "$other" checkout -q -b remote-task
  printf '# my brief\n\n## Goal\n\nDo the pushed thing.\n' >"$other/LOOP.md"
  git -C "$other" add LOOP.md
  git -C "$other" commit -q -m "brief"
  git -C "$other" push -q origin remote-task

  # this machine has neither a local 'remote-task' branch nor a fetched ref
  run loop_vibe loop "remote task" --until true --max 1
  [ "$status" -eq 0 ]
  # seed_loop skipped the pushed brief instead of overwriting it
  grep -q "Do the pushed thing" "$(wt remote-task)/LOOP.md"
  # the worktree's branch tracks origin and contains the pushed commit
  git -C "$(wt remote-task)" rev-parse '@{u}' >/dev/null
  run git -C "$(wt remote-task)" log --oneline
  [[ "$output" == *"brief"* ]]
}

@test "loop: --dangerously-allow-all refuses without permissive args configured" {
  cd "$(make_repo proj)"
  stub_agent
  run loop_vibe loop "danger task" --dangerously-allow-all --max 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"VIBE_LOOP_PERMISSIVE_ARGS"* ]]
}

# ---------------------------------------------------------------------------
# --sandbox: the third source of agent arguments. Empty by default, so the flag
# refuses rather than silently running the agent unconfined.
# ---------------------------------------------------------------------------
@test "loop: --sandbox refuses without sandbox args configured" {
  cd "$(make_repo proj)"
  stub_agent
  run loop_vibe loop "boxed task" --sandbox --max 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"VIBE_LOOP_SANDBOX_ARGS"* ]]
}

@test "loop: --sandbox appends VIBE_LOOP_SANDBOX_ARGS to the agent invocation" {
  cd "$(make_repo proj)"
  stub_agent
  STUB_ARGS="$BATS_TEST_TMPDIR/argv" \
    VIBE_LOOP_SANDBOX_ARGS="--stub-box /tmp" \
    run loop_vibe loop "boxed task" --sandbox --until false --max 1
  [ "$status" -eq 0 ]
  # word-split into two arguments, like its siblings
  grep -qx -- "--stub-box" "$BATS_TEST_TMPDIR/argv"
  grep -qx -- "/tmp" "$BATS_TEST_TMPDIR/argv"
}

@test "loop: without --sandbox the agent gets no sandbox args" {
  cd "$(make_repo proj)"
  stub_agent
  STUB_ARGS="$BATS_TEST_TMPDIR/argv" \
    VIBE_LOOP_SANDBOX_ARGS="--stub-box" \
    run loop_vibe loop "plain task" --until false --max 1
  [ "$status" -eq 0 ]
  run ! grep -qx -- "--stub-box" "$BATS_TEST_TMPDIR/argv"
  [ "$(loop_state plain-task SANDBOX)" = 0 ]
}

@test "loop: a resumed loop stays sandboxed without repeating the flag" {
  cd "$(make_repo proj)"
  stub_agent
  VIBE_LOOP_SANDBOX_ARGS="--stub-box" \
    loop_vibe loop "resume boxed" --sandbox --until false --max 1
  [ "$(loop_state resume-boxed SANDBOX)" = 1 ]

  local sf
  sf="$(wt resume-boxed)/.vibe-loop.state"
  set_state "$sf" STATUS running
  set_state "$sf" PID 99999999

  STUB_ARGS="$BATS_TEST_TMPDIR/argv" \
    VIBE_LOOP_SANDBOX_ARGS="--stub-box" \
    run loop_vibe loop "resume boxed" --until false --max 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"resuming loop"* ]]
  grep -qx -- "--stub-box" "$BATS_TEST_TMPDIR/argv"
  [ "$(loop_state resume-boxed SANDBOX)" = 1 ]
}

@test "loop: a state file written before --sandbox existed still resumes" {
  cd "$(make_repo proj)"
  stub_agent
  loop_vibe loop "legacy task" --until false --max 1
  local sf
  sf="$(wt legacy-task)/.vibe-loop.state"
  # an old runner's state: no SANDBOX key at all
  grep -v '^SANDBOX=' "$sf" >"$sf.t" && mv "$sf.t" "$sf"
  set_state "$sf" STATUS running
  set_state "$sf" PID 99999999

  run loop_vibe loop "legacy task" --until false --max 2
  [ "$status" -eq 0 ]
  [ "$(loop_state legacy-task ITER)" = 2 ]
  [ "$(loop_state legacy-task SANDBOX)" = 0 ]
}
