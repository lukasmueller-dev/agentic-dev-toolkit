#!/usr/bin/env bats
#
# skills/loop-brief/brief.sh — staging a refined LOOP.md brief on a task
# branch before an unattended loop starts. Everything runs in throwaway repos
# under $BATS_TEST_TMPDIR; the one loop-integration test drives a stub agent.

load helper

setup() { git_env; }

BRIEF="$REPO_ROOT/skills/loop-brief/brief.sh"

run_brief() {
  VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    bash "$BRIEF" "$@"
}

wt() { echo "$BATS_TEST_TMPDIR/worktrees/proj/$1"; }

# finish_brief DIR — replace the two placeholder paragraphs with real content,
# the way the model would after refinement.
finish_brief() {
  local f="$1/LOOP.md"
  awk '
    /^## Done when$/ { print; print ""; print "All tests in tests/ pass."; skip = 1; next }
    /^## Constraints$/ { print; print ""; print "Do not delete tests."; skip = 1; next }
    skip && /^##/ { print ""; skip = 0 }
    skip { next }
    { print }
  ' "$f" >"$f.t" && mv "$f.t" "$f"
}

# ---------------------------------------------------------------------------
# create: rendering
# ---------------------------------------------------------------------------
@test "create: renders LOOP.md from the shared template, tokens substituted" {
  cd "$(make_repo proj)"
  run run_brief create "Doc Task" --until 'false' --max 7
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=created"* ]]
  local f
  f="$(wt doc-task)/LOOP.md"
  [ -f "$f" ]
  grep -q "^# Loop — proj / doc-task$" "$f"
  grep -q "Doc Task" "$f"
  # shellcheck disable=SC2016  # literal backticks from the template's metadata line
  grep -qF '`false`' "$f"
  grep -q "Max rounds:.* 7" "$f"
  run grep -qE '<(repo|branch|worktree|goal|until|max|date|machine)>' "$f"
  [ "$status" -ne 0 ]
}

@test "create: seeds HANDOFF.md alongside the brief" {
  cd "$(make_repo proj)"
  run_brief create "hand task"
  local f
  f="$(wt hand-task)/HANDOFF.md"
  [ -f "$f" ]
  grep -q "^# Handoff — proj / hand-task$" "$f"
}

@test "create: keeps an existing HANDOFF.md" {
  cd "$(make_repo proj)"
  mkdir -p "$BATS_TEST_TMPDIR/worktrees/proj"
  git worktree add -q -b keep-hand "$(wt keep-hand)"
  echo "MY NOTES" >"$(wt keep-hand)/HANDOFF.md"
  run_brief create "keep hand"
  [ "$(cat "$(wt keep-hand)/HANDOFF.md")" = "MY NOTES" ]
}

@test "create: works from inside another worktree of the repo" {
  cd "$(make_repo proj)"
  run_brief create "task one"
  cd "$(wt task-one)"
  run run_brief create "task two"
  [ "$status" -eq 0 ]
  [ -f "$(wt task-two)/LOOP.md" ]
}

# ---------------------------------------------------------------------------
# create: existing state is never clobbered
# ---------------------------------------------------------------------------
@test "create: leaves an existing brief untouched" {
  cd "$(make_repo proj)"
  run_brief create "keep task"
  echo "MY BRIEF" >"$(wt keep-task)/LOOP.md"
  run run_brief create "keep task"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=existing-brief"* ]]
  [ "$(cat "$(wt keep-task)/LOOP.md")" = "MY BRIEF" ]
}

@test "create: adopts a branch that exists only on origin" {
  cd "$(make_repo proj)"
  local other
  other="$(clone_repo proj other)"
  git -C "$other" checkout -q -b feat
  echo "pushed brief" >"$other/LOOP.md"
  git -C "$other" add LOOP.md
  git -C "$other" commit -q -m "brief"
  git -C "$other" push -q origin feat

  # this machine has neither a local 'feat' branch nor a fetched remote ref
  run run_brief create "feat"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=existing-brief"* ]]
  grep -q "pushed brief" "$(wt feat)/LOOP.md"
  git -C "$(wt feat)" rev-parse '@{u}' >/dev/null
}

@test "create: refuses while the task's loop is live" {
  cd "$(make_repo proj)"
  run_brief create "busy task"
  local live
  sleep 30 &
  live=$!
  printf 'STATUS=running\nPID=%s\n' "$live" >"$(wt busy-task)/.vibe-loop.state"
  run run_brief create "busy task"
  kill "$live" 2>/dev/null || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"loop is running"* ]]
}

# ---------------------------------------------------------------------------
# publish: validation, commit, push
# ---------------------------------------------------------------------------
@test "publish: refuses while a placeholder section remains, naming it" {
  cd "$(make_repo proj)"
  run_brief create "raw task"
  run run_brief publish "raw task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Done when"* ]]
}

@test "publish: refuses when a section heading was lost" {
  cd "$(make_repo proj)"
  run_brief create "broken task"
  finish_brief "$(wt broken-task)"
  grep -v "^## Constraints$" "$(wt broken-task)/LOOP.md" >"$(wt broken-task)/LOOP.md.t"
  mv "$(wt broken-task)/LOOP.md.t" "$(wt broken-task)/LOOP.md"
  run run_brief publish "broken task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Constraints"* ]]
}

@test "publish: commits the finished brief and pushes with an upstream" {
  cd "$(make_repo proj)"
  run_brief create "ship task" --until 'true' --max 3
  finish_brief "$(wt ship-task)"
  run run_brief publish "ship task"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=published"* ]]
  [ -z "$(git -C "$(wt ship-task)" status --porcelain)" ]
  git -C "$(wt ship-task)" rev-parse '@{u}' >/dev/null
  git -C "$BATS_TEST_TMPDIR/proj.git" log --oneline ship-task | grep -q "brief 'ship-task'"
}

@test "publish: refuses while the task's loop is live" {
  cd "$(make_repo proj)"
  run_brief create "hot task"
  finish_brief "$(wt hot-task)"
  local live
  sleep 30 &
  live=$!
  printf 'STATUS=running\nPID=%s\n' "$live" >"$(wt hot-task)/.vibe-loop.state"
  run run_brief publish "hot task"
  kill "$live" 2>/dev/null || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"loop is running"* ]]
}

# ---------------------------------------------------------------------------
# fit with vibe loop: a published brief is used as-is
# ---------------------------------------------------------------------------
@test "publish: vibe loop uses the published brief without re-seeding it" {
  cd "$(make_repo proj)"
  run_brief create "go task" --until 'true' --max 2
  finish_brief "$(wt go-task)"
  run_brief publish "go task"

  # the same stub agent vibe-loop.bats drives
  cat >"$BATS_TEST_TMPDIR/agent.sh" <<'EOF'
#!/usr/bin/env bash
echo done >>progress.txt
exit 0
EOF
  chmod +x "$BATS_TEST_TMPDIR/agent.sh"
  export VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees"
  export VIBE_AGENT_CMD="$BATS_TEST_TMPDIR/agent.sh"
  export VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config"
  run "$VIBE" loop "go task" --until 'true' --max 2
  [ "$status" -eq 0 ]
  # the refined brief survived — not re-seeded from the template
  grep -q "All tests in tests/ pass." "$(wt go-task)/LOOP.md"
  # and vibe found nothing to commit at start (the brief was already committed)
  run git -C "$(wt go-task)" log --oneline
  [[ "$output" != *"vibe loop: start"* ]]
  [[ "$output" == *"vibe loop: brief"* ]]
}

# ---------------------------------------------------------------------------
# config: worktree root resolution must mirror vibe (env > config > default)
# ---------------------------------------------------------------------------
@test "config: worktree root from the config file is honored" {
  cd "$(make_repo proj)"
  printf 'VIBE_WORKTREE_ROOT=%s\n' "$BATS_TEST_TMPDIR/altroot" >"$BATS_TEST_TMPDIR/config"
  run env -u VIBE_WORKTREE_ROOT VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/config" \
    bash "$BRIEF" create "cfg task"
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/altroot/proj/cfg-task/LOOP.md" ]
}
