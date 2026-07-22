#!/usr/bin/env bats
#
# skills/project-status-scaffold/scaffold.sh — creating PROJECT_STATUS.md,
# PROJECT_ROADMAP.md (repo root) and HANDOFF.md (worktree root) from the
# canonical templates. Everything runs in throwaway repos under
# $BATS_TEST_TMPDIR.

load helper

setup() { git_env; }

SCAFFOLD="$REPO_ROOT/skills/project-status-scaffold/scaffold.sh"

@test "scaffold: creates all three files from the templates, tokens substituted" {
  cd "$(make_repo proj)"
  run bash "$SCAFFOLD"
  [ "$status" -eq 0 ]
  for f in PROJECT_STATUS.md PROJECT_ROADMAP.md HANDOFF.md; do
    [ -f "$f" ]
  done
  grep -q "^# Project Status — proj$" PROJECT_STATUS.md
  grep -q "^# Project Roadmap — proj$" PROJECT_ROADMAP.md
  run grep -qE '<(repo|branch|worktree|date|machine)>' PROJECT_ROADMAP.md
  [ "$status" -ne 0 ]
}

@test "scaffold: second run reports existing files and changes nothing" {
  cd "$(make_repo proj)"
  bash "$SCAFFOLD"
  local before
  before="$(cat PROJECT_STATUS.md PROJECT_ROADMAP.md HANDOFF.md)"
  run bash "$SCAFFOLD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROJECT_ROADMAP.md already exists"* ]]
  [ "$(cat PROJECT_STATUS.md PROJECT_ROADMAP.md HANDOFF.md)" = "$before" ]
}

@test "scaffold: never overwrites a file that already carries content" {
  cd "$(make_repo proj)"
  echo "hand-written roadmap" >PROJECT_ROADMAP.md
  run bash "$SCAFFOLD"
  [ "$status" -eq 0 ]
  [ "$(cat PROJECT_ROADMAP.md)" = "hand-written roadmap" ]
}

@test "scaffold: from a linked worktree, repo files go to the main root, handoff stays local" {
  local work
  work="$(make_repo proj)"
  cd "$work"
  git worktree add -q -b task "$BATS_TEST_TMPDIR/wt-task"
  cd "$BATS_TEST_TMPDIR/wt-task"
  run bash "$SCAFFOLD"
  [ "$status" -eq 0 ]
  [ -f "$work/PROJECT_STATUS.md" ]
  [ -f "$work/PROJECT_ROADMAP.md" ]
  [ -f "$BATS_TEST_TMPDIR/wt-task/HANDOFF.md" ]
  [ ! -f "$BATS_TEST_TMPDIR/wt-task/PROJECT_ROADMAP.md" ]
}

@test "scaffold: refuses outside a git repository" {
  mkdir -p "$BATS_TEST_TMPDIR/norepo"
  cd "$BATS_TEST_TMPDIR/norepo"
  run bash "$SCAFFOLD"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not inside a git repository"* ]]
}
