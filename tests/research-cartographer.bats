#!/usr/bin/env bats
#
# skills/_lib/research-lib.sh's repo-kind detection, and the map.sh steps
# built on it. Everything runs in throwaway repos under $BATS_TEST_TMPDIR.
#
# The verdict rule (docs/research-skills.md §4) is what these mostly guard:
# it is the piece a later change is most likely to get subtly wrong, and a
# wrong verdict is silent — the skill maps the repo with the wrong half of
# the schema in depth and nothing reports an error.

load helper

setup() { git_env; }

MAP="$REPO_ROOT/skills/research-cartographer/map.sh"

# kind_of DIR — the verdict alone, so a test reads as the rule it checks.
kind_of() {
  bash -c '
    set -euo pipefail
    . "$1/skills/_lib/research-lib.sh"
    detect_repo_kind "$2"
  ' _ "$REPO_ROOT" "$1"
}

evidence_of() {
  bash -c '
    set -euo pipefail
    . "$1/skills/_lib/research-lib.sh"
    repo_kind_evidence "$2"
  ' _ "$REPO_ROOT" "$1"
}

# A repo with two unambiguous research signals and nothing else.
make_research_repo() {
  local d="$BATS_TEST_TMPDIR/${1:-research}"
  mkdir -p "$d"
  : >"$d/train.py"
  cat >"$d/pyproject.toml" <<'EOF'
[project]
dependencies = ["torch>=2.0", "wandb>=0.16"]
EOF
  printf '%s' "$d"
}

# A repo with two unambiguous application signals and nothing else.
make_application_repo() {
  local d="$BATS_TEST_TMPDIR/${1:-app}"
  mkdir -p "$d"
  cat >"$d/package.json" <<'EOF'
{ "dependencies": { "express": "^4.0.0" } }
EOF
  : >"$d/vercel.json"
  printf '%s' "$d"
}

@test "repo kind: two research signals and nothing else is research" {
  local d
  d="$(make_research_repo)"
  [ "$(kind_of "$d")" = research ]
}

@test "repo kind: two application signals and nothing else is application" {
  local d
  d="$(make_application_repo)"
  [ "$(kind_of "$d")" = application ]
}

@test "repo kind: one application signal does not flip a research repo" {
  # §4's central case: a research repo that also serves something is normal,
  # so a single application signal must not change the verdict. This is the
  # rule a naive "whichever side has more signals" rewrite would break while
  # still passing the two tests above.
  local d
  d="$(make_research_repo mixed)"
  cat >"$d/package.json" <<'EOF'
{ "devDependencies": { "vite": "^6.0.0" } }
EOF
  [ "$(kind_of "$d")" = research ]
  # ...and the evidence must still show that side, since a human resolving a
  # close call needs both halves on screen.
  run evidence_of "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^\[research\]'
  echo "$output" | grep -q '^\[application\]'
}

@test "repo kind: signals on both sides is ambiguous even when one side leads" {
  # The case that separates §4's rule from "whichever side has more signals":
  # three research signals against two application ones is *ambiguous*, not
  # research. Two application signals mean the repo genuinely has an
  # application half, and the answer to that is to ask rather than to let a
  # majority decide which half of the schema gets depth.
  local d
  d="$(make_research_repo leaning)"
  : >"$d/eval.py"
  cat >"$d/package.json" <<'EOF'
{ "dependencies": { "express": "^4.0.0" } }
EOF
  : >"$d/vercel.json"
  [ "$(kind_of "$d")" = ambiguous ]
}

@test "repo kind: one signal each way is ambiguous, not a coin toss" {
  local d="$BATS_TEST_TMPDIR/tied"
  mkdir -p "$d"
  : >"$d/train.py"
  : >"$d/vercel.json"
  [ "$(kind_of "$d")" = ambiguous ]
}

@test "repo kind: a repo with no signal at all is ambiguous" {
  local d="$BATS_TEST_TMPDIR/plain"
  mkdir -p "$d"
  : >"$d/README.md"
  [ "$(kind_of "$d")" = ambiguous ]
  run evidence_of "$d"
  [ "$status" -eq 0 ]
  # Never silent: a verdict with no evidence still says why.
  [ -n "$output" ]
}

@test "repo kind: a JS ML dependency is not a research signal" {
  # "@tensorflow/tfjs" in a web app's package.json is not a deep-learning
  # research stack. Frameworks are read from python dependency declarations
  # for exactly this reason, so a bare grep for the name cannot creep back in.
  local d
  d="$(make_application_repo tfjs)"
  cat >"$d/package.json" <<'EOF'
{ "dependencies": { "express": "^4.0.0", "@tensorflow/tfjs": "^4.22.0" } }
EOF
  [ "$(kind_of "$d")" = application ]
  run evidence_of "$d"
  [ "$status" -eq 0 ]
  if echo "$output" | grep -q 'deep-learning framework'; then
    echo "tfjs was read as a research signal: $output" >&2
    return 1
  fi
}

@test "repo kind: a library module named trainer.py is not a training entry point" {
  # The anchored filename match: `trainer.py` is library code, `train.py` is
  # the thing you run. A loosened regex here silently promotes every repo
  # with a trainer module.
  local d="$BATS_TEST_TMPDIR/lib"
  mkdir -p "$d/pkg"
  : >"$d/pkg/trainer.py"
  run evidence_of "$d"
  [ "$status" -eq 0 ]
  if echo "$output" | grep -q 'training entry point'; then
    echo "trainer.py was read as an entry point: $output" >&2
    return 1
  fi
}

@test "repo kind: verdict and evidence cannot disagree" {
  # Both derive from one scan. If a future change gives them separate walks,
  # this is what notices.
  local d
  d="$(make_research_repo agree)"
  [ "$(kind_of "$d")" = research ]
  run evidence_of "$d"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -c '^\[research\]')" -ge 2 ]
}

@test "repo kind: a missing directory is ambiguous, never an error" {
  # "Cannot tell" is a verdict. A non-zero exit here would abort the caller
  # under `set -e` instead of reaching the ask.
  [ "$(kind_of "$BATS_TEST_TMPDIR/does-not-exist")" = ambiguous ]
}

@test "map.sh detect: prints the verdict and its evidence" {
  local d
  d="$(make_research_repo detected)"
  run bash "$MAP" detect "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^kind: research$'
  echo "$output" | grep -q 'training entry point'
}

@test "map.sh seed: renders the map into docs/, not the repo root" {
  local d
  d="$(make_repo mapped)"
  run bash "$MAP" seed research "$d"
  [ "$status" -eq 0 ]
  [ -f "$d/docs/CODEBASE_MAP.md" ]
  [ ! -f "$d/CODEBASE_MAP.md" ]
  grep -q '^mode: research$' "$d/docs/CODEBASE_MAP.md"
  grep -q '^# Codebase Map — mapped$' "$d/docs/CODEBASE_MAP.md"
  # No unrendered placeholder: a leftover token is an unfilled contract.
  run grep -nE '<(repo|date|mode|commit)>' "$d/docs/CODEBASE_MAP.md"
  [ "$status" -ne 0 ] || {
    echo "unrendered placeholder: $output" >&2
    return 1
  }
}

@test "map.sh seed: uses an existing docs directory under another name" {
  local d
  d="$(make_repo doc-named)"
  mkdir -p "$d/doc"
  run bash "$MAP" seed research "$d"
  [ "$status" -eq 0 ]
  [ -f "$d/doc/CODEBASE_MAP.md" ]
  [ ! -d "$d/docs" ]
}

@test "map.sh seed: never overwrites an existing map" {
  # The re-run contract: a mapped repo gets a diff, not a replacement. This
  # is the guard that makes "re-runs are diffable" true rather than merely
  # documented.
  local d before
  d="$(make_repo remapped)"
  bash "$MAP" seed research "$d"
  echo "hand-written content" >>"$d/docs/CODEBASE_MAP.md"
  before="$(cat "$d/docs/CODEBASE_MAP.md")"
  run bash "$MAP" seed application "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^exists: '
  [ "$(cat "$d/docs/CODEBASE_MAP.md")" = "$before" ]
}

@test "map.sh seed: records the commit, and marks a dirty tree as dirty" {
  # The frontmatter commit is what a re-run diffs against, so attributing a
  # dirty tree to the commit it is not would send the next run to the wrong
  # baseline.
  local d
  d="$(make_repo dirty)"
  echo "uncommitted" >"$d/scratch.txt"
  run bash "$MAP" seed research "$d"
  [ "$status" -eq 0 ]
  grep -qE '^commit: [0-9a-f]+-dirty$' "$d/docs/CODEBASE_MAP.md"
}

@test "map.sh seed: refuses a mode it was not given" {
  # An ambiguous verdict is resolved by asking a human; the script must not
  # be able to answer that question by defaulting.
  local d
  d="$(make_repo nomode)"
  run bash "$MAP" seed "$d"
  [ "$status" -ne 0 ]
  [ ! -f "$d/docs/CODEBASE_MAP.md" ]
}

@test "map.sh seed: refuses to write outside a git repository" {
  local d="$BATS_TEST_TMPDIR/not-a-repo"
  mkdir -p "$d"
  run bash "$MAP" seed research "$d"
  [ "$status" -ne 0 ]
  [ ! -e "$d/docs/CODEBASE_MAP.md" ]
}
