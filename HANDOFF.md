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
- **Last updated:** 2026-11-17 11:25 CET · turing

## State

Milestones 1 to 3 are done: card, status and report, paste panel, `research-stop` and `research-stop-now` routes.

## Next action

Milestone 4 of `SPEC.md`, the end action: move each decision to `pr.md`, then `git rm SPEC.md HANDOFF.md` and commit.
Done when `git ls-files SPEC.md HANDOFF.md` prints nothing.

## Blockers

None.

## Gotchas (unpromoted)

- `research_row` sets `R_PILL R_PROGRESS R_QUESTION R_PR R_DIR R_HEAD R_ITEMS R_WORKERS`; a worker line is `HID DEPTH STATE PLACE LAST METRIC USD IDEA DIR` joined by `\037`. `research_head`-style text is built in `research_card`: reuse it for status.
- Worker state words: `queued`, `coding`, `running` (status `gpu`), `closing`, `paste`, `infra`, else the job status.
- The full `bats tests/vibe-queue.bats` takes 11+ min and longer under load; run `-f '^(feature|page|status|report|count|header|research)'` (2.5 min).
- Browser test: `VIBE_TEST_BROWSER=~/.cache/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-linux64/chrome-headless-shell bats tests/vibe-web.bats`, set in the same Bash call.
- A bats run started with `&` inside a sandboxed Bash call is invisible and may die with the call: run it in the foreground (`timeout` 595000).
