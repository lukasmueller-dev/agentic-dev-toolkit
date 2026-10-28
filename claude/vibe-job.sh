#!/usr/bin/env bash
#
# vibe-job.sh WORKTREE NAME MODEL PROMPT — `vibe queue run` hook: one headless
# Claude session in WORKTREE, prompt from the file PROMPT. Nothing answers a
# permission prompt; vibe-job-settings.json keeps it sandboxed.
set -euo pipefail

dir="$1" name="$2" model="${3:-sonnet}" prompt="$4"
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$dir"
exec claude -p --model "$model" --name "$name" \
  --permission-mode auto --permission-prompts none \
  --settings "$here/vibe-job-settings.json" \
  --output-format stream-json --verbose <"$prompt"
