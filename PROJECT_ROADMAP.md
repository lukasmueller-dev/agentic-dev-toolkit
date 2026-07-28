# Project Roadmap — agentic-dev-toolkit

> Long-lived, one per repo. Planned work only: one item per task, each
> designed well enough that a session can pick it up cold, without the
> discussion that produced it. A snapshot, not a log — finished items are
> removed; their trail lives in git history and merged PRs.

_Last updated: 2026-07-27 · server (srv1841294)_

## Items

One item per PR — sized so a `HANDOFF.md` (the `handoff-brief` skill) or a
`LOOP.md` (the `loop-brief` skill) can be staged straight from it. Order
matters within a track; tracks are independent.

Track D — one launch path regardless of machine:

- [ ] **`--no-attach` works off a server, so `handoff-start` stops
      branching** — today the skill launches the session on a server and
      merely *prints* `vibe start <task>` locally. That asymmetry is not a
      preference; it is forced by `open_session`'s local branch, which
      `exec`s the agent into the caller's terminal, so a skill that ran
      `vibe start` locally would replace the very session running it.
      `cmd_start` refuses `--no-attach` off a server for the same reason
      (`bin/vibe:1688`), and `cmd_loop_args` carries the identical refusal
      (`:1425`).
      The mechanism: **`--no-attach` implies tmux, on any machine.** The
      local default does not change — a bare `vibe start` still runs in the
      foreground with no tmux, because nothing there needs to survive. Only
      the explicit "start it and return" asks for something to hold the
      session, and tmux is what the server path already uses. Do not make
      local starts tmux-backed in general; that is a different, much larger
      change to what `local` means.
      The real work is `vibe attach`, not the refusal. Its local branch
      `exec`s a fresh agent unconditionally, so a detached local session
      would be unreachable *and* attaching would silently start a second
      agent against the same worktree — the failure this must not ship
      with. Attach has to prefer an existing tmux session over `exec`
      wherever one exists, which makes `open_session`'s server/local split
      a session-exists/does-not split instead.
      Three smaller edges, each to be decided rather than discovered:
      tmux may be absent locally, where `doctor` currently downgrades that
      to "only needed on the server" (`:2686`) — `--no-attach` must fail
      with a clear message and `handoff-start` degrade to printing the
      command; `vibe loop --no-attach` gets the same treatment or is
      explicitly ruled out, but not left silently inconsistent; and
      `vibe rc` stays server-only (`:2567`) even though a local detached
      session weakens its stated reason, since reaching a laptop from a
      phone is a different problem. `vibe status` needs nothing — it
      already lists tmux sessions without consulting `detect_env`.
      Note this also settles the kickoff turn locally for free: the
      `--no-attach` gate added in the PR for `skill-handoff-start` is
      machine-agnostic, so a detached local start begins from `HANDOFF.md`
      on its own, exactly as it does on a server.
      Done when `handoff-start`'s Phase 2 is one code path with no `vibe
      where` branch, `vibe attach` on a local detached session attaches
      instead of launching a second agent (with a test that fails against
      today's `exec`), and `bats tests/` covers a local `--no-attach` start
      through the stub tmux rather than the real one.

Track C — research-codebase skills:

A family of portable skills for working in research codebases (the
motivating case is VLA research, but nothing in them may be VLA-specific).
The contracts every item here consumes — skill-vs-agent, templates,
artifact location, the two shared detections, the never-launch rule, the
name prefix — are settled in `docs/research-skills.md`; read it first and
do not re-decide any of them locally. The waves are ordered: **wave 1 must
be dogfooded on a real repo before wave 2 is started**, because the
`CODEBASE_MAP.md` schema will change on first contact. Dogfood target
throughout: the π0 / `openpi` codebase.

Deliberately rejected, so they are not re-proposed: a generic "optimize my
model" skill, anything that autonomously launches training, and a
paper-writing agent.

- [ ] **`research-first-run`** (wave 1) — gets an unfamiliar research
      codebase running. Resolve the environment first (python, torch,
      CUDA, and the flash-attn wheel that matches both), then reach the
      smallest thing that proves the training loop works — one batch, a
      tiny subset, a single GPU — before anything real is launched.
      Done is concrete: a committed `scripts/smoke.sh` that runs in under
      about two minutes. Every undocumented workaround gets logged into
      `docs/RUNBOOK.md` as it is discovered, since research repos always
      need several fixes that exist in no README and that knowledge
      otherwise dies in a scrollback.

- [ ] **`research-train-doctor`** (wave 2) — triages a run that is not
      learning. The value is the ordering, by prior probability rather
      than by convenience: action normalization → loss masked to action
      tokens only → trainable-parameter count against intent (is the
      adapter actually attached?) → lr and warmup → grad norm → mixed-
      precision overflow → dataloader shuffle and repeat. Reads
      `CODEBASE_MAP.md` where one exists rather than rediscovering the
      data path.
      Done when it locates a deliberately introduced fault (e.g.
      normalization stats from the wrong dataset) on `openpi` without
      being told where to look.

- [ ] **`research-run-archaeology`** (wave 2) — diffs two runs or two
      checkpoints across resolved config, git commit, data mix, and
      environment, to answer "why is this run worse than last week's".
      Resolved config, not the config file: the whole point is catching
      an override that changed underneath you.
      Done when, given two runs differing by one override, it names that
      override and does not bury it in a list of incidental diffs.

- [ ] **`research-lab-notebook`** (wave 3) — one entry per experiment:
      hypothesis, config delta, result, verdict. This is a new lifetime
      tier alongside `HANDOFF.md`, `PROJECT_STATUS.md`, and
      `PROJECT_ROADMAP.md`, so it needs its own row in
      `docs/artifact-architecture.md` and a line in `memory/GLOBAL.md` —
      otherwise experiment notes silently land in the handoff and die
      with the session.
      Done when the skill, its `templates/` entry, the
      `docs/artifact-architecture.md` row, and the `memory/GLOBAL.md`
      line all land in the same PR — the skill alone would create a tier
      nothing else knows about.

- [ ] **`research-ablation-planner`** (wave 3) — turns a research question
      into a minimal grid: what varies, what is held fixed, how many
      seeds, and what result would falsify the hypothesis. Emits roadmap
      items; launches nothing.
      Done when its output pastes into `PROJECT_ROADMAP.md` as items
      without editing, and every grid states its falsification criterion
      before any run.

- [ ] **`research-fork-delta`** (wave 3) — maintains `docs/FORK_DELTA.md`,
      one entry per intentional divergence from upstream with the reason,
      and drives rebases onto upstream without silently dropping local
      changes. Research work is usually a fork of a public VLA repo, and
      the divergences are currently only in the diff, where they carry no
      rationale.
      Done when a rebase of the dogfood fork onto a newer upstream leaves
      `FORK_DELTA.md` accurate and drops no local change silently.

- [ ] **`research-paper-to-code`** (wave 3) — maps a paper's claimed
      components onto a repo and flags what is missing, renamed, or
      quietly different. Useful in both directions: reading someone
      else's release, and checking your own repo still matches your draft.
      Done when, run against the π0 paper and `openpi`, every claimed
      component is marked present / renamed / absent, with a file pointer
      for each present one.
