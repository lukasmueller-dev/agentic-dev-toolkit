#!/usr/bin/env bash
# Shared setup for the bats suites.
#
# Everything happens under $BATS_TEST_TMPDIR, which bats creates per test and
# removes afterwards, so no test can touch the real HOME, the real ~/.claude,
# or the real worktree root.

REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
export VIBE="$REPO_ROOT/bin/vibe"

# git refuses to commit without an identity, and the CI runner has none.
git_env() {
  export GIT_AUTHOR_NAME="test"
  export GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="test"
  export GIT_COMMITTER_EMAIL="test@example.com"
  # Keep the test independent of the runner's own git config.
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
  export GIT_CONFIG_SYSTEM=/dev/null
  : >"$GIT_CONFIG_GLOBAL"
}

# make_repo NAME — a repo with one commit and a bare "remote" it tracks.
# Echoes the working copy path.
make_repo() {
  local name="${1:-proj}"
  local remote="$BATS_TEST_TMPDIR/$name.git"
  local work="$BATS_TEST_TMPDIR/$name"
  git init -q --bare "$remote"
  # Pin the bare remote's HEAD to main. The suite disables system/global git
  # config, so without this the built-in default (master) leaves HEAD pointing
  # at a ref we never create — and `clone_repo` then checks out nothing.
  git -C "$remote" symbolic-ref HEAD refs/heads/main
  git init -q -b main "$work"
  git -C "$work" commit -q --allow-empty -m "init"
  git -C "$work" remote add origin "$remote"
  git -C "$work" push -q -u origin main
  printf '%s' "$work"
}

# A second clone of the same remote, to create divergence between two copies.
clone_repo() {
  local name="$1" as="$2"
  git clone -q "$BATS_TEST_TMPDIR/$name.git" "$BATS_TEST_TMPDIR/$as"
  printf '%s' "$BATS_TEST_TMPDIR/$as"
}

# Run vibe with an isolated worktree root and a stub agent, never the real one.
run_vibe() {
  VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" "$@"
}
