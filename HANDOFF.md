# Handoff — agentic-dev-toolkit / research-run

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-run`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/research-run
- **Last updated:** 2026-11-17 09:58 CET · turing

## State

Not started. `SPEC.md` holds the milestones; the feature file holds the goal, the decisions and the contract.
Member of the feature `parallel-research` with `research-card` (this repo) and `research-setup` (safety-critic).

## Next action

Milestone 1 of `SPEC.md`: `vibe queue gpu --place runpod|vast -- CMD`, `run-result` and `infra`.
Done when `bats tests/vibe-queue.bats tests/vibe-ws.bats` pass with a test per sentence of the milestone, on stub places.

## Blockers

_What is stopping progress, and what would unblock it._

## Gotchas (unpromoted)

- A place script runs a workspace folder, not a bare command: the command reaches the container as `/ws/in/cmd` (feature contract).
- `git branch research/<slug>/<hid>` fails when a branch `research` or `research/<slug>` exists → refuse that research branch name with one line.
- `research-card` reads the job keys and the job dir files of the contract; a change to one needs the user.
