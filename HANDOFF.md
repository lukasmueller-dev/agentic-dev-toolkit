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

Milestones 1–4 are done. `job_run` queues `<id>-review1` when `review_due`; `job_review` runs a round (reviewer, fixer, tally) and the last round publishes. Reviewer: `claude/vibe-review.sh`. Keys: `after`, `review_rounds`, `review_trivial`, `review_model`, `review_level`, `review_timeout`. Tests: `review:` in `tests/vibe-queue.bats`, `after` in `tests/vibe-jobs.bats`.

## Next action

Milestone 5 of `SPEC.md`, the last: docs and end action. Add the rules and layout rows to `docs/vibe-queue.md` (review rounds, the six keys, `<id>-review<n>`, `after`) and the `after` key to `docs/vibe-jobs.md`. Add one decision line to `PROJECT_STATUS.md`. Move each Decisions line of `SPEC.md` into `pr.md`, then `git rm SPEC.md HANDOFF.md`. Done-when: `shfmt -d -i 2 -ci`, `shellcheck` and `bats tests/` pass (list files with `git ls-files`).

## Blockers

None.

## Gotchas (unpromoted)

- The main repo can hold an empty read-only `.git/config.lock` that a sandbox leaves: `git worktree add -b` and `git push -u` then fail with `could not lock config file`. Remove it outside the sandbox (no git process holds it), or skip the config write.
- `git add -A` fails on sandbox placeholder files in the worktree root (`.bashrc`, `.claude/agents`): add files by name. `shfmt -f .` and `shellcheck` need `git ls-files` for the same reason.
- The runner in use is the installed one from the main checkout: this branch's review loop does not review its own milestones.
- `install.bats` fails 3 tests in the sandbox: run it in a `git clone` under `$TMPDIR` (use absolute paths; the tests delete their cwd).
- The live `claude -p "/code-review …" --json-schema` call is untested: only stubs ran. Check one real review before you merge.
