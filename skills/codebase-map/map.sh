#!/usr/bin/env bash
#
# map.sh — seeds docs/CODEBASE_MAP.md from templates/codebase/; never overwrites.
#
#   bash map.sh seed [DIR]
set -euo pipefail

# Walks the symlink chain: the skill runs symlinked, so $PWD is the target repo.
script_dir() {
  local src="${BASH_SOURCE[0]}" dir
  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

SKILL_DIR="$(script_dir)"
LIB_DIR="$(dirname "$SKILL_DIR")/_lib"
# shellcheck disable=SC2034  # read by the lib's die message prefix
LIB_PROG=codebase-map
# vibe-lib.sh supplies die, render_template and TEMPLATE_DIR.
# shellcheck disable=SC1091  # path only exists at runtime, resolved above
. "$LIB_DIR/vibe-lib.sh"

usage() {
  echo "usage: bash map.sh seed [DIR]" >&2
  exit 2
}

# docs_dir REPO — an existing doc/ or documentation/ wins; else docs/ is created.
docs_dir() {
  local repo="$1" d
  for d in docs doc documentation; do
    if [ -d "$repo/$d" ]; then
      echo "$repo/$d"
      return 0
    fi
  done
  mkdir -p "$repo/docs"
  echo "$repo/docs"
}

[ "${1:-}" = seed ] || usage
dir="${2:-.}"
[ -d "$dir" ] || die "not a directory: $dir"

repo_root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" ||
  die "not inside a git repository: $dir"
out="$(docs_dir "$repo_root")/CODEBASE_MAP.md"
if [ -e "$out" ]; then
  echo "exists: $out"
  exit 0
fi

tpl="$TEMPLATE_DIR/codebase/CODEBASE_MAP.md"
[ -f "$tpl" ] || die "template not found: $tpl"

# A dirty tree is recorded as such: a re-run diffs against this commit.
commit="$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ -n "$(git -C "$repo_root" status --porcelain 2>/dev/null)" ]; then
  commit="$commit-dirty"
fi

render_template "$tpl" \
  '<repo>' "$(basename "$repo_root")" \
  '<date>' "$(date '+%Y-%m-%d')" \
  '<commit>' "$commit" >"$out"
echo "created: $out"
