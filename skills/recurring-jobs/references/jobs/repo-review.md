---
schedule: monthly
output: report
model: sonnet
timeout: 1h
---

Review the whole repo for correctness bugs, not a diff.

- Run `/code-review high .` inside this prompt. A bare slash command prints no findings.
- Skip `vendor/`, lockfiles and generated files.
- Keep only findings that name a file, a line and a concrete failure scenario.
- `/code-review` does not run: `result` is `blocked: /code-review unavailable; update claude`.

Findings: one line each, ranked most severe first: `file:line — summary`, then the failure scenario. Style, naming and a missing test alone are not findings. A finding that loses data or fails silently is `Needs you`.

May become a commit: nothing. This job is report-only.
