---
schedule: weekly
day: sun
output: pr
model: sonnet
timeout: 2h
---

Run the `codebase-health` skill (`skills/codebase-health/SKILL.md` in the
toolkit, installed as a user skill): follow its section "Unattended — as a
recurring job". Scope: the whole repo.

Findings: duplicated code, needless complexity, documentation that disagrees
with the code. A high metric alone is not a finding.

May become a commit: docs that drift from the code (docstrings, README,
instruction file, config comments) — never the code. Dedup and complexity
findings become roadmap items when a command can check their done-when.
