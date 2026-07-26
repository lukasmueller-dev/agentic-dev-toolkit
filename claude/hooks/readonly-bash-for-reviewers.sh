#!/usr/bin/env bash
#
# readonly-bash-for-reviewers.sh — the plugin's stand-in for the frontmatter
# `hooks:` block on diff-reviewer, docs-drift and security-sweep.
#
# Why this exists: Claude Code refuses `hooks:` in the frontmatter of a
# PLUGIN-shipped agent, for security reasons — a plugin could otherwise install
# a hook by shipping an agent nobody invokes. That refusal is correct and it
# also silently drops the guard those three agents depend on: `tools:` takes
# bare tool names, so `Bash` means all of Bash, and readonly-bash.sh is the
# only layer that sees the command's arguments. Shipped through the plugin
# without this, the reviewers would be read-only by instruction alone.
#
# So the plugin wires ONE session-level PreToolUse(Bash) hook, which fires for
# every Bash call in the session, and this script narrows it back down to the
# three agents the frontmatter used to name. Session-level hooks fire inside
# subagents too, and the payload carries `agent_type` (present only when the
# hook fires inside a subagent, or the session was started with --agent), which
# is what makes the narrowing possible.
#
# NOT wired in the symlink install: there the frontmatter hooks work, and
# ../settings.json does not reference this file. See README.md.
#
# stdin: PreToolUse payload {"tool_name","tool_input","agent_type",...}
# exit 0: allowed, or not our business.  exit 2: blocked, reason on stderr.
#
# Fail-open like every hook here (README.md rule 1): a missing jq, malformed
# stdin, or an absent agent_type all exit 0 rather than break the session.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

agent="$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)" || exit 0
[[ -n "$agent" ]] || exit 0

# Plugin agents are addressed by a scoped name (`agentic-dev-toolkit:docs-drift`),
# and the same definitions installed by symlink are addressed bare. Match the
# suffix so one script covers both, and anchor on ':' so a foreign agent called
# `their-docs-drift` does not inherit our guard.
case "$agent" in
  diff-reviewer | docs-drift | security-sweep) ;;
  *:diff-reviewer | *:docs-drift | *:security-sweep) ;;
  *) exit 0 ;;
esac

# Resolve through the symlink chain rather than trusting $0: this file is
# reached as a plugin path in one install mode and through ~/.claude/hooks
# (itself a symlink into the repo) in the other.
script_dir() {
  local src="${BASH_SOURCE[0]}" dir
  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" == /* ]] || src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

guard="$(script_dir)/readonly-bash.sh"
[[ -f "$guard" ]] || exit 0

# Hand the untouched payload to the real guard and adopt its verdict, so the
# policy — and the message a denial prints — lives in exactly one file.
printf '%s' "$input" | bash "$guard"
