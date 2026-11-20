# Handoff — agentic-dev-toolkit / extension-seam

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `extension-seam`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/extension-seam
- **Last updated:** 2026-11-20 · turing

## State

`SPEC.md` is written; no code changed. Research and `ws` code is in `bin/vibe`: 36 engine functions (about 730 lines), about 30 branch sites in queue functions (about 140 lines), about 730 lines of `ws` and tool-job code.

## Next action

Milestone 1 of `SPEC.md`: write `docs/vibe-extensions.md` (each research and `ws` site of `bin/vibe`, `bin/vibe-web` and the page mapped to an event or a passed command), then make `vibe` find extensions and call a stub. Done when `bats tests/vibe-ext.bats` passes.

## Blockers

None.

## Gotchas (unpromoted)

- Two research jobs are live until 2026-11-22 20:00: the branch must not merge while a research run is live.
- Research tests in `tests/vibe-queue.bats` pick the stub `claude` mode from prompt lines (`CLAUDE.md`, "Before committing").
