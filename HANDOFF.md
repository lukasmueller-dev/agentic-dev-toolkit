# Handoff — agentic-dev-toolkit / queue-page-v2

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `queue-page-v2`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/queue-page-v2
- **Last updated:** 2026-11-17 · turing

## State

Milestones 1 (Backend) and 2 (Page) of `SPEC.md` are done and ticked. The page has the direction B look and the label table's words; the docs still describe the old page.

## Next action

Third milestone of `SPEC.md` (Docs and end action): "Page words" table, Parts and Page actions tables in `docs/vibe-queue.md`, triage timer in `docs/vibe-jobs.md`; then delete `SPEC.md` and `spec-design/`.
Done when the "Before committing" commands of `CLAUDE.md` pass and `test ! -e SPEC.md && test ! -e spec-design`.

## Blockers

None.

## Gotchas (unpromoted)

- The branch is stacked on `ptest/parallel-research` (main + #209 + #208). The PR diff shows their commits until they merge.
- Page words: `st_label`, `st_tip`, `step_name`, `page_steps` and `job_files` in `bin/vibe` hold every label and tooltip; the docs table copies them.
- Help ↗ links `docs/vibe-queue.md#page-words` on GitHub (`gh_url`): the heading must read `## Page words`.
- Parts table (`docs/vibe-queue.md` near line 76): Rail, Header, Queue, Row, Panel, Workspaces, Config rows describe the old page; the phase bar, the steps fold and the tool.log tail are gone.
- Page actions table: Retry → Run again (note optional, needed when blocked); Hold → Put on hold, only failed, timeout, skipped or blocked; Send answer now only on the research card; Clear usage limit sits in Settings; Steer → Message to.
- "Add a route or a button" (`docs/vibe-queue.md` near line 317): `TOOLS` has no `cleanup.sh` now; page.js also reads `data-need` (a button that needs an optional field) and `data-pre` (a prefix on a field's value).
- `docs/vibe-jobs.md` near line 100: the page shows triage lines in the Jobs tab's "PR problems" fold, not a Queue tab under `## Triage`.
- Progress: `N of M items` for a lane, feature or research question; a branch of jobs without `lane=` shows its SPEC.md milestone, else `N of M jobs`.
- Run `bats` and the lint in a `git clone` in `$TMPDIR`: the sandbox's device files in the worktree root break `install.bats` and `shfmt -f .`.
- Browser test: `VIBE_TEST_BROWSER=~/.cache/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-linux64/chrome-headless-shell`; `PAGE_SHOTS=<dir>` writes screenshots.
