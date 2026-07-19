#!/usr/bin/env bash
#
# scaffold.sh — ensure PROJECT_STATUS.md (repo root) and HANDOFF.md (worktree
# root) exist. Idempotent: never overwrites an existing file.
#
# Usage: bash scaffold.sh
set -euo pipefail

git rev-parse --show-toplevel >/dev/null 2>&1 || {
  echo "scaffold: not inside a git repository." >&2; exit 1; }

# worktree root = top of THIS working tree
worktree_root="$(git rev-parse --show-toplevel)"
# main repo root (so PROJECT_STATUS lives with the main checkout, not each worktree)
common="$(git rev-parse --git-common-dir)"
common="$(cd "$(dirname "$common")" && pwd)/$(basename "$common")"
repo_root="$(dirname "$common")"

repo="$(basename "$repo_root")"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
today="$(date '+%Y-%m-%d')"
machine="$( [[ -n "${SSH_CONNECTION:-}" ]] && echo server || echo local )"

status_file="$repo_root/PROJECT_STATUS.md"
handoff_file="$worktree_root/HANDOFF.md"

if [[ -f "$status_file" ]]; then
  echo "scaffold: PROJECT_STATUS.md already exists — leaving it."
else
  cat > "$status_file" <<EOF
# Project Status — $repo

_Last updated: $today · ${machine}_

## Goal
_What is this project trying to achieve? One or two sentences._

## Architecture
_Key components and how they fit together. Update when structure changes._

## Key decisions
_Dated, one line each. Why we chose X over Y._
- $today: (initial scaffold)

## TODOs
- [ ] ...

## Open questions
_Unresolved things that block or shape the work._
- ...
EOF
  echo "scaffold: created $status_file"
fi

if [[ -f "$handoff_file" ]]; then
  echo "scaffold: HANDOFF.md already exists — leaving it."
else
  cat > "$handoff_file" <<EOF
# Handoff — $repo / $branch

_Last updated: $today · ${machine}_

## Current status
_What state is the work in right now?_

## Next steps
_What should the next session (on either machine) do first?_

## Open PRs / branches
_Links or numbers. \`vibe status\` refreshes this._

## Notes / gotchas
_Anything that would bite the other machine._
EOF
  echo "scaffold: created $handoff_file"
fi
