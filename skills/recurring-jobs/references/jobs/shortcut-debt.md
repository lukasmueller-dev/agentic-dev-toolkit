---
schedule: weekly
day: sat
output: report
model: sonnet
timeout: 30m
---

Check each `shortcut:` comment against the repo as it is now.

- One search: `git grep -n 'shortcut:' -- ':!*.md' ':!vendor/'`. Markdown only describes the convention.
- Each comment names a limit and when to upgrade. Measure the limit with a command where one exists: a line, file or row count.

Findings: one line each, `file:line`, the limit, the measured value. A crossed limit or a met upgrade condition is `Needs you`. A comment without a limit or an upgrade condition is a finding. A shortcut within its limit is no finding: one line gives their count.

May become a commit: nothing. This job is report-only.
