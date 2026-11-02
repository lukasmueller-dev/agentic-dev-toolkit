---
schedule: weekly
day: sat
output: pr
model: sonnet
timeout: 30m
kind: gpu
---

Research repo: the canonical eval, its headline metric against the last run.

- The repo file names the eval command, the headline metric, higher or lower is better, and a tolerance (default 2 % relative). No command: `blocked:` naming the missing line.
- No `## GPU run finished` section below: queue the eval with `vibe queue gpu -- <command>`. Send its outputs to `$VIBE_JOB_DIR/eval/` (expand the path now), never into the worktree.
- `## GPU run finished`: read the headline metric from the log or `${VIBE_JOB_DIR%-gpu*}/eval/`. Compare it with **Last run** above.
- `result`: `done: <metric> <new> (last <old>)` — both numbers, every run; `none` as old on a first run.
- A drop beyond the tolerance: one `PROJECT_ROADMAP.md` item — task "find the <metric> drop from <old> to <new>", done-when the eval gives <old> or better within the tolerance. The `pr.md` Changed line names both numbers.
- Run exit not 0: `failed:` with the log's last error line; no comparison.

Findings: a drop, a failed run. A gain is no finding.

May become a commit: the one roadmap item for a drop. Nothing else.
