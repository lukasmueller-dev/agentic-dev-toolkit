---
schedule: monthly
output: pr
model: sonnet
timeout: 2h
---

Make the mistakes agents repeat in this repo impossible.

- `Read` `~/.claude/skills/correct/SKILL.md` and follow it. The `Skill` tool refuses it.
- Evidence first: past review findings, the `findings` file in each `~/.local/state/vibe/queue/*-review*/` whose `job` file holds `repo=` with this repo's path.
- Then the sources the skill names: recent commits, reverts, the instruction file.
- A class needs 2 findings or more. Cite the job ids.
- Prove each new check fails on a past mistake: name the commit, run the check on it.

Findings: one line per class: the evidence, the level you picked, why a higher level does not work. A class with one finding is not a finding.

May become a commit: per class, one lint, CI check or test that fails on the past mistake, plus its row in the rule table of the instruction file. An architecture or type change becomes a roadmap item.
