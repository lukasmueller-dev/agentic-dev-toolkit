---
name: loop-brief
description: "Refines a rough task idea into a precise brief for an unattended agent loop and stages it on its own task branch, ready to run. Use when the user says 'set up a loop brief', 'prepare a loop', 'draft a LOOP.md', or wants to turn a feature idea into an unattended run with a checkable stop condition. Interactively pins down the goal, an executable done-check, hard constraints, and a round budget; then creates the branch and worktree, renders LOOP.md from the shared template, commits and pushes it — and prints the exact command to start the loop, without ever starting it."
disable-model-invocation: true
argument-hint: "<rough task idea>"
---

# Loop brief

Turn a rough idea into the brief an unattended loop agent is handed every
round. The brief is `LOOP.md` at the root of the task's own worktree,
committed and pushed so either machine can start the loop; the loop runner
(`vibe loop`) finds an existing `LOOP.md` and uses it instead of seeding a
blank one.

## Hard boundaries — never do these

- **Never start the loop.** No `vibe loop`, no headless agent invocation. The
  deliverable is the pushed brief and the printed command — starting the run
  is the user's move.
- **Never write LOOP.md from memory or a heredoc.** `brief.sh create` renders
  it from `templates/LOOP.md`; you only edit the rendered file.
- **Never touch a task whose loop is live.** `brief.sh` refuses on its own —
  do not work around it by editing files directly.
- **Never force-push or resolve divergence.** If `brief.sh publish` fails to
  push, report the error and stop.

## Phase 1 — Understand the idea

The rough idea arrives as `$ARGUMENTS`; if it is empty, ask for it. Confirm
you are inside a git repository with an `origin` remote — the brief travels
through git, so a repo without a remote cannot hand off to another machine.

Pick a short task name with the user (it becomes the branch and worktree
name). Explore the codebase as needed to ground the next phase in reality —
a brief written without reading the code produces a loop that flails.

## Phase 2 — Refine, then confirm

Iterate with the user until all four are pinned down. Push back on vagueness:
the agent running the loop gets *only* this brief, with no one watching.

1. **Goal** — one concrete paragraph. What "working" looks like, not a list
   of activities. Name the files or modules involved if known.
2. **Done when** — the single checkable condition. Push hard for an
   *executable* stop check usable as `--until '<cmd>'`: a test command, a
   grep, a build step. If the command is safe and read-only, run it now and
   confirm it currently **fails** — a stop check that already passes would end
   the loop on round one. If no executable check exists, say plainly that the
   loop will then only stop on max rounds or stall.
3. **Constraints** — what the unattended agent must NOT do: files to leave
   alone, scope limits, commands that are off-limits. Anything not ruled out
   here is permitted.
4. **Budget** — max rounds (default 10), and whether each round should push
   (`--push`, recommended so progress is visible from another machine).

Show the four answers together as the draft brief and **wait for explicit
approval before Phase 3**.

## Phase 3 — Stage

Run the bundled script (resolve the path from this skill's directory):

```
bash brief.sh create "<task>" --until '<cmd>' --max <n>
```

It creates the branch and worktree (adopting a branch that exists only on
origin), renders `LOOP.md` from the shared template, and seeds `HANDOFF.md`.
Read the `KEY=VALUE` output:

- `STATE=created` — fresh brief; continue to Phase 4.
- `STATE=existing-brief` — a brief already exists (perhaps from a maxed or
  stalled earlier run). Read it, show the user what is there, and refine
  *that* file in Phase 4 instead of starting over.

## Phase 4 — Fill in the refined brief

Edit the `LOOP.md` the script printed as `LOOP_MD=`:

- Expand `## Goal` to the refined paragraph from Phase 2.
- Replace the italic placeholder under `## Done when` with the refined
  condition (mention the stop-check command and what it proves).
- Replace the italic placeholder under `## Constraints` with the refined
  list.
- Leave the header metadata and the `## Iteration log` placeholder untouched
  — the loop maintains the log.

## Phase 5 — Publish and hand off

Run:

```
bash brief.sh publish "<task>"
```

It validates the brief (no unrendered tokens, no placeholder left in the two
refined sections), commits, and pushes. If validation fails it names the
unfinished section — fix it and retry.

Then print the exact start command and stop:

```
vibe loop <branch> --until '<cmd>' --max <n> [--push]
```

with three notes: run it **on the server** for a tmux-detached session that
survives disconnect (locally it runs in the foreground); when starting it
from inside another agent session (remote-controlled from a phone, or any
script), append `--no-attach` so the command returns instead of attaching;
and if the stop check contains single quotes, re-quote it for the shell
before running.

**Done means:** the brief is pushed and the command is printed. Do not start
the loop, and do not keep refining after approval.
