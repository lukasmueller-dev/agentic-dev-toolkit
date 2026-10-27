---
schedule: weekly
day: sun
output: report
model: sonnet
timeout: 1h
---

Research repo: every run recorded, comparable and reported (`docs/EXPERIMENT_SETUP.md` is the contract).

- Run directories without a run record, or a record without the comparison key.
- Run directories over 5 GB with no record that names them.
- Tracker state: runs the tracker never received (offline dirs not synced).
- Configs or checkpoints referenced by `PROJECT_STATUS.md` or the report that no longer exist on disk.

Findings: one line per run directory, size included. Never delete anything.

May become a commit: nothing. This job is report-only.
