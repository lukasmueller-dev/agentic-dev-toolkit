# Handoff — agentic-dev-toolkit / queue-redesign

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `queue-redesign`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/queue-redesign
- **Last updated:** 2026-11-16 · turing

## State

`SPEC.md`, the boards in `design/queue-a/` and the fonts in `templates/fonts/` are committed. No code has changed yet.

## Next action

Milestone 1, Shell: tokens, fonts, rail, header, the six sections, rows with label, lamp, phase bar and primary button; tab title; no zoom. Done when `bats tests/vibe-queue.bats tests/vibe-web.bats` passes with new tests for the sections, the Needs-you rules and the copied fonts.

## Blockers

None.

## Gotchas (unpromoted)

- The boards are `.dc.html` design files: they load `./support.js` and Google Fonts, so they do not render alone. Read them for layout, sizes and colors.
