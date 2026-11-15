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

Milestones 1 and 2 are done: `docs/workspaces/kapso.md` holds the recipe and the test repo, and `tests/ws-kapso.bats` has 10 tests. No Docker ran in a job, so the image is unbuilt and recipe step 2 is unrun.

## Next action

The end action, the last open milestone of `SPEC.md`: `delete` both `SPEC.md` and `HANDOFF.md`, and move each decision and the gotchas below into `pr.md`. Done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

## Blockers

None.

## Gotchas (unpromoted)

- `up` on turing likely fails: Docker makes `/ws` as root for the bind mounts, and `docker exec` runs as `node`, so `mkdir /ws/data` fails. The recipe's "What breaks it" names the fix, `RUN mkdir -p /ws && chown node:node /ws` before `USER node`. It is not in the Dockerfile.
- Rented places exec over ssh as root (`ws-place-runpod`, `ws-place-vast`): no image `ENV`, so `kapso` may be off `PATH`, and Claude Code refuses root without `IS_SANDBOX=1`. The other tool images set it. The human test covers turing only.
- The recipe's step 4 names the job keys from the contract. The `/enqueue` route for a tool run lands with `ws-surface`.
