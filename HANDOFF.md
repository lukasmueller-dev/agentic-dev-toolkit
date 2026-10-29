# Handoff — agentic-dev-toolkit / job-review

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `job-review`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/job-review
- **Last updated:** 2026-10-29 08:40 CET · turing

## State

`SPEC.md` is written from a grilling session; no code yet. Two roadmap items from the same session are committed.

## Next action

Milestone 1 of `SPEC.md`: keep each job's `session_id` in `queue/<id>/session` and let `claude/vibe-job.sh` resume a given session. Done when a test in `tests/vibe-queue.bats` shows the stub `claude` got `--resume <that id>`.

## Blockers

None.

## Gotchas (unpromoted)

- The main repo can hold an empty read-only `.git/config.lock` that a sandbox leaves: `git worktree add -b` and `git push -u` then fail with `could not lock config file`. Remove it outside the sandbox (no git process holds it), or skip the config write.
- The runner in use is the installed one from the main checkout: this branch's review loop does not review its own milestones.
