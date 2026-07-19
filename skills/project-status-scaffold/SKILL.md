---
name: project-status-scaffold
description: Ensures every repo has an up-to-date PROJECT_STATUS.md (long-lived project state) and each worktree a HANDOFF.md (short-lived session handoff), and keeps them current. Use this skill whenever starting work in a repo that lacks these files, when the user says "scaffold status files", "set up handoff", or "update project status", AND proactively at the end of a work session to record what changed. Always check for and maintain these two files when working across the Mac-local / Linux-server vibe workflow, even if the user does not explicitly ask.
---

# Project Status & Handoff Scaffold

This skill maintains two Markdown files that let work move cleanly between the
Mac (local) and the Linux server, and across sessions/agents.

## The two files (different lifespans)

- **PROJECT_STATUS.md** — lives at the **repo root**, long-lived. The durable
  picture of the project: goal, architecture, key decisions, TODOs, open
  questions. Survives across all tasks and branches. Committed to git.
- **HANDOFF.md** — lives at the **worktree root**, short-lived. "Where am I
  right now, what should the next session (on the other machine) do first."
  One per worktree/branch. Usually git-ignored or committed per taste.

## When to act

1. **On entering a repo** — if `PROJECT_STATUS.md` is missing at the repo root,
   create it from the template below (or run `scaffold.sh`). If `HANDOFF.md` is
   missing in the current worktree, create it too.
2. **On request** — user asks to scaffold, set up, or update these files.
3. **At the end of a work session (proactive)** — before wrapping up, update
   both files so the other machine can pick up:
   - Update `HANDOFF.md`: current status, next steps, open PRs, gotchas.
   - Update `PROJECT_STATUS.md` **only** when something durable changed: a new
     decision, an architecture change, a TODO completed or added.

## How to create them

Prefer the bundled script, which is idempotent (never overwrites an existing
file):

```bash
bash scaffold.sh          # scaffolds both in the current repo/worktree
```

If the script is unavailable, create the files by hand from the templates
below. **Never overwrite an existing file** — if it exists, read it and update
the relevant sections instead.

## Updating vs. creating

- If a file already exists, **read it first**, then edit the specific sections
  that changed. Do not regenerate it from scratch — you would lose history.
- Keep entries terse and factual. Prefer bullet points. Date decisions.
- In `PROJECT_STATUS.md`, move finished TODOs to a short "Done" note rather
  than deleting them, so the trail is visible.

## PROJECT_STATUS.md template

```markdown
# Project Status — <repo>

_Last updated: <date> · <machine>_

## Goal
_What is this project trying to achieve? One or two sentences._

## Architecture
_Key components and how they fit together. Update when structure changes._

## Key decisions
_Dated, one line each. Why we chose X over Y._
- <date>: ...

## TODOs
- [ ] ...

## Open questions
_Unresolved things that block or shape the work._
- ...
```

## HANDOFF.md template

```markdown
# Handoff — <repo> / <branch>

_Last updated: <date> · <machine>_

## Current status
_What state is the work in right now?_

## Next steps
_What should the next session (on either machine) do first?_

## Open PRs / branches
_Links or numbers. `vibe status` refreshes this._

## Notes / gotchas
_Anything that would bite the other machine._
```
