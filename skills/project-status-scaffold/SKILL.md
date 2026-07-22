---
name: project-status-scaffold
description: Ensures every repo has an up-to-date PROJECT_STATUS.md (long-lived project state) and PROJECT_ROADMAP.md (planned work, one designed item per task), and each worktree a HANDOFF.md (short-lived session handoff), and keeps all three current. Use this skill whenever starting work in a repo that lacks these files, when the user says "scaffold status files", "set up handoff", "update project status", or "update the roadmap", AND proactively at the end of a work session to record what changed. Always check for and maintain these files when work moves between machines, worktrees, or sessions, even if the user does not explicitly ask.
---

# Project Status & Handoff Scaffold

This skill maintains three Markdown files that let work move cleanly across
sessions, worktrees, machines, and agents — so the next session can pick up
without re-reading the whole diff to work out where things stand.

## The three files (different lifespans)

- **PROJECT_STATUS.md** — lives at the **repo root**, long-lived. The durable
  *current* picture of the project: goal, architecture, key decisions, open
  questions. A snapshot, not a log — git history is the log. Key decisions
  are one dated line each with a pointer (commit or PR) to the full
  rationale; the reasoning itself lives in the commit/PR body, never here.
  Survives across all tasks and branches. Committed to git.
- **PROJECT_ROADMAP.md** — lives at the **repo root**, long-lived. Planned
  work, one item per task, each designed well enough that a session can pick
  it up cold. Same snapshot discipline as the status file: finished items are
  deleted, not checked off and kept — their trail is git history and the
  merged PR. Adding a well-designed item is the `add-roadmap-item` skill's
  job; this skill creates the file and prunes it.
- **HANDOFF.md** — lives at the **worktree root**, short-lived: the baton
  between sessions on one task. Strictly present tense — current state, next
  concrete action, blockers, unresolved gotchas. **Overwrite it each session,
  never append**; history and rationale belong in git, not the baton. One per
  worktree/branch, committed so it reaches other machines.

## When to act

1. **On entering a repo** — if `PROJECT_STATUS.md` or `PROJECT_ROADMAP.md` is
   missing at the repo root, create them by running `scaffold.sh` (fallback:
   render them by hand from the toolkit's `templates/` directory — see
   below). If `HANDOFF.md` is missing in the current worktree, create it too.
2. **On request** — user asks to scaffold, set up, or update these files.
3. **At the end of a work session (proactive)** — before wrapping up, update
   the files so the next session can pick up:
   - Rewrite `HANDOFF.md` (don't append): current state, next action,
     blockers, unresolved gotchas.
   - Update `PROJECT_STATUS.md` **only** when something durable changed: a
     new decision (one line + pointer), an architecture change.
   - Update `PROJECT_ROADMAP.md` when planned work changed shape: delete
     items this session finished, correct items whose design the session
     proved wrong.
4. **When a task finishes (branch merged or abandoned)** — the baton dies.
   Promote what is durable out of `HANDOFF.md` first: a gotcha that will bite
   again goes to the repo's agent-instructions file, a decision goes to the
   commit/PR body with a one-liner in `PROJECT_STATUS.md`. Then delete
   `HANDOFF.md` and sync. A finished task hands nothing off — left on the
   branch, even a cleared handoff merges into the default branch as a stray
   file, so tooling may refuse to tear the worktree down while the file is
   still there.

## How to create them

Prefer the bundled script. It is idempotent — it never overwrites an existing
file — and it renders all three documents from the canonical templates:

```bash
bash scaffold.sh          # scaffolds all three in the current repo/worktree
```

If the script cannot run, create the files by hand from the templates in the
toolkit's `templates/` directory:

- `templates/HANDOFF.md`
- `templates/PROJECT_STATUS.md`
- `templates/PROJECT_ROADMAP.md`

Read the template file and copy it, substituting the angle-bracket tokens
(`<repo>`, `<branch>`, `<worktree>`, `<date>`, `<machine>`). Those templates
are the single source of truth — do not reproduce their content here, and do
not invent a different structure. **Never overwrite an existing file**: if it
exists, read it and update the relevant sections instead.

## Updating vs. creating

- If `PROJECT_STATUS.md` or `PROJECT_ROADMAP.md` already exists, **read it
  first**, then edit the specific sections that changed. `HANDOFF.md` is the
  exception: rewrite its section contents each time — stale baton text is
  worse than none.
- Keep entries terse and factual. Prefer bullet points. Date decisions and
  point each one at the commit or PR that carries the full reasoning.
- In `PROJECT_ROADMAP.md`, delete finished items — the trail lives in git
  history and merged PRs, not in the snapshot.

## Done

Done when the files exist and read true for *right now*: `HANDOFF.md` names
the current state, the next concrete action, and any blockers;
`PROJECT_STATUS.md` reflects every durable change from this session;
`PROJECT_ROADMAP.md` carries no finished items. Stop there — committing,
pushing, and deleting a finished task's handoff belong to the task workflow
(`vibe sync` / `vibe done`), not to this skill. Designing and adding a new
roadmap item is the `add-roadmap-item` skill's job, not this one's.
