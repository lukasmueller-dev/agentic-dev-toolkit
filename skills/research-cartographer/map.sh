#!/usr/bin/env bash
#
# map.sh — the two mechanical steps of research-cartographer: classify the
# repo, and seed the artifact the skill then fills in.
#
#   bash map.sh detect [DIR]        repo kind + the evidence behind it
#   bash map.sh seed MODE [DIR]     create docs/CODEBASE_MAP.md if absent
#
# Both are deliberately dumb. The verdict comes from the shared detection in
# _lib/research-lib.sh so that two skills in the family classify a repo the
# same way, and the document comes from templates/research/CODEBASE_MAP.md so
# there is one copy of the schema. Nothing here decides anything the SKILL.md
# should be deciding: `seed` takes MODE as an argument rather than calling
# `detect` itself, because an ambiguous verdict is resolved by asking the
# human, and a script cannot ask.
#
# `seed` never overwrites. A repo that already has a map gets `exists:` and an
# untouched file — re-running produces a diff against the existing map, not a
# replacement.
set -euo pipefail

# ---------------------------------------------------------------------------
# Locating ourselves
#
# The skill is normally reached through a symlinked directory, so $PWD is the
# *target* repo, not ours. Resolve our own location and source the libs beside
# us. script_dir has to stay here: it is what finds them. `readlink -f` is
# avoided — macOS shipped BSD readlink without it for years.
# ---------------------------------------------------------------------------
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
# shellcheck disable=SC2034  # read by the lib's die/info message prefix
LIB_PROG=cartographer
# shellcheck disable=SC1091  # path only exists at runtime, resolved above
. "$LIB_DIR/research-lib.sh"
# vibe-lib.sh is sourced for render_template and TEMPLATE_DIR only — the
# placeholder contract in templates/README.md has one implementation.
# shellcheck disable=SC1091
. "$LIB_DIR/vibe-lib.sh"

usage() {
  echo "usage: bash map.sh detect [DIR]" >&2
  echo "       bash map.sh seed research|application [DIR]" >&2
  exit 2
}

# docs_dir REPO — the repo's documentation directory, created if it has none.
# An existing directory under another name is used as-is: §3 puts the artifact
# in the repo's docs directory, never its root, and never invents a second one.
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

cmd="${1:-}"
[ -n "$cmd" ] || usage

case "$cmd" in
  detect)
    dir="${2:-.}"
    [ -d "$dir" ] || die "not a directory: $dir"
    echo "kind: $(detect_repo_kind "$dir")"
    repo_kind_evidence "$dir"
    ;;

  seed)
    mode="${2:-}"
    case "$mode" in
      research | application) ;;
      *) usage ;;
    esac
    dir="${3:-.}"
    [ -d "$dir" ] || die "not a directory: $dir"

    repo_root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" ||
      die "not inside a git repository: $dir"
    out="$(docs_dir "$repo_root")/CODEBASE_MAP.md"
    if [ -e "$out" ]; then
      echo "exists: $out"
      exit 0
    fi

    tpl="$TEMPLATE_DIR/research/CODEBASE_MAP.md"
    [ -f "$tpl" ] || die "template not found: $tpl"

    # The commit the map describes, so a later re-run knows what it is
    # diffing against. A dirty tree is recorded as such rather than silently
    # attributed to the commit it is not.
    commit="$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    if [ -n "$(git -C "$repo_root" status --porcelain 2>/dev/null)" ]; then
      commit="$commit-dirty"
    fi

    render_template "$tpl" \
      '<repo>' "$(basename "$repo_root")" \
      '<date>' "$(date '+%Y-%m-%d')" \
      '<mode>' "$mode" \
      '<commit>' "$commit" >"$out"
    echo "created: $out"
    ;;

  *) usage ;;
esac
