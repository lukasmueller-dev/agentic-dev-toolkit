# Project Roadmap — agentic-dev-toolkit

> Long-lived, one per repo. Planned work only: one item per task, each
> designed well enough that a session can pick it up cold, without the
> discussion that produced it. A snapshot, not a log — finished items are
> removed; their trail lives in git history and merged PRs.

_Last updated: 2026-07-26 · server (srv1841294)_

## Items

One item per PR — sized so a `HANDOFF.md` (the `handoff-brief` skill) or a
`LOOP.md` (the `loop-brief` skill) can be staged straight from it. Order
matters within a track; tracks are independent.

Track B — portability and team:

- [ ] `.claude-plugin/` manifest bundling skills, agents, hooks, and
      `memory/GLOBAL.md` so the toolkit installs in web/cloud sessions
      with no `$HOME` symlinks. Pure addition beside `install.sh`, which
      stays the install path on real machines. Note the `@` import in
      `claude/CLAUDE.md` resolves against `~/.claude`, which a plugin does
      not populate.
      **A 228-line design doc for this exists but was never merged:**
      `docs/plugins.md` on `origin/claude/open-source-alternatives-2yiha7`
      (2 commits, no PR ever opened). Recover it before starting, and
      before any branch pruning.
- [ ] Curated MCP server list in `docs/` (docs-first; `~/.claude.json` is
      Claude-written and stays unmanaged — same file class as
      `settings.json`'s runtime keys)
- [ ] Decide whether `install.sh` should prune orphaned symlinks. It
      rebuilds its link map from the repo on every run, so a *renamed*
      skill leaves the old link behind pointing at a directory that no
      longer exists — `~/.claude/skills/review-brief` after the
      `codebase-review` rename is the live example, and Claude Code scans
      that directory. `doctor` reports dangling links only for paths still
      in the map, so an orphan is invisible to it. The reason this is a
      decision and not a bug fix: pruning means deleting a symlink the
      current repo does not know about, which is exactly the authority
      `--uninstall`'s ownership check exists to constrain — resolve each
      candidate and skip anything not pointing back into the checkout. Add
      a test alongside the existing ownership one. Until this lands, a
      rename needs manual cleanup on every machine.

Track C — research-codebase skills:

A family of portable skills for working in research codebases (the
motivating case is VLA research, but nothing in them may be VLA-specific).
The first item fixes the contracts the other eight depend on and must land
first. After that the waves are ordered: **wave 1 must be dogfooded on a
real repo before wave 2 is started**, because the `CODEBASE_MAP.md` schema
will change on first contact. Dogfood target throughout: the π0 / `openpi`
codebase.

Deliberately rejected, so they are not re-proposed: a generic "optimize my
model" skill, anything that autonomously launches training, and a
paper-writing agent.

- [ ] **Contracts for the `research-*` family.** Design-only item; no
      skill ships from it. Decide and write down, in `docs/`, seven things
      every later item consumes:
      (1) skill vs agent — `skills/` by default for portability, with
      `research-cartographer` the one candidate for `claude/agents/`,
      justified only if read-only fan-out with isolated context is the
      real need;
      (2) a `templates/` entry for every document these skills emit
      (`CODEBASE_MAP.md`, `RUNBOOK.md`, `FORK_DELTA.md`, an experiment
      entry) per the layout contract — and CI's template check reads a
      hardcoded file list, so that list needs extending in the same PR;
      (3) emitted artifacts land in the target repo's `docs/`, not its
      root, which the status trio already occupies;
      (4) shared research-repo detection in `skills/_lib/`;
      (5) shared execution-context detection, same location — cluster vs
      workstation vs **ambiguous → ask**, from `sbatch`/`srun` on `PATH`,
      `SLURM_*` in the env, and `nvidia-smi`. Model it on `vibe`'s
      `detect_env`: detected per-session, never a fixed label, and it
      prints its verdict and the reason rather than guessing silently.
      Ambiguity is the common case (a login node, or a workstation with
      cluster access) and guessing wrong burns an allocation;
      (6) the never-launch-the-expensive-thing rule, stated once and
      referenced by the rest — smoke-scale runs may execute, anything
      multi-GPU or multi-hour stops and hands over the command;
      (7) the `research-` name prefix.
      Done when a later item can be picked up cold without re-deciding any
      of the seven.

- [ ] **`research-cartographer`** (wave 1) — explains an unfamiliar
      codebase into `docs/CODEBASE_MAP.md` against a *fixed* schema, so
      output is comparable across repos and re-runs can diff against the
      existing map. One skill, two branches, auto-detected with an
      explicit override; `mode:` goes in the artifact's frontmatter.
      Detection: `train.py` + `configs/*.yaml` + hydra/gin/draccus +
      wandb + torch/jax → research; `package.json`, route definitions,
      Dockerfile-serving → application; ambiguous → ask. The mode picks
      which middle sections get depth, not which exist — a research repo
      with a serving path is normal.
      Shared sections: entry points, config resolution chain (including
      keys that are silently ignored), dependency graph, how to run it,
      and **landmines** — globals, monkeypatches, hardcoded paths, dead
      config branches.
      Research middle: data path with real shapes/dtypes/ranges, model
      forward (tokenizer, vision encoder, action head, action
      tokenization), loss and what is masked out of it, eval hook,
      checkpoint format.
      Application middle: request lifecycle, state and persistence,
      external services, auth boundaries, build and deploy.
      Done when a map generated for `openpi` fills every schema section
      with a `file:line` pointer, and a re-run after an upstream pull
      reports a diff rather than a fresh map.

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
