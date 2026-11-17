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

Milestone 1 of `SPEC.md` (Backend) is done and ticked. The page still has the old look and labels.

## Next action

Second milestone of `SPEC.md` (Page): direction B per `spec-design/` and the Decisions, every label from the table.
Done when `bats tests/vibe-web.bats` passes with `VIBE_TEST_BROWSER` set, `tests/page_check.py` checks the five tabs
and no raw state word, and the three screenshots are in `$VIBE_JOB_DIR/shots/`.

## Blockers

None.

## Gotchas (unpromoted)

- The branch is stacked on `ptest/parallel-research` (main + #209 + #208). The PR diff shows their commits until they merge.
- The page's Research card comes from #208; restyle it, keep its content. Its answer field still posts to route `answer`.
- Backend for the page: route `retry` takes `{note?}`, route `hold` takes `{note}`: one field named `note` serves both.
- `GET /queue/api/job/<id>/activity` → JSON list of `{time, kind, text}`, newest first; no `log` → 404.
- Settings data: `rc_servers` (claude-rc@ unit files); Recurring data: `job_rows REPO` (TSV, `-` or `never` when unset). Both render on today's Config page (`config_page`).
- `job_steps` still renders the last tool steps into the block; Activity replaces it, so the page milestone can drop it.
- Docs for milestone 3: the new labels in the Parts and Page actions tables of `docs/vibe-queue.md`, and the Page words table. The triage timer, the retry note and the activity route are in the docs already.
- Run `bats` and the lint in a `git clone` in `$TMPDIR`: the sandbox's device files in the worktree root break `install.bats` and `shfmt -f .`.
- Browser test: `VIBE_TEST_BROWSER=~/.cache/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-linux64/chrome-headless-shell`.
