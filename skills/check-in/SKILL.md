---
name: check-in
description: "Check-in on the vibe queue, at any time of day: reviews the finished jobs (mark ready, answer and requeue, hold, close) with the review-jobs skill, then tops the queue up with the fill-queue skill. Use when the user says 'check in', 'morning check-in', 'what did the agents do', 'go through the briefing', or starts a work block and wants the results triaged and the queue full."
disable-model-invocation: true
---

# Check-in

Review what the agents finished, then keep the queue full. Queue layout:
`docs/vibe-queue.md` in the toolkit.

## Hard boundaries — never do these

- **Never skip a phase's approval gate.** Each skill below keeps its own.
- **Never start a session.** Rows that need the user stay held in the queue.

## Phase 1 — Review

Read `../review-jobs/SKILL.md` and do every phase of it.

## Phase 2 — Fill

Read `../fill-queue/SKILL.md` and do every phase of it. The user declines → stop.

## Done

Done when both skills are done or declined. Report in at most 6 lines:
merged, requeued, held, closed, jobs added, and `Decisions/risks:`.
