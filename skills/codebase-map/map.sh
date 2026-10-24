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
# shellcheck disable=SC1091  # paths only exist at runtime, resolved above
. "$LIB_DIR/lib.sh"
# shellcheck disable=SC1091
. "$LIB_DIR/doc-lib.sh"

usage() {
  echo "usage: bash map.sh seed [DIR]" >&2
  exit 2
}

[ "${1:-}" = seed ] || usage
seed_doc codebase/CODEBASE_MAP.md "${2:-.}" CODEBASE_MAP.md
