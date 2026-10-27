---
name: night-shift
description: "Plans and starts unattended overnight work across the active repos: sweeps roadmap items and handoff next actions, keeps only what can run without a human, ranks it, and after approval starts one headless agent job per item, each ending in a draft PR. Use when the user says 'night shift', 'what can run overnight', 'plan the night', 'queue work for tonight', or wraps up the day and wants idle tokens or GPU hours used."
disable-model-invocation: true
argument-hint: "[<repo>...]"
---

# Night shift

Evening: sweep the active repos, gate and rank what can run unattended,
get approval, start the jobs. Runner, layout and traps:
`docs/night-shift.md` in the toolkit.

## Hard boundaries — never do these

- **Never start a job without explicit approval of the list.**
- **Never change a repo yourself.** You write only the night dir; the jobs do the work.
- **Never list an item that fails the gate.** Show it under "Rejected" with the reason.
- **Never plan more than** 8 jobs, 2 per repo, 1 on Opus. The rest default to Sonnet.
- **Never plan a GPU run or a job that needs one.** Gate them out (`no GPU queue yet`).

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
4. It needs no GPU run, no login, no secret.
5. No open PR already carries it, unless it is that PR's handoff.
6. Its worktree is not `DIRTY`.

## Phase 3 — Rank and plan

1. Order by the repo's rank, then by order in the repo: handoffs first, then roadmap items top to bottom.
2. Propose up to 3 new next steps from a repo's goal and roadmap gaps; mark them `new`. Each one must pass the gate.
3. Per job: id `NN-<branch>` (rank order), branch slug (a handoff keeps its branch), model, one-line done-when.
4. Propose Opus only for a job that needs design judgment; say why.

## Phase 4 — Approve

Show one table: `# · repo · task · source · model · branch · done-when`.
Below it, fold "Rejected" (item → failed rule). **Stop and wait for
approval.** Apply every change the user asks for, then show the table again.

## Phase 5 — Write the night

For each approved job, under `${XDG_STATE_HOME:-~/.local/state}/night-shift/<YYYY-MM-DD>/jobs/<id>/`:

- `job` — three lines: `repo=<absolute path>`, `branch=<slug>`, `model=<sonnet|opus>`.
- `prompt.md` — `references/job-prompt.md` with every `<…>` filled. Time limit: 3h unless the user set one.

## Phase 6 — Start

Run outside the sandbox (tmux and git push must not inherit it):

```bash
vibe night start --claude <night-dir>          # --jobs 4 --until 06:30 --timeout 3h
```

## Done

Done when `vibe night start` printed `night started`. Report in 3 lines:
job count, the deadline, `vibe night status <night-dir>`.
