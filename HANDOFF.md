# Handoff — agentic-dev-toolkit / ws-kapso

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-kapso`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-kapso
- **Last updated:** 2026-11-15 · turing

## State

Milestone 1 is done: `workspaces/kapso/` (conf, `config.yaml`, Dockerfile, `run`, `stop`, `steer`) and `tests/ws-kapso.bats` pass against a stub `kapso`. The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The next open milestone of `SPEC.md`: write the recipe `docs/workspaces/kapso.md` with the small test repo for the human test. Done when `grep -c '^## ' docs/workspaces/kapso.md` prints 4 or more. Include: the args keys (`evaluation=<dir in the repo>`, `experiments=<n>`), the uid 1000 mount trap, and the image build and bring-up steps.

## Blockers

None.

## Gotchas (unpromoted)

None.
