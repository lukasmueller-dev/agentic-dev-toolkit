#!/usr/bin/env bats
#
# bin/vibe — start, sync and status in throwaway repos with a bare origin.
# Stubs for `code`, `gh` and `systemctl` record their calls under $STUBS.

load helper

VIBE="$REPO_ROOT/bin/vibe"

setup() {
  git_env
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"
  printf '#!/bin/sh\necho "$@" >>"%s/code.log"\n' "$STUBS" >"$STUBS/code"
  printf '#!/bin/sh\ncat "%s/gh.out" 2>/dev/null\n' "$STUBS" >"$STUBS/gh"
  chmod +x "$STUBS/code" "$STUBS/gh"
  PATH="$STUBS:$PATH"
  # No toolkit check against the real origin; tests that want it set their own.
  export VIBE_TOOLKIT="$BATS_TEST_TMPDIR/no-toolkit"
  export VIBE_ROOT="$BATS_TEST_TMPDIR"
}

@test "start: a new task branches from origin/main, untracked, and opens VS Code" {
  local r o
  r="$(make_repo proj)"
  o="$(clone_repo proj other)"
  git -C "$o" commit -q --allow-empty -m "newer main"
  git -C "$o" push -q origin main
  cd "$r"
  run "$VIBE" start "My Task"
  [ "$status" -eq 0 ]
  [ -d "$r/.claude/worktrees/my-task" ]
  [ "$(git -C "$r/.claude/worktrees/my-task" rev-parse HEAD)" = "$(git -C "$o" rev-parse HEAD)" ]
  run git -C "$r/.claude/worktrees/my-task" rev-parse --abbrev-ref '@{u}'
  [ "$status" -ne 0 ]
  grep -qx "$r/.claude/worktrees/my-task" "$STUBS/code.log"
  [ "$(grep -cxF '.claude/worktrees/' "$r/.git/info/exclude")" -eq 1 ]
  [ -z "$(git -C "$r" status --porcelain)" ]
}

@test "start: adopts a branch pushed from another machine" {
  local r o
  r="$(make_repo proj)"
  o="$(clone_repo proj other)"
  git -C "$o" switch -q -c feat
  git -C "$o" commit -q --allow-empty -m "work elsewhere"
  git -C "$o" push -q -u origin feat
  run "$VIBE" start -C "$r" feat
  [ "$status" -eq 0 ]
  [ "$(git -C "$r/.claude/worktrees/feat" rev-parse HEAD)" = "$(git -C "$o" rev-parse HEAD)" ]
}

@test "start: reopens an existing worktree and fast-forwards it" {
  local r o
  r="$(make_repo proj)"
  o="$(clone_repo proj other)"
  git -C "$o" switch -q -c feat
  git -C "$o" push -q -u origin feat
  "$VIBE" start -C "$r" feat
  git -C "$o" commit -q --allow-empty -m "later work"
  git -C "$o" push -q origin feat
  run "$VIBE" start -C "$r" feat
  [ "$status" -eq 0 ]
  [ "$(git -C "$r" worktree list | wc -l | tr -d ' ')" -eq 2 ]
  [ "$(git -C "$r/.claude/worktrees/feat" rev-parse HEAD)" = "$(git -C "$o" rev-parse HEAD)" ]
}

@test "start: prints the open PR of the branch" {
  local r
  r="$(make_repo proj)"
  printf 'feat\thttps://example.com/pull/7\nother\thttps://example.com/pull/8\n' >"$STUBS/gh.out"
  run "$VIBE" start -C "$r" feat
  [ "$status" -eq 0 ]
  [[ "$output" == *"PR:       https://example.com/pull/7"* ]] || false
  [[ "$output" != *"pull/8"* ]] || false
}

@test "start: without code, prints the path and succeeds" {
  local r
  r="$(make_repo proj)"
  rm "$STUBS/code"
  PATH="$(path_without code)" run "$VIBE" start -C "$r" feat
  [ "$status" -eq 0 ]
  [[ "$output" == *"worktree: $r/.claude/worktrees/feat"* ]] || false
}

@test "start: refuses the default branch and a missing task" {
  local r
  r="$(make_repo proj)"
  run "$VIBE" start -C "$r" main
  [ "$status" -ne 0 ]
  run "$VIBE" start -C "$r"
  [ "$status" -ne 0 ]
}

@test "sync: pushes new and ahead branches, skips a branch without commits" {
  local r
  r="$(make_repo proj)"
  "$VIBE" start -C "$r" new-work
  "$VIBE" start -C "$r" nothing-yet
  git -C "$r/.claude/worktrees/new-work" commit -q --allow-empty -m "work"
  cd "$r"
  run "$VIBE" sync
  [ "$status" -eq 0 ]
  [[ "$output" == *"pushed"*"proj/new-work"* ]] || false
  [[ "$output" == *"empty"*"proj/nothing-yet"* ]] || false
  git -C "$r" show-ref --verify --quiet refs/remotes/origin/new-work
  run git -C "$r" ls-remote --heads origin nothing-yet
  [ -z "$output" ]
  git -C "$r/.claude/worktrees/new-work" commit -q --allow-empty -m "more"
  run "$VIBE" sync
  [[ "$output" == *"pushed"*"proj/new-work"* ]] || false
  [ "$(git -C "$r" rev-parse origin/new-work)" = "$(git -C "$r/.claude/worktrees/new-work" rev-parse HEAD)" ]
}

@test "sync: marks a main checkout that is not on the default branch" {
  local r
  r="$(make_repo proj)"
  cd "$r"
  run "$VIBE" sync
  [[ "$output" != *"off main"* ]] || false
  git -C "$r" switch -q -c side
  run "$VIBE" sync
  [ "$status" -eq 0 ]
  [[ "$output" == *"proj "*"side"*"off main"* ]] || false
}

@test "sync: a branch whose upstream was deleted is merged and never pushed again" {
  local r
  r="$(make_repo proj)"
  "$VIBE" start -C "$r" done-task
  git -C "$r/.claude/worktrees/done-task" commit -q --allow-empty -m "work"
  cd "$r"
  "$VIBE" sync
  git -C "$r" push -q origin --delete done-task
  run "$VIBE" sync
  [ "$status" -eq 0 ]
  [[ "$output" == *"merged"*"proj/done-task"*"/worktree-cleanup"* ]] || false
  run git -C "$r" ls-remote --heads origin done-task
  [ -z "$output" ]
}

@test "toolkit check: sync ignores the fetch cache" {
  local t o r
  t="$(make_repo kit)"
  o="$(clone_repo kit kit-other)"
  r="$(make_repo proj)"
  cd "$r"
  VIBE_TOOLKIT="$t" VIBE_FETCH_INTERVAL=3600 "$VIBE" sync
  git -C "$o" commit -q --allow-empty -m "merged a minute ago"
  git -C "$o" push -q origin main
  VIBE_TOOLKIT="$t" VIBE_FETCH_INTERVAL=3600 run "$VIBE" status --claude
  [[ "$output" != *"behind origin/main"* ]] || false
  VIBE_TOOLKIT="$t" VIBE_FETCH_INTERVAL=3600 run "$VIBE" sync
  [[ "$output" == *"toolkit is 1 commits behind origin/main"* ]] || false
}

@test "sync: never pushes an app session branch that has no upstream" {
  local r
  r="$(make_repo proj)"
  git -C "$r" worktree add -q -b worktree-snug "$r/.claude/worktrees/snug"
  git -C "$r/.claude/worktrees/snug" commit -q --allow-empty -m "session work"
  cd "$r"
  run "$VIBE" sync
  [ "$status" -eq 0 ]
  [[ "$output" == *"local"*"proj/snug"* ]] || false
  run git -C "$r" ls-remote --heads origin worktree-snug
  [ -z "$output" ]
}

@test "sync: fast-forwards a clean branch, reports dirty and diverged ones" {
  local r o
  r="$(make_repo proj)"
  o="$(clone_repo proj other)"
  for b in clean dirty split; do
    git -C "$o" switch -q -c "$b" main
    git -C "$o" push -q -u origin "$b"
    "$VIBE" start -C "$r" "$b"
    git -C "$o" commit -q --allow-empty -m "remote $b"
    git -C "$o" push -q origin "$b"
  done
  echo x >"$r/.claude/worktrees/dirty/x.txt"
  git -C "$r/.claude/worktrees/split" commit -q --allow-empty -m "local split"
  cd "$r"
  run "$VIBE" sync
  [ "$status" -eq 0 ]
  [[ "$output" == *"pulled"*"proj/clean"* ]] || false
  [[ "$output" == *"behind"*"proj/dirty"*"dirty"* ]] || false
  [[ "$output" == *"diverged"*"proj/split"* ]] || false
  [ -f "$r/.claude/worktrees/dirty/x.txt" ]
  [ "$(git -C "$r/.claude/worktrees/clean" rev-parse HEAD)" = "$(git -C "$o" rev-parse clean)" ]
}

@test "sync --wip: commits and pushes a dirty task branch, never main" {
  local r
  r="$(make_repo proj)"
  "$VIBE" start -C "$r" feat
  echo x >"$r/.claude/worktrees/feat/x.txt"
  echo y >"$r/main-edit.txt"
  cd "$r"
  run "$VIBE" sync --wip
  [ "$status" -eq 0 ]
  [[ "$output" == *"pushed"*"proj/feat"*"wip committed"* ]] || false
  [ "$(git -C "$r" log -1 --format=%s origin/feat | cut -c1-4)" = "wip:" ]
  [ -f "$r/main-edit.txt" ]
  [ -n "$(git -C "$r" status --porcelain)" ]
  [ "$(git -C "$r" rev-list --count main)" -eq 1 ]
}

@test "sync: a locked worktree is pushed but not fast-forwarded" {
  local r o
  r="$(make_repo proj)"
  o="$(clone_repo proj other)"
  git -C "$o" switch -q -c held
  git -C "$o" push -q -u origin held
  "$VIBE" start -C "$r" held
  git -C "$r" worktree lock "$r/.claude/worktrees/held"
  git -C "$o" commit -q --allow-empty -m "remote work"
  git -C "$o" push -q origin held
  cd "$r"
  run "$VIBE" sync
  [[ "$output" == *"behind"*"proj/held"*"locked"* ]] || false
  [ "$(git -C "$r/.claude/worktrees/held" rev-parse HEAD)" != "$(git -C "$o" rev-parse held)" ]
}

@test "sync --all: covers every repo under VIBE_ROOT" {
  local a b
  a="$(make_repo alpha)"
  b="$(make_repo beta)"
  "$VIBE" start -C "$a" one
  git -C "$a/.claude/worktrees/one" commit -q --allow-empty -m "work"
  "$VIBE" start -C "$b" two
  git -C "$b/.claude/worktrees/two" commit -q --allow-empty -m "work"
  cd "$BATS_TEST_TMPDIR"
  run "$VIBE" sync --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"pushed"*"alpha/one"* ]] || false
  [[ "$output" == *"pushed"*"beta/two"* ]] || false
}

@test "toolkit check: warns when the toolkit is behind, silent when current" {
  local t o
  t="$(make_repo kit)"
  o="$(clone_repo kit kit-other)"
  export VIBE_TOOLKIT="$t" VIBE_FETCH_INTERVAL=0
  run "$VIBE" status --claude
  [[ "$output" != *"warning: toolkit"* ]] || false
  git -C "$o" commit -q --allow-empty -m "newer toolkit"
  git -C "$o" push -q origin main
  run "$VIBE" status --claude
  [[ "$output" == *"toolkit is 1 commits behind origin/main"* ]] || false
  git -C "$t" switch -q -c side
  run "$VIBE" status --claude
  [[ "$output" == *"is on 'side', not main"* ]] || false
}

@test "status: --claude lists claude-rc units and the role; other flags fail" {
  cat >"$STUBS/systemctl" <<'EOF'
#!/bin/sh
case "$2" in
  list-units) echo "claude-rc@proj.service loaded active running x" ;;
  show) printf 'ActiveState=active\nSubState=running\nNRestarts=2\nActiveEnterTimestamp=Sun\n' ;;
esac
EOF
  chmod +x "$STUBS/systemctl"
  run "$VIBE" status --claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"role: client"* ]] || false
  [[ "$output" == *"proj"*"active/running"*"2"* ]] || false
  [[ "$output" == *"role is not 'server'"* ]] || false
  mkdir -p "$HOME/.config/vibe"
  echo server >"$HOME/.config/vibe/role"
  run "$VIBE" status --claude
  [[ "$output" != *"role is not"* ]] || false
  run "$VIBE" status --nope
  [ "$status" -ne 0 ]
  run "$VIBE" status
  [ "$status" -ne 0 ]
}

@test "unit: the server starts only with role 'server'" {
  local unit="$REPO_ROOT/claude/systemd/claude-rc@.service"
  grep -q '^ExecCondition=.*grep -qx server %h/.config/vibe/role' "$unit"
}
