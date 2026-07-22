#!/usr/bin/env bash
#
# Notification hook — push to my phone via ntfy.sh.
#
# Claude Code fires Notification when it wants attention: a permission prompt,
# an idle prompt, a finished agent. On a remote session I am not looking at,
# that is exactly the moment a phone push is useful.
#
# The topic is never hardcoded. It is read from, in order:
#   1. $VIBE_NTFY_TOPIC
#   2. VIBE_NTFY_TOPIC= in ~/.config/vibe/config
# With neither set this script silently does nothing, which is the correct
# behavior on a machine that has not opted in.
#
# On the public ntfy.sh instance the topic name IS the access control — anyone
# who knows it can read and post. Use a long random one. See docs/notifications.md.
#
# stdin: {"session_id","cwd","hook_event_name","notification_type",...}
# Always exits 0: a failed push must never disrupt the session.
set -uo pipefail

CONFIG_FILE="${VIBE_CONFIG_FILE:-$HOME/.config/vibe/config}"

topic="${VIBE_NTFY_TOPIC:-}"
if [[ -z "$topic" && -r "$CONFIG_FILE" ]]; then
  # Read without sourcing: this file is config, not code.
  # `sed -E`, not a BRE with \|: BSD sed (macOS) does not support alternation
  # in basic regexes and silently matches nothing, which would leave
  # notifications quietly switched off on macOS.
  topic="$(sed -E -n 's/^[[:space:]]*VIBE_NTFY_TOPIC[[:space:]]*=[[:space:]]*//p' \
    "$CONFIG_FILE" | tail -1 | tr -d '"'\''' | tr -d '[:space:]')"
fi
[[ -n "$topic" ]] || exit 0
command -v curl >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"

# Degrade gracefully when jq is absent: still push, just without detail.
if command -v jq >/dev/null 2>&1; then
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
  kind="$(printf '%s' "$input" | jq -r '.notification_type // .hook_event_name // empty')"
  msg="$(printf '%s' "$input" | jq -r '.message // empty')"
else
  cwd="" kind="" msg=""
fi

project="${cwd:+$(basename "$cwd")}"
project="${project:-claude-code}"

# Branch is the useful bit when several worktrees of one repo are in flight.
branch=""
if [[ -n "$cwd" && -d "$cwd" ]]; then
  branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi

title="$project"
[[ -n "$branch" ]] && title="$project · $branch"

body="${msg:-Claude Code needs attention}"
[[ -n "$kind" ]] && body="$body"$'\n'"($kind)"

# Priority: a permission prompt is blocking work, so it earns a louder push.
prio=default
tags=robot
case "$kind" in
  permission_prompt) prio=high tags=lock ;;
  idle_prompt | agent_needs_input) prio=high tags=hourglass ;;
  agent_completed) prio=default tags=heavy_check_mark ;;
esac

# -f so an HTTP error is a non-zero exit rather than a silent success.
# --data-raw, never -d/--data: curl reads a leading '@' in the value as "this
# is a filename". A notification whose message starts with '@' would otherwise
# POST the contents of that local file to a public ntfy topic, where the topic
# name is the only access control - and if the path does not exist, curl fails
# and the '|| true' below drops the push without a word.
curl -fsS --max-time 10 \
  -H "Title: $title" \
  -H "Priority: $prio" \
  -H "Tags: $tags" \
  --data-raw "$body" \
  "https://ntfy.sh/$topic" >/dev/null 2>&1 || true

exit 0
