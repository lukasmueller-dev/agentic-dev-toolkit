# Where information goes

Route everything you write by lifetime. Write it once at the lowest layer
whose lifetime fits; higher layers point down, never restate. Full
architecture: `~/github/agentic-dev-toolkit/docs/artifact-architecture.md`.

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
a one-liner in `PROJECT_STATUS.md` — then delete `HANDOFF.md` (`git rm`,
commit, push). Left on the branch, even a cleared handoff merges into the default
branch as a stray file; CI fails on one.

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

All work lives on one always-on workstation. Each repo there runs a
persistent agent server; I start, steer and finish sessions from a phone or a
browser. Setup and traps: `~/github/agentic-dev-toolkit/docs/remote-sessions.md`.

- Every session gets its own git worktree and branch under
  `<repo>/.claude/worktrees/`; the server removes it when the session ends
  clean. The `worktree-cleanup` skill removes the merged ones that are left.
- The toolkit is installed from `~/github/agentic-dev-toolkit` by symlink, so
  `git pull` updates the installed tools in place.

## What this means for you

**The handoff carries context from one session to the next.** A new session,
a `/clear`, or the next day starts cold; anything not written down is lost.

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

**Prefer commands that survive the session.** Long-running work (training,
large builds) belongs in its own `tmux` session or job, not in a foreground
process of the agent.

# Tool traps

- A second `uv sync` while one runs blocks silently on the cache lock. Check
  for a running one by its output; never start a second to retry.
- `kill $(pgrep -f <pattern>)` also kills the calling shell (exit 144). Read
  the pid first, then kill it.
- `tmux has-session -t name` prefix-matches. Use `-t '=name'`.
- `git push` fails now and then with `signing failed ... communication with
  agent failed`. Retry once; else ask me to run it.

# Working on the toolkit itself

When the repo in question *is* `agentic-dev-toolkit`, its own instruction file
at the repo root takes precedence — it documents the skill-authoring
conventions, the installer's auto-discovery contract, and the shellcheck-clean
requirement.
