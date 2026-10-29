# Handoff — agentic-dev-toolkit / research-guards

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-guards`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/research-guards
- **Last updated:** 2026-10-29 CET · turing

## State

`SPEC.md` is written from a grilling session and parked for the owner's review; no code yet, not queued.

## Next action

The owner reviews `SPEC.md`. After that and after `job-review` merges: rebase on the default branch, then milestone 1 — the stop rule in `gpu-queue`; done when a test in `tests/gpu-queue.bats` shows a stub run whose `stop` exits 0 ends `stopped` and its `--then` gets `GPUQ_STOP`.

## Blockers

- Owner review of `SPEC.md`.
- `job-review` must merge first: both branches change `job_run` and `job_publish` in `bin/vibe`.

## Gotchas (unpromoted)

- The main repo can hold an empty read-only `.git/config.lock` that a sandbox leaves; `git worktree add -b` and `git push -u` then fail with `could not lock config file`. Remove it outside the sandbox when no git process holds it.
