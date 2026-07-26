#!/usr/bin/env bash
#
# inject-global-memory.sh — the plugin's stand-in for ~/.claude/CLAUDE.md.
#
# Why this exists: a plugin cannot install global memory. Claude Code reads its
# global instructions from ~/.claude/CLAUDE.md, a path no plugin populates, and
# a CLAUDE.md at the plugin root is explicitly NOT loaded as context. The
# documented way to ship instructions is a skill — but a skill is loaded on
# demand, and memory/GLOBAL.md is standing instruction: it has to be in context
# before the agent decides anything, or it cannot influence that decision.
#
# So the plugin injects it the same way ../hooks/session-start-handoff.sh
# injects HANDOFF.md — as SessionStart additionalContext. Same mechanism, same
# source filter, one tier up in lifetime.
#
# NOT wired in the symlink install: there ~/.claude/CLAUDE.md exists and imports
# ~/.claude/global-memory.md, so injecting would duplicate it. ../settings.json
# does not reference this file. See README.md.
#
# Only fires on `startup` and `clear`, the two sources whose context starts
# empty. `resume`, `compact` and `fork` carry history forward, and re-injecting
# 5KB of standing instruction on every compaction is exactly the runaway this
# filter prevents.
#
# stdin: {"session_id","cwd","hook_event_name","source",...}
# Output: {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":...}}
# exit 0 always — SessionStart cannot block, and a missing dependency degrades
# to a silent no-op like every hook in this directory.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

src="$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null)" || exit 0
case "$src" in
  startup | clear) ;;
  *) exit 0 ;;
esac

# Resolve through the symlink chain rather than trusting $0: this file is
# reached as a plugin path in one install mode and through ~/.claude/hooks
# (itself a symlink into the repo) in the other.
script_dir() {
  local s="${BASH_SOURCE[0]}" dir
  while [[ -L "$s" ]]; do
    dir="$(cd -P "$(dirname "$s")" && pwd)"
    s="$(readlink "$s")"
    [[ "$s" == /* ]] || s="$dir/$s"
  done
  cd -P "$(dirname "$s")" && pwd
}

memory="$(script_dir)/../../memory/GLOBAL.md"
[[ -f "$memory" ]] || exit 0

content="$(cat "$memory" 2>/dev/null || true)"
[[ -n "$content" ]] || exit 0

jq -n --arg ctx "$content" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
