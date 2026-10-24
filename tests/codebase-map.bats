#!/usr/bin/env bats
#
# skills/codebase-map/map.sh seed. Everything runs in throwaway repos under $BATS_TEST_TMPDIR.

load helper

setup() { git_env; }

MAP="$REPO_ROOT/skills/codebase-map/map.sh"

@test "map.sh seed: renders the map into docs/, not the repo root" {
  local d
  d="$(make_repo mapped)"
  run bash "$MAP" seed "$d"
  [ "$status" -eq 0 ]
  [ -f "$d/docs/CODEBASE_MAP.md" ]
  [ ! -f "$d/CODEBASE_MAP.md" ]
  grep -q '^# Codebase Map — mapped$' "$d/docs/CODEBASE_MAP.md"
  # No unrendered placeholder: a leftover token is an unfilled contract.
  run grep -nE '<(repo|date|commit)>' "$d/docs/CODEBASE_MAP.md"
  [ "$status" -ne 0 ] || {
    echo "unrendered placeholder: $output" >&2
    return 1
  }
}

@test "map.sh seed: uses an existing docs directory under another name" {
  local d
  d="$(make_repo doc-named)"
  mkdir -p "$d/doc"
  run bash "$MAP" seed "$d"
  [ "$status" -eq 0 ]
  [ -f "$d/doc/CODEBASE_MAP.md" ]
  [ ! -d "$d/docs" ]
}

@test "map.sh seed: never overwrites an existing map" {
  # The re-run contract: a mapped repo gets a diff, not a replacement.
  local d before
  d="$(make_repo remapped)"
  bash "$MAP" seed "$d"
  echo "hand-written content" >>"$d/docs/CODEBASE_MAP.md"
  before="$(cat "$d/docs/CODEBASE_MAP.md")"
  run bash "$MAP" seed "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^exists: '
  [ "$(cat "$d/docs/CODEBASE_MAP.md")" = "$before" ]
}

@test "map.sh seed: records the commit, and marks a dirty tree as dirty" {
  # The frontmatter commit is what a re-run diffs against.
  local d
  d="$(make_repo dirty)"
  echo "uncommitted" >"$d/scratch.txt"
  run bash "$MAP" seed "$d"
  [ "$status" -eq 0 ]
  grep -qE '^commit: [0-9a-f]+-dirty$' "$d/docs/CODEBASE_MAP.md"
}

@test "map.sh: refuses an unknown subcommand" {
  local d
  d="$(make_repo nocmd)"
  run bash "$MAP" detect "$d"
  [ "$status" -eq 2 ]
  [ ! -f "$d/docs/CODEBASE_MAP.md" ]
}

@test "map.sh seed: refuses to write outside a git repository" {
  local d="$BATS_TEST_TMPDIR/not-a-repo"
  mkdir -p "$d"
  run bash "$MAP" seed "$d"
  [ "$status" -ne 0 ]
  [ ! -e "$d/docs/CODEBASE_MAP.md" ]
}
