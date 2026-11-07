---
schedule: monthly
output: pr
model: sonnet
timeout: 2h
---

Keep the repo's verification skill true to the app.

- `Read` `~/.claude/skills/maintain-verification-skill/SKILL.md` and follow it. The `Skill` tool refuses it.
- No `verify-*` skill with a feature map: `result` is `blocked: no verify skill; a human runs /create-verification-skill`.
- A server started in one Bash call is unreachable from the next: start it, drive it and stop it in one Bash call.
- The sandbox denies writes to `.claude/skills/`. Write the proven fixes for a skill there as one patch, `$VIBE_JOB_DIR/verify-skill.patch`. `git apply --check` must pass on it.

Findings: doc drift and harness gaps, each with its feature and the command that proved it. A product gap (the map is right, the app is wrong) is `Needs you`. A feature you could not reach names its prerequisite.

May become a commit: proven fixes to a verify skill outside `.claude/skills/`. A patch is `Needs you`: its path and `git apply` in a worktree.
