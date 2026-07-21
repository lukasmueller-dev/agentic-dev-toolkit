#!/usr/bin/env bash
#
# PostToolUse(Write|Edit) hook — after a file inside a skill is edited, run
# skill-lint on just that one skill and feed any findings back to the agent.
#
# This runs on *every* Write/Edit in *every* repo, so the overriding rule is
# bail fast and say nothing unless the edited file is genuinely part of a skill.
# A skill file is one whose nearest ancestor holding a SKILL.md sits directly
# under a directory named 'skills' (covers both skills/<name> and
# .claude/skills/<name>).
#
# stdin: PostToolUse payload {"tool_input":{"file_path":...},"cwd":...,...}
# exit 0: nothing to say.   exit 2: findings on stderr, shown to the agent.
set -uo pipefail

# Degrade to a no-op when a dependency is missing — never break the session.
command -v jq >/dev/null 2>&1 || exit 0
command -v skill-lint >/dev/null 2>&1 || exit 0

input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$file" ] || exit 0

# Resolve a relative file_path against the payload's cwd.
case "$file" in
  /*) ;;
  *)
    cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
    [ -n "$cwd" ] && file="$cwd/$file"
    ;;
esac

# Walk up to the skill directory: a directory holding SKILL.md whose parent is
# named 'skills'. Bail the moment we can rule the path out — this is the fast
# path for the overwhelming majority of edits, which touch no skill.
dir="$(dirname "$file")"
skill=""
while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
  if [ -f "$dir/SKILL.md" ] && [ "$(basename "$(dirname "$dir")")" = "skills" ]; then
    skill="$dir"
    break
  fi
  dir="$(dirname "$dir")"
done
[ -n "$skill" ] || exit 0

# Lint that one skill. Pointed at a directory that itself holds a SKILL.md,
# skill-lint checks exactly it (and stays silent on '_'-prefixed ones).
out="$(skill-lint "$skill" 2>/dev/null)" || true
findings="$(printf '%s\n' "$out" | grep -E ': (error|warn): ' || true)"
[ -n "$findings" ] || exit 0

{
  printf 'skill-lint flagged %s:\n' "$(basename "$skill")"
  printf '%s\n' "$findings"
} >&2
exit 2
