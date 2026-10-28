# Spec — agentic-dev-toolkit / feat/agent-queue

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `feat/agent-queue`
- **Written:** 2026-10-28

## Goal

One always-on job queue replaces the day and night shifts. Two skills, run at any time, review results and fill the queue.

## Non-goals

- The job itself: `job-prompt.md`, worktree per job, draft PR per job, the gate.
- The recurring-jobs catalogue, its due rule and its opt-in files.
- `gpu-queue`.

## Decisions

- One persistent queue dir; the runner waits when empty and never stops on its own — the shifts left windows unused when short jobs finished early.
- Sources only append: the `fill` skill (after approval), the 01:00 recurring dispatcher, GPU follow-ups.
- Heavy job = `timeout` > 2h; no new field.
- Night window, default `18:00-07:00`, one config line: heavy jobs start only in it, heavy first; by day light jobs only.
- Slots by window: day 2, night 4 — protects daytime rate limits and the GPU.
- `vibe queue add --now` overrides the window for one job.
- `fill` after 17:00 ranks heavy items first; it needs no other time logic.
- Two skills: `review` (today's `/check-in` phases 1–3), `fill` (today's `/agent-shift` sweep, gate, approval).
- Every decision view groups rows by repo, each row with its `Context` line: the `review` table and walk, the `fill` approval table, the status.
- `review` marks handled jobs; the status shows only unreviewed ones.
- CLI: `vibe queue add|status|run|pause|resume` replaces `vibe night`, no alias.
- The 07:00 and 13:00 briefing timers go; the status is on demand.

## Open questions (grill before M1)

- Mark reviewed: move the job dir to `archive/`, or a `reviewed` state file?
- The briefing copy to the vault (`briefing-dir`): on every status, on `review` only, or dropped?
- State dir: keep `~/.local/state/night-shift/`, or a new `agent-queue/` with the old nights left as they are?
- `/shutdown`: handoffs only, then it offers `fill`? `/check-in`: becomes `review`, or `review` then `fill`?
- Window and slots: one config file, or flags on the service?

## Milestones

- [ ] Runner: persistent queue, window rule, slots per window, `pause`/`resume` — code — done when `bats tests/` covers heavy-waits-by-day, heavy-first-at-night, slots per window
- [ ] `vibe queue add [--now]`; the dispatcher and GPU follow-ups append to the queue — code — done when `tests/agent-jobs.bats` queues into the one queue dir
- [ ] `vibe queue status`: rows grouped by repo with `Context`, unreviewed only — code — done when a bats test checks the grouping and the reviewed filter
- [ ] Skills `review` and `fill` from `check-in` and `agent-shift`; `shutdown` adjusted — code — done when `./bin/skill-lint --strict skills` passes and no skill names `vibe night`
- [ ] systemd: one `agent-queue.service`; the two report timers removed; `vibe update-toolkit` migrates the units — code — done when `tests/vibe.bats` unit tests pass and `grep -rn 'vibe night' .` finds nothing outside `vendor/`
- [ ] End action — rewrite `docs/night-shift.md` into `docs/agent-queue.md`; decisions into the PR body; delete `SPEC.md` and `HANDOFF.md`

## End action

`rewrite into docs/agent-queue.md` (what the code now is, not what was planned). Either way, each decision moves to the PR body.
