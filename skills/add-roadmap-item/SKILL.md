---
name: add-roadmap-item
description: "Distills a discussed idea into a designed item in PROJECT_ROADMAP.md — goal, approach, constraints, what done looks like — queued for a later session instead of started now. Use when the user says 'add this to the roadmap', 'roadmap this', 'add a roadmap item', 'queue this for later', or a discussion has scoped future work that should be captured before the context evaporates. Creates the roadmap file from the canonical template when the repo lacks one."
disable-model-invocation: true
argument-hint: "[<item name>]"
---

# Add a roadmap item

Turn the idea that was just discussed into an item in `PROJECT_ROADMAP.md`
(repo root) that a future session can pick up cold. The bar for an item: it
carries enough design that a task brief — a handoff for a supervised session
or a loop brief for an unattended one — can be staged from it *without the
discussion that produced it*.

## Hard boundaries — never do these

- **Never start the work.** The deliverable is the roadmap entry. No
  branches, no worktrees, no implementation — queueing is the point.
- **Never write PROJECT_ROADMAP.md from memory or a heredoc.** If the file
  is missing, run `scaffold.sh` from the `project-status-scaffold` skill (a
  sibling directory of this one), or render `templates/PROJECT_ROADMAP.md`
  by hand per the placeholder contract. You only ever *edit* the rendered
  file.
- **Never delete, reorder, or rewrite existing items** unless the user asks.
  Pruning finished items belongs to `project-status-scaffold`.
- **Never absorb rationale into the item.** The item holds the conclusion
  and a pointer; the reasoning lives in the commit/PR body or the discussion
  it links to.

## Phase 1 — Harvest

The raw material is the discussion that just happened. Collect what was
actually concluded: the goal, the approach chosen, alternatives rejected and
why, constraints, files or modules identified, and how the result would be
verified. If any of goal, approach, or verification is missing, ask —
inventing design the discussion never settled produces an item that lies to
the session that picks it up.

## Phase 2 — Design the item

Shape the harvest into one checkbox item:

- **Name and one-line goal** first — what exists when the item is done.
- **Design bullets** — approach, constraints, touchpoints, and rejected
  alternatives worth a line so they are not re-litigated.
- **What "done" looks like** — observable, not aspirational; if the work
  could run unattended, this is its stop check.
- **A pointer** to fuller rationale (PR, commit, issue) when one exists.

One item is one task, sized for a single PR. If the harvest describes more
than that, split it and say so.

## Phase 3 — Place and write

1. If `PROJECT_ROADMAP.md` is missing, create it (see boundaries above).
2. Read the existing file. Choose placement: an existing track if the item
   extends its theme, the flat item list otherwise; start a new track only
   when ordering against other new work matters.
3. Check the new item against what is already there — a duplicate or a
   contradiction with an existing item is a finding to raise, not silently
   merge.
4. Write the item, update the file's `Last updated` line, and show the user
   the entry as written.

## Done

Done when the item is in `PROJECT_ROADMAP.md` and would read true to a
session with none of today's context. Stop there — committing and pushing
belong to the task workflow, and starting the work belongs to whoever picks
the item up.
