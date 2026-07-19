#!/usr/bin/env bash
#
# scaffold.sh — ensure PROJECT_STATUS.md (repo root) and HANDOFF.md (worktree
# root) exist. Idempotent: never overwrites an existing file.
#
# Both files are rendered from the toolkit's templates/ directory, which is the
# single source of truth. This script holds no copy of either document.
#
# Usage: bash scaffold.sh
set -euo pipefail

# ---------------------------------------------------------------------------
# Locating the templates
#
# This skill is normally installed as a symlinked directory
# (~/.claude/skills/project-status-scaffold -> <repo>/skills/project-status-scaffold),
# so $PWD is the user's repo, not ours. Resolve our own location instead, then
# read templates/ relative to the toolkit root two levels up.
# `readlink -f` is avoided: macOS shipped BSD readlink without it for years.
# ---------------------------------------------------------------------------
script_dir() {
  local src="${BASH_SOURCE[0]}" dir
  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  # cd -P resolves symlinked parent directories, which is the usual case here:
  # the skill *directory* is the symlink, not this file.
  cd -P "$(dirname "$src")" && pwd
}

SKILL_DIR="$(script_dir)"
TOOLKIT_HOME="$(dirname "$(dirname "$SKILL_DIR")")" # skills/<name>/ -> repo root
TEMPLATE_DIR="${VIBE_TEMPLATE_DIR:-$TOOLKIT_HOME/templates}"

# render_template FILE [TOKEN VALUE]... — print FILE with each TOKEN replaced.
# Pure bash: no sed, so a value containing slashes cannot corrupt the result.
render_template() {
  local tpl="$1"
  shift
  local content
  content="$(cat "$tpl")"
  while (($# >= 2)); do
    content="${content//$1/$2}"
    shift 2
  done
  printf '%s\n' "$content"
}

# ---------------------------------------------------------------------------
# Where the files go
# ---------------------------------------------------------------------------
git rev-parse --show-toplevel >/dev/null 2>&1 || {
  echo "scaffold: not inside a git repository." >&2
  exit 1
}

# worktree root = top of THIS working tree
worktree_root="$(git rev-parse --show-toplevel)"
# main repo root (so PROJECT_STATUS lives with the main checkout, not each worktree)
common="$(git rev-parse --git-common-dir)"
common="$(cd "$(dirname "$common")" && pwd)/$(basename "$common")"
repo_root="$(dirname "$common")"

repo="$(basename "$repo_root")"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
today="$(date '+%Y-%m-%d')"
machine="$([[ -n "${SSH_CONNECTION:-}" ]] && echo server || echo local)"

status_file="$repo_root/PROJECT_STATUS.md"
handoff_file="$worktree_root/HANDOFF.md"

# scaffold_one DST TEMPLATE LABEL [TOKEN VALUE]...
scaffold_one() {
  local dst="$1" tpl="$2" label="$3"
  shift 3
  if [[ -f "$dst" ]]; then
    echo "scaffold: $label already exists — leaving it."
    return 0
  fi
  if [[ ! -f "$tpl" ]]; then
    echo "scaffold: template missing at $tpl — cannot create $label." >&2
    return 1
  fi
  render_template "$tpl" "$@" >"$dst"
  echo "scaffold: created $dst"
}

scaffold_one "$status_file" "$TEMPLATE_DIR/PROJECT_STATUS.md" "PROJECT_STATUS.md" \
  '<repo>' "$repo" \
  '<date>' "$today" \
  '<machine>' "$machine"

scaffold_one "$handoff_file" "$TEMPLATE_DIR/HANDOFF.md" "HANDOFF.md" \
  '<repo>' "$repo" \
  '<branch>' "$branch" \
  '<worktree>' "$worktree_root" \
  '<date>' "$today" \
  '<machine>' "$machine"
