---
name: recurring-jobs
description: "Lists, installs and checks the recurring agent jobs that run unattended on a schedule (a weekly codebase-health sweep, stale-state check, toolkit self-check): shows the catalogue and what is due per repo, opts a repo into a job, runs one now, installs the 01:00 timer. Use when the user says 'recurring jobs', 'agent jobs', 'scheduled jobs', 'weekly sweep', 'opt this repo into', 'which jobs are due', 'run the health job now', or wants a job to run on its own every night or week."
disable-model-invocation: true
argument-hint: "[list | add <job> | run <job> | timer]"
---

# Recurring jobs

A recurring job is a prompt plus a schedule. The 01:00 timer queues every
due job on the night runner; the morning report shows the result. Runner,
layout and traps: `docs/recurring-jobs.md` in the toolkit.

## Hard boundaries — never do these

- **Never run a job yourself.** You list, install and queue; `vibe night` runs the jobs.
- **Never overwrite `.agent-jobs/<job>.md`.** `vibe job add` refuses an existing file; edit it instead.
- **Never write a catalogue entry from memory.** Copy `references/jobs/_template.md`.
- **Never queue a job without saying which repo and job.** `vibe job run` is a real start.

## Phase 1 — Show the state

1. Catalogue: one line per `references/jobs/<job>.md` — name, `schedule`, `day`, `output`, the first body line.
2. Per repo: `vibe job list` (every repo under `~/github` with `.agent-jobs/`, or named). Show its table as is.
3. Timer: `systemctl --user list-timers agent-jobs.timer`; say "not installed" when it prints no row.

## Phase 2 — Act on what the user asked

- **`add <job>`** in the current repo (or a named one): `vibe job add <repo> <job>`. Then edit
  the new file: keep only the keys the repo overrides, write one line per repo-specific
  instruction. Ask the user to commit it.
- **`run <job>`**: outside the sandbox, `vibe job run --claude <repo> <job>`. Report the
  job dir it printed and `vibe night status`.
- **`timer`**: outside the sandbox, the two `systemctl --user` lines from `docs/recurring-jobs.md` §3.
- **A new catalogue job**: copy `references/jobs/_template.md` to `references/jobs/<job>.md`
  in the toolkit checkout; fill the frontmatter and the body. The body is the task: what to
  check, what counts as a finding, what may become a commit. Add a `tests/` row only when the
  job needs a runner change.

## Phase 3 — Check

`vibe job due --claude --dry` lists what the next 01:00 run queues. Show it.

## Done

Done when the user has the table, and the change they asked for is on disk
(the repo file, the catalogue entry, or the timer). Report in 3 lines: what
changed, what the next 01:00 run queues, what to commit.
