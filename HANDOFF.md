# Handoff — agentic-dev-toolkit / queue-verify-skills

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `queue-verify-skills`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/queue-verify-skills
- **Last updated:** 2026-11-07 · turing

## State

Milestones 1 to 5 are done. `job_phases` in `bin/vibe` feeds the phase line on each card of the page and in `vibe queue status`.

## Next action

Milestone 6: add the 5 catalogue jobs and the `docs/vibe-jobs.md` rows, and add the `lean-audit` roadmap item. Done when `bats tests/vibe-jobs.bats` passes and `grep -q lean-audit PROJECT_ROADMAP.md` passes.

## Blockers

None.

## Gotchas (unpromoted)

- `vibe-queue.bats` test "page: a feature is one card on top" is flaky: it failed once in a full run, then passed 5 of 5 alone and on `main`.
- Open PRs #174 and #175 change `bin/vibe`; #171 changes `memory/GLOBAL.md`. Expect conflicts at the merge.
- Milestone 6: `lean-audit` also sets `disable-model-invocation: true`. Its catalogue job must `Read` the skill, not call the `Skill` tool.
- Milestone 6: `skills/recurring-jobs/references/job-prompt.md` has no `unslop` rule; milestone 3 changed only the fill-queue prompt.
- Milestone 6: `maintain-verification-skill` edits `.claude/skills/`, which the job sandbox denies. The `verify-maintain` PR job cannot ship a fix until this is decided.
- Milestone 7: `docs/vibe-queue.md:124` still names only `/code-review` in a review round; the doc has no verify step, and its job-key list (`:224`) lacks `verify=`.
- Milestone 7: `docs/vibe-queue.md` has no phase line yet: the marks, R2 once queued, Verify with the key, Gate and PR from the chain's last job.
- End action, for `pr.md`: "the open card names the passes" is read as a `<details>` phase line; open, it lists `R1, R2: /code-review + lean-review`. A line with no review round stays a `<p>`.
- A rule in `skills/fill-queue/references/job-prompt.md` must not hold a slot token like `<branch>`: `render_template` in `bin/vibe` fills it in the whole file.
- The two-pass review and the verify step have no run with a real model: the runner uses the main checkout's scripts, so the first real run comes after the merge.
- `./install.sh skills` is not run: it writes outside the worktree. The links (`~/.claude/skills/unslop`, `~/.claude/vibe-verify.sh` too) arrive with `vibe update-toolkit` after the merge.
- Sandbox false alarms: `shfmt` stops on `.claude/` placeholders and 3 `install.bats` tests fail. Rerun both in a clone under `$TMPDIR`. Full `bats tests/` runs over 10 minutes, so start it in the background.
