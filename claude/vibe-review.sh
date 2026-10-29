#!/usr/bin/env bash
#
# vibe-review.sh WORKTREE NAME MODEL LEVEL BASE — `vibe queue run` hook: one headless, read-only
# Claude review of origin/BASE...HEAD in WORKTREE. Prints one JSON result; the findings are
# in `.structured_output.findings`. Nothing answers a permission prompt; the job settings keep it sandboxed.
# A bare `/code-review` prompt runs as a local command: no model turn, no structured output.
set -euo pipefail

dir="$1" name="$2" model="${3:-sonnet}" level="${4:-high}" base="$5"
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
schema='{"type":"object","required":["findings"],"properties":{"findings":{"type":"array","items":{"type":"object","required":["file","summary","failure_scenario"],"properties":{"file":{"type":"string"},"line":{"type":"integer"},"summary":{"type":"string"},"failure_scenario":{"type":"string"}}}}}}'
rules="Return the verified findings only through the structured output: one entry per finding, most severe first, with file, line, a one-sentence summary and a concrete failure_scenario. Return an empty findings list when there are none."

cd "$dir"
exec claude -p --model "$model" --name "$name" \
  --disallowedTools Edit,Write,NotebookEdit \
  --permission-mode auto --permission-prompts none \
  --settings "$here/vibe-job-settings.json" \
  --append-system-prompt "$rules" \
  --output-format json --json-schema "$schema" <<<"Run /code-review $level origin/$base...HEAD. Then return its findings through the structured output."
