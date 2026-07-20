---
name: project-status-scaffold
description: Ensures every repo has an up-to-date PROJECT_STATUS.md (long-lived project state) and each worktree a HANDOFF.md (short-lived session handoff), and keeps them current. Use this skill whenever starting work in a repo that lacks these files, when the user says "scaffold status files", "set up handoff", or "update project status", AND proactively at the end of a work session to record what changed. Always check for and maintain these two files when work moves between machines, worktrees, or sessions, even if the user does not explicitly ask.
---

# Project Status & Handoff Scaffold

This skill maintains two Markdown files that let work move cleanly across
sessions, worktrees, machines, and agents — so the next session can pick up
without re-reading the whole diff to work out where things stand.

## The two files (different lifespans)

- **PROJECT_STATUS.md** — lives at the **repo root**, long-lived. The durable
  *current* picture of the project: goal, architecture, key decisions, TODOs,
  open questions. A snapshot, not a log — git history is the log. Key
  decisions are one dated line each with a pointer (commit or PR) to the full
  rationale; the reasoning itself lives in the commit/PR body, never here.
  Survives across all tasks and branches. Committed to git.
- **HANDOFF.md** — lives at the **worktree root**, short-lived: the baton
  between sessions on one task. Strictly present tense — current state, next
  concrete action, blockers, unresolved gotchas. **Overwrite it each session,
  never append**; history and rationale belong in git, not the baton. One per
  worktree/branch, committed so it reaches other machines.

## When to act

1. **On entering a repo** — if `PROJECT_STATUS.md` is missing at the repo root,
   create it from the template below (or run `scaffold.sh`). If `HANDOFF.md` is
   missing in the current worktree, create it too.
2. **On request** — user asks to scaffold, set up, or update these files.
3. **At the end of a work session (proactive)** — before wrapping up, update
   both files so the next session can pick up:
   - Rewrite `HANDOFF.md` (don't append): current state, next action,
     blockers, unresolved gotchas.
   - Update `PROJECT_STATUS.md` **only** when something durable changed: a new
     decision (one line + pointer), an architecture change, a TODO completed
     or added.
4. **When a task finishes (branch merged or abandoned)** — the baton dies.
   Promote what is durable out of `HANDOFF.md` first: a gotcha that will bite
   again goes to the repo's agent-instructions file, a decision goes to the
   commit/PR body with a one-liner in `PROJECT_STATUS.md`. Then clear
   `HANDOFF.md` back to its headings and sync. A finished task hands nothing
   off — tooling may refuse to tear the worktree down while the handoff still
   carries content.

## How to create them

Prefer the bundled script. It is idempotent — it never overwrites an existing
file — and it renders both documents from the canonical templates:

```bash
bash scaffold.sh          # scaffolds both in the current repo/worktree
```

If the script cannot run, create the files by hand from the templates in the
toolkit's `templates/` directory:

- `templates/HANDOFF.md`
- `templates/PROJECT_STATUS.md`

Read the template file and copy it, substituting the angle-bracket tokens
(`<repo>`, `<branch>`, `<worktree>`, `<date>`, `<machine>`). Those templates
are the single source of truth — do not reproduce their content here, and do
not invent a different structure. **Never overwrite an existing file**: if it
exists, read it and update the relevant sections instead.

## Updating vs. creating

- If `PROJECT_STATUS.md` already exists, **read it first**, then edit the
  specific sections that changed. `HANDOFF.md` is the exception: rewrite its
  section contents each time — stale baton text is worse than none.
- Keep entries terse and factual. Prefer bullet points. Date decisions and
  point each one at the commit or PR that carries the full reasoning.
- In `PROJECT_STATUS.md`, delete finished TODOs — the trail lives in git
  history and merged PRs, not in the snapshot.
