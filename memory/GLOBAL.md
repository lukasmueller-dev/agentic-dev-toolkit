# Where information goes

Route everything you write by lifetime. Write it once at the lowest layer
whose lifetime fits; higher layers point down, never restate. Full
architecture: `~/git/agentic-dev-toolkit/docs/artifact-architecture.md`.

| Information                                            | Home                                     |
| ------------------------------------------------------ | ---------------------------------------- |
| Progress notes, end-of-task summary                    | chat (evaporates — nothing lives *only* here) |
| Current task state, next action, blockers, gotchas     | `HANDOFF.md` — overwrite, never append   |
| Why a change was made, alternatives rejected           | commit body (be verbose here)            |
| Task intent, what to verify, risks                     | PR description (detail in `<details>`)   |
| Durable picture: goal, architecture, decisions, TODOs  | `PROJECT_STATUS.md` (snapshot, not a log) |
| Decision rationale referenced from PROJECT_STATUS      | commit/PR body — status holds one line + pointer |
| Rules that should change agent behavior                | the repo's instruction file (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) |
| Deep narrative on one topic                            | `docs/`                                  |

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

# My setup

I work across two machines on the same repos, and this shapes what "done" means
for a work session.

- **Mac (local)** — where I usually start. Interactive work, no tmux forced.
- **Linux VPS (server)** — reached over SSH. Every task runs in its own
  persistent `tmux` session, so an agent keeps working after I disconnect. I
  reattach later from the laptop or from my phone.

Both machines run the same toolkit from `~/git/agentic-dev-toolkit`, installed
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
  decision, an architecture change, a TODO opened or closed.
- The `project-status-scaffold` skill handles both. Let it.

**Nothing uncommitted crosses machines.** The handoff travels through git.
Uncommitted work on the Mac is invisible on the VPS. If a session ends with
work worth keeping, it needs to be committed and pushed (`vibe sync`).

**Prefer commands that survive a disconnect.** On the server, long-running work
belongs in the task's tmux session, not in a foreground process attached to my
SSH connection.

## Environment detection

`vibe` decides local-vs-server from `$SSH_CONNECTION` / `$SSH_TTY`, falling
back to comparing the hostname against `$VIBE_SERVER_HOSTNAME`. If a command
behaves as though it is on the wrong machine, that is the thing to check —
`vibe where` prints the verdict and the reason for it.

# Working on the toolkit itself

When the repo in question *is* `agentic-dev-toolkit`, its own instruction file
at the repo root takes precedence — it documents the skill-authoring
conventions, the installer's auto-discovery contract, and the shellcheck-clean
requirement.
