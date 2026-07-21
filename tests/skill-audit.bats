#!/usr/bin/env bats
#
# skills/skill-audit/scripts/criteria-path.sh — the whole point of this script
# is to find docs/skill-quality.md after the skill has been reached through a
# symlinked ~/.claude/skills directory. So the tests build a fake toolkit
# checkout and a fake HOME under $BATS_TEST_TMPDIR and resolve through it.

load helper

setup() {
  SRC="$REPO_ROOT/skills/skill-audit/scripts/criteria-path.sh"
  # A self-contained fake checkout: docs/ plus the skill holding a copy of the
  # real script, so resolution walks up to *this* root, not the real repo's.
  TK="$BATS_TEST_TMPDIR/toolkit"
  mkdir -p "$TK/docs" "$TK/skills/skill-audit/scripts"
  # criteria-path.sh resolves through cd -P, so it returns the physical path.
  # $BATS_TEST_TMPDIR itself sits under a symlink on macOS (/var ->
  # /private/var), so TK must be resolved the same way or every comparison
  # below mismatches on that platform only.
  TK="$(cd "$TK" && pwd -P)"
  printf '# criteria\n' >"$TK/docs/skill-quality.md"
  cp "$SRC" "$TK/skills/skill-audit/scripts/criteria-path.sh"
}

@test "resolves the doc when run directly" {
  run bash "$TK/skills/skill-audit/scripts/criteria-path.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "$TK/docs/skill-quality.md" ]
}

@test "resolves the doc through a symlinked skills directory" {
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home/.claude/skills"
  ln -s "$TK/skills/skill-audit" "$home/.claude/skills/skill-audit"

  # Reached the way Claude Code reaches it: through the symlinked skill dir.
  run bash "$home/.claude/skills/skill-audit/scripts/criteria-path.sh"
  [ "$status" -eq 0 ]
  # Still the real doc in the checkout, not a path under the fake HOME.
  [ "$output" = "$TK/docs/skill-quality.md" ]
}

@test "resolves through a relative symlink too" {
  # A relative symlink target exercises the BASH_SOURCE reassembly branch.
  local links="$BATS_TEST_TMPDIR/links"
  mkdir -p "$links"
  ln -s ../toolkit/skills/skill-audit "$links/skill-audit"
  run bash "$links/skill-audit/scripts/criteria-path.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "$TK/docs/skill-quality.md" ]
}

@test "errors when the criteria doc is missing" {
  rm -f "$TK/docs/skill-quality.md"
  run bash "$TK/skills/skill-audit/scripts/criteria-path.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot find docs/skill-quality.md"* ]]
}
