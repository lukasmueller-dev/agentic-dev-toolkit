#!/usr/bin/env bats
#
# skills/handoff-brief/handoff.sh — staging a refined HANDOFF.md on a task
# branch before a dedicated session picks it up. Everything runs in throwaway
# repos under $BATS_TEST_TMPDIR.

load helper

setup() { git_env; }

HANDOFF="$REPO_ROOT/skills/handoff-brief/handoff.sh"

run_handoff() {
  VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    bash "$HANDOFF" "$@"
}

wt() { echo "$BATS_TEST_TMPDIR/worktrees/proj/$1"; }

# finish_handoff DIR — replace the State and Next action placeholders with
# real content, the way the model would after refinement.
finish_handoff() {
  local f="$1/HANDOFF.md"
  awk '
    /^## State$/ { print; print ""; print "Not started. We decided to use bats."; skip = 1; next }
    /^## Next action$/ { print; print ""; print "Write the first failing test."; skip = 1; next }
    skip && /^##/ { print ""; skip = 0 }
    skip { next }
    { print }
  ' "$f" >"$f.t" && mv "$f.t" "$f"
}

# ---------------------------------------------------------------------------
# create: rendering
# ---------------------------------------------------------------------------
@test "create: renders HANDOFF.md from the shared template, tokens substituted" {
  cd "$(make_repo proj)"
  run run_handoff create "Doc Task"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=created"* ]]
  local f
  f="$(wt doc-task)/HANDOFF.md"
  [ -f "$f" ]
  grep -q "^# Handoff — proj / doc-task$" "$f"
  run grep -qE '<(repo|branch|worktree|date|machine)>' "$f"
  [ "$status" -ne 0 ]
}

@test "create: works from inside another worktree of the repo" {
  cd "$(make_repo proj)"
  run_handoff create "task one"
  cd "$(wt task-one)"
  run run_handoff create "task two"
  [ "$status" -eq 0 ]
  [ -f "$(wt task-two)/HANDOFF.md" ]
}

# ---------------------------------------------------------------------------
# create: existing state is never clobbered
# ---------------------------------------------------------------------------
@test "create: reports a scaffold-only handoff as safe to fill in" {
  cd "$(make_repo proj)"
  run_handoff create "twice task"
  run run_handoff create "twice task"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=existing-scaffold"* ]]
}

@test "create: leaves a handoff with content untouched, and says so" {
  cd "$(make_repo proj)"
  run_handoff create "keep task"
  echo "MY NOTES" >>"$(wt keep-task)/HANDOFF.md"
  run run_handoff create "keep task"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=existing-handoff"* ]]
  grep -q "MY NOTES" "$(wt keep-task)/HANDOFF.md"
}

@test "create: adopts a branch that exists only on origin" {
  cd "$(make_repo proj)"
  local other
  other="$(clone_repo proj other)"
  git -C "$other" checkout -q -b feat
  echo "pushed handoff" >"$other/HANDOFF.md"
  git -C "$other" add HANDOFF.md
  git -C "$other" commit -q -m "handoff"
  git -C "$other" push -q origin feat

  # this machine has neither a local 'feat' branch nor a fetched remote ref
  run run_handoff create "feat"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=existing-handoff"* ]]
  grep -q "pushed handoff" "$(wt feat)/HANDOFF.md"
  git -C "$(wt feat)" rev-parse '@{u}' >/dev/null
}

@test "create: refuses while the task's loop is live" {
  cd "$(make_repo proj)"
  run_handoff create "busy task"
  local live
  sleep 30 &
  live=$!
  printf 'STATUS=running\nPID=%s\n' "$live" >"$(wt busy-task)/.vibe-loop.state"
  run run_handoff create "busy task"
  kill "$live" 2>/dev/null || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"loop is running"* ]]
}

# ---------------------------------------------------------------------------
# publish: validation, commit, push
# ---------------------------------------------------------------------------
@test "publish: refuses while a placeholder section remains, naming it" {
  cd "$(make_repo proj)"
  run_handoff create "raw task"
  run run_handoff publish "raw task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"State"* ]]
}

@test "publish: refuses when only Next action is still the placeholder" {
  cd "$(make_repo proj)"
  run_handoff create "half task"
  # write State but leave Next action untouched — a word elsewhere must not
  # pass for a finished brief
  local f
  f="$(wt half-task)/HANDOFF.md"
  awk '
    /^## State$/ { print; print ""; print "Not started, plan agreed."; skip = 1; next }
    skip && /^##/ { print ""; skip = 0 }
    skip { next }
    { print }
  ' "$f" >"$f.t" && mv "$f.t" "$f"
  run run_handoff publish "half task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Next action"* ]]
}

@test "publish: refuses when a section heading was lost" {
  cd "$(make_repo proj)"
  run_handoff create "broken task"
  finish_handoff "$(wt broken-task)"
  grep -v "^## Next action$" "$(wt broken-task)/HANDOFF.md" >"$(wt broken-task)/HANDOFF.md.t"
  mv "$(wt broken-task)/HANDOFF.md.t" "$(wt broken-task)/HANDOFF.md"
  run run_handoff publish "broken task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Next action"* ]]
}

@test "publish: commits the finished handoff and pushes with an upstream" {
  cd "$(make_repo proj)"
  run_handoff create "ship task"
  finish_handoff "$(wt ship-task)"
  run run_handoff publish "ship task"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=published"* ]]
  [ -z "$(git -C "$(wt ship-task)" status --porcelain)" ]
  git -C "$(wt ship-task)" rev-parse '@{u}' >/dev/null
  git -C "$BATS_TEST_TMPDIR/proj.git" log --oneline ship-task | grep -q "brief 'ship-task'"
}

@test "publish: refuses while the task's loop is live" {
  cd "$(make_repo proj)"
  run_handoff create "hot task"
  finish_handoff "$(wt hot-task)"
  local live
  sleep 30 &
  live=$!
  printf 'STATUS=running\nPID=%s\n' "$live" >"$(wt hot-task)/.vibe-loop.state"
  run run_handoff publish "hot task"
  kill "$live" 2>/dev/null || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"loop is running"* ]]
}

# ---------------------------------------------------------------------------
# fit with vibe: the published handoff is what a session picks up
# ---------------------------------------------------------------------------
@test "publish: vibe start adopts the worktree without reseeding the handoff" {
  cd "$(make_repo proj)"
  run_handoff create "go task"
  finish_handoff "$(wt go-task)"
  run_handoff publish "go task"

  run run_vibe start "go task"
  [ "$status" -eq 0 ]
  # the refined handoff survived — not re-seeded from the template
  grep -q "Write the first failing test." "$(wt go-task)/HANDOFF.md"
}

@test "publish: vibe done refuses while the brief is unconsumed" {
  cd "$(make_repo proj)"
  run_handoff create "done task"
  finish_handoff "$(wt done-task)"
  run_handoff publish "done task"
  run run_vibe "done" "done task"
  [ "$status" -ne 0 ]
  [[ "$output" == *"HANDOFF"* || "$output" == *"handoff"* ]]
}

# ---------------------------------------------------------------------------
# config: worktree root resolution must mirror vibe (env > config > default)
# ---------------------------------------------------------------------------
@test "config: worktree root from the config file is honored" {
  cd "$(make_repo proj)"
  printf 'VIBE_WORKTREE_ROOT=%s\n' "$BATS_TEST_TMPDIR/altroot" >"$BATS_TEST_TMPDIR/config"
  run env -u VIBE_WORKTREE_ROOT VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/config" \
    bash "$HANDOFF" create "cfg task"
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/altroot/proj/cfg-task/HANDOFF.md" ]
}
