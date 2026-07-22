#!/usr/bin/env bash
#
# SessionStart hook — inject HANDOFF.md as session context so a freshly
# started agent does not need "read HANDOFF.md" as its first prompt.
#
# Only fires on sources where the session's own context starts empty:
# `startup` (a new session, e.g. `vibe start` launching the agent in a task
# worktree) and `clear` (`/clear` resets to zero). `resume`, `compact`, and
# `fork` all carry forward prior conversation history that already reflects
# the handoff's content, so re-injecting there would duplicate context
# rather than fill a gap.
#
# stdin: {"session_id","cwd","hook_event_name","source","transcript_path","model"}
# Output: {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":...}}
# on stdout when injecting. exit 0 always — SessionStart cannot block, and a
# missing dependency degrades to silent no-op like every hook in this dir.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
src="$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null)"
case "$src" in
  startup | clear) ;;
  *) exit 0 ;;
esac

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[[ -n "$cwd" && -d "$cwd" ]] || exit 0

git -C "$cwd" rev-parse --show-toplevel >/dev/null 2>&1 || exit 0
root="$(git -C "$cwd" rev-parse --show-toplevel)"

handoff="$root/HANDOFF.md"
[[ -f "$handoff" ]] || exit 0

# Same line filter as VIBE_HANDOFF_SCAFFOLD_RE in bin/vibe, which
# handoff_carries_content() and the 'vibe done' guard both apply — a third
# literal copy lives in skills/_lib/vibe-lib.sh; update all three together.
# Lockstep is by comment, not by sourcing: this hook runs on machines that may
# not have bin/vibe on PATH, and hooks must not depend on other repo scripts.
grep -qvE '^[[:space:]]*$|^#|^>|^- \*\*|^_.*_[[:space:]]*$' "$handoff" || exit 0

content="$(cat "$handoff")"
jq -n --arg ctx "$content" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
