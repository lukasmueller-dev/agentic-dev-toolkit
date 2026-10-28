---
name: fill-queue
description: "Fills the agent queue with unattended work across the active repos: shows the queue, asks for big work and proposes up to 3 items (each grilled into a SPEC.md), sweeps roadmap items and handoff next actions, keeps only what can run without a human, ranks it, and after approval adds one headless agent job per item, each ending in a draft PR. Use when the user says 'fill the queue', 'queue work', 'what can run unattended', 'plan the night', 'keep the agents busy', or has spare agent or GPU time."
disable-model-invocation: true
argument-hint: "[<repo>...]"
---

# Fill queue

Show the queue, sweep the active repos, gate and rank what can run
unattended, get approval, add the jobs. Runner, window and layout:
`docs/agent-queue.md` in the toolkit.

## Hard boundaries — never do these

- **Never add a job without explicit approval of the list.**
- **Never change a repo yourself.** You write only job dirs, and in Phase 1 a new branch's `SPEC.md` and `HANDOFF.md`; the jobs do the work.
- **Never write a `SPEC.md` without a grilling the user took part in.**
- **Never list an item that fails the gate.** Show it under "Rejected" with the reason.
- **Never queue an item whose branch is already queued or running.** The sweep marks it `QUEUED`.

## Phase 0 — Queue

Run `vibe queue status`. Show its header, and per repo the jobs that are
queued or running: id, heavy or light, context.

## Phase 1 — Big work

The user says skip → go to Phase 2.

1. Ask for the user's big work items: a feature, a migration, a GPU run.
2. Propose up to 3 more from the repos' goals, roadmaps and gaps, one line each.
3. For each item the user picks, run the `grilling` skill with the user until every
   section of `templates/SPEC.md` (toolkit) has an answer.
4. Outside the sandbox: `git -C <repo> worktree add -b <slug> <repo>/.claude/worktrees/<slug>`.
   Write `SPEC.md` from the template and `HANDOFF.md` from `templates/HANDOFF.md`;
   its next action is the first milestone with its done-when.
   Commit `docs(spec): <slug>`, push. The sweep then finds it as a handoff.

## Phase 2 — Sweep

Run `sweep.sh [<repo>...]` from this skill's directory. It reads the
arguments, else `~/.config/agent-queue/repos` (one repo per line, highest
rank first). With neither, ask for the repos and offer to write that file.
It fetches each repo and reads goal and roadmap from `origin`'s default branch.
If it prints `gh failed` or `fetch failed`, run it again outside the sandbox.

## Phase 3 — Gate

An item or handoff next action passes only when all are true:

1. Its done-when names a check a command can make: a test, a metric, a file.
2. It names no person, no physical hardware, no `Blocked` marker, no "with <name>".
3. It changes only its own repo.
4. It needs no login and no secret. A GPU run has a command or config that runs as written.
5. No open PR already carries it, unless it is that PR's handoff.
6. Its worktree is not `DIRTY` and not `QUEUED`.

## Phase 4 — Rank and plan

1. Order by the repo's rank, then by order in the repo: handoffs first, then roadmap items top to bottom.
   After 17:00, heavy jobs first: the night window opens at 18:00.
2. Propose up to 3 new next steps from a repo's goal and roadmap gaps; mark them `new`. Each one must pass the gate.
3. Per job: branch slug (a handoff keeps its branch), model, kind, one-line done-when, timeout,
   and the context: what the work is about in plain words — the problem, the idea — at most 25 words, no detail.
   Kind `gpu`: the job prepares the code and queues the run; a follow-up job finishes after it.
4. Timeout: 2h, a light job. More only for a `SPEC.md` milestone, GPU prep, or work the user calls big —
   a heavy job, which starts only in the night window.
5. Propose Opus only for a job that needs design judgment; say why.
6. A worktree with `SPEC.md`: one job. Its task is "the first open milestone of `SPEC.md`"; the runner
   queues the next milestone when one is done.

## Phase 5 — Approve

Show one table per repo, in rank order: `# · task · context · source · kind · heavy/light · timeout · model · branch · done-when`.
Below it, fold "Rejected" (item → failed rule). **Stop and wait for
approval.** Apply every change the user asks for, then show the tables again.

## Phase 6 — Add

For each approved job, in rank order, write a fresh dir (`mktemp -d`):

- `job` — `repo=<absolute path>`, `branch=<slug>`, `model=<sonnet|opus>`, `context=<context>`, `timeout=<timeout>`.
- `prompt.md` — `references/job-prompt.md` with every `<…>` filled.
  The two template slots take `templates/job-pr.md` and `templates/job-report.md` from the toolkit, verbatim.

Then, outside the sandbox: `vibe queue add <dir>...` in rank order. A job the user wants now,
whatever the window: `vibe queue add --now <dir>`.

## Done

Done when `vibe queue add` printed one `queued` line per approved job. Report
in 3 lines: jobs added (heavy, light), the heavy ones waiting for the window,
`vibe queue status`.
