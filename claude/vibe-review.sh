#!/usr/bin/env bash
#
# vibe-review.sh WORKTREE NAME MODEL LEVEL BASE [PASSES] — `vibe queue run` hook: one headless, read-only
# Claude review of origin/BASE...HEAD in WORKTREE: `/code-review`, then the lean-review rubric.
# PASSES=code: `/code-review` only. Prints one JSON result; the findings are in `.structured_output.findings`.
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

dir="$1" name="$2" model="${3:-sonnet}" level="${4:-high}" base="$5" passes="${6:-review}"
here="$(script_dir)"
schema='{"type":"object","required":["findings"],"properties":{"findings":{"type":"array","items":{"type":"object","required":["file","summary","failure_scenario"],"properties":{"file":{"type":"string"},"line":{"type":"integer"},"summary":{"type":"string"},"failure_scenario":{"type":"string"}}}}}}'
entry="one entry per finding, most severe first, with file, line, a one-sentence summary and a concrete failure_scenario."
none="Return an empty findings list when there are none."
if [[ "$passes" == code ]]; then
  system="Return the verified findings only through the structured output: $entry $none"
  prompt="Run /code-review $level origin/$base...HEAD. Then return its findings through the structured output."
else
  # In the system prompt, not a Read: a missing rubric stops the round instead of skipping the pass.
  rubric="$(cat "$here/../skills/lean-review/SKILL.md")"
  system="Return the verified findings of both passes only through the structured output: $entry Merge a finding that both passes report. From the lean-review rubric below, skip the report format and the Nice to have group. $none"$'\n\n'"$rubric"
  prompt="Run /code-review $level origin/$base...HEAD. Then apply the lean-review rubric from your system prompt to the same diff. Then return the findings of both passes through the structured output."
fi

cd "$dir"
exec claude -p --model "$model" --name "$name" \
  --disallowedTools Edit,Write,NotebookEdit \
  --permission-mode auto --permission-prompts none \
  --settings "$here/vibe-job-settings.json" \
  --add-dir "${VIBE_JOB_DIR:?}" \
  --append-system-prompt "$system" \
  --output-format json --json-schema "$schema" <<<"$prompt"
