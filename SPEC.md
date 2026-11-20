# Spec — agentic-dev-toolkit / extension-seam

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `extension-seam`
- **Written:** 2026-11-20

## Goal

`bin/vibe`, `bin/vibe-web` and the page templates hold no research or workspace code.
That code runs as one executable under `extensions/research/`, called through a documented contract. Behaviour is unchanged.

## Non-goals

- No file leaves this repo; the move to the research repo is a later job.
- No change of behaviour, job keys, file formats or command names.
- No new research feature; the engine stays bash.
- `skills/research-*`, `templates/research/`, `workspaces/` and `docs/workspaces/` stay in place.
- No history rewrite.

## Decisions

- Seam first, in this repo: one test suite proves the move before the code leaves for `agentic-research-toolkit`.
- One-way dependency: the queue names no research or workspace term. With no extension, `vibe` works; a research or `ws` command prints one error line.
- Boundary of commands, job keys and files: the extension sources no toolkit file and calls no `vibe` function. Reason: the engine can change language, and a `vibe` refactor cannot break it unseen.
- Events: the queue runs the extension at add, session end, runner pass, stop, archive, answer, retry, card, status and report. The contract may change later.
- Commands: `vibe` passes `ws`, `queue worker`, `queue gpu --place` and the `--research` flags to the extension. The prompts and the user type the same commands as today.
- `vibe ws`, tool jobs and place runs move with the engine: nothing else uses them.
- Discovery: each `extensions/<name>/<name>` in the toolkit checkout, plus each line of `~/.config/vibe/extensions`. Reason: the merge needs no step on the machine; the later move needs one config line.
- Merge only when no research run is live: a regression hits paid runs.

## Milestones

- [ ] Contract and dispatcher: `docs/vibe-extensions.md` maps each research and `ws` site of `bin/vibe`, `bin/vibe-web` and the page to an event or a passed command; `vibe` finds extensions and calls a stub — code — done when `bats tests/vibe-ext.bats` passes.
- [ ] `ws` and tool jobs behind the contract — code — done when `grep -cE 'ws_|WS_|workspace' bin/vibe` prints 0 and `bats tests/vibe-ws.bats tests/ws-*.bats` and the tool tests of `tests/vibe-queue.bats` pass.
- [ ] Research lifecycle behind the contract: add, session end, runner pass, worker, place run, stop, archive, answer, retry — code — done when `bin/vibe` defines no function of the engine list in `docs/vibe-extensions.md` and `bats tests/vibe-queue.bats` passes.
- [ ] Research card, status, report and web routes behind the contract — code — done when `grep -ciE 'research|workspace' bin/vibe bin/vibe-web templates/queue-page.html templates/queue-page.js` prints 0 for each file and `bats tests/vibe-queue.bats tests/vibe-web.bats` pass.
- [ ] Test split: research and `ws` tests, helpers and stub modes sit in their own files and pass with `extensions/research/` copied outside the checkout — code — done when `grep -ci research tests/vibe-queue.bats tests/vibe-web.bats tests/helper.bash` prints 0 for each file and `bats tests/` passes.
- [ ] End action: update `CLAUDE.md` (layout), `docs/vibe-queue.md`, `docs/workspaces.md` and the CI template check; add the roadmap item for the move to the research repo — code — done when `test ! -e SPEC.md` and the "Before committing" gate of `CLAUDE.md` passes.

## End action

`rewrite into docs/vibe-extensions.md`: what the contract now is. Each decision moves to the PR body.
