#!/usr/bin/env bash
#
# vibe-start.sh WORKTREE NAME — `vibe start` hook: app sessions started in
# WORKTREE are named NAME-<two words> (prefix in .claude/settings.local.json).
set -euo pipefail

dir="$1" name="$2"
f="$dir/.claude/settings.local.json"
key=CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX

# The file is per machine: keep it out of git in every checkout of the repo.
common="$(git -C "$dir" rev-parse --git-common-dir)"
case "$common" in /*) ;; *) common="$dir/$common" ;; esac
mkdir -p "$common/info"
grep -qxF '.claude/settings.local.json' "$common/info/exclude" 2>/dev/null ||
  echo '.claude/settings.local.json' >>"$common/info/exclude"

mkdir -p "$dir/.claude"
if command -v jq >/dev/null 2>&1; then
  [[ -s "$f" ]] || echo '{}' >"$f"
  tmp="$f.vibe.$$"
  jq --arg k "$key" --arg v "$name" '.env[$k] = $v' "$f" >"$tmp" && mv "$tmp" "$f"
elif [[ ! -s "$f" ]]; then
  printf '{\n  "env": {\n    "%s": "%s"\n  }\n}\n' "$key" "$name" >"$f"
else
  echo "vibe: warning: no jq; session name not set in existing $f" >&2
fi
