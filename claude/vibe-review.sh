#!/usr/bin/env bash
#
# vibe-review.sh WORKTREE NAME MODEL LEVEL BASE — `vibe queue run` hook: one headless, read-only
# Claude review of origin/BASE...HEAD in WORKTREE: `/code-review`, then the lean-review rubric.
# Prints one JSON result; the findings of both passes are in `.structured_output.findings`.
# Nothing answers a permission prompt; the job settings keep it sandboxed.
# A bare `/code-review` prompt runs as a local command: no model turn, no structured output.
set -euo pipefail

script_dir() {
  local src="${BASH_SOURCE[0]}" dir
  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

dir="$1" name="$2" model="${3:-sonnet}" level="${4:-high}" base="$5"
here="$(script_dir)"
# In the system prompt, not a Read: a missing rubric stops the round instead of skipping the pass.
rubric="$(cat "$here/../skills/lean-review/SKILL.md")"
schema='{"type":"object","required":["findings"],"properties":{"findings":{"type":"array","items":{"type":"object","required":["file","summary","failure_scenario"],"properties":{"file":{"type":"string"},"line":{"type":"integer"},"summary":{"type":"string"},"failure_scenario":{"type":"string"}}}}}}'
rules="Return the verified findings of both passes only through the structured output: one entry per finding, most severe first, with file, line, a one-sentence summary and a concrete failure_scenario. Merge a finding that both passes report. From the lean-review rubric below, skip the report format and the Nice to have group. Return an empty findings list when there are none."

cd "$dir"
exec claude -p --model "$model" --name "$name" \
  --disallowedTools Edit,Write,NotebookEdit \
  --permission-mode auto --permission-prompts none \
  --settings "$here/vibe-job-settings.json" \
  --add-dir "${VIBE_JOB_DIR:?}" \
  --append-system-prompt "$rules"$'\n\n'"$rubric" \
  --output-format json --json-schema "$schema" <<<"Run /code-review $level origin/$base...HEAD. Then apply the lean-review rubric from your system prompt to the same diff. Then return the findings of both passes through the structured output."
