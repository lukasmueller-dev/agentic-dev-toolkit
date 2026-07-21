#!/usr/bin/env bats
#
# bin/skill-lint — the mechanical skill checks. Every fixture is built under
# $BATS_TEST_TMPDIR, so nothing here touches a real skills directory.

load helper

setup() {
  LINT="$REPO_ROOT/bin/skill-lint"
  SKILLS="$BATS_TEST_TMPDIR/skills"
  mkdir -p "$SKILLS"
}

# writeskill <name> <name-field> <description-field> — a skill with valid
# frontmatter shape and the given name/description values.
writeskill() {
  local d="$SKILLS/$1"
  mkdir -p "$d"
  {
    printf -- '---\n'
    printf 'name: %s\n' "$2"
    printf 'description: %s\n' "$3"
    printf -- '---\n\n# body\n'
  } >"$d/SKILL.md"
}

GOOD_DESC="Analyzes the thing and reports findings; use it when the user asks to check the thing."

# min_path <dir> <tool>... — a PATH holding only the named tools, symlinked in.
# Used to prove the degrade paths when shellcheck or shfmt is absent.
min_path() {
  local out="$1"
  shift
  mkdir -p "$out"
  local t p
  for t in "$@"; do
    p="$(command -v "$t")" || continue
    ln -sf "$p" "$out/$t"
  done
  printf '%s' "$out"
}

# ---------------------------------------------------------------------------
# The happy path
# ---------------------------------------------------------------------------
@test "clean skill passes with no findings" {
  writeskill good good "$GOOD_DESC"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 error(s), 0 warning(s)"* ]]
}

# ---------------------------------------------------------------------------
# Frontmatter structure
# ---------------------------------------------------------------------------
@test "missing frontmatter is an error" {
  mkdir -p "$SKILLS/nofm"
  printf '# just a heading\n' >"$SKILLS/nofm/SKILL.md"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must start with YAML frontmatter"* ]]
}

@test "unclosed frontmatter is an error" {
  mkdir -p "$SKILLS/open"
  printf -- '---\nname: open\ndescription: %s\n' "$GOOD_DESC" >"$SKILLS/open/SKILL.md"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not closed by a second"* ]]
}

# A large body after the closing '---' used to false-positive as unclosed:
# `sed ... | grep -qx -- '---'` lets grep exit the moment it matches, and on
# a big enough file sed is still writing when that happens - SIGPIPE kills
# sed, and `set -o pipefail` turns that into the pipeline's exit status
# instead of grep's success.
@test "a large body after the closing --- is not a false-positive unclosed error" {
  local d="$SKILLS/big"
  mkdir -p "$d"
  {
    printf -- '---\n'
    printf 'name: big\n'
    printf 'description: %s\n' "$GOOD_DESC"
    printf -- '---\n\n'
    for _ in $(seq 1 20000); do
      printf 'padding line to force a large write through the frontmatter check\n'
    done
  } >"$d/SKILL.md"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" != *"not closed by a second"* ]]
}

# ---------------------------------------------------------------------------
# name field
# ---------------------------------------------------------------------------
@test "missing name is an error" {
  local d="$SKILLS/noname"
  mkdir -p "$d"
  printf -- '---\ndescription: %s\n---\n' "$GOOD_DESC" >"$d/SKILL.md"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'name:'"* ]]
}

@test "name not matching the directory is an error" {
  writeskill mydir otherName "$GOOD_DESC"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not match directory"* ]]
}

@test "uppercase name is an error" {
  # The directory carries the same bad value so only the charset rule fires.
  writeskill BadName BadName "$GOOD_DESC"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"lowercase letters, digits and single hyphens"* ]]
}

@test "name containing claude is an error" {
  writeskill claude-helper claude-helper "$GOOD_DESC"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must not contain 'claude' or 'anthropic'"* ]]
}

@test "name over 64 characters is an error" {
  local n="aaaaaaaaaa-aaaaaaaaaa-aaaaaaaaaa-aaaaaaaaaa-aaaaaaaaaa-aaaaaaaaaa-aa"
  writeskill "$n" "$n" "$GOOD_DESC"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"exceeds 64 characters"* ]]
}

# ---------------------------------------------------------------------------
# description field
# ---------------------------------------------------------------------------
@test "missing description is an error" {
  local d="$SKILLS/nodesc"
  mkdir -p "$d"
  printf -- '---\nname: nodesc\n---\n' >"$d/SKILL.md"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'description:'"* ]]
}

@test "over-long description is an error" {
  local long
  long="$(printf 'x%.0s' $(seq 1 1100))"
  writeskill big big "$long"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"over the 1024 limit"* ]]
}

@test "first-person description is a warning, not an error" {
  writeskill me me "You should use this whenever you want to analyze the thing in great detail."
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warn: "* ]]
  [[ "$output" == *"first-person"* ]]
}

@test "short description is a warning" {
  writeskill tiny tiny "Does a thing."
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"too thin to trigger"* ]]
}

@test "--strict promotes a warning to an error" {
  writeskill tiny tiny "Does a thing."
  run "$LINT" --strict "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"error: "* ]]
}

# ---------------------------------------------------------------------------
# Bundled scripts
# ---------------------------------------------------------------------------
@test "a bundled script that fails shellcheck is an error" {
  writeskill s s "$GOOD_DESC"
  mkdir -p "$SKILLS/s/scripts"
  # SC2154: $undefined is referenced but never assigned. Formatting is fine, so
  # only the shellcheck rule fires. The literal $ must reach the fixture file.
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\necho "$undefined_variable_here"\n' \
    >"$SKILLS/s/scripts/run.sh"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fails shellcheck"* ]]
}

@test "a badly formatted bundled script is an error" {
  writeskill s s "$GOOD_DESC"
  mkdir -p "$SKILLS/s/scripts"
  # Passes shellcheck but not shfmt -i 2: the body is unindented.
  printf '#!/usr/bin/env bash\nif true; then\necho hi\nfi\n' \
    >"$SKILLS/s/scripts/run.sh"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not formatted with shfmt"* ]]
}

# ---------------------------------------------------------------------------
# Skipping and discovery
# ---------------------------------------------------------------------------
@test "underscore-prefixed directories are skipped" {
  # A broken skill under _template must not be reported.
  mkdir -p "$SKILLS/_template"
  printf 'no frontmatter here\n' >"$SKILLS/_template/SKILL.md"
  writeskill good good "$GOOD_DESC"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked 1 skill(s)"* ]]
}

@test "directories without a SKILL.md are ignored" {
  mkdir -p "$SKILLS/notaskill"
  printf 'hello\n' >"$SKILLS/notaskill/README.md"
  writeskill good good "$GOOD_DESC"
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked 1 skill(s)"* ]]
}

@test "no argument discovers ./.claude/skills" {
  mkdir -p "$BATS_TEST_TMPDIR/proj/.claude/skills/good"
  {
    printf -- '---\nname: good\ndescription: %s\n---\n' "$GOOD_DESC"
  } >"$BATS_TEST_TMPDIR/proj/.claude/skills/good/SKILL.md"
  cd "$BATS_TEST_TMPDIR/proj"
  run "$LINT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked 1 skill(s)"* ]]
}

@test "no argument falls back to ./skills" {
  writeskill good good "$GOOD_DESC"
  cd "$BATS_TEST_TMPDIR"
  run "$LINT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked 1 skill(s)"* ]]
}

@test "no argument and no skills directory is a usage error" {
  cd "$BATS_TEST_TMPDIR"
  rm -rf "$SKILLS"
  run "$LINT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage:"* ]]
}

# ---------------------------------------------------------------------------
# Degrade paths — the linter must stay useful without its optional tools.
# ---------------------------------------------------------------------------
@test "missing shellcheck skips correctness checks with a note" {
  writeskill s s "$GOOD_DESC"
  mkdir -p "$SKILLS/s/scripts"
  # Would fail shellcheck, but shellcheck is absent from PATH here.
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\necho "$undefined_variable_here"\n' \
    >"$SKILLS/s/scripts/run.sh"
  local p
  p="$(min_path "$BATS_TEST_TMPDIR/pathA" bash env sed grep head basename dirname shfmt)"
  run env PATH="$p" "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"shellcheck not found"* ]]
}

@test "missing shfmt skips the bundled-script checks entirely" {
  writeskill s s "$GOOD_DESC"
  mkdir -p "$SKILLS/s/scripts"
  printf '#!/usr/bin/env bash\nif true; then\necho hi\nfi\n' \
    >"$SKILLS/s/scripts/run.sh"
  local p
  p="$(min_path "$BATS_TEST_TMPDIR/pathB" bash env sed grep head basename dirname)"
  run env PATH="$p" "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"shfmt not found"* ]]
}

@test "a nonexistent skills directory is an error" {
  run "$LINT" "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no such directory"* ]]
}

# ---------------------------------------------------------------------------
# Single-skill targeting — a directory that is itself a skill (used by the hook)
# ---------------------------------------------------------------------------
@test "a single skill directory lints just that skill" {
  writeskill one one "$GOOD_DESC"
  writeskill two two "You should use this when you want to do the second thing in full."
  run "$LINT" "$SKILLS/one"
  [ "$status" -eq 0 ]
  # Only 'one' was checked; 'two' (which has a warning) was not.
  [[ "$output" == *"checked 1 skill(s)"* ]]
  [[ "$output" != *"first-person"* ]]
}

@test "a single skill directory reports its own findings" {
  writeskill bad Wrong "$GOOD_DESC"
  run "$LINT" "$SKILLS/bad"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not match directory"* ]]
}

@test "pointing at an underscore skill directory checks nothing" {
  mkdir -p "$SKILLS/_template"
  printf 'broken\n' >"$SKILLS/_template/SKILL.md"
  run "$LINT" "$SKILLS/_template"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked 0 skill(s)"* ]]
}

# ---------------------------------------------------------------------------
# Per-repo extension: .skill-lint.conf
#
# The default $SKILLS lives at $BATS_TEST_TMPDIR/skills, which is not a git
# repo, so find_config's ceiling is its parent — a .skill-lint.conf written to
# $BATS_TEST_TMPDIR is discovered by walking up one level.
# ---------------------------------------------------------------------------
writeconf() { printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/.skill-lint.conf"; }

@test "forbid-pattern flags a match in the body" {
  writeskill good good "$GOOD_DESC"
  printf 'TODO: finish this\n' >>"$SKILLS/good/SKILL.md"
  writeconf 'forbid-pattern TODO body still has a TODO marker'
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"body still has a TODO marker (.skill-lint.conf)"* ]]
}

@test "forbid-pattern ignores a match that is only in the frontmatter" {
  writeskill fm fm "Analyzes TODO items and reports them; use it when the user asks to review the todo list."
  writeconf 'forbid-pattern TODO body still has a TODO marker'
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
}

@test "require-field flags a missing frontmatter key" {
  writeskill good good "$GOOD_DESC"
  writeconf 'require-field allowed-tools'
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required field 'allowed-tools' (.skill-lint.conf)"* ]]
}

@test "require-field passes when the key is present" {
  local d="$SKILLS/withtools"
  mkdir -p "$d"
  printf -- '---\nname: withtools\ndescription: %s\nallowed-tools: Read\n---\n' "$GOOD_DESC" >"$d/SKILL.md"
  writeconf 'require-field allowed-tools'
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
}

@test "ignore-warn silences a warning for the named skill" {
  writeskill tiny tiny "Does a thing."
  writeconf 'ignore-warn tiny SQ7'
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" != *"too thin to trigger"* ]]
}

@test "ignore-warn is scoped to the one skill it names" {
  writeskill tiny tiny "Does a thing."
  writeskill teeny teeny "Short one here."
  writeconf 'ignore-warn tiny SQ7'
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$SKILLS/teeny/SKILL.md: warn"* ]]
  [[ "$output" != *"$SKILLS/tiny/SKILL.md: warn"* ]]
}

@test "ignore-warn cannot silence an error" {
  writeskill mydir wrongname "$GOOD_DESC"
  writeconf 'ignore-warn mydir SQ3'
  run "$LINT" "$SKILLS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[SQ3]"* ]]
}

@test "a silenced warning does not resurface under --strict" {
  writeskill tiny tiny "Does a thing."
  writeconf 'ignore-warn tiny SQ7'
  run "$LINT" --strict "$SKILLS"
  [ "$status" -eq 0 ]
}

@test "an unknown directive is noted but not fatal" {
  writeskill good good "$GOOD_DESC"
  writeconf 'bogus-directive whatever'
  run "$LINT" "$SKILLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unknown directive 'bogus-directive'"* ]]
}

@test "the config is found by walking up to the git root" {
  local proj="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$proj/skills/good"
  git init -q "$proj"
  printf -- '---\nname: good\ndescription: %s\n---\n\n# body\nTODO here\n' "$GOOD_DESC" \
    >"$proj/skills/good/SKILL.md"
  printf 'forbid-pattern TODO no TODO markers allowed\n' >"$proj/.skill-lint.conf"
  run "$LINT" "$proj/skills"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no TODO markers allowed (.skill-lint.conf)"* ]]
}
