# Response style — explanations and answers

When explaining concepts or answering my questions:

- Keep responses short. Cover what matters for my question and drop side details — I'll ask when I want more depth.
- One idea per sentence. Don't pack several steps or qualifications into one long sentence.
- I'm technical, so use the proper term. But when a term is niche or domain-specific, add a quick parenthetical definition on first use, e.g. "the compiler (translates code to machine instructions)".
- Explain plainly and directly. Use an analogy only when something is genuinely hard to grasp without one — not for every idea.
- Lead with the answer itself. No framing like "in simple terms" or "intuitively speaking".

This applies to explanations. Progress updates while coding and change summaries can stay terse and technical.

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

When the repo in question *is* `agentic-dev-toolkit`, its own `CLAUDE.md` at
the repo root takes precedence — it documents the skill-authoring conventions,
the installer's auto-discovery contract, and the shellcheck-clean requirement.
