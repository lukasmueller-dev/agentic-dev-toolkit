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

Milestone 1 is done: 6 skills vendored at `6b03002`, `docs/pstack-adapter.md` added, pointer line in `claude/CLAUDE.md`. Security review: no findings.

## Next action

Milestone 2: add `skills/lean-review/` and `skills/lean-audit/`, and run the rubric in `claude/vibe-review.sh`. Done when `./bin/skill-lint --strict skills && bats tests/vibe-queue.bats` passes with a test that the review prompt names both passes.

## Blockers

None.

## Gotchas (unpromoted)

- Open PRs #174 and #175 change `bin/vibe`; #171 changes `memory/GLOBAL.md`. Expect conflicts at the merge.
- Milestone 2: neither the spec nor the repo gives a URL for the `ponytail` source.
- Milestone 3: all 6 vendored skills set `disable-model-invocation: true`. The job prompt must name `Read ~/.claude/skills/unslop/SKILL.md`, not the `Skill` tool.
- Milestone 6: `maintain-verification-skill` edits `.claude/skills/`, which the job sandbox denies. The `verify-maintain` PR job cannot ship a fix until this is decided.
- `./install.sh skills` is not run: it writes outside the worktree. The links arrive with `vibe update-toolkit` after the merge.
- Sandbox false alarms: `shfmt` stops on `.claude/` placeholders and 3 `install.bats` tests fail. Rerun both in a clone under `$TMPDIR`.
