#!/usr/bin/env bats
#
# skills/worktree-cleanup/cleanup.sh — rating linked worktrees and removing
# only the ones whose work has landed. Everything runs in throwaway repos
# under $BATS_TEST_TMPDIR.

load helper

setup() { git_env; }

CLEANUP="$REPO_ROOT/skills/worktree-cleanup/cleanup.sh"

# add_wt REPO NAME — a worktree at REPO/.claude/worktrees/NAME on branch NAME.
add_wt() {
  git -C "$1" worktree add -q -b "$2" "$1/.claude/worktrees/$2"
  printf '%s' "$1/.claude/worktrees/$2"
}

# state_of PATH — the state the scan reports for PATH.
state_of() {
  bash "$CLEANUP" scan | awk -F'\t' -v p="$1" '$2 == p { print $1 }'
}

@test "scan: skips the main checkout and rates a clean branch on main as merged" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" done-task)"
  cd "$r"
  run bash "$CLEANUP" scan
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c "^merged	")" -eq 1 ]
  run grep -q "	$r	" <<<"$output"
  [ "$status" -ne 0 ]
  [ "$(state_of "$w")" = merged ]
}

@test "scan: commits not on main are unpushed, changes are dirty" {
  local r a b
  r="$(make_repo proj)"
  a="$(add_wt "$r" ahead)"
  git -C "$a" commit -q --allow-empty -m "work"
  b="$(add_wt "$r" edited)"
  echo x >"$b/new.txt"
  cd "$r"
  [ "$(state_of "$a")" = unpushed ]
  [ "$(state_of "$b")" = dirty ]
}

@test "scan: a branch whose upstream was deleted counts as merged" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" squashed)"
  git -C "$w" commit -q --allow-empty -m "work"
  git -C "$w" push -q -u origin squashed
  git -C "$r" push -q origin --delete squashed
  cd "$r"
  [ "$(state_of "$w")" = merged ]
}

@test "scan: locked and current worktrees are never removable" {
  local r l c
  r="$(make_repo proj)"
  l="$(add_wt "$r" held)"
  git -C "$r" worktree lock "$l"
  c="$(add_wt "$r" here)"
  cd "$c"
  [ "$(state_of "$l")" = locked ]
  [ "$(state_of "$c")" = current ]
}

@test "remove: deletes a merged worktree and its branch" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" done-task)"
  cd "$r"
  run bash "$CLEANUP" remove "$w"
  [ "$status" -eq 0 ]
  [ ! -d "$w" ]
  run git -C "$r" show-ref --verify --quiet refs/heads/done-task
  [ "$status" -ne 0 ]
}

@test "remove: refuses unpushed work and leaves it intact" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" ahead)"
  git -C "$w" commit -q --allow-empty -m "work"
  cd "$r"
  run bash "$CLEANUP" remove "$w"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unpushed"* ]] || false
  [ -d "$w" ]
  git -C "$r" show-ref --verify --quiet refs/heads/ahead
}

@test "remove: prunes the record of a worktree whose directory is gone" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" vanished)"
  rm -rf "$w"
  cd "$r"
  [ "$(state_of "$w")" = prunable ]
  run bash "$CLEANUP" remove "$w"
  [ "$status" -eq 0 ]
  run git -C "$r" worktree list
  [[ "$output" != *"vanished"* ]] || false
}
