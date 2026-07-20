#!/usr/bin/env bash
#
# criteria-path.sh — print the absolute path to docs/skill-quality.md.
#
# The criteria doc is not bundled with this skill; it has one home in the
# toolkit checkout. This skill is normally reached through a symlinked
# directory (~/.claude/skills/skill-audit -> <repo>/skills/skill-audit), so
# $PWD is the *user's* repo, not ours. Resolve this script's own location
# through the symlink chain, then walk up to the toolkit root and name the doc.
#
# `readlink -f` is avoided: macOS shipped BSD readlink without it for years.
set -euo pipefail

# script_dir — the real directory holding this script, symlinks resolved.
# The symlink is usually the skill *directory*, not this file, so `cd -P`
# (which resolves symlinked parents) does the real work. Copied from bin/vibe.
script_dir() {
  local src="${BASH_SOURCE[0]}" dir
  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

SCRIPT_DIR="$(script_dir)"
# scripts/ -> skill-audit/ -> skills/ -> toolkit root
TOOLKIT_HOME="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
CRITERIA="$TOOLKIT_HOME/docs/skill-quality.md"

if [[ ! -f "$CRITERIA" ]]; then
  echo "criteria-path: cannot find docs/skill-quality.md (looked in $TOOLKIT_HOME)" >&2
  exit 1
fi

printf '%s\n' "$CRITERIA"
