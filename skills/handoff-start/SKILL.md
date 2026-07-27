---
name: handoff-start
description: "Distills the current conversation into a HANDOFF.md brief on its own task branch and then starts the session that picks it up. Use when the user says 'hand this off and start it', 'spin this off and run it', 'kick this off as its own task', or a discussion has produced a plan that should be handed to a separate session and begun now rather than left staged. Stages and pushes the brief exactly as handoff-brief does, then launches the session — detached on a server, or printing the command to run locally."
disable-model-invocation: true
argument-hint: "[<task name>]"
---

# Handoff start

Stage the baton and hand it over in one move. The brief is the same
`HANDOFF.md` that `handoff-brief` produces, on the same branch and worktree;
the only difference is who runs `vibe start` afterwards. Use this when the
work should begin now and the person staging it is not going to be the one
typing the command.

Reach for `handoff-brief` instead when the brief is meant to sit until
someone picks it up — a task for tomorrow, or for another machine.

## Hard boundaries — never do these

- **Never stage the brief here.** Phases 1–5 belong to `handoff-brief` and
  are not repeated in this file. Two copies of a five-phase procedure drift,
  and the one that drifts is always the copy.
- **Never launch against an unpushed brief.** A session started before
  `handoff.sh publish` succeeds cannot be picked up from another machine, and
  the handoff it starts from exists nowhere but this disk.
- **Never launch a session locally.** Off a server `vibe start` opens an
  interactive session in the terminal *this* session is using — print the
  command and let the user run it.
- **Never keep working on the task after launching.** The launched session
  owns the branch and the worktree from that moment; two agents on one branch
  is a merge conflict with extra steps.

## Phase 1 — Stage the brief, exactly as `handoff-brief` does

Read `../handoff-brief/SKILL.md` — a sibling of this skill's own directory,
wherever it is installed — and follow its Phases 1 through 5 in full: harvest, draft, **wait for explicit approval**, `handoff.sh create`,
fill in the brief, `handoff.sh publish`. Its hard boundaries apply here too,
with one exception — its "never start the session" rule is the one thing this
skill replaces.

Stop at the point where it prints the start commands. That is Phase 2's job.

## Phase 2 — Launch it

Only once `handoff.sh publish` has reported success. Check which kind of
machine this is — `vibe where` prints the verdict and its reason — and branch
on it:

- **Server** (output begins `server`): start the session without attaching,
  because this session has no terminal to hand over.

  ```
  vibe start <task> --no-attach
  ```

  It creates the tmux session, launches the agent, and returns. Because
  nobody is attaching, that session begins from `HANDOFF.md` on its own
  rather than waiting at an idle prompt. Report that it is running and print
  how to reach it:

  ```
  vibe attach <task>    # from here or any other machine
  ```

- **Local** (output begins `local`): print the command and stop — `vibe
  start` opens an interactive session, which is the user's to run.
  `--no-attach` is rejected off a server, so there is no way to launch it
  from here.

  ```
  vibe start <task>
  ```

  A session someone attaches to opens with the handoff already in context and
  waits for them to say go.

Close with one note either way: the session that picks this up must promote
what is durable and delete the handoff before finishing (`vibe done` enforces
it), so the brief is guaranteed to be consumed and promoted, never silently
dropped — and never merged onto the default branch as a stray file.

**Done means:** the handoff is pushed, and on a server the session is running
detached with its attach command printed; locally, the start command is
printed. Either way this session stops touching the task.
