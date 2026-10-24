#!/usr/bin/env bats
#
# claude/hooks/* — these run inside a live editing session, so the contract
# they must never break is: exit 0 and stay quiet when they cannot do their job.

load helper

setup() {
  git_env
  HOOKS="$REPO_ROOT/claude/hooks"
}

# ---------------------------------------------------------------------------
# session-start-handoff.sh
# ---------------------------------------------------------------------------
@test "start: injects HANDOFF.md content on startup" {
  local r
  r="$(make_repo proj)"
  printf '# Handoff — proj\n\n## State\n\nSomething real to hand off.\n' >"$r/HANDOFF.md"

  run bash -c "echo '{\"cwd\":\"$r\",\"source\":\"startup\"}' | '$HOOKS/session-start-handoff.sh'"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"'
  echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "Something real to hand off."
}

@test "start: injects on clear as well as startup" {
  local r
  r="$(make_repo proj)"
  printf '## State\n\nReal content.\n' >"$r/HANDOFF.md"

  run bash -c "echo '{\"cwd\":\"$r\",\"source\":\"clear\"}' | '$HOOKS/session-start-handoff.sh'"
  [ "$status" -eq 0 ]
  echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "Real content."
}

@test "start: silent on resume, compact, and fork" {
  local r
  r="$(make_repo proj)"
  printf '## State\n\nReal content.\n' >"$r/HANDOFF.md"

  for src in resume compact fork; do
    run bash -c "echo '{\"cwd\":\"$r\",\"source\":\"$src\"}' | '$HOOKS/session-start-handoff.sh'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "start: silent when there is no HANDOFF.md" {
  local r
  r="$(make_repo proj)"
  run bash -c "echo '{\"cwd\":\"$r\",\"source\":\"startup\"}' | '$HOOKS/session-start-handoff.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "start: silent on a scaffold-only HANDOFF.md" {
  local r
  r="$(make_repo proj)"
  cp "$REPO_ROOT/templates/HANDOFF.md" "$r/HANDOFF.md"
  run bash -c "echo '{\"cwd\":\"$r\",\"source\":\"startup\"}' | '$HOOKS/session-start-handoff.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "start: silent outside a git repository" {
  printf '## State\n\nReal content.\n' >"$BATS_TEST_TMPDIR/HANDOFF.md"
  run bash -c "echo '{\"cwd\":\"$BATS_TEST_TMPDIR\",\"source\":\"startup\"}' | '$HOOKS/session-start-handoff.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "start: survives malformed stdin without complaining" {
  run bash -c "echo 'not json at all' | '$HOOKS/session-start-handoff.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "start: no-ops when jq is unavailable" {
  run env PATH= /bin/bash "$HOOKS/session-start-handoff.sh" </dev/null
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# statusline.sh
# ---------------------------------------------------------------------------
@test "statusline: prints repo and branch in a plain checkout" {
  local r
  r="$(make_repo proj)"
  run bash -c "echo '{\"workspace\":{\"current_dir\":\"$r\"}}' | '$HOOKS/statusline.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"proj"* ]] || false
  [[ "$output" == *"main"* ]] || false
}

@test "statusline: reports the main repo name from inside a worktree" {
  local r
  r="$(make_repo proj)"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/feat-x"
  mkdir -p "$(dirname "$wt")"
  git -C "$r" worktree add -q -b feat-x "$wt"

  run bash -c "echo '{\"workspace\":{\"current_dir\":\"$wt\"}}' | '$HOOKS/statusline.sh'"
  [ "$status" -eq 0 ]
  # the repo, not the worktree directory
  [[ "$output" == *"proj"* ]] || false
  [[ "$output" == *"feat-x"* ]] || false
}

@test "statusline: never errors on empty stdin" {
  run bash -c "echo '' | '$HOOKS/statusline.sh'"
  [ "$status" -eq 0 ]
}
