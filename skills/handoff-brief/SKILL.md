---
name: handoff-brief
description: "Distills the current conversation into a HANDOFF.md brief on its own task branch, ready for a dedicated session to pick up. Use when the user says 'hand this off', 'prepare a handoff', 'spin this off into a vibe task', or a discussion has produced a plan that a separate agent session should execute. Captures the conclusions — context, decisions, first concrete step — into the handoff, stages it on the task's branch and worktree, commits and pushes it, and prints the exact command to start the session, without ever starting it."
disable-model-invocation: true
argument-hint: "[<task name>]"
---

# Handoff brief

Turn the conversation that just happened into the baton a dedicated session
picks up cold. The brief is `HANDOFF.md` at the root of the task's own
worktree, committed and pushed so either machine can start the session; the
session runner (`vibe start`) adopts an existing worktree and never reseeds a
handoff that is already there.

This is the interactive sibling of `loop-brief`: same staging, but the
artifact is a handoff for a supervised session rather than a `LOOP.md` for an
unattended loop. If the task has a checkable stop condition and should run
unattended, use `loop-brief` instead.

## Hard boundaries — never do these

- **Never start the session.** No `vibe start`, no agent launch. The
  deliverable is the pushed handoff and the printed command — starting the
  session is the user's move.
- **Never write HANDOFF.md from memory or a heredoc.** `handoff.sh create`
  renders it from `templates/HANDOFF.md`; you only edit the rendered file.
- **Never overwrite a handoff that carries content.** `handoff.sh` reports
  one — show the user what is there and refine it in place.
- **Never touch a task whose loop is live.** `handoff.sh` refuses on its own
  — do not work around it by editing files directly.
- **Never force-push or resolve divergence.** If `handoff.sh publish` fails
  to push, report the error and stop.

## Phase 1 — Harvest the conversation

The raw material is the discussion that just happened, not new input. Collect
what was actually concluded: the goal, the approach chosen, alternatives
rejected and why, files or modules identified, constraints and gotchas that
surfaced. If the conversation has not reached a conclusion worth handing
off, say so instead of staging a vague brief.

Confirm you are inside a git repository with an `origin` remote — the
handoff travels through git, so a repo without a remote cannot hand off to
another machine or session.

A task name may arrive as `$ARGUMENTS`; otherwise pick a short one with the
user (it becomes the branch and worktree name).

## Phase 2 — Draft, then confirm

Draft the handoff's sections for a reader with *none* of this conversation's
context. Keep it tool-agnostic — it is written for "the next session", not
for a particular agent.

1. **State** — where the work stands now. For a fresh task that is: not
   started, plus the context the next session cannot recover on its own —
   what was decided, what was rejected and why, which files matter.
2. **Next action** — the first concrete step, specific enough to act on
   without having seen this discussion. Push back on vagueness here the way
   `loop-brief` pushes on the stop check: "implement the thing we discussed"
   hands off nothing.
3. **Blockers / Gotchas** — anything already known to be in the way, and
   surprises surfaced during the discussion. Leave a section's placeholder
   alone if there is genuinely nothing.

Show the draft as one piece and **wait for explicit approval before
Phase 3**.

## Phase 3 — Stage

Run the bundled script (resolve the path from this skill's directory):

```
bash handoff.sh create "<task>"
```

It creates the branch and worktree (adopting a branch that exists only on
origin) and seeds `HANDOFF.md` from the shared template. Read the
`KEY=VALUE` output:

- `STATE=created` or `STATE=existing-scaffold` — an empty handoff is ready;
  continue to Phase 4.
- `STATE=existing-handoff` — a handoff with real content exists (a task
  already in flight). Read it, show the user what is there, and merge the
  new conclusions into *that* file in Phase 4 instead of starting over.

## Phase 4 — Fill in the refined brief

Edit the `HANDOFF.md` the script printed as `HANDOFF_MD=`:

- Replace the italic placeholder under `## State` with the context from
  Phase 2.
- Replace the italic placeholder under `## Next action` with the first step.
- Fill `## Blockers` and `## Gotchas (unpromoted)` only if there is content
  for them.
- Leave the header metadata and section headings untouched.

## Phase 5 — Publish and hand off

Run:

```
bash handoff.sh publish "<task>"
```

It validates the handoff (no unrendered tokens, `## State` and
`## Next action` actually written), commits, and pushes. If validation fails
it names the unfinished section — fix it and retry.

Then print the start commands and stop:

```
vibe start <task>     # here — on the server this is a tmux session that survives disconnect
vibe attach <task>    # from the other machine, after a git fetch happens automatically
```

with one note: the session that picks this up must clear the handoff back to
its headings before finishing (`vibe done` enforces it), so the brief is
guaranteed to be consumed and promoted, never silently dropped.

**Done means:** the handoff is pushed and the command is printed. Do not
start the session, and do not keep refining after approval.
