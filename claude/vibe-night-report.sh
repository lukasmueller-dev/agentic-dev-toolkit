#!/usr/bin/env bash
#
# vibe-night-report.sh REPORT DIR — `vibe night report` hook: an interactive
# Claude session with Remote Control, in tmux, that pushes the report's summary
# to the phone and stays open for questions. Replaces the previous one.
set -euo pipefail

report="$1" dir="$2"
root="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prompt="Read $report — the night-shift report. Send me one push notification:\
 the counts line and the first thing I should do. Then show the report as a\
 short table and wait. Change nothing and start nothing unless I ask."

command -v tmux >/dev/null 2>&1 || {
  echo "vibe-night-report: no tmux — report only: $report" >&2
  exit 0
}
tmux -L night-shift kill-session -t '=report' 2>/dev/null || true
# The toolkit checkout is a trusted workspace; an untrusted one stops at a dialog.
# --add-dir is variadic: placed last, it swallows the prompt.
tmux -L night-shift new-session -d -s report -c "$root" \
  "$(printf '%q ' claude --add-dir "$dir" --model sonnet --remote-control "night-shift ${dir##*/}" "$prompt")"
echo "session: tmux -L night-shift attach -t report"
