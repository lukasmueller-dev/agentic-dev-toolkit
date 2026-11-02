#!/usr/bin/env bash
#
# PreToolUse hook (Bash) — before an unsandboxed command, remove the empty
# read-only .git/config.lock a sandboxed command leaves behind.
# Symptom without it: `could not lock config file .git/config: File exists` on
# `push -u` or `worktree add`. Same test as clear_config_lock in bin/vibe.
#
# stdin: {"cwd","tool_input":{"dangerouslyDisableSandbox"},…}. exit 0 always, silent.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)"
[[ "$(printf '%s' "$input" | jq -r '.tool_input.dangerouslyDisableSandbox // false' 2>/dev/null)" == true ]] || exit 0
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[[ -n "$cwd" && -d "$cwd" ]] || exit 0
f="$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)" || exit 0
case "$f" in /*) ;; *) f="$cwd/$f" ;; esac
f="$f/config.lock"
if [[ -f "$f" && ! -s "$f" && ! -w "$f" ]]; then rm -f "$f"; fi
exit 0
