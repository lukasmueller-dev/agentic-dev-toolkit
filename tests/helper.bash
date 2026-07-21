#!/usr/bin/env bash
# Shared setup for the bats suites.
#
# Everything happens under $BATS_TEST_TMPDIR, which bats creates per test and
# removes afterwards, so no test can touch the real HOME, the real ~/.claude,
# or the real worktree root.

REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
export VIBE="$REPO_ROOT/bin/vibe"

# ---------------------------------------------------------------------------
# Isolation from the real machine's tmux
#
# detect_env() calls us "server" whenever SSH_CONNECTION/SSH_TTY is set or the
# hostname matches VIBE_SERVER_HOSTNAME. Run the suite over SSH and every
# `vibe start` / `vibe loop` then creates a REAL tmux session against the live
# tmux server — outside $BATS_TEST_TMPDIR, where bats' cleanup cannot reach it,
# with a real agent running in it against a worktree bats later deletes.
#
# So: force the local path for every test (braces), and make the real tmux
# unreachable anyway (belt), so a test that deliberately exercises the server
# path asserts against a log instead of leaking a session.
# ---------------------------------------------------------------------------
unset SSH_CONNECTION SSH_TTY SSH_CLIENT
# No hostname can contain a slash, so this never matches.
export VIBE_SERVER_HOSTNAME="vibe-tests/never-a-real-host"

# The runner's own vibe configuration must not reach the suite: a developer
# machine that exports VIBE_LOOP_PERMISSIVE_ARGS or keeps a real
# ~/.config/vibe/config would otherwise flip assertions from under the tests.
unset VIBE_WORKTREE_ROOT VIBE_AGENT_CMD VIBE_AGENT_HEADLESS_ARGS \
  VIBE_LOOP_PERMISSIVE_ARGS VIBE_TMUX_PREFIX VIBE_NTFY_TOPIC VIBE_RC_ON_START
export VIBE_CONFIG_FILE="${BATS_TEST_TMPDIR:-$BATS_FILE_TMPDIR}/no-such-config"

# Resolved before the stub goes on PATH, so a test can still ask the real tmux
# server whether it grew a session. Empty when the machine has no tmux.
VIBE_TEST_REAL_TMUX="$(command -v tmux 2>/dev/null || true)"
export VIBE_TEST_REAL_TMUX

VIBE_TEST_BIN="${BATS_FILE_TMPDIR:-${BATS_RUN_TMPDIR:-$BATS_TMPDIR}}/stub-bin"
if [ ! -x "$VIBE_TEST_BIN/tmux" ]; then
  mkdir -p "$VIBE_TEST_BIN"
  cat >"$VIBE_TEST_BIN/tmux" <<'STUB'
#!/usr/bin/env bash
# Stub tmux for the bats suite: record the call, never touch a real server.
printf '%s\n' "$*" >>"${VIBE_TEST_TMUX_LOG:?VIBE_TEST_TMUX_LOG unset}"
# has-session must fail, or callers think a session is already running.
case "${1:-}" in
has-session) exit 1 ;;
esac
exit 0
STUB
  chmod +x "$VIBE_TEST_BIN/tmux"
fi
case ":$PATH:" in
  *":$VIBE_TEST_BIN:"*) ;;
  *)
    PATH="$VIBE_TEST_BIN:$PATH"
    export PATH
    ;;
esac
export VIBE_TEST_TMUX_LOG="${BATS_TEST_TMPDIR:-$VIBE_TEST_BIN}/tmux.log"

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
