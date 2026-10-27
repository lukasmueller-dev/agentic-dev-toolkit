---
schedule: weekly
day: sun
output: report
model: sonnet
timeout: 30m
---

Check the repo's state files against the repo; report, never edit them.

- `PROJECT_STATUS.md`: `_Last updated_` older than 4 weeks, or a decision line that names a branch which no longer exists.
- `PROJECT_ROADMAP.md`: an item without a done-when, or whose done-when already holds (run the check when it is a command).
- `HANDOFF.md` on a branch whose PR is merged (`git branch -r --merged origin/HEAD`), or at the repo root of the default branch.
- Worktrees under `.claude/worktrees/` whose branch is merged.

Findings: one line each, with the file and line. A done-when that already holds is `Needs you`.

May become a commit: nothing. This job is report-only.
