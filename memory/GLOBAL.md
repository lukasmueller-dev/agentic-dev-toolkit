# Where information goes

Route everything you write by lifetime. Write it once at the lowest layer
whose lifetime fits; higher layers point down, never restate. Full
architecture: `~/git/agentic-dev-toolkit/docs/artifact-architecture.md`.

| Information                                            | Home                                     |
| ------------------------------------------------------ | ---------------------------------------- |
| Progress notes, end-of-task summary                    | chat (evaporates — nothing lives *only* here) |
| Current task state, next action, blockers, gotchas     | `HANDOFF.md` — overwrite, never append   |
| Why a change was made, alternatives rejected           | commit body — one line per reason        |
| Task intent, what to verify, risks                     | PR description (detail in `<details>`)   |
| Durable picture: goal, architecture, decisions         | `PROJECT_STATUS.md` (snapshot, not a log) |
| Planned work                                           | `PROJECT_ROADMAP.md` — task + done-when per item; finished items deleted |
| Decision rationale referenced from PROJECT_STATUS      | commit/PR body — status holds one line + pointer |
| Rules that should change agent behavior                | the repo's instruction file (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) |
| One topic in depth (still scannable)                   | `docs/`                                  |

**End-of-task summaries are ≤6 lines**: what changed, what to verify, and a
mandatory `Decisions/risks:` line ("none" if none) — surprises, judgment
calls made on my behalf, anything hard to reverse. Each line says where the
detail lives instead of restating it. If a summary wants to be longer, the
overflow belongs in an artifact, not in chat.

**Before a task ends, the handoff must be gone.** Promote what is durable —
recurring gotcha → the repo's instruction file; decision → commit/PR body plus
a one-liner in `PROJECT_STATUS.md` — then delete `HANDOFF.md` (`git rm`, then
sync). Left on the branch, even a cleared handoff merges into the default
branch as a stray file. `vibe done` refuses while the handoff still carries
content, and again while the file is still on the branch.

# Write for scanning, not reading

Repo prose — README, docs, recipes, status and roadmap files, code comments,
docstrings, TOML comments — is scanned, not read. Assume nobody reads a
paragraph. Commit and PR bodies are the same: a few one-line facts each.

- Keep only: commands, tables, measured numbers, and one-line traps
  (symptom + fix). Delete rationale, history, narrative and "why this
  matters" unless the reader would type something different without it.
- Never restate across files. One home per fact; other files link to it.
- Bring-up recipes: `## Requirements`, then `## 1.` … `## N. Verify`, then
  `## What breaks it` as bullets. Each step is a code block plus at most two
  lines.
- Code comments and docstrings: one line, what not why. A trap gets one line
  naming the symptom and the fix. No module-level essays.
- Status/roadmap files: one line per decision or open question plus a
  pointer. Roadmap items are task + done-when, no design discussion.
- Rewriting is the default, not trimming: when asked to cut, rewrite the file
  from its facts and aim for a third of the original length.
- Chat can carry explanation; the repo cannot. Add rationale only when asked.

# My setup

I work across several machines on the same repos, and this shapes what "done"
means for a work session. How many there are does not matter; what matters is
the role each one plays in a given session:

- **local** — a machine I am sitting at. Interactive work, no tmux forced.
- **server** — a machine I reach over SSH, where work has to outlive the
  connection. Every task runs in its own persistent `tmux` session, so an agent
  keeps working after I disconnect. I reattach later from any other machine, or
  from my phone.

The role is per-session, not a fixed label on a box: the same machine is
"local" when I sit at it and "server" when I SSH into it, and the operating
system is irrelevant to the split.

Every machine runs the same toolkit from `~/git/agentic-dev-toolkit`, installed
by symlink, so `git pull` updates the installed tools in place.

`vibe` is the CLI that drives this: one git branch + one git worktree per task,
under `$VIBE_WORKTREE_ROOT/<repo>/<task>` (default `~/git/worktrees`). Run
`vibe help` for the commands and `vibe doctor` when something looks wrong.

## What this means for you

**The handoff is the product of a session, not an afterthought.** Because work
moves between machines, anything you know that is not written down is lost when
the session ends. Concretely:

- Keep `HANDOFF.md` (worktree root) current — where the work stands and what
  the next session should do first. Update it *before* I wrap up, not after I
  ask.
- Update `PROJECT_STATUS.md` (repo root) only when something durable changed: a
  decision or an architecture change. Planned work lives in
  `PROJECT_ROADMAP.md` — delete items a session finishes; add new ones through
  the `add-roadmap-item` skill where it is available: task + done-when, one
  item per task.
- Where the `project-status-scaffold` skill is available, it scaffolds and
  maintains these files — let it. Without that skill, keep them current by
  hand, per the table above.

**Nothing uncommitted crosses machines.** The handoff travels through git.
Uncommitted work on one machine is invisible everywhere else. If a session ends
with work worth keeping, it needs to be committed and pushed (`vibe sync`).

**Prefer commands that survive a disconnect.** On the server, long-running work
belongs in the task's tmux session, not in a foreground process attached to my
SSH connection.

## Environment detection

`vibe` decides local-vs-server per machine, from `$SSH_CONNECTION` / `$SSH_TTY`,
falling back to comparing the hostname against `$VIBE_SERVER_HOSTNAME` — which
each machine sets to *its own* hostname when it should count as a server. If a
command behaves as though it is on the wrong machine, that is the thing to check —
`vibe where` prints the verdict and the reason for it.

# Working on the toolkit itself

When the repo in question *is* `agentic-dev-toolkit`, its own instruction file
at the repo root takes precedence — it documents the skill-authoring
conventions, the installer's auto-discovery contract, and the shellcheck-clean
requirement.
