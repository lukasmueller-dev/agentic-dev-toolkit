# Spec — agentic-dev-toolkit / research-run

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-run`
- **Written:** 2026-11-17

## Goal

A research job runs as a coordinator and up to K workers; each worker makes one run on one of 4 places.
Feature: ~/.local/state/vibe/features/parallel-research.md

## Non-goals

see the feature file

## Decisions

see the feature file

## Milestones

- [x] `vibe queue gpu --place runpod|vast -- CMD`: the repo's `.claude/research/` is the workspace folder; `up`, `exec run`, `pull`, `down`, the `hours` limit, then the follow-up job. No folder: one error line. The runner writes `run-result` from the last `RESULT {` line of each run log, on turing too; none means failed. A failed `up` writes `infra`. — code — done when `bats tests/vibe-queue.bats tests/vibe-ws.bats` pass with a test per sentence, on stub places.
- [x] Place verb `price` (USD per hour before `up`; exit 3 on turing) and the `usd=` gate: a start is refused when spent + `hours` × price is above `usd`; a running run counts at its full `hours`. The runner writes `cost` per worker. — code — done when `bats tests/vibe-queue.bats tests/ws-place-runpod.bats tests/ws-place-vast.bats` pass with a gate test and a `price` test per place.
- [x] `vibe queue worker HID [--place P]` from inside the coordinator job: the branch `research/<slug>/<hid>` from the research branch tip, the worker keys, `after=`, no PR. Refused above `workers=`, past `deadline=`, or with no baseline row. A worker end queues one coordinator follow-up unless one is queued. — code — done when `bats tests/vibe-queue.bats` passes with a test per refusal and a fan-in test with 2 worker ends.
- [ ] Prompts and templates: `references/research.md` becomes the coordinator block (baseline first, pick up to K, `Builds on`, the noise rule, merge the best, `failed: infra`, each row from `runs/<hid>/row.md` checked against `run-result`); new `references/research-worker.md`; `templates/RESEARCH.md` gets `workers` and `usd` in Budget, `Place:` and `Builds on:` per item, a `place` ledger column; route Research reads `## Research`; `docs/vibe-queue.md` § Research jobs holds the contract. — code — done when `./bin/skill-lint --strict skills` and `bats tests/` pass, with a test that a coordinator prompt and a worker prompt each hold their block.
- [ ] IAS and stop: a `place=ias` worker writes `runs/<hid>/job.sbatch` from the repo's template and `paste.md`, then ends `blocked:`; `vibe queue answer <id> 'RESULT {…}'` writes `run-result` and queues session 2. `vibe queue stop --research <slug>` drains; `--now` runs `stop`, `pull`, `down` per run. A close session runs past `deadline` and `usd`. — code — done when `bats tests/vibe-queue.bats` passes with an answer test, a drain test, a now test and a past-deadline close test.
- [ ] End action. — code — done when `git ls-files SPEC.md HANDOFF.md` prints nothing.

## End action

delete
