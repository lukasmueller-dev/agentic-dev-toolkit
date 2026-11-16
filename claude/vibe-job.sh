#!/usr/bin/env bash
#
# vibe-job.sh WORKTREE NAME MODEL PROMPT [EFFORT] [SESSION] [MAX_TURNS] — `vibe queue run` hook: one
# headless Claude session in WORKTREE, prompt from the file PROMPT; SESSION resumes that
# session; MAX_TURNS caps its turns. Nothing answers a permission prompt; vibe-job-settings.json keeps it sandboxed.
# A FIFO at $VIBE_JOB_DIR/steer (queue.conf steer=1): each NUL-ended text in it is one more user message.
set -euo pipefail

dir="$1" name="$2" model="${3:-sonnet}" prompt="$4" effort="${5:-}" session="${6:-}" turns="${7:-}"
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fifo="${VIBE_JOB_DIR:?}/steer"

cd "$dir"
extra=()
if [[ -n "$effort" ]]; then extra=(--effort "$effort"); fi
if [[ -n "$session" ]]; then extra+=(--resume "$session"); fi
if [[ -n "$turns" ]]; then extra+=(--max-turns "$turns"); fi
args=(-p --model "$model" "${extra[@]+"${extra[@]}"}" --name "$name"
  --permission-mode auto --permission-prompts none
  --settings "$here/vibe-job-settings.json"
  --add-dir "$VIBE_JOB_DIR"
  --output-format stream-json --verbose)
if [[ ! -p "$fifo" ]]; then exec claude "${args[@]}" <"$prompt"; fi

# user — stdin as one stream-json user message.
user() { jq -Rsc '{type: "user", message: {role: "user", content: [{type: "text", text: .}]}}'; }
# The prompt, then each text from the FIFO. An empty text ends the input: the first result event writes
# one (its keys come in any order), and so does the end of the output.
# shortcut: without timeout(1) a stop TERMs this shell, not claude; trap TERM once a runner lacks timeout(1).
exec 3<>"$fifo"
{
  user <"$prompt"
  while IFS= read -r -d '' t <&3 && [[ -n "$t" ]]; do printf '%s' "$t" | user; done
  rm -f "$fifo"
} | claude "${args[@]}" --input-format stream-json 3<&- | {
  while IFS= read -r l || [[ -n "$l" ]]; do
    printf '%s\n' "$l"
    if [[ "$l" == *'"type":"result"'* ]]; then printf '\0' >&3; fi
  done
  printf '\0' >&3
}
