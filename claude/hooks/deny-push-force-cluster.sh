#!/usr/bin/env bash
#
# PreToolUse hook (Bash) — deny `git push` with a short-flag cluster that holds
# f (-vf, -fuv, -qf). Deny rules match whole tokens, so they miss these.
# shortcut: text match, not a shell parse; a flag hidden by quotes or $VAR passes.
#
# stdin: {"tool_input":{"command"},…}. stdout: a deny decision, else nothing. exit 0 always.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
# jq joins `\`-newline continuations, then drops quoted text, so a commit message or PR body that names the flag passes.
cmd="$(jq -r --arg q "'" '(.tool_input.command // "") | gsub("\\\\\n"; " ") | gsub("\"[^\"]*\""; "_") | gsub($q + "[^" + $q + "]*" + $q; "_")' 2>/dev/null)" || exit 0
b='[[:blank:]]'
# git [global opts] push [words] -<letters>f — words and flag stay inside one command (no ; & |).
re="(^|[^[:alnum:]_.-])git(${b}+(-[cC]|--git-dir|--work-tree)${b}+[^[:space:]]+|${b}+-[^[:space:]]+)*${b}+push(${b}+[^;&|[:space:]]+)*${b}+-[[:alnum:]]*f"
[[ "$cmd" =~ $re ]] || exit 0
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"git push with a force flag (f in a short-flag cluster) is denied. Push without it, or ask the user."}}'
exit 0
