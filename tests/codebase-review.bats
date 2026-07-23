#!/usr/bin/env bats
#
# skills/codebase-review/review.sh — staging the brief for an independent
# repo-review round: round numbering, the merge gate between rounds, and the
# shared handoff publish contract. Everything runs in throwaway repos under
# $BATS_TEST_TMPDIR.

load helper

setup() { git_env; }

REVIEW="$REPO_ROOT/skills/codebase-review/review.sh"

run_review() {
  VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    bash "$REVIEW" "$@"
}

wt() { echo "$BATS_TEST_TMPDIR/worktrees/proj/$1"; }

# finish_handoff DIR — replace the State and Next action placeholders with
# real content, the way the model would after assembling the mission.
finish_handoff() {
  local f="$1/HANDOFF.md"
  awk '
    /^## State$/ { print; print ""; print "Not started. Round mission: full catalog."; skip = 1; next }
    /^## Next action$/ { print; print ""; print "Rebase onto origin/main, run the gate."; skip = 1; next }
    skip && /^##/ { print ""; skip = 0 }
    skip { next }
    { print }
  ' "$f" >"$f.t" && mv "$f.t" "$f"
}

# merged_round NAME — create round branch NAME at the current main tip and
# push it, like a completed round whose handoff was consumed. The caller
# advances main afterwards so the round sits strictly behind, the way a real
# merged round does.
merged_round() {
  git branch "$1" main
  git push -q origin "$1"
}

advance_main() {
  git commit -q --allow-empty -m "post-round work"
  git push -q origin main
}

# ---------------------------------------------------------------------------
# create: round numbering
# ---------------------------------------------------------------------------
@test "create: first round in a fresh repo is fresh-review-1" {
  cd "$(make_repo proj)"
  run run_review create
  [ "$status" -eq 0 ]
  [[ "$output" == *"ROUND=1"* ]]
  [[ "$output" == *"ROUND_STATE=new"* ]]
  [[ "$output" == *"BRANCH=fresh-review-1"* ]]
  [[ "$output" == *"DEFAULT_BRANCH=main"* ]]
  [[ "$output" == *"STATE=created"* ]]
  local f
  f="$(wt fresh-review-1)/HANDOFF.md"
  [ -f "$f" ]
  grep -q "^# Handoff — proj / fresh-review-1$" "$f"
  run grep -qE '<(repo|branch|worktree|date|machine)>' "$f"
  [ "$status" -ne 0 ]
}

@test "create: counts the bare fresh-review branch as round 1" {
  cd "$(make_repo proj)"
  merged_round fresh-review
  merged_round fresh-review-2
  advance_main
  run run_review create
  [ "$status" -eq 0 ]
  [[ "$output" == *"ROUND=3"* ]]
  [[ "$output" == *"BRANCH=fresh-review-3"* ]]
  [[ "$output" == *"LAST_ROUND_BRANCH=fresh-review-2"* ]]
}

@test "create: numbering survives a deleted round branch via merge subjects" {
  cd "$(make_repo proj)"
  git commit -q --allow-empty -m "Merge pull request #7 from someone/fresh-review-3"
  git push -q origin main
  run run_review create
  [ "$status" -eq 0 ]
  [[ "$output" == *"ROUND=4"* ]]
}

@test "create: a fresh-review-* branch without a number is not a round" {
  cd "$(make_repo proj)"
  git checkout -q -b fresh-review-fixes
  git commit -q --allow-empty -m "unmerged side work"
  git checkout -q main
  run run_review create
  [ "$status" -eq 0 ]
  [[ "$output" == *"ROUND=1"* ]]
  [[ "$output" == *"BRANCH=fresh-review-1"* ]]
}

# ---------------------------------------------------------------------------
# create: the merge gate between rounds
# ---------------------------------------------------------------------------
@test "create: refuses while an older round is unmerged" {
  cd "$(make_repo proj)"
  git checkout -q -b fresh-review
  git commit -q --allow-empty -m "round 1 still open"
  git checkout -q main
  merged_round fresh-review-2
  advance_main
  run run_review create
  [ "$status" -eq 1 ]
  [[ "$output" == *"not merged"* ]]
  [[ "$output" == *"fresh-review"* ]]
}

@test "create: adopts the latest round when it is staged but unmerged" {
  cd "$(make_repo proj)"
  git checkout -q -b fresh-review-2
  echo "Round 2 mission: already staged." >>HANDOFF.md
  git add HANDOFF.md
  git commit -q -m "vibe handoff: brief 'fresh-review-2'"
  git push -q origin fresh-review-2
  git checkout -q main
  run run_review create
  [ "$status" -eq 0 ]
  [[ "$output" == *"ROUND=2"* ]]
  [[ "$output" == *"ROUND_STATE=existing"* ]]
  [[ "$output" == *"STATE=existing-handoff"* ]]
  grep -q "already staged" "$(wt fresh-review-2)/HANDOFF.md"
}

@test "create: rerun re-adopts its own staging leftover instead of burning the number" {
  cd "$(make_repo proj)"
  run_review create
  run run_review create
  [ "$status" -eq 0 ]
  [[ "$output" == *"ROUND=1"* ]]
  [[ "$output" == *"ROUND_STATE=existing"* ]]
  [[ "$output" == *"STATE=existing-scaffold"* ]]
}

# ---------------------------------------------------------------------------
# publish: shared handoff contract
# ---------------------------------------------------------------------------
@test "publish: refuses while a placeholder section remains, naming it" {
  cd "$(make_repo proj)"
  run_review create
  run run_review publish fresh-review-1
  [ "$status" -eq 1 ]
  [[ "$output" == *"State"* ]]
}

@test "publish: commits the finished brief and pushes with an upstream" {
  cd "$(make_repo proj)"
  run_review create
  finish_handoff "$(wt fresh-review-1)"
  run run_review publish fresh-review-1
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=published"* ]]
  [ -z "$(git -C "$(wt fresh-review-1)" status --porcelain)" ]
  git -C "$(wt fresh-review-1)" rev-parse '@{u}' >/dev/null
  git -C "$BATS_TEST_TMPDIR/proj.git" log --oneline fresh-review-1 |
    grep -q "brief 'fresh-review-1'"
}

@test "publish: rejects a branch outside the round namespace" {
  cd "$(make_repo proj)"
  run run_review publish some-feature
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a review-round branch"* ]]
}
