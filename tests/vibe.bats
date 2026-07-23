#!/usr/bin/env bats
#
# vibe: slug(), the `done` guard, and sync/resume divergence handling.

load helper

setup() { git_env; }

@test "helper: HOME is redirected into the bats sandbox" {
  # The isolation contract in CLAUDE.md: no test may touch the real
  # ~/.claude, ~/bin, or worktree root. helper.bash enforces it by
  # pointing HOME into a bats tmpdir — this pins that guard.
  case "$HOME" in
    "$BATS_TEST_TMPDIR"* | "${BATS_FILE_TMPDIR:-//}"* | "${BATS_RUN_TMPDIR:-//}"*) ;;
    *)
      echo "HOME escaped the sandbox: $HOME" >&2
      return 1
      ;;
  esac
}

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
  rm "$wt/HANDOFF.md" # a finished task hands nothing off
  echo "done" >"$wt/work.txt"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "work"
  git -C "$wt" push -q -u origin task-two

  run run_vibe "done" "task two"
  [ "$status" -eq 0 ]
  [ ! -d "$wt" ]
}

@test "done: refuses while HANDOFF.md still carries content" {
  cd "$(make_repo proj)"
  run_vibe start "task h"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-h"
  echo "- migration half done, resume at step 3" >>"$wt/HANDOFF.md"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "work"
  git -C "$wt" push -q -u origin task-h

  run run_vibe "done" "task h"
  [ "$status" -eq 1 ]
  [[ "$output" == *"HANDOFF.md still carries content"* ]]
  [[ "$output" == *"resume at step 3"* ]]
  [ -d "$wt" ]
}

@test "done: refuses while a cleared HANDOFF.md is still on the branch" {
  cd "$(make_repo proj)"
  run_vibe start "task hc"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-hc"
  # the seeded template is scaffolding only (headings, quotes, metadata,
  # single-line placeholders) — exactly what a cleared handoff looks like.
  # Committed, it would merge into the default branch as a stray file.
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "work"
  git -C "$wt" push -q -u origin task-hc

  run run_vibe "done" "task hc"
  [ "$status" -eq 1 ]
  [[ "$output" == *"HANDOFF.md is still on branch"* ]]
  [ -d "$wt" ]
}

@test "done: passes once HANDOFF.md is deleted and synced" {
  cd "$(make_repo proj)"
  run_vibe start "task hg"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-hg"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "work"
  git -C "$wt" rm -q HANDOFF.md
  git -C "$wt" commit -q -m "chore: drop handoff"
  git -C "$wt" push -q -u origin task-hg

  run run_vibe "done" "task hg"
  [ "$status" -eq 0 ]
  [ ! -d "$wt" ]
}

@test "done: --discard-handoff leaves the handoff on the branch deliberately" {
  cd "$(make_repo proj)"
  run_vibe start "task hk"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-hk"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "work"
  git -C "$wt" push -q -u origin task-hk

  run run_vibe "done" --discard-handoff "task hk"
  [ "$status" -eq 0 ]
  [ ! -d "$wt" ]
  git show task-hk:HANDOFF.md >/dev/null
}

@test "done: --discard-handoff removes despite handoff content" {
  cd "$(make_repo proj)"
  run_vibe start "task hd"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-hd"
  echo "- leftover note" >>"$wt/HANDOFF.md"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "work"
  git -C "$wt" push -q -u origin task-hd

  run run_vibe "done" --discard-handoff "task hd"
  [ "$status" -eq 0 ]
  [ ! -d "$wt" ]
}

@test "done: --force skips the handoff guard too" {
  cd "$(make_repo proj)"
  run_vibe start "task hf"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-hf"
  echo "- leftover note" >>"$wt/HANDOFF.md"

  run run_vibe "done" --force "task hf"
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

@test "done: removes the worktree before killing the task's tmux session" {
  cd "$(make_repo proj)"
  run_vibe start "task kill" >/dev/null
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-kill"

  # Run from inside the session vibe is about to kill — the real shape of the
  # bug: killing first SIGHUPs vibe itself, so the removal never runs and not
  # even the refusal messages reach the user. The stub cannot deliver a real
  # SIGHUP, so it records whether the worktree was still there at kill time.
  local dir="$BATS_TEST_TMPDIR/tmuxbin-done"
  mkdir -p "$dir"
  cat >"$dir/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${VIBE_TEST_TMUX_LOG:?}"
case "${1:-}" in
  has-session) exit 0 ;;
  kill-session) [ -d "${VIBE_TEST_DOOMED_WT:?}" ] &&
    printf 'STILL-PRESENT-AT-KILL\n' >>"$VIBE_TEST_TMUX_LOG" ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"

  run env PATH="$dir:$PATH" \
    VIBE_TEST_DOOMED_WT="$wt" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" "done" --force "task kill"
  [ "$status" -eq 0 ]
  [ ! -d "$wt" ]
  grep -q "kill-session -t vibe-proj-task-kill" "$VIBE_TEST_TMUX_LOG"
  run ! grep -q "STILL-PRESENT-AT-KILL" "$VIBE_TEST_TMUX_LOG"
}

@test "done: reports the removal before the kill that can cut the output off" {
  cd "$(make_repo proj)"
  run_vibe start "task msg" >/dev/null

  local dir="$BATS_TEST_TMPDIR/tmuxbin-msg"
  mkdir -p "$dir"
  cat >"$dir/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${VIBE_TEST_TMUX_LOG:?}"
case "${1:-}" in
  has-session) exit 0 ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"

  run env PATH="$dir:$PATH" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" "done" --force "task msg"
  [ "$status" -eq 0 ]
  # Nothing after the kill is guaranteed to be printed, so the outcome must
  # already be on screen when the kill is announced.
  [[ "${output#*removed worktree}" == *"killing tmux session"* ]]
}

@test "done: rejects an unknown option instead of treating it as a task" {
  cd "$(make_repo proj)"
  run run_vibe "done" --bogus "task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "done: removes multiple tasks in one call" {
  cd "$(make_repo proj)"
  run_vibe start task_a
  run_vibe start task_b

  run run_vibe "done" --force task_a task_b
  [ "$status" -eq 0 ]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/task_a" ]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/task_b" ]
}

@test "done: multiple tasks keeps going past one failure and exits non-zero" {
  cd "$(make_repo proj)"
  run_vibe start task_a
  run_vibe start task_b
  echo "unsaved work" >"$BATS_TEST_TMPDIR/worktrees/proj/task_a/scratch.txt"
  rm "$BATS_TEST_TMPDIR/worktrees/proj/task_b/HANDOFF.md" # a finished task hands nothing off

  run run_vibe "done" task_a task_b
  [ "$status" -eq 1 ]
  [[ "$output" == *"uncommitted changes"* ]]
  [ -d "$BATS_TEST_TMPDIR/worktrees/proj/task_a" ]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/task_b" ]
}

@test "done: multiple tasks — a git-side removal refusal is a failure, not a false success" {
  cd "$(make_repo proj)"
  run_vibe start task_a
  run_vibe start task_b
  rm "$BATS_TEST_TMPDIR/worktrees/proj/task_a/HANDOFF.md"
  rm "$BATS_TEST_TMPDIR/worktrees/proj/task_b/HANDOFF.md"
  # vibe's own guards all pass; git itself refuses to remove a locked worktree.
  git worktree lock "$BATS_TEST_TMPDIR/worktrees/proj/task_a"

  run run_vibe "done" task_a task_b
  [ "$status" -eq 1 ]
  [[ "$output" != *"removed worktree $BATS_TEST_TMPDIR/worktrees/proj/task_a"* ]]
  [ -d "$BATS_TEST_TMPDIR/worktrees/proj/task_a" ]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/task_b" ]
}

@test "done: multiple tasks run from inside the first worktree still removes the rest" {
  cd "$(make_repo proj)"
  run_vibe start task_a
  run_vibe start task_b
  rm "$BATS_TEST_TMPDIR/worktrees/proj/task_a/HANDOFF.md"
  rm "$BATS_TEST_TMPDIR/worktrees/proj/task_b/HANDOFF.md"

  # Removing task_a deletes this shell's cwd; task_b must not be collateral.
  cd "$BATS_TEST_TMPDIR/worktrees/proj/task_a"
  run run_vibe "done" task_a task_b
  [ "$status" -eq 0 ]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/task_a" ]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/task_b" ]
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

@test "resume --rebase: a conflicting rebase fails without claiming success" {
  # Both sides edit the same line, so the rebase must stop on a conflict.
  # What matters: non-zero exit, no "rebased" success line, and the worktree
  # left mid-rebase for a human — never a silent half-merge reported as done.
  cd "$(make_repo proj)"
  echo "base" >shared.txt
  git add -A
  git commit -q -m "base"
  git push -q

  local other
  other="$(clone_repo proj other)"
  echo "theirs" >"$other/shared.txt"
  git -C "$other" add -A
  git -C "$other" commit -q -m "theirs"
  git -C "$other" push -q

  echo "mine" >shared.txt
  git add -A
  git commit -q -m "mine"

  run run_vibe resume --rebase
  [ "$status" -ne 0 ]
  [[ "$output" != *"rebased main onto remote"* ]]
  # git left the rebase in progress, conflict markers and all
  run git status
  [[ "$output" == *"rebase in progress"* ]]
  git rebase --abort
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

@test "start: adopts a branch that exists only on origin" {
  cd "$(make_repo proj)"
  local other
  other="$(clone_repo proj other)"
  git -C "$other" checkout -q -b remote-start
  echo marker >"$other/marker.txt"
  git -C "$other" add marker.txt
  git -C "$other" commit -q -m "marker"
  git -C "$other" push -q origin remote-start

  run run_vibe start "remote start"
  [ "$status" -eq 0 ]
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/remote-start"
  [ -f "$wt/marker.txt" ]
  git -C "$wt" rev-parse '@{u}' >/dev/null
}

@test "start: --no-attach starts the tmux session and returns (server)" {
  # Mirrors "loop: on the server a fresh loop starts detached inside tmux":
  # the session is created against the stub tmux and never attached, so
  # 'ssh <host> vibe start <task>' exits 0 instead of dying on the headless
  # attach after the agent is already up.
  cd "$(make_repo proj)"
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" start "srv headless" --no-attach
  [ "$status" -eq 0 ]
  [[ "$output" == *"session running detached"* ]]
  [[ "$output" == *"vibe attach srv-headless"* ]]
  grep -q "new-session -d -s vibe-proj-srv-headless " "$VIBE_TEST_TMUX_LOG"
  # no attach: started from a script, attaching would fail or hang the caller
  run grep -qE "attach-session|switch-client" "$VIBE_TEST_TMUX_LOG"
  [ "$status" -ne 0 ]
}

@test "start: --no-attach refuses on local before creating anything" {
  cd "$(make_repo proj)"
  run run_vibe start "det start" --no-attach
  [ "$status" -eq 1 ]
  [[ "$output" == *"server"* ]]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/det-start" ]
}

@test "start: a second bare word is an error, not a silently truncated task" {
  # 'vibe start sota 2026-W30' used to keep only '2026-W30' and make branch
  # '2026-w30'. A task name with spaces must be quoted; two words is a mistake.
  cd "$(make_repo proj)"
  run run_vibe start sota 2026-W30
  [ "$status" -eq 1 ]
  [[ "$output" == *"one task at a time"* ]]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/2026-w30" ]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees/proj/sota" ]
  # the quoted form is still accepted
  run run_vibe start "sota 2026-W30"
  [ "$status" -eq 0 ]
  [ -d "$BATS_TEST_TMPDIR/worktrees/proj/sota-2026-w30" ]
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------
@test "list: an existing but empty worktree dir lists nothing and exits 0" {
  # The normal state after the last 'vibe done': git worktree remove leaves
  # the per-repo parent directory behind. The old tail-position '[[ ]] &&'
  # made cmd_list return 1 here, which set -e turned into a silent exit 1.
  cd "$(make_repo proj)"
  mkdir -p "$BATS_TEST_TMPDIR/worktrees/proj"
  run run_vibe list
  [ "$status" -eq 0 ]
  [[ "$output" == *"no tasks yet"* ]]
}

@test "list: prints one line per existing task" {
  cd "$(make_repo proj)"
  run_vibe start "task one" >/dev/null
  run_vibe start "task two" >/dev/null
  run run_vibe list
  [ "$status" -eq 0 ]
  [[ "$output" == *"task-one"* ]]
  [[ "$output" == *"task-two"* ]]
  [[ "$output" != *"no tasks yet"* ]]
}

@test "list: reports no tasks before the first worktree exists" {
  # No worktree root at all — the guard before the glob, not the empty-glob
  # path (that one has its own test above).
  cd "$(make_repo proj)"
  run run_vibe list
  [ "$status" -eq 0 ]
  [[ "$output" == *"no tasks yet for proj"* ]]
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

# The three upstream states a task can be in are what tells you whether it
# still has somewhere to push: never pushed, pushed, or pushed and since
# deleted on the remote (a merged PR — the signal that 'vibe done' can run).
@test "status: reports a task that was never pushed as having no upstream" {
  cd "$(make_repo proj)"
  run_vibe start "task nu"
  run run_vibe status
  [ "$status" -eq 0 ]
  local line
  line="$(printf '%s\n' "$output" | grep -A1 "worktrees/proj/task-nu" | tail -1)"
  [[ "$line" == *"no upstream"* ]]
  [[ "$line" != *"behind"* ]]
}

@test "status: reports ahead/behind once the branch tracks a remote" {
  cd "$(make_repo proj)"
  run_vibe start "task up"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-up"
  git -C "$wt" push -q -u origin task-up

  run run_vibe status
  [ "$status" -eq 0 ]
  local line
  line="$(printf '%s\n' "$output" | grep -A1 "worktrees/proj/task-up" | tail -1)"
  [[ "$line" == *"0 ahead"* ]]
  [[ "$line" == *"0 behind"* ]]
  [[ "$line" != *"upstream"* ]]
}

@test "status: reports a deleted remote branch as 'upstream gone'" {
  cd "$(make_repo proj)"
  run_vibe start "task gone"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/task-gone"
  git -C "$wt" push -q -u origin task-gone
  # what a merged PR leaves behind: the remote branch deleted, then pruned
  git -C "$wt" push -q origin --delete task-gone
  git -C "$wt" fetch -q --prune

  run run_vibe status
  [ "$status" -eq 0 ]
  local line
  line="$(printf '%s\n' "$output" | grep -A1 "worktrees/proj/task-gone" | tail -1)"
  [[ "$line" == *"upstream gone"* ]]
  [[ "$line" != *"behind"* ]]
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

@test "status: scopes tmux sessions to the current repo" {
  cd "$(make_repo proj)"
  run_vibe start "task a" >/dev/null

  local dir="$BATS_TEST_TMPDIR/tmuxbin-scope"
  mkdir -p "$dir"
  cat >"$dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  ls)
    echo "vibe-proj-task-a: 1 windows"
    echo "vibe-other-task-b: 1 windows"
    exit 0
    ;;
  has-session) exit 1 ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"

  run env PATH="$dir:$PATH" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"vibe-proj-task-a"* ]]
  [[ "$output" != *"vibe-other-task-b"* ]]
}

@test "status --all: shows tmux sessions from every repo" {
  cd "$(make_repo proj)"

  local dir="$BATS_TEST_TMPDIR/tmuxbin-scope-all"
  mkdir -p "$dir"
  cat >"$dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  ls)
    echo "vibe-proj-task-a: 1 windows"
    echo "vibe-other-task-b: 1 windows"
    exit 0
    ;;
  has-session) exit 1 ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"

  run env PATH="$dir:$PATH" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" status --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"vibe-proj-task-a"* ]]
  [[ "$output" == *"vibe-other-task-b"* ]]
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
  # clean, pushed, and handoff-free, so the guards have nothing to object to
  rm "$wt/HANDOFF.md"
  echo "done" >"$wt/work.txt"
  git -C "$wt" add -A
  git -C "$wt" commit -q -m "work"
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
# Harness isolation — the suite must never touch the real tmux server, even
# when it runs over SSH on the server itself. See tests/helper.bash.
# ---------------------------------------------------------------------------
@test "harness: the suite always looks local, whatever machine it runs on" {
  cd "$(make_repo proj)"
  run run_vibe where
  [ "$status" -eq 0 ]
  [[ "$output" == local* ]]
}

@test "harness: a server-path command hits the stub tmux, not the real one" {
  cd "$(make_repo proj)"
  local before=""
  if [ -n "$VIBE_TEST_REAL_TMUX" ]; then
    before="$("$VIBE_TEST_REAL_TMUX" list-sessions 2>/dev/null || true)"
  fi

  # SSH_CONNECTION set on purpose: this is the server path.
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" start "tmux isolation"
  [ "$status" -eq 0 ]
  [[ "$output" == *"persistent tmux session"* ]]

  # The session was created against the stub...
  grep -q "new-session -d -s vibe-proj-tmux-isolation " "$VIBE_TEST_TMUX_LOG"
  # ...and the real tmux server is untouched.
  if [ -n "$VIBE_TEST_REAL_TMUX" ]; then
    [ "$("$VIBE_TEST_REAL_TMUX" list-sessions 2>/dev/null || true)" = "$before" ]
  fi
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

@test "rc: refuses when the task has no tmux session" {
  # Server path against the helper's stub tmux, whose has-session always
  # fails — exactly the "worktree exists but nothing is running" case.
  cd "$(make_repo proj)"
  run_vibe start "rc idle" >/dev/null
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" rc "rc idle"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no tmux session"* ]]
}

@test "rc: sends /rc into an idle interactive session" {
  cd "$(make_repo proj)"
  run_vibe start "rc live" >/dev/null

  # A tmux whose session exists and whose pane shows an idle agent prompt,
  # so wait_for_pane_idle returns immediately instead of polling for 20s.
  local dir="$BATS_TEST_TMPDIR/tmuxbin"
  mkdir -p "$dir"
  cat >"$dir/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${VIBE_TEST_TMUX_LOG:?}"
case "${1:-}" in
  has-session) exit 0 ;;
  capture-pane) printf '│ > \n' ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"

  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    PATH="$dir:$PATH" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" rc "rc live"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sending /rc"* ]]
  grep -q "send-keys -t vibe-proj-rc-live /rc" "$VIBE_TEST_TMUX_LOG"
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

# ---------------------------------------------------------------------------
# script_dir / symlink resolution
# ---------------------------------------------------------------------------
@test "script_dir: resolves templates when vibe is invoked through a symlink" {
  # install.sh links ~/bin/vibe -> <repo>/bin/vibe, so EVERY real invocation
  # goes through a symlink and none of the rest of the suite does. If the
  # symlink walk broke, TEMPLATE_DIR would resolve next to the link instead of
  # the repo, `vibe start` would seed nothing, and the whole suite would stay
  # green — the failure would only show up on a real machine.
  cd "$(make_repo proj)"
  mkdir -p "$BATS_TEST_TMPDIR/fakebin"
  ln -s "$VIBE" "$BATS_TEST_TMPDIR/fakebin/vibe"
  run env -u TOOLKIT_TEMPLATE_DIR VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$BATS_TEST_TMPDIR/fakebin/vibe" doctor
  [[ "$output" == *"templates   $REPO_ROOT/templates"* ]]
}

@test "script_dir: resolves through a chain of symlinks" {
  cd "$(make_repo proj)"
  mkdir -p "$BATS_TEST_TMPDIR/l1" "$BATS_TEST_TMPDIR/l2"
  ln -s "$VIBE" "$BATS_TEST_TMPDIR/l1/vibe"
  ln -s "$BATS_TEST_TMPDIR/l1/vibe" "$BATS_TEST_TMPDIR/l2/vibe"
  run env -u TOOLKIT_TEMPLATE_DIR VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$BATS_TEST_TMPDIR/l2/vibe" doctor
  [[ "$output" == *"templates   $REPO_ROOT/templates"* ]]
}
