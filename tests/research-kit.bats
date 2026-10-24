#!/usr/bin/env bats
#
# The research-* seed scripts. Everything runs in throwaway repos under $BATS_TEST_TMPDIR.

load helper

setup() { git_env; }

SETUP="$REPO_ROOT/skills/research-experiment-setup/seed.sh"
TRIAL="$REPO_ROOT/skills/research-hardware-trial/seed.sh"

@test "experiment seed: renders docs/EXPERIMENT_SETUP.md with every card row" {
  local d
  d="$(make_repo exp)"
  run bash "$SETUP" "$d"
  [ "$status" -eq 0 ]
  [ -f "$d/docs/EXPERIMENT_SETUP.md" ]
  [ "$(grep -cE '^\| [0-9]+ \|' "$d/docs/EXPERIMENT_SETUP.md")" -eq 10 ]
  run grep -nE '<(repo|date|commit)>' "$d/docs/EXPERIMENT_SETUP.md"
  [ "$status" -ne 0 ]
}

@test "experiment seed: never overwrites an existing setup table" {
  local d before
  d="$(make_repo exp-again)"
  bash "$SETUP" "$d"
  echo "decided by hand" >>"$d/docs/EXPERIMENT_SETUP.md"
  before="$(cat "$d/docs/EXPERIMENT_SETUP.md")"
  run bash "$SETUP" "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^exists: '
  [ "$(cat "$d/docs/EXPERIMENT_SETUP.md")" = "$before" ]
}

@test "hardware seed: renders one slot file per platform under docs/hardware/" {
  local d
  d="$(make_repo hw)"
  run bash "$TRIAL" go2 "$d"
  [ "$status" -eq 0 ]
  grep -q '^# Hardware trial — go2$' "$d/docs/hardware/go2.md"
  run grep -nE '<(repo|date|commit|platform)>' "$d/docs/hardware/go2.md"
  [ "$status" -ne 0 ]
}

@test "hardware seed: refuses a platform name that is a path" {
  # The name becomes a file name; a slash or dot would write outside docs/hardware/.
  local d
  d="$(make_repo hw-path)"
  run bash "$TRIAL" ../escape "$d"
  [ "$status" -eq 2 ]
  [ ! -e "$d/docs/escape.md" ]
  run bash "$TRIAL" "" "$d"
  [ "$status" -eq 2 ]
}
