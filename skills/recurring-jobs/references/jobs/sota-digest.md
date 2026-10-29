---
schedule: weekly
day: sun
output: pr
model: sonnet
timeout: 2h
after:
---

Toolkit repo only. Run the repo-local `sota-digest` skill
(`.claude/skills/sota-digest/SKILL.md`): fix the week, sweep the sources by
web search, diff against the roadmap and the status decisions, write
`docs/sota/<YYYY-Www>.md`. This prompt is the user's ask to commit it.

Findings: the digest's recommendations, one line each in `report.md`.

May become a commit: the digest file, one commit. Never `PROJECT_ROADMAP.md`,
never `PROJECT_STATUS.md`, never code.
