#!/usr/bin/env bats
#
# skills/handoff-brief/handoff.sh — staging a refined HANDOFF.md on a task
# branch before a dedicated session picks it up. Everything runs in throwaway
# repos under $BATS_TEST_TMPDIR.

load helper

setup() { git_env; }

HANDOFF="$REPO_ROOT/skills/handoff-brief/handoff.sh"

run_handoff() { bash "$HANDOFF" "$@"; }

wt() { echo "$BATS_TEST_TMPDIR/proj/.claude/worktrees/$1"; }

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
  [[ "$output" == *"STATE=created"* ]] || false
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
  [[ "$output" == *"STATE=existing-scaffold"* ]] || false
}

@test "create: leaves a handoff with content untouched, and says so" {
  cd "$(make_repo proj)"
  run_handoff create "keep task"
  echo "MY NOTES" >>"$(wt keep-task)/HANDOFF.md"
  run run_handoff create "keep task"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=existing-handoff"* ]] || false
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
  [[ "$output" == *"STATE=existing-handoff"* ]] || false
  grep -q "pushed handoff" "$(wt feat)/HANDOFF.md"
  git -C "$(wt feat)" rev-parse '@{u}' >/dev/null
}

# ---------------------------------------------------------------------------
# publish: validation, commit, push
# ---------------------------------------------------------------------------
@test "publish: refuses while a placeholder section remains, naming it" {
  cd "$(make_repo proj)"
  run_handoff create "raw task"
  run run_handoff publish "raw task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"State"* ]] || false
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
  [[ "$output" == *"Next action"* ]] || false
}

@test "publish: refuses when a section heading was lost" {
  cd "$(make_repo proj)"
  run_handoff create "broken task"
  finish_handoff "$(wt broken-task)"
  grep -v "^## Next action$" "$(wt broken-task)/HANDOFF.md" >"$(wt broken-task)/HANDOFF.md.t"
  mv "$(wt broken-task)/HANDOFF.md.t" "$(wt broken-task)/HANDOFF.md"
  run run_handoff publish "broken task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Next action"* ]] || false
}

@test "publish: commits the finished handoff and pushes it" {
  cd "$(make_repo proj)"
  run_handoff create "ship task"
  finish_handoff "$(wt ship-task)"
  run run_handoff publish "ship task"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=published"* ]] || false
  git -C "$BATS_TEST_TMPDIR/proj.git" log --oneline ship-task | grep -q "brief 'ship-task'"
  git -C "$BATS_TEST_TMPDIR/proj.git" show ship-task:HANDOFF.md | grep -q "Write the first failing test."
}

@test "publish: a relative core.hooksPath runs no hook of the staged branch on the commit and the push" {
  local r m="$BATS_TEST_TMPDIR/hooked"
  r="$(make_repo proj)"
  hook_files "$r" "$m" pre-commit commit-msg post-commit pre-push
  git -C "$r" config core.hooksPath .githooks
  cd "$r"
  run_handoff create "hook task"
  finish_handoff "$(wt hook-task)"
  run run_handoff publish "hook task"
  [ "$status" -eq 0 ]
  [ -n "$(git -C "$r" ls-remote origin refs/heads/hook-task)" ]
  [ ! -e "$m" ]
}

@test "publish: a handoff that adds an LFS-tracked file is not pushed with hooks off" {
  local r lfs="$BATS_TEST_TMPDIR/lfs"
  r="$(make_repo proj)"
  mkdir -p "$lfs" && printf '#!/bin/sh\n' >"$lfs/git-lfs" && chmod +x "$lfs/git-lfs"
  echo '*.md filter=lfs diff=lfs merge=lfs -text' >"$r/.gitattributes"
  git -C "$r" add .gitattributes && git -C "$r" commit -q -m "chore: lfs" && git -C "$r" push -q origin main
  cd "$r"
  run_handoff create "big task"
  finish_handoff "$(wt big-task)"
  PATH="$lfs:$PATH" run run_handoff publish "big task"
  [ "$status" -ne 0 ]
  [[ "$output" == *"git-lfs: not pushed"* ]] || false
  [ -z "$(git -C "$r" ls-remote origin refs/heads/big-task)" ]
}

@test "publish: removes the staging worktree so a new session can switch to the branch" {
  local r
  r="$(make_repo proj)"
  cd "$r"
  run_handoff create "free task"
  finish_handoff "$(wt free-task)"
  run_handoff publish "free task"
  [ ! -d "$(wt free-task)" ]
  git -C "$r" worktree add -q "$BATS_TEST_TMPDIR/session" -b session-x
  git -C "$BATS_TEST_TMPDIR/session" switch -q free-task
  grep -q "Write the first failing test." "$BATS_TEST_TMPDIR/session/HANDOFF.md"
}

@test "create: an untracked .claude/worktrees/ does not stop the fast-forward of main" {
  local r other
  r="$(make_repo proj)"
  cd "$r"
  run_handoff create "first task"
  other="$(clone_repo proj other)"
  git -C "$other" commit -q --allow-empty -m "teammate"
  git -C "$other" push -q origin main
  run run_handoff create "second task"
  [ "$status" -eq 0 ]
  [ "$(git -C "$(wt second-task)" log -1 --format=%s)" = "teammate" ]
}

@test "create: a failed fast-forward of main stops with git's error and the reason" {
  local r other
  r="$(make_repo proj)"
  other="$(clone_repo proj other)"
  echo upstream >"$other/clash.txt"
  git -C "$other" add clash.txt && git -C "$other" commit -q -m "add clash.txt"
  git -C "$other" push -q origin main
  echo local >"$r/clash.txt"
  cd "$r"
  run run_handoff create "clash task"
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot fast-forward main"*"stale HEAD"*"clash.txt"* ]] || false
  [ ! -d "$(wt clash-task)" ]
}
