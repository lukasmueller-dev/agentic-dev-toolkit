# Handoff — agentic-dev-toolkit / research-card

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-card`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/research-card
- **Last updated:** 2026-11-17 10:50 CET · turing

## State

Milestone 1 is done: `research_row` (`bin/vibe`) reads the job dirs; `queue_jobs` prints a `Research` group; `page_row` and `status_card`/`research_card` render the row and the block; `research_fixture` (`tests/helper.bash`) is the fixture of 1 coordinator and 4 workers.
`status_line` has no `research` arm yet, so `vibe queue status` prints an empty `Research` header.

## Next action

Milestone 2 of `SPEC.md`: `vibe queue status` and the report.
Add a `research` arm to `status_line` and a `research_md` table (call it next to `feature_md` in `queue_report_md`): one row per question (`2/4`), the place on each worker row.
Done when `bats tests/vibe-queue.bats -f research` passes with a status test on `research_fixture`.

## Blockers

None.

## Gotchas (unpromoted)

- `research_row` sets `R_PILL R_PROGRESS R_QUESTION R_PR R_DIR R_HEAD R_ITEMS R_WORKERS`; a worker line is `HID DEPTH STATE PLACE LAST METRIC USD IDEA DIR` joined by `\037`. `research_head`-style text is built in `research_card`: reuse it for status.
- Worker state words: `queued`, `coding`, `running` (status `gpu`), `closing`, `paste`, `infra`, else the job status.
- The full `bats tests/vibe-queue.bats` takes 11+ min and longer under load; run `-f '^(feature|page|status|report|count|header|research)'` (2.5 min).
- Browser test: `VIBE_TEST_BROWSER=~/.cache/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-linux64/chrome-headless-shell bats tests/vibe-web.bats`, set in the same Bash call.
- A bats run started with `&` inside a sandboxed Bash call is invisible and may die with the call: run it in the foreground (`timeout` 595000).
