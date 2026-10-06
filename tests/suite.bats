#!/usr/bin/env bats
#
# Guards on the suite itself: things that make a test report green without
# having asserted anything.

load helper

# bash 3.2 — /bin/bash on macOS, and the shell bats runs under there — does
# not apply errexit (or the ERR trap) to a failing `[[ ]]` or `(( ))`. A test
# whose assertion is one of those, anywhere but its last line, keeps going
# after the mismatch and passes. Every `[[` assertion in this suite therefore
# ends in `|| false`: the `||` list's last command is a simple one, which
# errexit does see on every bash.
@test "no assertion in the suite is a bare [[ ]] or (( )) statement" {
  run grep -nE \
    '^[[:space:]]*!?[[:space:]]*(\[\[|\(\().*(\]\]|\)\))[[:space:]]*(#.*)?$' \
    "$REPO_ROOT"/tests/*.bats "$REPO_ROOT"/tests/helper.bash
  echo "$output"
  # grep exits 1 when nothing matched; anything else is a bare assertion, or
  # an error reading the suite
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

# The idiom the lint enforces has to actually stop the test on the bash the
# suite runs under.
@test "a failing [[ ]] || false stops a function under errexit" {
  run bash -c 'set -eET; t() { [[ 1 == 2 ]] || false; echo continued; }; t'
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

# The trap itself, so a future bash that closes the hole retires the rule
# visibly rather than silently.
@test "bash 3.2 lets a function continue past a failing bare [[ ]]" {
  local v
  v="$(bash -c 'echo "$BASH_VERSION"')"
  case "$v" in
    3.2.*) ;;
    *) skip "bash $v is not 3.2" ;;
  esac
  run bash -c 'set -eET; t() { [[ 1 == 2 ]]; echo continued; }; t'
  [ "$status" -eq 0 ]
  [ "$output" = "continued" ]
}
