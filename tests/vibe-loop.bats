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

# A foreground loop exits with its outcome (0 success, 2 stalled, 3 maxed,
# 4 timeup, 5 stopped — docs/vibe-loop.md). Tests that run a loop only for
# its side effects swallow exactly those codes here, so a real failure
# (die exits 1) still fails the test.
loop_ended() {
  local rc=0
  loop_vibe "$@" || rc=$?
  case "$rc" in
    2 | 3 | 4 | 5) return 0 ;;
    *) return "$rc" ;;
  esac
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
# --for: the wall-clock bound. A deadline of 0s is already spent by the time
# the first round's stop check runs, so one iteration is enough to exercise it
# without making the suite wait on a clock.
@test "loop: --for rejects a duration it cannot parse" {
  cd "$(make_repo proj)"
  stub_agent
  run ! loop_vibe loop "bad for" --for 90x --max 1
  [[ "$output" == *"--for must be a duration"* ]]
}

@test "loop: a second bare word is an error, not a silently truncated task" {
  # 'vibe loop sota 2026-W30' quietly looped on branch '2026-w30' before.
  cd "$(make_repo proj)"
  stub_agent
  run ! loop_vibe loop sota 2026-W30 --max 1
  [[ "$output" == *"one task at a time"* ]]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/2026-w30" ]
}

@test "loop: --for= stops the loop once its time budget is spent" {
  cd "$(make_repo proj)"
  stub_agent
  run loop_vibe loop "timed task" --until false --for=0s --max 10
  [ "$status" -eq 4 ]
  [[ "$output" == *"time budget spent"* ]]
  [ "$(loop_state timed-task STATUS)" = timeup ]
  [ "$(loop_state timed-task ITER)" = 1 ]
}

@test "loop: a resumed loop keeps the original --for deadline" {
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "keep deadline" --until false --for 6h --max 1
  local first
  first="$(loop_state keep-deadline DEADLINE)"
  [ -n "$first" ]
  run loop_vibe loop "keep deadline" --until false --max 2
  [ "$status" -eq 3 ]
  [ "$(loop_state keep-deadline DEADLINE)" = "$first" ]
}

@test "loop: --for pushes the final round before stopping" {
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "timed push" --until false --for=0s --max 10 --push
  [ "$(loop_state timed-push STATUS)" = timeup ]
  # The remote must actually hold the final round's commit — asserting only
  # "not ahead" passed vacuously whenever the status command itself failed.
  local local_head remote_head
  local_head="$(git -C "$(wt timed-push)" rev-parse HEAD)"
  remote_head="$(git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse refs/heads/timed-push)"
  [ -n "$local_head" ]
  [ "$local_head" = "$remote_head" ]
}

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
  [ "$status" -eq 3 ]
  [[ "$output" == *"hit max 3 iterations"* ]]
  [ "$(loop_state max-task STATUS)" = maxed ]
  [ "$(loop_state max-task ITER)" = 3 ]
}

@test "loop: detects a stall (two rounds with no change)" {
  cd "$(make_repo proj)"
  stub_agent
  STUB_MODE=noop run loop_vibe loop "stall task" --max 10
  [ "$status" -eq 2 ]
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
  loop_ended loop "clean task" --until false --max 2
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
  [ "$status" -eq 3 ]
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
  loop_ended loop "resume task" --until false --max 2
  local sf
  sf="$(wt resume-task)/.vibe-loop.state"
  [ "$(loop_state resume-task ITER)" = 2 ]
  [ "$(wc -l <"$(wt resume-task)/progress.txt")" -eq 2 ]

  # Simulate a kill mid-run: STATUS=running with a PID that is not alive.
  set_state "$sf" STATUS running
  set_state "$sf" PID 99999999

  run loop_vibe loop "resume task" --until false --max 4
  [ "$status" -eq 3 ]
  [[ "$output" == *"resuming loop"* ]]
  # continued at 3 and 4, did not restart at 1
  [ "$(loop_state resume-task ITER)" = 4 ]
  [ "$(wc -l <"$(wt resume-task)/progress.txt")" -eq 4 ]
}

@test "loop: refuses to start a second runner while one is live" {
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "busy task" --until false --max 1
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
  loop_ended loop "div task" --until false --max 1 --push
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
  [ "$status" -eq 5 ]
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
  [ "$status" -eq 3 ]
  [ ! -f "$BATS_TEST_TMPDIR/curl-was-called" ]
}

# ---------------------------------------------------------------------------
# Fit with the other verbs
# ---------------------------------------------------------------------------
@test "loop: done refuses while the loop is running" {
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "guard task" --until false --max 1
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
  loop_ended loop "stopme task" --until false --max 1
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
  loop_ended loop "brief task" --until false --max 1 --push
  run loop_vibe "done" "brief task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"LOOP.md"* ]]
  [ -d "$(wt brief-task)" ]
}

@test "done: --keep-brief removes the worktree, brief stays in history" {
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "keep brief" --until false --max 1 --push
  run loop_vibe "done" --keep-brief "keep brief"
  [ "$status" -eq 0 ]
  [ ! -d "$(wt keep-brief)" ]
  git show keep-brief:LOOP.md >/dev/null
}

@test "done: passes once the brief is deleted and synced" {
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "del brief" --until false --max 1 --push
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
  loop_ended loop "watch task" --until false --max 1
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
  loop_ended loop "shown task" --until false --max 2
  run loop_vibe status
  [ "$status" -eq 0 ]
  [[ "$output" == *"loop iter 2/2"* ]]
  [[ "$output" == *"maxed"* ]]
}

@test "loop: status calls a running loop with a dead runner interrupted" {
  # A killed runner leaves STATUS=running behind with a dead PID. loop_active
  # already treats that as not-running (so resume works); the status line
  # printed the raw word "running" anyway, reporting a crashed loop as
  # healthy forever.
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "dead runner" --until false --max 1
  local sf dead
  sf="$(wt dead-runner)/.vibe-loop.state"
  true &
  dead=$!
  wait "$dead"
  set_state "$sf" STATUS running
  set_state "$sf" PID "$dead"
  run loop_vibe status
  [ "$status" -eq 0 ]
  [[ "$output" == *"interrupted"* ]]
  [[ "$output" != *"· running"* ]]

  # An empty PID is the launch window — cmd_loop writes the state before
  # tmux starts the runner — and that must still read as running.
  set_state "$sf" PID ""
  run loop_vibe status
  [ "$status" -eq 0 ]
  [[ "$output" == *"· running"* ]]
}

# ---------------------------------------------------------------------------
# LOOP.md is rendered from the template, tokens all substituted
# ---------------------------------------------------------------------------
@test "loop: seeds LOOP.md from the shared template" {
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "Doc Task" --until false --max 1
  local f
  f="$(wt doc-task)/LOOP.md"
  [ -f "$f" ]
  grep -q "^# Loop — proj / doc-task$" "$f"
  grep -q "Doc Task" "$f"
  run grep -qE '<(repo|branch|worktree|goal|until|max|date|machine)>' "$f"
  [ "$status" -ne 0 ]
}

@test "loop: an --until holding '&&' renders verbatim into LOOP.md" {
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "amp task" --until 'a && b && c' --max 1
  local f
  f="$(wt amp-task)/LOOP.md"
  # bash >= 5.2 would expand each unescaped '&' to the matched token
  run grep -qF 'a && b && c' "$f"
  [ "$status" -eq 0 ]
  run grep -qF '<until>' "$f"
  [ "$status" -ne 0 ]
}

@test "loop: a goal that names another placeholder renders literally" {
  # Sequential substitution re-substituted a later token inside an earlier
  # value: a goal mentioning <machine> rendered as "document the local
  # (host) placeholder" in the brief. The renderer must never rescan what
  # it just inserted.
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "document the <machine> placeholder" --until false --max 1
  local f
  f="$(wt document-the-machine-placeholder)/LOOP.md"
  [ -f "$f" ]
  grep -q "document the <machine> placeholder" "$f"
}

@test "loop: --prompt substitutes a custom brief" {
  cd "$(make_repo proj)"
  stub_agent
  printf '# Custom brief for <branch>\n\nDo the thing.\n' >"$BATS_TEST_TMPDIR/brief.md"
  loop_ended loop "custom task" --prompt "$BATS_TEST_TMPDIR/brief.md" --until false --max 1
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
  [ "$status" -eq 3 ]
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
  [ "$status" -eq 3 ]
  run ! grep -qx -- "--stub-box" "$BATS_TEST_TMPDIR/argv"
  [ "$(loop_state plain-task SANDBOX)" = 0 ]
}

@test "loop: a resumed loop stays sandboxed without repeating the flag" {
  cd "$(make_repo proj)"
  stub_agent
  VIBE_LOOP_SANDBOX_ARGS="--stub-box" \
    loop_ended loop "resume boxed" --sandbox --until false --max 1
  [ "$(loop_state resume-boxed SANDBOX)" = 1 ]

  local sf
  sf="$(wt resume-boxed)/.vibe-loop.state"
  set_state "$sf" STATUS running
  set_state "$sf" PID 99999999

  STUB_ARGS="$BATS_TEST_TMPDIR/argv" \
    VIBE_LOOP_SANDBOX_ARGS="--stub-box" \
    run loop_vibe loop "resume boxed" --until false --max 2
  [ "$status" -eq 3 ]
  [[ "$output" == *"resuming loop"* ]]
  grep -qx -- "--stub-box" "$BATS_TEST_TMPDIR/argv"
  [ "$(loop_state resume-boxed SANDBOX)" = 1 ]
}

@test "loop: a state file written before --sandbox existed still resumes" {
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "legacy task" --until false --max 1
  local sf
  sf="$(wt legacy-task)/.vibe-loop.state"
  # an old runner's state: no SANDBOX key at all
  grep -v '^SANDBOX=' "$sf" >"$sf.t" && mv "$sf.t" "$sf"
  set_state "$sf" STATUS running
  set_state "$sf" PID 99999999

  run loop_vibe loop "legacy task" --until false --max 2
  [ "$status" -eq 3 ]
  [ "$(loop_state legacy-task ITER)" = 2 ]
  [ "$(loop_state legacy-task SANDBOX)" = 0 ]
}

# ---------------------------------------------------------------------------
# --pr: the loop opens its own pull request
# ---------------------------------------------------------------------------
# A stub 'gh' on PATH, controlled by the environment at call time:
#   GH_LOG      — every invocation's argv, one argument per line, '--' between
#   GH_EXISTING — what 'gh pr list' reports as the open PR for the branch
#   GH_FAIL     — non-empty makes every subcommand exit 1 (unauthenticated)
# 'gh pr create' echoes a URL the way the real one does.
stub_gh() {
  local dir="$BATS_TEST_TMPDIR/ghbin"
  mkdir -p "$dir"
  cat >"$dir/gh" <<'EOF'
#!/usr/bin/env bash
if [ -n "${GH_LOG:-}" ]; then printf '%s\n' "$@" '--' >>"$GH_LOG"; fi
[ -n "${GH_FAIL:-}" ] && exit 1
case "$2" in
  list) printf '%s\n' "${GH_EXISTING:-}" ;;
  create) echo "https://github.test/proj/pull/7" ;;
esac
exit 0
EOF
  chmod +x "$dir/gh"
  PATH="$dir:$PATH"
  export PATH GH_LOG="$BATS_TEST_TMPDIR/gh.log"
}

@test "loop: --pr implies --push" {
  cd "$(make_repo proj)"
  stub_agent
  stub_gh
  loop_vibe loop "implied push" --until true --max 1 --pr
  [ "$(loop_state implied-push PR)" = 1 ]
  [ "$(loop_state implied-push PUSH)" = 1 ]
  git -C "$(wt implied-push)" rev-parse '@{u}' >/dev/null 2>&1
}

@test "loop: --pr opens a ready PR when the stop check passed" {
  cd "$(make_repo proj)"
  stub_agent
  stub_gh
  run loop_vibe loop "pr task" --until true --max 1 --pr
  [ "$status" -eq 0 ]
  [ "$(loop_state pr-task STATUS)" = success ]
  [[ "$output" == *"opened PR: https://github.test/proj/pull/7"* ]]
  grep -qx -- "create" "$GH_LOG"
  # ready for review, not a draft
  run ! grep -qx -- "--draft" "$GH_LOG"
}

@test "loop: --pr opens a draft when the loop did not pass" {
  cd "$(make_repo proj)"
  stub_agent
  stub_gh
  run loop_vibe loop "draft task" --until false --max 1 --pr
  [ "$status" -eq 3 ]
  [ "$(loop_state draft-task STATUS)" = maxed ]
  [[ "$output" == *"opened draft PR"* ]]
  grep -qx -- "--draft" "$GH_LOG"
}

@test "loop: --pr drops the brief and the handoff from the branch" {
  cd "$(make_repo proj)"
  stub_agent
  stub_gh
  # a handoff on the branch too: both are input, neither belongs in the diff
  git checkout -q -b stripped-task
  printf '# handoff\n' >HANDOFF.md
  git add -A
  git commit -q -m "seed handoff"
  git checkout -q main

  loop_vibe loop "stripped task" --until true --max 1 --pr
  local dir
  dir="$(wt stripped-task)"
  run git -C "$dir" ls-files -- LOOP.md HANDOFF.md
  [ -z "$output" ]
  [ ! -f "$dir/LOOP.md" ]
  # the brief is archived, not lost
  [ -f "$(git -C "$dir" rev-parse --absolute-git-dir)/vibe-loop-brief.md" ]
}

@test "loop: a resumed loop gets back the exact brief its PR stripped" {
  cd "$(make_repo proj)"
  stub_agent
  stub_gh
  loop_vibe loop "restored task" --until true --max 1 --pr
  local dir
  dir="$(wt restored-task)"
  # a refined brief, not a fresh render of the task string
  printf '# refined\n\n## Goal\n\nThe refined goal.\n' \
    >"$(git -C "$dir" rev-parse --absolute-git-dir)/vibe-loop-brief.md"

  local sf="$dir/.vibe-loop.state"
  set_state "$sf" STATUS running
  set_state "$sf" PID 99999999
  # PR=1 carries forward, so the resume finds its own PR already open.
  GH_EXISTING="https://github.test/proj/pull/7" \
    run loop_vibe loop "restored task" --until false --max 2
  [ "$status" -eq 3 ]
  [[ "$output" == *"restored LOOP.md from the archived brief"* ]]
  # The resumed rounds ran against the refined brief, and the end of the run
  # stripped it off the branch again — re-archived, not lost.
  grep -q "The refined goal." \
    "$(git -C "$dir" rev-parse --absolute-git-dir)/vibe-loop-brief.md"
  run git -C "$dir" ls-files -- LOOP.md
  [ -z "$output" ]
}

@test "loop: --pr leaves an already-open PR alone" {
  cd "$(make_repo proj)"
  stub_agent
  stub_gh
  GH_EXISTING="https://github.test/proj/pull/3" \
    run loop_vibe loop "second pr" --until true --max 1 --pr
  [ "$status" -eq 0 ]
  [[ "$output" == *"PR already open"* ]]
  run ! grep -qx -- "create" "$GH_LOG"
  # The brief is still stripped and pushed: a merge from GitHub never passes
  # vibe done's guards, so leaving LOOP.md here would land it on main.
  run git -C "$(wt second-pr)" ls-files -- LOOP.md
  [ -z "$output" ]
}

@test "loop: --pr warns instead of failing when gh cannot reach GitHub" {
  cd "$(make_repo proj)"
  stub_agent
  stub_gh
  GH_FAIL=1 run loop_vibe loop "no auth" --until true --max 1 --pr
  [ "$status" -eq 0 ]
  [ "$(loop_state no-auth STATUS)" = success ]
  [[ "$output" == *"no PR opened"* ]]
  # The brief is stripped and pushed BEFORE the gh checks give up: the warn
  # says to open the PR by hand, and when the gh checks ran first that
  # advice handed over a branch with LOOP.md still on it — the hand-opened
  # PR carried the brief in its diff.
  run git -C "$(wt no-auth)" ls-files -- LOOP.md
  [ -z "$output" ]
  # the stripped state is what was pushed, so opening by hand is safe
  local local_head remote_head
  local_head="$(git -C "$(wt no-auth)" rev-parse HEAD)"
  remote_head="$(git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse refs/heads/no-auth)"
  [ "$local_head" = "$remote_head" ]
}

# ---------------------------------------------------------------------------
# Server path: reusing (or refusing) the task's existing tmux session
# ---------------------------------------------------------------------------
# A tmux stub that, unlike the helper's, reports the session as existing —
# with a pane running PANE_CMD — so the reuse/refuse fork can be exercised.
stub_tmux_existing() { # stub_tmux_existing PANE_CMD
  local dir="$BATS_TEST_TMPDIR/tmuxbin"
  mkdir -p "$dir"
  cat >"$dir/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"\${VIBE_TEST_TMUX_LOG:?}"
case "\${1:-}" in
  has-session) exit 0 ;;
  display-message) echo "$1" ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"
  PATH="$dir:$PATH"
}

# A tmux that fails to create sessions — the launch-failure path. The state
# file is written as "running" *before* tmux runs, so the failure must not
# leave it that way.
stub_tmux_failing() {
  local dir="$BATS_TEST_TMPDIR/tmuxbin"
  mkdir -p "$dir"
  cat >"$dir/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"\${VIBE_TEST_TMUX_LOG:?}"
case "\${1:-}" in
  has-session) exit 1 ;;
  new-session) exit 1 ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"
  PATH="$dir:$PATH"
}

@test "loop: on the server a fresh loop starts detached inside tmux" {
  # The helper's stub tmux reports no session, so this takes the new-session
  # branch: state written as running, the runner typed into the session, and
  # --no-attach leaves it detached. The stub never runs the runner, which is
  # the point — cmd_loop's job ends at handing the loop to tmux.
  cd "$(make_repo proj)"
  stub_agent
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD="$BATS_TEST_TMPDIR/agent.sh" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" loop "srv fresh" --no-attach --max 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"starting loop in tmux session"* ]]
  [[ "$output" == *"loop running detached"* ]]
  grep -q "new-session -d -s vibe-proj-srv-fresh " "$VIBE_TEST_TMUX_LOG"
  grep -q "send-keys -t vibe-proj-srv-fresh .*__loop-run" "$VIBE_TEST_TMUX_LOG"
  # no attach: started from a script, attaching would hang the caller
  run ! grep -qE "attach-session|switch-client" "$VIBE_TEST_TMUX_LOG"
  [ "$(loop_state srv-fresh STATUS)" = running ]
}

@test "loop: the runner is handed this invocation's VIBE_* values" {
  # The pane's environment comes from the tmux SERVER process, not from the
  # shell that ran 'vibe loop', so without the env prefix on the typed
  # command the runner re-resolved VIBE_* from whatever the first
  # tmux-touching command on the machine had: a loop that passed the
  # sandbox/permissive validation here ran without those args in the pane —
  # state saying SANDBOX=1, agent argv carrying nothing.
  cd "$(make_repo proj)"
  stub_agent
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD="$BATS_TEST_TMPDIR/agent.sh" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    VIBE_LOOP_SANDBOX_ARGS="--sandbox-flag" \
    VIBE_LOOP_PERMISSIVE_ARGS="--yolo-flag" \
    "$VIBE" loop "env carry" --no-attach --max 1 --sandbox --dangerously-allow-all
  [ "$status" -eq 0 ]
  local typed
  typed="$(grep "send-keys -t vibe-proj-env-carry" "$VIBE_TEST_TMUX_LOG")"
  [[ "$typed" == *"VIBE_AGENT_CMD=$BATS_TEST_TMPDIR/agent.sh"* ]]
  [[ "$typed" == *"VIBE_LOOP_SANDBOX_ARGS=--sandbox-flag"* ]]
  [[ "$typed" == *"VIBE_LOOP_PERMISSIVE_ARGS=--yolo-flag"* ]]
}

@test "loop: __loop-run drives a loop from its saved state" {
  # This is what the tmux session actually executes on the server. Seed state
  # with a finished local loop, raise MAX, and hand the worktree to
  # __loop-run — it must pick up ITER/MAX from the state file and continue.
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "runner task" --until false --max 1
  [ "$(loop_state runner-task ITER)" = 1 ]
  set_state "$(wt runner-task)/.vibe-loop.state" MAX 2

  run loop_vibe __loop-run "$(wt runner-task)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hit max 2 iterations"* ]]
  [ "$(loop_state runner-task STATUS)" = maxed ]
  [ "$(loop_state runner-task ITER)" = 2 ]
}

@test "loop: __loop-run refuses a worktree that has no loop state" {
  cd "$(make_repo proj)"
  run loop_vibe __loop-run "$BATS_TEST_TMPDIR/proj"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no loop state"* ]]

  run loop_vibe __loop-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage: vibe __loop-run"* ]]

  run loop_vibe __loop-run "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no worktree at"* ]]
}

@test "rc: refuses while the session is running a loop" {
  # /rc typed into a loop session lands on the runner, not an agent prompt.
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "rc loop" --until false --max 1
  local sf live
  sf="$(wt rc-loop)/.vibe-loop.state"
  sleep 30 &
  live=$!
  set_state "$sf" STATUS running
  set_state "$sf" PID "$live"
  stub_tmux_existing claude
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD="$BATS_TEST_TMPDIR/agent.sh" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" rc "rc loop"
  kill "$live" 2>/dev/null || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"running a loop, not an interactive agent"* ]]
  # and nothing was typed into the session
  run ! grep -q "send-keys" "$VIBE_TEST_TMUX_LOG"
}

@test "loop: a failed tmux launch marks the state stopped, not running" {
  cd "$(make_repo proj)"
  stub_agent
  stub_tmux_failing
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD="$BATS_TEST_TMPDIR/agent.sh" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" loop "no tmux" --no-attach --max 1
  [ "$status" -eq 1 ]
  # Without the guard, the launch failure died mid-command via set -e and
  # left STATUS=running with no runner — reported as a live loop forever.
  [ "$(loop_state no-tmux STATUS)" = stopped ]
}

@test "loop: a leftover idle tmux session gets the runner typed back into it" {
  cd "$(make_repo proj)"
  stub_agent
  stub_tmux_existing bash
  # SSH_CONNECTION set on purpose: this is the server path.
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD="$BATS_TEST_TMPDIR/agent.sh" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    STUB_COUNT="$BATS_TEST_TMPDIR/count" \
    "$VIBE" loop "idle sess" --no-attach --max 1
  [ "$status" -eq 0 ]
  # The old path said "already exists", attached, and ran nothing — leaving
  # the state file at STATUS=running with no runner behind it.
  [[ "$output" == *"restarting loop in existing tmux session"* ]]
  grep -q "send-keys -t vibe-proj-idle-sess .*__loop-run" "$VIBE_TEST_TMUX_LOG"
  run ! grep -q "new-session" "$VIBE_TEST_TMUX_LOG"
}

@test "loop: refuses a tmux session that is busy running something else" {
  cd "$(make_repo proj)"
  stub_agent
  stub_tmux_existing claude
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD="$BATS_TEST_TMPDIR/agent.sh" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    STUB_COUNT="$BATS_TEST_TMPDIR/count" \
    "$VIBE" loop "busy sess" --no-attach --max 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"busy running 'claude'"* ]]
  # Refused before anything was written: no worktree, no state saying running.
  [ ! -d "$(wt busy-sess)" ]
}

@test "loop: done --stop keeps the PR flag in the state file" {
  cd "$(make_repo proj)"
  stub_agent
  loop_ended loop "stop pr" --until false --max 1
  local sf live
  sf="$(wt stop-pr)/.vibe-loop.state"
  sleep 30 &
  live=$!
  set_state "$sf" STATUS running
  set_state "$sf" PID "$live"
  set_state "$sf" PR 1
  # done goes on to refuse (unpushed work) — the stop still happened, and the
  # rewrite it does must not lose PR, or the next resume forgets to open one.
  run loop_vibe "done" --stop "stop pr"
  kill "$live" 2>/dev/null || true
  [ "$(loop_state stop-pr STATUS)" = stopped ]
  [ "$(loop_state stop-pr PR)" = 1 ]
}
