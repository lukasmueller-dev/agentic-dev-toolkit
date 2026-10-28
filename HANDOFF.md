# Handoff — agentic-dev-toolkit / feat/agent-queue

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `feat/agent-queue`
- **Worktree:** .claude/worktrees/agent-queue
- **Last updated:** 2026-10-28 · turing

## State

`SPEC.md` holds the agreed design; no code yet.

## Next action

`/grilling` on the five open questions in `SPEC.md`, write the answers into its Decisions, then M1.

## Blockers

Base on #113 (`vibe job` repo scan) once it merges; M2 touches the same functions.

## Gotchas (unpromoted)

- `/check-in` at 13:00 reads the morning briefing and starts a day shift with `--until 10:30`, which `deadline_epoch` reads as tomorrow 10:30. The queue removes both; until then, skip Phase 4 after lunch.
