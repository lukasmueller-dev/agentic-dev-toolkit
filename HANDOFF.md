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

Milestones 1 and 2 are done. `job_agent` in `bin/vibe` runs one session (args: job, timeout, prompt, session, max turns) and appends to `log`. `job_handoff` resumes after exit 124/137 with `resume.md`, `--max-turns 5`, a 10m limit. `job_run` truncates `log` at start.

## Next action

Milestone 3 of `SPEC.md`: the retry after a usage limit resumes the session. In `job_run`, pass `$d/session` to `job_agent` when it exists (a fresh dir has none). Done when a test shows the retry of a limited job got `--resume`: the `limit` stub mode in `tests/vibe-queue.bats` already runs twice, so check `claude.log` for `--resume sess-<id>` on the second call.

## Blockers

None.

## Gotchas (unpromoted)

- The main repo can hold an empty read-only `.git/config.lock` that a sandbox leaves: `git worktree add -b` and `git push -u` then fail with `could not lock config file`. Remove it outside the sandbox (no git process holds it), or skip the config write.
- `git add -A` fails on sandbox placeholder files in the worktree root (`.bashrc`, `.claude/agents`): add files by name. `shfmt -f .` and `shellcheck` need `git ls-files` for the same reason.
- The runner in use is the installed one from the main checkout: this branch's review loop does not review its own milestones.
