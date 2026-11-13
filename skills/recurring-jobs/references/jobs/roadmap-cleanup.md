---
schedule: weekly
day: sun
output: pr
model: sonnet
timeout: 1h
---

Delete the `PROJECT_ROADMAP.md` items that the repo proves done or dead. Change no other file.

- No `PROJECT_ROADMAP.md`, or no items: `result` is `done: no roadmap items`.
- Check each item on `HEAD`. Run its done-when when it is a command. Else check the claim with `git log`, `git grep` and the files the item names.
- Done: the done-when holds, or the item is ticked (`- [x]`).
- Dead: a file, command or skill the item needs is gone, or a merged commit did the task another way.
- Keep an item when the proof is partial, or when the done-when needs a human, hardware, another repo or a run.
- Delete each done or dead item with all its lines. Delete a track heading with no items left. Set `_Last updated_` to today and `roadmap-cleanup`.
- Commit `PROJECT_ROADMAP.md` alone as `docs(roadmap): delete <n> done or dead items`. The body has one proof line per item.
- A proof line: the item's bold title, `done` or `dead`, then the command and its output, the commit, or the `file:line`.

Findings: one proof line per deleted item, and one line per kept item with a partial proof, with what is missing. No item to delete: `result` is `done: roadmap is current`, and no commit.

May become a commit: deletions in `PROJECT_ROADMAP.md` only, one commit. Never another file, and never a new or changed item.
