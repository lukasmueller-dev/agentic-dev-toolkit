#!/usr/bin/env bash
#
# vibe-job.sh WORKTREE NAME MODEL PROMPT [EFFORT] [SESSION] [MAX_TURNS] — `vibe queue run` hook: one
# headless Claude session in WORKTREE, prompt from the file PROMPT; SESSION resumes that
# session; MAX_TURNS caps its turns. Nothing answers a permission prompt; vibe-job-settings.json keeps it sandboxed.
set -euo pipefail

dir="$1" name="$2" model="${3:-sonnet}" prompt="$4" effort="${5:-}" session="${6:-}" turns="${7:-}"
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$dir"
extra=()
if [[ -n "$effort" ]]; then extra=(--effort "$effort"); fi
if [[ -n "$session" ]]; then extra+=(--resume "$session"); fi
if [[ -n "$turns" ]]; then extra+=(--max-turns "$turns"); fi
exec claude -p --model "$model" "${extra[@]+"${extra[@]}"}" --name "$name" \
  --permission-mode auto --permission-prompts none \
  --settings "$here/vibe-job-settings.json" \
  --output-format stream-json --verbose <"$prompt"
