#!/usr/bin/env bats
#
# skills/babysit-pr — the stop check (pr-ready.sh) and the brief staging
# script. `gh` is always a stub under $BATS_TEST_TMPDIR, placed early on PATH:
# no test reaches the real GitHub API, the real HOME, or the worktree root.

load helper

BRIEF="$REPO_ROOT/skills/babysit-pr/brief.sh"
PR_READY="$REPO_ROOT/skills/babysit-pr/pr-ready.sh"

setup() {
  git_env
  STUB_BIN="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB_BIN"
  install_gh_stub
  PATH="$STUB_BIN:$PATH"
  export PATH
  # Defaults: a clean PR. Individual tests overwrite these fixtures.
  export GH_PR_JSON="$BATS_TEST_TMPDIR/pr.json"
  export GH_CHECKS_JSON="$BATS_TEST_TMPDIR/checks.json"
  export GH_THREADS_JSON="$BATS_TEST_TMPDIR/threads.json"
  echo '{"headRefName":"fix-thing","title":"Fix the thing","url":"https://example.invalid/pr/42"}' >"$GH_PR_JSON"
  echo '[{"bucket":"pass"},{"bucket":"skipping"}]' >"$GH_CHECKS_JSON"
  threads true true
}

# install_gh_stub — a `gh` that answers only from fixture files, and shouts if
# the code under test ever calls a subcommand it should not (merge, comment…).
install_gh_stub() {
  cat >"$STUB_BIN/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "pr view")
    cat "$GH_PR_JSON"
    ;;
  "pr checks")
    if [ -n "${GH_CHECKS_ERR:-}" ]; then
      echo "$GH_CHECKS_ERR" >&2
      exit 1
    fi
    cat "$GH_CHECKS_JSON"
    ;;
  "repo view")
    printf '%s\n' "${GH_NWO:-owner/proj}"
    ;;
  "api graphql")
    if [ -n "${GH_API_ERR:-}" ]; then
      echo "$GH_API_ERR" >&2
      exit 1
    fi
    cat "$GH_THREADS_JSON"
    ;;
  *)
    echo "gh stub: forbidden or unexpected call: $*" >&2
    exit 3
    ;;
esac
STUB
  chmod +x "$STUB_BIN/gh"
}

# threads BOOL... — write the reviewThreads fixture, one isResolved per arg.
threads() {
  local nodes="" b
  for b in "$@"; do
    [ -z "$nodes" ] || nodes="$nodes,"
    nodes="$nodes{\"isResolved\":$b}"
  done
  printf '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[%s]}}}}}\n' \
    "$nodes" >"$GH_THREADS_JSON"
}

run_brief() {
  VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    bash "$BRIEF" "$@"
}

wt() { echo "$BATS_TEST_TMPDIR/worktrees/proj/$1"; }

# The same trick tests/loop-brief.bats uses: fill the two placeholder sections
# the way the model would after refinement.
finish_brief() {
  local f="$1/LOOP.md"
  awk '
    /^## Done when$/ { print; print ""; print "Checks pass, no unresolved threads."; skip = 1; next }
    /^## Constraints$/ { print; print ""; print "Never merge the PR."; skip = 1; next }
    skip && /^##/ { print ""; skip = 0 }
    skip { next }
    { print }
  ' "$f" >"$f.t" && mv "$f.t" "$f"
}

# ---------------------------------------------------------------------------
# pr-ready.sh — the stop check
# ---------------------------------------------------------------------------
@test "pr-ready: clean PR — green checks, all threads resolved — exits 0" {
  run bash "$PR_READY" 42
  [ "$status" -eq 0 ]
  [[ "$output" == *"is ready"* ]]
}

@test "pr-ready: a failing check is not ready" {
  echo '[{"bucket":"pass"},{"bucket":"fail"}]' >"$GH_CHECKS_JSON"
  run bash "$PR_READY" 42
  [ "$status" -ne 0 ]
  [[ "$output" == *"failing or pending"* ]]
}

@test "pr-ready: a pending check is not ready" {
  echo '[{"bucket":"pending"}]' >"$GH_CHECKS_JSON"
  run bash "$PR_READY" 42
  [ "$status" -ne 0 ]
  [[ "$output" == *"failing or pending"* ]]
}

@test "pr-ready: an unresolved review thread is not ready" {
  threads true false
  run bash "$PR_READY" 42
  [ "$status" -ne 0 ]
  [[ "$output" == *"unresolved review thread"* ]]
}

@test "pr-ready: a PR with no review threads at all is ready" {
  threads
  run bash "$PR_READY" 42
  [ "$status" -eq 0 ]
}

@test "pr-ready: gh missing is not ready" {
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  run env PATH="$BATS_TEST_TMPDIR/empty" "$BASH" "$PR_READY" 42
  [ "$status" -ne 0 ]
  [[ "$output" == *"'gh' is not installed"* ]]
}

@test "pr-ready: gh erroring (unauthenticated) is not ready, never 'done'" {
  export GH_CHECKS_ERR="gh: To use GitHub CLI in a GitHub Actions workflow, set the GH_TOKEN environment variable"
  run bash "$PR_READY" 42
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not read checks"* ]]
}

@test "pr-ready: the review-thread query erroring is not ready" {
  export GH_API_ERR="HTTP 502"
  run bash "$PR_READY" 42
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not read review threads"* ]]
}

@test "pr-ready: a non-numeric PR argument is rejected" {
  run bash "$PR_READY" "not-a-number"
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage"* ]]
}

# ---------------------------------------------------------------------------
# brief.sh create
# ---------------------------------------------------------------------------
@test "create: renders LOOP.md on the PR's own head branch" {
  cd "$(make_repo proj)"
  run run_brief create 42
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=created"* ]]
  [[ "$output" == *"BRANCH=fix-thing"* ]]
  local f
  f="$(wt fix-thing)/LOOP.md"
  [ -f "$f" ]
  grep -q "^# Loop — proj / fix-thing$" "$f"
  grep -q "PR #42 is mergeable" "$f"
  grep -q "pr-ready.sh 42" "$f"
  run grep -qE '<(repo|branch|worktree|goal|until|max|date|machine)>' "$f"
  [ "$status" -ne 0 ]
}

@test "create: seeds HANDOFF.md alongside the brief" {
  cd "$(make_repo proj)"
  run_brief create 42
  grep -q "^# Handoff — proj / fix-thing$" "$(wt fix-thing)/HANDOFF.md"
}

@test "create: leaves an existing brief untouched" {
  cd "$(make_repo proj)"
  run_brief create 42
  echo "MY BRIEF" >"$(wt fix-thing)/LOOP.md"
  run run_brief create 42
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=existing-brief"* ]]
  [ "$(cat "$(wt fix-thing)/LOOP.md")" = "MY BRIEF" ]
}

@test "create: adopts the PR branch that exists only on origin" {
  cd "$(make_repo proj)"
  local other
  other="$(clone_repo proj other)"
  git -C "$other" checkout -q -b fix-thing
  git -C "$other" commit -q --allow-empty -m "pr work"
  git -C "$other" push -q origin fix-thing

  run run_brief create 42
  [ "$status" -eq 0 ]
  git -C "$(wt fix-thing)" rev-parse '@{u}' >/dev/null
  git -C "$(wt fix-thing)" log --oneline | grep -q "pr work"
}

@test "create: rejects a non-numeric PR argument before touching git" {
  cd "$(make_repo proj)"
  run run_brief create "forty-two"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
  [ ! -d "$BATS_TEST_TMPDIR/worktrees" ]
}

@test "create: refuses while the PR's loop is live" {
  cd "$(make_repo proj)"
  run_brief create 42
  local live
  sleep 30 &
  live=$!
  printf 'STATUS=running\nPID=%s\n' "$live" >"$(wt fix-thing)/.vibe-loop.state"
  run run_brief create 42
  kill "$live" 2>/dev/null || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"loop is running"* ]]
}

# ---------------------------------------------------------------------------
# brief.sh publish
# ---------------------------------------------------------------------------
@test "publish: refuses while a placeholder section remains, naming it" {
  cd "$(make_repo proj)"
  run_brief create 42
  run run_brief publish 42
  [ "$status" -eq 1 ]
  [[ "$output" == *"Done when"* ]]
}

@test "publish: commits the finished brief and pushes to the PR branch" {
  cd "$(make_repo proj)"
  run_brief create 42
  finish_brief "$(wt fix-thing)"
  run run_brief publish 42
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATE=published"* ]]
  [ -z "$(git -C "$(wt fix-thing)" status --porcelain)" ]
  git -C "$(wt fix-thing)" rev-parse '@{u}' >/dev/null
  git -C "$BATS_TEST_TMPDIR/proj.git" log --oneline fix-thing |
    grep -q "PR #42 is mergeable"
}

@test "publish: refuses without a staged worktree" {
  cd "$(make_repo proj)"
  run run_brief publish 42
  [ "$status" -eq 1 ]
  [[ "$output" == *"brief.sh create 42"* ]]
}
