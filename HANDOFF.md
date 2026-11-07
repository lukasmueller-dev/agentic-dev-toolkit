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

Milestones 1 to 4 are done. A job with `verify=` gets an `<id>-verify` step after its last review round (`job_verify` in `bin/vibe`, `claude/vibe-verify.sh`).

## Next action

Milestone 5: add `job_phases`, the page line with its CSS, and the status line. Done when `bats tests/vibe-queue.bats tests/vibe-web.bats` passes with a test per phase state, in the page HTML and in the status output.

## Blockers

None.

## Gotchas (unpromoted)

- Milestone 5: the verify step's job file has `review=verify`; `review_base` gives the job a round or the verify step follows. `JOB/verify` holds the verdict: `pass`, `fail`, `dirty`, `timeout`, `verify failed`, `no verify skill`, or `<verdict>, no verify skill`.
- `vibe-queue.bats` test "page: a feature is one card on top" is flaky: it failed once in a full run, then passed 5 of 5 alone and on `main`.
- Open PRs #174 and #175 change `bin/vibe`; #171 changes `memory/GLOBAL.md`. Expect conflicts at the merge.
- Milestone 6: `lean-audit` also sets `disable-model-invocation: true`. Its catalogue job must `Read` the skill, not call the `Skill` tool.
- Milestone 6: `skills/recurring-jobs/references/job-prompt.md` has no `unslop` rule; milestone 3 changed only the fill-queue prompt.
- Milestone 6: `maintain-verification-skill` edits `.claude/skills/`, which the job sandbox denies. The `verify-maintain` PR job cannot ship a fix until this is decided.
- Milestone 7: `docs/vibe-queue.md:124` still names only `/code-review` in a review round; the doc has no verify step, and its job-key list (`:224`) lacks `verify=`.
- A rule in `skills/fill-queue/references/job-prompt.md` must not hold a slot token like `<branch>`: `render_template` in `bin/vibe` fills it in the whole file.
- The two-pass review and the verify step have no run with a real model: the runner uses the main checkout's scripts, so the first real run comes after the merge.
- `./install.sh skills` is not run: it writes outside the worktree. The links (`~/.claude/skills/unslop`, `~/.claude/vibe-verify.sh` too) arrive with `vibe update-toolkit` after the merge.
- Sandbox false alarms: `shfmt` stops on `.claude/` placeholders and 3 `install.bats` tests fail. Rerun both in a clone under `$TMPDIR`. Full `bats tests/` runs over 10 minutes, so start it in the background.
