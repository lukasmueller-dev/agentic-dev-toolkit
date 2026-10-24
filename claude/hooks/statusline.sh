#!/usr/bin/env bash
#
# statusLine command — renders:  repo · branch
#
# Not a hook event, despite living in hooks/: Claude Code invokes it through
# the "statusLine" setting rather than the "hooks" block. It sits here because
# it is the same kind of thing — an executable this toolkit installs for Claude
# Code to call — and one symlinked directory is simpler than two.
#
# stdin: the statusLine JSON payload. Most fields are optional, so every read
# has a fallback; a status line that errors out is worse than one missing a
# segment.
set -uo pipefail

input="$(cat 2>/dev/null || true)"

cwd=""
if command -v jq >/dev/null 2>&1; then
  cwd="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)"
fi
[[ -n "$cwd" ]] || cwd="$PWD"

# --- repo -------------------------------------------------------------------
# The main repo root, so every worktree of a repo reports the same repo name
# rather than the task name.
# Uses parameter expansion rather than basename/dirname: this script runs on
# every status line render, so each subprocess avoided is worth it.
repo=""
if git -C "$cwd" rev-parse --git-common-dir >/dev/null 2>&1; then
  common="$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)"
  case "$common" in
    /*) ;;
    *) common="$cwd/$common" ;;
  esac
  parent="${common%/*}" # dirname
  repo="${parent##*/}"  # basename
fi
[[ -n "$repo" ]] || repo="${cwd##*/}"

# --- branch -----------------------------------------------------------------
branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
[[ "$branch" == "HEAD" ]] && branch="detached"

# --- render -----------------------------------------------------------------
c_dim=$'\033[2m'
c_off=$'\033[0m'
c_cyn=$'\033[36m'
c_grn=$'\033[32m'

out="${c_cyn}${repo}${c_off}"
[[ -n "$branch" ]] && out="$out ${c_dim}·${c_off} ${c_grn}${branch}${c_off}"

printf '%s' "$out"
