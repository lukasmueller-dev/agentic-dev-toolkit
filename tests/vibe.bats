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
  [ "$(slug 'feat/add (new) stuff!')" = "feat-add-new-stuff" ]
}

@test "slug: maps slashes to hyphens instead of deleting them" {
  [ "$(slug 'docs/fix-rmapi-config-path')" = "docs-fix-rmapi-config-path" ]
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

@test "resume --rebase: rebases a diverged branch instead of refusing" {
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

  run run_vibe resume --rebase
  [ "$status" -eq 0 ]
  [[ "$output" == *"rebased"* ]]
  # remote work pulled in, and local work kept (replayed on top)
  [ -f theirs.txt ]
  [ -f mine.txt ]
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
# status — the worktree listing must not present the main checkout as a task
# ---------------------------------------------------------------------------
@test "status: shows per-worktree sync state" {
  cd "$(make_repo proj)"
  run_vibe start "task s"
  echo "scratch" >"$BATS_TEST_TMPDIR/worktrees/proj/task-s/x.txt"
  run run_vibe status
  [ "$status" -eq 0 ]
  [[ "$output" == *"dirty"* ]]
  [[ "$output" == *"ahead"* ]]
  [[ "$output" == *"behind"* ]]
  [[ "$output" == *"handoff"* ]]
}

@test "status --all: works from outside any git repository" {
  cd "$(make_repo proj)"
  run_vibe start "task a"
  run_vibe start "task b"

  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  cd "$BATS_TEST_TMPDIR/elsewhere"
  run run_vibe status --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"proj/task-a"* ]]
  [[ "$output" == *"proj/task-b"* ]]
}

@test "attach: with no task and no tasks, reports there is nothing to pick" {
  cd "$(make_repo proj)"
  run run_vibe attach
  [ "$status" -eq 1 ]
  [[ "$output" == *"no tasks yet"* ]]
}

@test "status: labels the main checkout so it is not mistaken for a task" {
  cd "$(make_repo proj)"
  run_vibe start "task one"
  run run_vibe status
  [ "$status" -eq 0 ]
  # git worktree list prints physical paths, so match against the resolved one
  local main_phys main_line task_line
  main_phys="$(cd "$BATS_TEST_TMPDIR/proj" && pwd -P)"
  main_line="$(printf '%s\n' "$output" | grep -F "$main_phys ")"
  task_line="$(printf '%s\n' "$output" | grep "worktrees/proj/task-one")"
  [[ "$main_line" == *"(main checkout, not a vibe task)"* ]]
  [[ "$task_line" != *"(main"* && "$task_line" != *"(not"* ]]
}

# ---------------------------------------------------------------------------
# attach — the single "arrive" verb: fast-forward when safe, never refuse
# ---------------------------------------------------------------------------

# remote_ahead WT BRANCH — push BRANCH, then advance origin/BRANCH by one
# commit from a second clone, leaving WT one commit behind its upstream.
remote_ahead() {
  local wt="$1" branch="$2" other
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "seed handoff"
  git -C "$wt" push -q -u origin "$branch"
  other="$(clone_repo proj other)"
  git -C "$other" fetch -q origin "$branch"
  git -C "$other" checkout -q "$branch"
  echo "theirs" >"$other/theirs.txt"
  git -C "$other" add -A
  git -C "$other" commit -q -m "theirs"
  git -C "$other" push -q origin "$branch"
}

@test "attach: fast-forwards a clean worktree before attaching" {
  cd "$(make_repo proj)"
  run_vibe start "task f"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-f"
  remote_ahead "$wt" task-f

  # from the main checkout; VIBE_AGENT_CMD=true makes the attach itself a no-op
  run run_vibe attach "task f"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fast-forwarded"* ]]
  [[ "$output" == *"1 commit"* ]]
  [ -f "$wt/theirs.txt" ]
}

@test "attach: warns but attaches anyway when the worktree is dirty" {
  cd "$(make_repo proj)"
  run_vibe start "task p"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-p"
  remote_ahead "$wt" task-p
  echo "wip" >"$wt/wip.txt"

  run run_vibe attach "task p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"uncommitted changes"* ]]
  # pulling was unsafe, so the remote commit was not merged
  [ ! -f "$wt/theirs.txt" ]
}

@test "attach: warns but attaches anyway when the branch has diverged" {
  cd "$(make_repo proj)"
  run_vibe start "task d"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-d"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "seed handoff"
  git -C "$wt" push -q -u origin task-d

  # local and remote advance independently
  echo "mine" >"$wt/mine.txt"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "mine"
  local other
  other="$(clone_repo proj other)"
  git -C "$other" fetch -q origin task-d
  git -C "$other" checkout -q task-d
  echo "theirs" >"$other/theirs.txt"
  git -C "$other" add -A
  git -C "$other" commit -q -m "theirs"
  git -C "$other" push -q origin task-d

  run run_vibe attach "task d"
  [ "$status" -eq 0 ]
  [[ "$output" == *"diverged"* ]]
  # local work intact, remote not merged
  [ -f "$wt/mine.txt" ]
  [ ! -f "$wt/theirs.txt" ]
}

@test "attach: refuses a task with no worktree" {
  cd "$(make_repo proj)"
  run run_vibe attach "never-started"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no worktree"* ]]
}

# ---------------------------------------------------------------------------
# cwd inference — sync/done/park operate on the worktree you are standing in
# ---------------------------------------------------------------------------
@test "sync: infers the worktree from the cwd (no task argument)" {
  cd "$(make_repo proj)"
  run_vibe start "infer me"
  cd "$BATS_TEST_TMPDIR/worktrees/proj/infer-me"
  echo "change" >f.txt

  run run_vibe sync
  [ "$status" -eq 0 ]
  [ "$(git rev-parse infer-me)" = "$(git rev-parse origin/infer-me)" ]
}

@test "sync: a task argument targets that worktree from the main checkout" {
  cd "$(make_repo proj)"
  run_vibe start "remote task"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/remote-task"
  echo "change" >"$wt/f.txt"

  # cwd stays in the main checkout; the argument selects the worktree
  run run_vibe sync "remote task"
  [ "$status" -eq 0 ]
  [ "$(git -C "$wt" rev-parse remote-task)" = "$(git -C "$wt" rev-parse origin/remote-task)" ]
}

@test "done: refuses with no task argument outside a vibe worktree" {
  cd "$(make_repo proj)"
  run run_vibe "done"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a vibe worktree"* ]]
}

@test "done: infers the task from the cwd inside a worktree" {
  cd "$(make_repo proj)"
  run_vibe start "task inf"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-inf"
  # clean and pushed, so the data-loss guard has nothing to object to
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "seed handoff"
  git -C "$wt" push -q -u origin task-inf
  cd "$wt"

  run run_vibe "done"
  [ "$status" -eq 0 ]
  [ ! -d "$wt" ]
}

# ---------------------------------------------------------------------------
# park — refresh HANDOFF.md via the agent, then sync; degrade if agent absent
# ---------------------------------------------------------------------------
@test "park: warns and still syncs when the agent is missing" {
  cd "$(make_repo proj)"
  run_vibe start "park me"
  cd "$BATS_TEST_TMPDIR/worktrees/proj/park-me"
  echo "# Handoff" >HANDOFF.md
  echo "work" >code.txt

  run env VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD="vibe-no-such-agent-xyz" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" park
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found"* ]]
  # degraded, but the work was still synced
  [ "$(git rev-parse park-me)" = "$(git rev-parse origin/park-me)" ]
}

@test "park: refreshes HANDOFF.md via the headless agent, then syncs" {
  cd "$(make_repo proj)"
  run_vibe start "park two"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/park-two"

  # a stub agent that only writes HANDOFF.md, standing in for `claude -p`
  local stub="$BATS_TEST_TMPDIR/stub-agent"
  cat >"$stub" <<'EOF'
#!/usr/bin/env bash
printf 'refreshed by agent\n' >HANDOFF.md
EOF
  chmod +x "$stub"

  run env VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD="$stub" \
    VIBE_AGENT_HEADLESS_ARGS=" " \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" park "park two"
  [ "$status" -eq 0 ]
  [ "$(cat "$wt/HANDOFF.md")" = "refreshed by agent" ]
  # the refreshed handoff landed on the remote
  git -C "$wt" cat-file -e "origin/park-two:HANDOFF.md"
}

# ---------------------------------------------------------------------------
# rc — Remote Control is a server concern
# ---------------------------------------------------------------------------
@test "rc: is a no-op on local, with an explanation" {
  cd "$(make_repo proj)"
  # no SSH_CONNECTION and no matching hostname => local
  run env -u SSH_CONNECTION -u SSH_TTY \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" rc "some task"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no-op on local"* ]]
}

@test "rc: requires a task name" {
  cd "$(make_repo proj)"
  run run_vibe rc
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

# ---------------------------------------------------------------------------
# doctor
# ---------------------------------------------------------------------------
@test "doctor: rejects a non-boolean VIBE_RC_ON_START" {
  cd "$(make_repo proj)"
  run env VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_RC_ON_START=maybe \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"VIBE_RC_ON_START must be 0 or 1"* ]]
}

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
