#!/usr/bin/env bash
#
# seed.sh — seeds docs/EXPERIMENT_SETUP.md from templates/research/; never overwrites.
#
#   bash seed.sh [DIR]
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
LIB_PROG=research-experiment-setup
# shellcheck disable=SC1091  # paths only exist at runtime, resolved above
. "$LIB_DIR/vibe-lib.sh"
# shellcheck disable=SC1091
. "$LIB_DIR/doc-lib.sh"

seed_doc research/EXPERIMENT_SETUP.md "${1:-.}" EXPERIMENT_SETUP.md
