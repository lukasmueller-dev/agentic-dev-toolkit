---
schedule: monthly
output: report
model: sonnet
timeout: 1h
---

Audit the whole repo with the `lean-audit` rubric.

- `Read` `~/.claude/skills/lean-audit/SKILL.md` and follow it on the whole repo. The `Skill` tool refuses it.
- Skip `vendor/`, lockfiles and generated files.
- Write the skill's full report to `$VIBE_JOB_DIR/audit.md`.

Findings: in `report.md`, one line per audit finding: its number, group and `file:line`. A Must fix finding is `Needs you`.

May become a commit: nothing. This job is report-only.
