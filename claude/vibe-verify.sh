#!/usr/bin/env bash
#
# vibe-verify.sh WORKTREE NAME MODEL BASE KINDS — `vibe queue run` hook: one headless Claude check of
# origin/BASE...HEAD in WORKTREE after the last review round. KINDS: app (the repo's verify skill),
# blast-radius, or app,blast-radius. Prints one JSON result: `.structured_output` holds the verdict and checks.
# It reports only; the runner checks that no tracked file changed.
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

dir="$1" name="$2" model="${3:-sonnet}" base="$4" kinds="$5"
here="$(script_dir)"
schema='{"type":"object","required":["verdict","checks"],"properties":{"verdict":{"type":"string","enum":["pass","fail"]},"checks":{"type":"array","items":{"type":"object","required":["command","output"],"properties":{"command":{"type":"string"},"output":{"type":"string"}}}}}}'
rules="You check a change; you do not change it. Change no tracked file, make no commit, and remove what you create in the worktree.
Save evidence (screenshots, logs, transcripts) under ${VIBE_JOB_DIR:?}/evidence/.
A server started in one Bash call is unreachable from the next: start it, drive it and stop it in one Bash call.
Return only through the structured output: verdict pass when every check proves the change works, else fail.
One checks entry per command you ran as proof: the command and the last lines of its output, at most 20."
task="Verify origin/$base...HEAD."
if [[ ",$kinds," == *,app,* ]]; then
  task+=" Drive the app: read each .claude/skills/verify-*/SKILL.md, then do its Launch, Doctor, Drive, Evidence and Cleanup for the features the diff touches."
fi
if [[ ",$kinds," == *,blast-radius,* ]]; then
  task+=" Then do the blast-radius skill from your system prompt on the same diff."
  # In the system prompt, not a Read: a missing skill stops the step instead of skipping the pass.
  adapter="$(cat "$here/../docs/pstack-adapter.md")"
  skill="$(cat "$here/../vendor/skills/blast-radius/SKILL.md")"
  rules+=$'\n\n'"$adapter"$'\n\n'"$skill"
fi

cd "$dir"
exec claude -p --model "$model" --name "$name" \
  --disallowedTools Edit,Write,NotebookEdit \
  --permission-mode auto --permission-prompts none \
  --settings "$here/vibe-job-settings.json" \
  --add-dir "$VIBE_JOB_DIR" \
  --output-format json --json-schema "$schema" \
  --append-system-prompt "$rules" <<<"$task Then return the verdict and the checks through the structured output."
