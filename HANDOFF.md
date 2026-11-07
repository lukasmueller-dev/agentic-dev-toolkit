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

Milestones 1 and 2 are done. `skills/lean-review/` and `skills/lean-audit/` exist; `claude/vibe-review.sh` runs `/code-review` and the lean rubric in each round.

## Next action

Milestone 3: add the `unslop` rule to `skills/fill-queue/references/job-prompt.md`, and replace "Prefer the cut" in `memory/GLOBAL.md`. Done when `grep -q unslop skills/fill-queue/references/job-prompt.md && ! grep -q '^# Prefer the cut' memory/GLOBAL.md` passes and `bats tests/install.bats` passes in a clone under `$TMPDIR`.

## Blockers

None.

## Gotchas (unpromoted)

- Open PRs #174 and #175 change `bin/vibe`; #171 changes `memory/GLOBAL.md`. Expect conflicts at the merge.
- Milestone 3: all 6 vendored skills set `disable-model-invocation: true`. The job prompt must name `Read ~/.claude/skills/unslop/SKILL.md`, not the `Skill` tool.
- Milestone 3: both lean skills treat a `shortcut:` comment as a decision. `memory/GLOBAL.md` must use that exact marker.
- Milestone 6: `lean-audit` also sets `disable-model-invocation: true`. Its catalogue job must `Read` the skill, not call the `Skill` tool.
- Milestone 6: `maintain-verification-skill` edits `.claude/skills/`, which the job sandbox denies. The `verify-maintain` PR job cannot ship a fix until this is decided.
- Milestone 7: `docs/vibe-queue.md:124` still names only `/code-review` in a review round.
- The two-pass review has no run with a real model: the runner uses the main checkout's script, so the first real round comes after the merge.
- `./install.sh skills` is not run: it writes outside the worktree. The links arrive with `vibe update-toolkit` after the merge.
- Sandbox false alarms: `shfmt` stops on `.claude/` placeholders and 3 `install.bats` tests fail. Rerun both in a clone under `$TMPDIR`. Full `bats tests/` runs over 10 minutes, so start it in the background.
