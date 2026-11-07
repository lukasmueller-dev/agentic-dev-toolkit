# Handoff — agentic-dev-toolkit / queue-verify-skills

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `queue-verify-skills`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/queue-verify-skills
- **Last updated:** 2026-11-07 · turing

## State

Not started. `SPEC.md` holds the goal, the decisions and the milestones.

## Next action

Milestone 1: vendor the 6 skills, run `/security-review` over the new tree (a finding stops the job as blocked), add `docs/pstack-adapter.md`, add a pointer line to it in `claude/CLAUDE.md`. Done when `./bin/plug verify && bats tests/plug.bats tests/plugin.bats` passes.

## Blockers

None.

## Gotchas (unpromoted)

- Open PRs #174 and #175 change `bin/vibe`; #171 changes `memory/GLOBAL.md`. Expect conflicts at the merge.
