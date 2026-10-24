#!/usr/bin/env bash
#
# seed.sh — seeds docs/hardware/<platform>.md from templates/research/; never overwrites.
#
#   bash seed.sh PLATFORM [DIR]
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
LIB_PROG=research-hardware-trial
# shellcheck disable=SC1091  # paths only exist at runtime, resolved above
. "$LIB_DIR/lib.sh"
# shellcheck disable=SC1091
. "$LIB_DIR/doc-lib.sh"

usage() {
  echo "usage: bash seed.sh PLATFORM [DIR]" >&2
  exit 2
}

platform="${1:-}"
# A name, never a path: it becomes a file name under docs/hardware/.
case "$platform" in
  "" | *[!A-Za-z0-9_-]*) usage ;;
esac
seed_doc research/HARDWARE_TRIAL.md "${2:-.}" "hardware/$platform.md" '<platform>' "$platform"
