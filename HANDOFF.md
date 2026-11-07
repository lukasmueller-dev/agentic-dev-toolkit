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

Milestones 1 to 3 are done. The fill-queue job prompt has the `unslop` rule (rule 16); `memory/GLOBAL.md` has "Least new code, whole task" in place of "Prefer the cut".

## Next action

Milestone 4: add the `verify=` key, `claude/vibe-verify.sh`, the `<id>-verify` step, and the field in `/enqueue` and `/fill-queue`. Done when `bats tests/vibe-queue.bats` passes with tests for: key set, no key, no skill, `V: fail`, `V: dirty`, refused lane job.

## Blockers

None.

## Gotchas (unpromoted)

- Open PRs #174 and #175 change `bin/vibe`; #171 changes `memory/GLOBAL.md`. Expect conflicts at the merge.
- Milestone 6: `lean-audit` also sets `disable-model-invocation: true`. Its catalogue job must `Read` the skill, not call the `Skill` tool.
- Milestone 6: `skills/recurring-jobs/references/job-prompt.md` has no `unslop` rule; milestone 3 changed only the fill-queue prompt.
- Milestone 6: `maintain-verification-skill` edits `.claude/skills/`, which the job sandbox denies. The `verify-maintain` PR job cannot ship a fix until this is decided.
- Milestone 7: `docs/vibe-queue.md:124` still names only `/code-review` in a review round.
- A rule in `skills/fill-queue/references/job-prompt.md` must not hold a slot token like `<branch>`: `render_template` in `bin/vibe` fills it in the whole file.
- The two-pass review has no run with a real model: the runner uses the main checkout's script, so the first real round comes after the merge.
- `./install.sh skills` is not run: it writes outside the worktree. The links (`~/.claude/skills/unslop` too) arrive with `vibe update-toolkit` after the merge.
- Sandbox false alarms: `shfmt` stops on `.claude/` placeholders and 3 `install.bats` tests fail. Rerun both in a clone under `$TMPDIR`. Full `bats tests/` runs over 10 minutes, so start it in the background.
