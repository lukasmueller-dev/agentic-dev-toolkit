#!/usr/bin/env bash
#
# env.sh — the two mechanical steps of research-first-run: report the
# execution context, and seed the runbook the skill then fills in.
#
#   bash env.sh detect              execution context + the evidence behind it
#   bash env.sh seed [DIR]          create docs/RUNBOOK.md if absent
#
# Deliberately dumb, and deliberately incapable of running anything: the
# verdict comes from the shared detection in _lib/research-lib.sh so that two
# skills in the family classify a machine the same way, and the document comes
# from templates/research/RUNBOOK.md so there is one copy of it. `detect`
# prints and exits — resolving an ambiguous verdict means asking a human, and
# a script cannot ask.
#
# `seed` never overwrites. The runbook is appended to over a repo's whole
# life, so regenerating it would destroy exactly the knowledge it exists to
# keep.
set -euo pipefail

# ---------------------------------------------------------------------------
# Locating ourselves
#
# The skill is normally reached through a symlinked directory, so $PWD is the
# *target* repo, not ours. script_dir has to stay here: it is what finds the
# libs. `readlink -f` is avoided — macOS shipped BSD readlink without it for
# years.
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
LIB_PROG=first-run
# shellcheck disable=SC1091  # path only exists at runtime, resolved above
. "$LIB_DIR/research-lib.sh"
# vibe-lib.sh is sourced for render_template and TEMPLATE_DIR only — the
# placeholder contract in templates/README.md has one implementation.
# shellcheck disable=SC1091
. "$LIB_DIR/vibe-lib.sh"

usage() {
  echo "usage: bash env.sh detect" >&2
  echo "       bash env.sh seed [DIR]" >&2
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
    echo "context: $(detect_exec_context)"
    exec_context_evidence
    ;;

  seed)
    dir="${2:-.}"
    [ -d "$dir" ] || die "not a directory: $dir"
    repo_root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" ||
      die "not inside a git repository: $dir"
    out="$(docs_dir "$repo_root")/RUNBOOK.md"
    if [ -e "$out" ]; then
      echo "exists: $out"
      exit 0
    fi
    tpl="$TEMPLATE_DIR/research/RUNBOOK.md"
    [ -f "$tpl" ] || die "template not found: $tpl"
    render_template "$tpl" \
      '<repo>' "$(basename "$repo_root")" \
      '<date>' "$(date '+%Y-%m-%d')" >"$out"
    echo "created: $out"
    ;;

  *) usage ;;
esac
