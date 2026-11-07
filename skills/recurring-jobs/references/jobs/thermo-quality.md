---
schedule: weekly
day: sat
output: report
model: sonnet
timeout: 1h
---

Review the code merged in the last 7 days for maintainability, not correctness.

- `Read` `~/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md` and follow it. The `Skill` tool refuses it.
- Scope: the merged diff, not a branch: `git diff "$(git rev-list -1 --first-parent --before='7 days ago' origin/HEAD)" origin/HEAD`.
- Skip `vendor/`, lockfiles and generated files.
- Empty diff: `result` is `done: nothing merged in 7 days`.

Findings: one line each, most severe first: `file:line — the problem`, then the simpler shape. A file the diff pushed past 1000 lines is `Needs you`. Taste alone is not a finding.

May become a commit: nothing. This job is report-only.
