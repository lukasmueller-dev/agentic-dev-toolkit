---
name: agent-shift
description: "Plans and starts unattended overnight work across the active repos: sweeps roadmap items and handoff next actions, keeps only what can run without a human, ranks it, and after approval starts one headless agent job per item, each ending in a draft PR. Big work — the user's items and up to 3 proposals, a feature, a migration, a GPU run — is specified in a grilling session into a SPEC.md first. With `day`, the same as a shorter day shift that stops by 12:30. Use when the user says 'night shift', 'what can run overnight', 'plan the night', 'queue work for tonight', 'plan the day shift', or wraps up the day and wants idle tokens or GPU hours used."
disable-model-invocation: true
argument-hint: "[day] [<repo>...]"
---

# Night shift

Sweep the active repos, gate and rank what can run unattended,
get approval, start the jobs. Runner, layout and traps:
`docs/night-shift.md` in the toolkit.

| Shift | Night dir | Time limit | Start flags |
| --- | --- | --- | --- |
| night (default) | `<YYYY-MM-DD>` | 3h | `--until 06:30 --timeout 3h` |
| `day` (from `/check-in`) | `<YYYY-MM-DD>-day` | 2h | `--until 10:30 --timeout 2h` |

The first argument `day` picks the day shift; every phase below is the same.

## Hard boundaries — never do these

- **Never start a job without explicit approval of the list.**
- **Never change a repo yourself.** You write only the night dir, and in Phase 0 a new branch's `SPEC.md` and `HANDOFF.md`; the jobs do the work.
- **Never write a `SPEC.md` without a grilling the user took part in.**
- **Never list an item that fails the gate.** Show it under "Rejected" with the reason.
- **Never plan more than** 8 jobs, 2 per repo, 1 on Opus. The rest default to Sonnet. A `SPEC.md` job does not count.
- **Never plan GPU runs that cannot finish by the deadline together.** They run one at a time.

## Phase 0 — Big work

The user says skip → go to Phase 1.

1. Ask for the user's big work items: a feature, a migration, a GPU run.
2. Propose up to 3 more from the repos' goals, roadmaps and gaps, one line each.
3. For each item the user picks, run the `grilling` skill with the user until every
   section of `templates/SPEC.md` (toolkit) has an answer.
4. Outside the sandbox: `git -C <repo> worktree add -b <slug> <repo>/.claude/worktrees/<slug>`.
   Write `SPEC.md` from the template and `HANDOFF.md` from `templates/HANDOFF.md`;
   its next action is the first milestone with its done-when.
   Commit `docs(spec): <slug>`, push. The sweep then finds it as a handoff.

## Phase 1 — Sweep

Run `sweep.sh [<repo>...]` from this skill's directory. It reads the
arguments, else `~/.config/night-shift/repos` (one repo per line, highest
rank first). With neither, ask for the repos and offer to write that file.
If it prints `gh failed`, run it again outside the sandbox.

## Phase 2 — Gate

An item or handoff next action passes only when all are true:

1. Its done-when names a check a command can make: a test, a metric, a file.
2. It names no person, no physical hardware, no `Blocked` marker, no "with <name>".
3. It changes only its own repo.
4. It needs no login and no secret. A GPU run has a command or config that runs as written.
5. No open PR already carries it, unless it is that PR's handoff.
6. Its worktree is not `DIRTY`.

## Phase 3 — Rank and plan

1. Order by the repo's rank, then by order in the repo: handoffs first, then roadmap items top to bottom.
2. Propose up to 3 new next steps from a repo's goal and roadmap gaps; mark them `new`. Each one must pass the gate.
3. Per job: id `NN-<branch>` (rank order), branch slug (a handoff keeps its branch), model, kind, one-line done-when.
   Kind `gpu`: the job prepares the code and queues the run; a follow-up job finishes after it.
4. Propose Opus only for a job that needs design judgment; say why.
5. A worktree with `SPEC.md`: one job, the next open milestone. Its time limit runs to the shift's end (night 06:30, day 12:30).

## Phase 4 — Approve

Show one table: `# · repo · task · source · kind · model · branch · done-when`.
Below it, fold "Rejected" (item → failed rule). **Stop and wait for
approval.** Apply every change the user asks for, then show the table again.

## Phase 5 — Write the night

For each approved job, under `${XDG_STATE_HOME:-~/.local/state}/night-shift/<night dir>/jobs/<id>/`:

- `job` — three lines: `repo=<absolute path>`, `branch=<slug>`, `model=<sonnet|opus>`.
  A `SPEC.md` job adds `timeout=<its time limit>`, e.g. `timeout=9h`.
- `prompt.md` — `references/job-prompt.md` with every `<…>` filled. Time limit: the shift's, unless the user set one.
  The two template slots take `templates/job-pr.md` and `templates/job-report.md` from the toolkit, verbatim.

## Phase 6 — Start

Run outside the sandbox (tmux and git push must not inherit it):

```bash
vibe night start --claude <night-dir> <start flags>   # the shift's flags; --jobs 4 is the default
```

It also starts the GPU queue (`gpu-queue run --until <the --until time>`) when none runs.
It prints `a night already runs` → a job of the night still runs; report it, start nothing.

## Done

Done when `vibe night start` printed `night started`. Report in 3 lines:
job count, the deadline, `vibe night status <night-dir>`. The report comes
by timer (07:00, or 13:00 for a day shift), or now with `vibe night report`.
