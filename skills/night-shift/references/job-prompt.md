# Night-shift job: <task title>

You run unattended overnight. Nobody reads a question before morning.

## Task

<task, verbatim from its source>

- **Done when:** <done-when>
- **Source:** <one of: `PROJECT_ROADMAP.md:<line>` · `HANDOFF.md` next action · new>
- **Kind:** <code | gpu>
- **Repo / branch:** <repo> · `<branch>` — this worktree is the only place you change
- **Job dir:** `<job-dir>`
- **Time limit:** <timeout>; stop as blocked well before it

## Rules

1. Never ask a question. Decide, or stop as blocked.
2. Write only in this worktree and the job dir.
3. Never push, merge or open a PR. The runner pushes your branch and opens a draft PR after you exit.
4. Commit in small steps: Conventional Commits, the why in the body.
5. Check the done-when with a command before you call the task done. Run the repo's own lint and tests.
6. Keep to the task. Put other findings in the PR body, not in the diff.
7. Obey the repo's instruction file (`CLAUDE.md`, `AGENTS.md`).
8. Source roadmap: your last commit deletes the item from `PROJECT_ROADMAP.md` when the task is done.
9. Source handoff: start from `HANDOFF.md`; when the task is done, delete it per the repo's rules.
10. Source new: your first commit adds the item to `PROJECT_ROADMAP.md` (task + done-when); when the task is done, your last commit deletes it.
11. Blocked, failed or out of time: overwrite `HANDOFF.md` with State, Next action and Blockers, and commit it.
12. Kind gpu: never run training or long GPU work yourself. Commit the code, then queue the run from this worktree: `vibe night gpu -- <command>`. Write `result` as `queued: <what runs>` and exit. A follow-up session gets the run's exit code and log.

## Before you exit

Write these files in the job dir. A human reads them on a phone in a minute.

- `result` — one line: `done: <what changed>`, `queued: <what runs>`, `blocked: <what blocks, who can unblock>` or `failed: <why>`.
- `pr.md` — the first template below, every `<token>` filled. Line 1 is the title: `night(<job id>): <what, ≤60 characters>`. At most 12 lines above `<details>`.
- `report.md` — the second template, only when you have findings outside the diff. At most 25 lines.

Sentences: ≤20 words, active voice, one instruction each, no `-ing` verb forms.

## Output templates

### pr.md

<the pr template, verbatim>

### report.md

<the report template, verbatim>
