#!/usr/bin/env bats
#
# vibe: leaving the terminal clean after a tmux attach.
#
# tmux asks the terminal for its colours (OSC 10/11) on every attach. The
# answer arrives on the tty input side, and if the client is gone by then it
# lands in the shell that inherits the terminal — visible as
# "10;rgb:cccc/cccc/cccc" sitting on the prompt, one Enter from being run as a
# command. vibe drains the terminal after attach so that cannot happen.

bats_require_minimum_version 1.5.0

load helper

setup() { git_env; }

# A tmux stub whose attach-session fails, to check that draining afterwards
# does not swallow the failure along with the junk.
stub_tmux_attach_fails() {
  local dir="$BATS_TEST_TMPDIR/tmuxbin"
  mkdir -p "$dir"
  cat >"$dir/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${VIBE_TEST_TMUX_LOG:?}"
case "${1:-}" in
  has-session) exit 1 ;;
  attach-session) exit 3 ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"
  PATH="$dir:$PATH"
}

# A tmux stub that says when its attach-session returns, so the driver playing
# the terminal knows the moment the client went away — the moment a colour
# answer still in flight has nobody left to receive it.
ATTACH_MARKER="ATTACH-RETURNED"
stub_tmux_attach_announces() {
  local dir="$BATS_TEST_TMPDIR/tmuxbin"
  mkdir -p "$dir"
  cat >"$dir/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"\${VIBE_TEST_TMUX_LOG:?}"
case "\${1:-}" in
  has-session) exit 1 ;;
  attach-session) echo "$ATTACH_MARKER" ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"
  PATH="$dir:$PATH"
}

@test "tty: a failed attach still fails, draining does not mask it" {
  cd "$(make_repo proj)"
  stub_tmux_attach_fails
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" start "attach boom"
  [ "$status" -eq 3 ]
  grep -q "attach-session -t vibe-proj-attach-boom" "$VIBE_TEST_TMUX_LOG"
}

@test "tty: with no terminal on stdin nothing is asked of the terminal" {
  # Scripted use — 'ssh host vibe start …', a cron job — has no terminal on
  # stdin to read an answer from, so there is nothing to drain and no reason
  # to ask. Asking anyway would put an escape sequence on the terminal of
  # whoever launched it and then wait out the timeout for an answer that
  # cannot arrive. Stdin is closed here while a terminal still exists, which
  # is exactly that shape.
  command -v python3 >/dev/null 2>&1 || skip "python3 needed to allocate a pty"
  cd "$(make_repo proj)"
  # shellcheck disable=SC2016 # $VIBE is for the inner bash, which inherits it
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    python3 "$REPO_ROOT/tests/pty-run.py" \
    bash -c '"$VIBE" start "no tty" </dev/null'
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\033[6n'* ]]
}

@test "tty: a stale colour answer lands on nobody's prompt" {
  command -v python3 >/dev/null 2>&1 || skip "python3 needed to allocate a pty"
  cd "$(make_repo proj)"
  stub_tmux_attach_announces

  # pty-run.py plays the terminal. It sends the colour answer a beat after the
  # stub announces the client is gone — the in-flight answer that has nowhere
  # left to go. What the terminal *shows* is the whole symptom, so that is the
  # assertion: drained silently it is never echoed; left alone it appears on
  # the prompt as "11;rgb:1818/1818/1818".
  # shellcheck disable=SC2016 # $VIBE is for the inner bash, which inherits it
  run env SSH_CONNECTION="1.2.3.4 1 5.6.7.8 22" \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    PTY_RUN_MARKER="$ATTACH_MARKER" \
    python3 "$REPO_ROOT/tests/pty-run.py" bash -c '
      "$VIBE" start "stale answer"
      sleep 1'
  [ "$status" -eq 0 ]
  [[ "$output" == *"$ATTACH_MARKER"* ]] # the attach really did happen
  [[ "$output" != *"rgb:"* ]]
}
