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

Milestone 1 (Shell) is done and ticked in `SPEC.md`. `vibe queue page` renders the rail, the header and six sections of rows (`page_row`, `page_sections`, `page_status` in `bin/vibe`); fonts copy to `web/fonts/`.

- Each row folds open to its old card (`status_card`): every button and file link still lives there.
- The page buttons sit on `#config`; the New work cards on `#new` (header link New job).
- Outside GPU runs are already rows in Running, Queued, Held and Done.

## Next action

Milestone 2, Panel and Config: hidden blocks, always-open panel and bottom sheet, `#job-<id>`, input fields, keys, swap guard, New job panel, Config page. Done when `node --check templates/queue-page.js` passes, no `prompt(` is left in it, and the bats suites pass with tests for the panel blocks and the Config parts.

- Turn each row's fold (`<details class="row">` + `status_card`) into a row plus one hidden block; the panel shows the block.
- Move `#new` (New work) and the Config buttons into the New job panel and the Config page.

## Blockers

None.

## Gotchas (unpromoted)

- The boards are `.dc.html` design files: they load `./support.js` and Google Fonts, so they do not render alone. Read them for layout, sizes and colors.
- A screenshot of the page needs it served under `/queue/` (fonts and `page.js` load from there): `python3 -m http.server` on a dir with a `queue` symlink to `web/`, then `chrome-headless-shell --screenshot` in the same Bash call.
- In a fetched page, page.js finds a node only by a path from `body` (`body > main > #queue`): a `.md` can hold any class.
