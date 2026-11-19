# Spec — agentic-dev-toolkit / research-card-status

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-card-status`
- **Written:** 2026-11-19

## Goal

A research card names its live run, the run's progress, its ETA, the box end
time, the real spend and why a stopped question stopped. The pill says which
of the states the question is in, not `Running` for a session that only closes.

## Non-goals

- Pause for a research question (`pause` file, both gates, CLI verb, buttons) — its own PR.
- The `PROGRESS` emitter in `safety-critic/.claude/research/run` — a task in that repo.
- The `research_md` report row keeps its current columns.

## Decisions

- Progress comes from a contract line, `PROGRESS {"done":…, "total":…, "at":…, "run":…}`, the last one winning — the rule `RESULT` already uses. The toolkit owns no repo's log words.
- The contract is optional: a run without it shows no progress and never fails for that.
- A `Step:` fallback reads the last such line before the first `Average time:` line. shortcut: safety-critic's log words, drop when repos emit PROGRESS.
- ETA divides the step delta by the time delta of the last two PROGRESS lines. One line gives no ETA. Rate from `done / (now − started)` counts smoke and startup and underestimates.
- The `at` epoch is absolute, so the box's UTC clock needs no conversion on the CET host.
- The card reads the live instance dir `workspaces/research-<job id>/` for a live run, `queue/<id>/run/` for an ended one. The spec sentence "job files only" changes.
- `place_run` mirrors `started` and `limit` into `queue/<id>/run/` at start, beside the `price` mirror: the instance dir is deleted when the box goes.
- Spend sums the coordinator chain's `cost` files too. That omission is the whole `$0.00 of $35` bug.
- A live box shows `price × (now − started)`, not the gate's full-hours reservation, so spend grows from $0.
- The state line is `<state> · <reason> · <run> on <place> · <done> of <total> steps · eta <time> · box until <time>`, empty fields dropped. `waits for` is retired.
- State first, because the left edge is scanned down the card. Box end last, because it changes slowest.
- Precedence: `needs you` → `drained` → `on <place>` → `coding` → `closing` → `thinking` → `queued` → `done`.
- `drained` sits above a live run: after a Stop, that is the fact you need. A run-first line made a follow-up job look like a restart.
- The newest run with no `run/exit` wins, coordinator or worker; else the newest ended one. A worker's run names its hid.
- The run's name is the contract's `"run"` field, else a worker's `hid=`, else no name. `run/cmd` is `printf '%q'` of the repo's own arguments, so no position is reliable.
- Pill label and CSS state are separate values: `.s-running` and `.s-gpu` drive the brand glider, and a word with a space would break both.
- Class mapping: `thinking`, `coding`, `closing` → `running`; `on <place>` → `gpu`; `drained` → `held`; `needs you` → `blocked`.
- `drained` takes the `held` look, a ring with no fill. Red stays for failure alone.
- The head reads `0 of 3 workers` from `workers=` until the first worker job exists.
- The drained reason, first match: `drain`=`now`, `drain`=`drain`, `run/exit` 1 with `failed: smoke`, `run/exit` 124, a `usd=` refusal, `deadline=` passed.
- A drained question loses Stop question, keeps Stop now while a run lives, and gains Archive.
- `vibe queue status` prints the same line; spend stays one total with no `$/h` rate.
- The state line wraps on the phone. The box end time is the part a truncation would lose.

## Milestones

- [x] Spend counts the coordinator chain — code — done when `vibe queue status` prints a non-zero spend for tray-noise
- [x] `place_run` mirrors `started` and `limit` into `run/` — code — done when a new run's `queue/<id>/run/started` holds an epoch
- [x] State line, precedence and the drained reason — code — done when the tray-noise card line matches the order above
- [x] Pill label and CSS state split — code — done when the pill reads the state word and a live run still renders `s-gpu`
- [x] `PROGRESS` contract, the `Step:` fallback and the ETA — code — done when a log with two PROGRESS lines renders steps and an ETA
- [x] Head budget and the drained buttons — code — done when a drained question shows Archive and no Stop question
- [x] Docs and tests — code — done when `docs/vibe-queue.md` §Research card matches and `page_check.py` covers each new branch
- [x] End action

## End action

`delete`. Each decision moves to the PR body.
