#!/usr/bin/env bats
#
# vibe: color safety (NO_COLOR / CLICOLOR_FORCE / tty gating) and vibe help.

bats_require_minimum_version 1.5.0

load helper

setup() { git_env; }

# Escapes are gone once no ANSI CSI sequence ('\033[', the start of every
# SGR color code vibe emits) appears anywhere in the output.
has_escapes() { [[ "$1" == *$'\033['* ]]; }

@test "color: NO_COLOR=1 strips escapes from vibe status" {
  cd "$(make_repo proj)"
  run env NO_COLOR=1 \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" status
  [ "$status" -eq 0 ]
  local captured="$output"
  run ! has_escapes "$captured"
}

@test "color: piping vibe status through a non-tty strips escapes" {
  cd "$(make_repo proj)"
  run bash -c '
    VIBE_WORKTREE_ROOT="$1" VIBE_AGENT_CMD=true VIBE_CONFIG_FILE="$2" "$3" status | cat
  ' _ "$BATS_TEST_TMPDIR/worktrees" "$BATS_TEST_TMPDIR/no-such-config" "$VIBE"
  [ "$status" -eq 0 ]
  local captured="$output"
  run ! has_escapes "$captured"
}

@test "color: CLICOLOR_FORCE=1 keeps escapes even without a tty" {
  cd "$(make_repo proj)"
  run env CLICOLOR_FORCE=1 \
    VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    VIBE_AGENT_CMD=true \
    VIBE_CONFIG_FILE="$BATS_TEST_TMPDIR/no-such-config" \
    "$VIBE" status
  [ "$status" -eq 0 ]
  local captured="$output"
  run has_escapes "$captured"
  [ "$status" -eq 0 ]
}

@test "help: lists every command in main()'s dispatch" {
  run run_vibe help
  [ "$status" -eq 0 ]
  # Read the dispatch out of main() itself, so a command added there without
  # a help entry fails here. The old hardcoded list also matched bare
  # substrings — "rc" is inside "force", "done" inside "abandoned" — so it
  # could not fail; anchor each match to a help line that starts with the
  # command as its own word.
  local cmd found=0
  while IFS= read -r cmd; do
    found=$((found + 1))
    printf '%s\n' "$output" | grep -qE "^  ${cmd}( |\$)" ||
      {
        echo "missing from help: $cmd" >&2
        return 1
      }
  done < <(sed -n 's/^    \([a-z][a-z-]*\)) cmd_.*/\1/p' "$VIBE")
  # and the dispatch was actually parsed — an empty list proves nothing
  [ "$found" -ge 12 ]
}
