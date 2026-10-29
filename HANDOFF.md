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
- **Last updated:** 2026-10-29 · job-review

## State

Milestone 1 is done: `job_session` in `bin/vibe` writes `queue/<id>/session` after every run; `claude/vibe-job.sh` takes the session as its 6th argument and passes `--resume`. Nothing passes a session yet.

## Next action

Milestone 2 of `SPEC.md`: on exit 124 the runner resumes the session for one turn (`--max-turns 5`) that commits `HANDOFF.md` and writes `result`. Done when a test with a stub past its timeout ends `timeout` with `HANDOFF.md` committed on the branch. `vibe-job.sh` needs a way to pass `--max-turns`; the stub `claude` in `tests/vibe-queue.bats` prints a `system/init` event (`sess-<job id>`).

## Blockers

None.

## Gotchas (unpromoted)

- The main repo can hold an empty read-only `.git/config.lock` that a sandbox leaves: `git worktree add -b` and `git push -u` then fail with `could not lock config file`. Remove it outside the sandbox (no git process holds it), or skip the config write.
- `git add -A` fails on sandbox placeholder files in the worktree root (`.bashrc`, `.claude/agents`): add files by name. `shfmt -f .` and `shellcheck` need `git ls-files` for the same reason.
- The runner in use is the installed one from the main checkout: this branch's review loop does not review its own milestones.
