# Handoff — agentic-dev-toolkit / ws-autoresearchclaw

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-autoresearchclaw`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-autoresearchclaw
- **Last updated:** 2026-11-15 · turing

## State

Nothing is built. `SPEC.md` holds the plan. The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The first open milestone of `SPEC.md`: Conf, config file, Dockerfile and the three scripts against a stub `researchclaw` — code — done when `bats tests/ws-autoresearchclaw.bats` passes: a `pipeline_summary.json` with a failed stage gives `failed:` at exit 0; `steer` names the next stage; `grep -c 'mode: sandbox' workspaces/autoresearchclaw/*.yaml` prints 1.

## Blockers

None.

## Gotchas (unpromoted)

None.
