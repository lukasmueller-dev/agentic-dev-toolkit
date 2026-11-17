# Handoff — agentic-dev-toolkit / research-card

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-card`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/research-card
- **Last updated:** 2026-11-17 09:58 CET · turing

## State

Not started. `SPEC.md` holds the milestones; the feature file holds the goal, the decisions and the contract.
Member of the feature `parallel-research` with `research-run` (this repo) and `research-setup` (safety-critic).

## Next action

Milestone 1 of `SPEC.md`: the `Research` group and its card, on fixture job dirs.
Done when `bats tests/vibe-queue.bats` and `python3 tests/page_check.py` pass with a fixture of 1 coordinator and 4 workers.

## Blockers

_What is stopping progress, and what would unblock it._

## Gotchas (unpromoted)

- `research-run` writes the job keys and job dir files; this branch has no writer → build each fixture job dir by hand from the contract.
- The card never reads `RESEARCH.md`: each value comes from a job file or a job dir file.
- The CSP runs only `page.js`: the copy buttons go into `templates/queue-page.js`.
- `vibe queue stop --research <slug> [--now]` does not exist on this branch → test the route's argv only.
