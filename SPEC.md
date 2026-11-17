# Spec — agentic-dev-toolkit / research-card

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-card`
- **Written:** 2026-11-17

## Goal

The queue page shows one card per research question, with one row per worker, a paste panel for IAS and two stop buttons.
Feature: ~/.local/state/vibe/features/parallel-research.md

## Non-goals

see the feature file

## Decisions

see the feature file

## Milestones

- [x] A `Research` group below `Features`: one card per `research=` slug. Header: question, best metric with its hid, USD spent of `usd`, deadline, `waits for` (`you (paste <hid>)`, `GPU`, `coordinator`, `nothing`). One row per worker: state, place, last step, metric, USD, idea; a `builds=<hid>` row sits indented below its parent. Desk first, the look of the page as it is, no new color. Built on fixture job dirs. — code — done when `bats tests/vibe-queue.bats` and `python3 tests/page_check.py` pass with a fixture of 1 coordinator and 4 workers.
- [x] `vibe queue status` and the report: one row per question (`2/5`), and the place on each worker row. — code — done when `bats tests/vibe-queue.bats` passes with a status test on the same fixture.
- [ ] Paste panel and stop: a blocked worker with `paste.md` shows its steps with a copy button each and one field that posts to `answer`. Buttons `Stop question` and `Stop now ✓` post to the routes `research-stop` and `research-stop-now`. The Page actions table has the 3 new rows. — code — done when `bats tests/vibe-web.bats` passes with a test per route's argv.
- [ ] End action. — code — done when `git ls-files SPEC.md HANDOFF.md` prints nothing.

## End action

delete
