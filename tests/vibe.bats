#!/usr/bin/env bats
#
# vibe: slug(), the `done` guard, and sync/resume divergence handling.

load helper

setup() { git_env; }

# ---------------------------------------------------------------------------
# slug() — unit-tested by sourcing vibe with its final `main "$@"` stripped,
# so the function definitions land in the shell without the CLI running.
# ---------------------------------------------------------------------------
slug() {
  local lib="$BATS_TEST_TMPDIR/vibe.lib"
  if [ ! -f "$lib" ]; then
    sed 's/^main "\$@"$//' "$VIBE" >"$lib"
  fi
  bash -c 'source "$1"; slug "$2"' _ "$lib" "$1"
}

@test "slug: lowercases and hyphenates spaces" {
  [ "$(slug 'Fix Login Bug')" = "fix-login-bug" ]
}

@test "slug: strips characters that are illegal in a branch name" {
  [ "$(slug 'feat/add (new) stuff!')" = "featadd-new-stuff" ]
}

@test "slug: keeps dots, underscores and hyphens" {
  [ "$(slug 'v1.2_beta-x')" = "v1.2_beta-x" ]
}

@test "slug: collapses an already-slugged name to itself" {
  [ "$(slug 'already-slugged')" = "already-slugged" ]
}

# ---------------------------------------------------------------------------
# vibe done — the data-loss guard
# ---------------------------------------------------------------------------
@test "done: refuses to remove a worktree with uncommitted changes" {
  cd "$(make_repo proj)"
  run_vibe start "task one"
  echo "unsaved work" >"$BATS_TEST_TMPDIR/worktrees/proj/task-one/scratch.txt"

  run run_vibe "done" "task one"
  [ "$status" -eq 1 ]
  [[ "$output" == *"uncommitted changes"* ]]
  [ -d "$BATS_TEST_TMPDIR/worktrees/proj/task-one" ]
}

@test "done: --force removes a dirty worktree" {
  cd "$(make_repo proj)"
  run_vibe start "task one"
  echo "unsaved work" >"$BATS_TEST_TMPDIR/worktrees/proj/task-one/scratch.txt"

  run run_vibe "done" --force "task one"
  [ "$status" -eq 0 ]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/task-one" ]
}

@test "done: refuses when the branch has commits that are on no remote" {
  cd "$(make_repo proj)"
  run_vibe start "task two"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-two"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "work that was never pushed"

  run run_vibe "done" "task two"
  [ "$status" -eq 1 ]
  [[ "$output" == *"on no remote"* ]]
  [ -d "$wt" ]
}

@test "done: allows removal once the branch is pushed" {
  cd "$(make_repo proj)"
  run_vibe start "task two"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-two"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "work"
  git -C "$wt" push -q -u origin task-two

  run run_vibe "done" "task two"
  [ "$status" -eq 0 ]
  [ ! -d "$wt" ]
}

@test "done: keeps the branch after removing the worktree" {
  cd "$(make_repo proj)"
  run_vibe start "task three"
  run run_vibe "done" --force "task three"
  [ "$status" -eq 0 ]
  git show-ref --verify --quiet refs/heads/task-three
}

@test "done: rejects an unknown option instead of treating it as a task" {
  cd "$(make_repo proj)"
  run run_vibe "done" --bogus "task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown option"* ]]
}

# ---------------------------------------------------------------------------
# vibe sync / resume — divergence handling
# ---------------------------------------------------------------------------
@test "sync: pushes a clean fast-forward" {
  cd "$(make_repo proj)"
  echo "change" >file.txt
  run run_vibe sync
  [ "$status" -eq 0 ]
  [ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ]
}

@test "sync: commits handoff files as their own commit" {
  cd "$(make_repo proj)"
  echo "# Handoff" >HANDOFF.md
  echo "code" >app.txt
  run run_vibe sync
  [ "$status" -eq 0 ]
  # newest commit is the code, the one before it is the handoff
  [[ "$(git log -1 --format=%s)" == "vibe sync:"* ]]
  [[ "$(git log -2 --format=%s | tail -1)" == "chore: handoff"* ]]
}

@test "sync: refuses when the remote is ahead" {
  cd "$(make_repo proj)"
  local other
  other="$(clone_repo proj other)"
  echo "theirs" >"$other/theirs.txt"
  git -C "$other" add -A
  git -C "$other" commit -q -m "theirs"
  git -C "$other" push -q

  git fetch -q
  run run_vibe sync
  [ "$status" -eq 1 ]
  [[ "$output" == *"remote is ahead"* ]]
}

@test "sync: refuses on genuine divergence" {
  cd "$(make_repo proj)"
  local other
  other="$(clone_repo proj other)"
  echo "theirs" >"$other/theirs.txt"
  git -C "$other" add -A
  git -C "$other" commit -q -m "theirs"
  git -C "$other" push -q

  echo "mine" >mine.txt
  git add -A
  git commit -q -m "mine"

  run run_vibe sync
  [ "$status" -eq 1 ]
  [[ "$output" == *"DIVERGED"* ]]
}

@test "resume: refuses when the working tree is dirty" {
  cd "$(make_repo proj)"
  echo "wip" >wip.txt
  run run_vibe resume
  [ "$status" -eq 1 ]
  [[ "$output" == *"uncommitted changes"* ]]
}

@test "resume: fast-forwards when the remote is ahead" {
  cd "$(make_repo proj)"
  local other
  other="$(clone_repo proj other)"
  echo "theirs" >"$other/theirs.txt"
  git -C "$other" add -A
  git -C "$other" commit -q -m "theirs"
  git -C "$other" push -q

  run run_vibe resume
  [ "$status" -eq 0 ]
  [ -f theirs.txt ]
}

@test "resume: refuses on genuine divergence" {
  cd "$(make_repo proj)"
  local other
  other="$(clone_repo proj other)"
  echo "theirs" >"$other/theirs.txt"
  git -C "$other" add -A
  git -C "$other" commit -q -m "theirs"
  git -C "$other" push -q

  echo "mine" >mine.txt
  git add -A
  git commit -q -m "mine"

  run run_vibe resume
  [ "$status" -eq 1 ]
  [[ "$output" == *"DIVERGED"* ]]
}

@test "resume: reports being ahead rather than pulling" {
  cd "$(make_repo proj)"
  echo "mine" >mine.txt
  git add -A
  git commit -q -m "mine"
  run run_vibe resume
  [ "$status" -eq 0 ]
  [[ "$output" == *"ahead of remote"* ]]
}

# ---------------------------------------------------------------------------
# start / templates
# ---------------------------------------------------------------------------
@test "start: seeds HANDOFF.md from the shared template" {
  cd "$(make_repo proj)"
  run run_vibe start "Seed Me"
  [ "$status" -eq 0 ]
  local f="$BATS_TEST_TMPDIR/worktrees/proj/seed-me/HANDOFF.md"
  [ -f "$f" ]
  grep -q "^# Handoff — proj / seed-me$" "$f"
  # every placeholder must have been substituted
  run grep -qE '<(repo|branch|worktree|date|machine)>' "$f"
  [ "$status" -ne 0 ]
}

@test "start: does not overwrite an existing HANDOFF.md" {
  cd "$(make_repo proj)"
  run_vibe start "keep me"
  local f="$BATS_TEST_TMPDIR/worktrees/proj/keep-me/HANDOFF.md"
  echo "MY NOTES" >"$f"
  run_vibe start "keep me"
  [ "$(cat "$f")" = "MY NOTES" ]
}

# ---------------------------------------------------------------------------
# doctor
# ---------------------------------------------------------------------------
@test "doctor: exits 0 in a healthy repo" {
  cd "$(make_repo proj)"
  run run_vibe doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"vibe doctor"* ]]
}

@test "doctor: fails on a config file that is not plain KEY=VALUE" {
  cd "$(make_repo proj)"
  local cfg="$BATS_TEST_TMPDIR/bad-config"
  printf 'VIBE_NTFY_TOPIC=fine\nrm -rf /tmp/nope\n' >"$cfg"
  run env VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$cfg" "$VIBE" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"not plain KEY=VALUE"* ]]
}

@test "config: environment variable beats the config file" {
  cd "$(make_repo proj)"
  local cfg="$BATS_TEST_TMPDIR/config"
  printf 'VIBE_WORKTREE_ROOT=%s/from-config\n' "$BATS_TEST_TMPDIR" >"$cfg"
  run env VIBE_CONFIG_FILE="$cfg" VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/from-env" \
    "$VIBE" doctor
  [[ "$output" == *"from-env"* ]]
  [[ "$output" != *"from-config"* ]]
}

@test "config: the config file beats the built-in default" {
  cd "$(make_repo proj)"
  local cfg="$BATS_TEST_TMPDIR/config"
  printf 'VIBE_WORKTREE_ROOT=%s/from-config\n' "$BATS_TEST_TMPDIR" >"$cfg"
  run env -u VIBE_WORKTREE_ROOT VIBE_CONFIG_FILE="$cfg" "$VIBE" doctor
  [[ "$output" == *"from-config"* ]]
}
