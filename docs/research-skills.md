# Contracts for the `research-*` skill family

Contracts for skills that work in research codebases (`train.py`, a config
tree, a cluster). Shipped today: `codebase-map` (outside the prefix, §4).
Change a contract here, in the same PR, never locally in one skill.

## 1. Skills, not agents

- Every item ships as a skill under `skills/` — portable; `claude/agents/` is
  not.
- A skill may delegate reads to subagents when the host has them; it must
  never require one.
- Model-invocable: a skill whose writes stay inside the target repo and whose
  commands pass §3. The host's permission prompts gate each write.
- `disable-model-invocation: true` (SQ13): a skill that changes anything
  outside the repo — installs, scheduler submissions, robot commands, pushes.

## 2. Where emitted artifacts land

- The target repo's `docs/` (or an existing `doc/`, `documentation/`), never
  its root — the root belongs to `PROJECT_STATUS.md`, `PROJECT_ROADMAP.md`,
  `HANDOFF.md`.
- Never write outside the repo.
- `PROJECT_STATUS.md` gets a one-line pointer to each new artifact.

## 3. The smoke-scale rule

A skill runs a command only when all five hold; otherwise it hands the
command over verbatim, with the reason and what it needs.

1. One process, one device (no `torchrun`, `accelerate launch`, `deepspeed`,
   `mpirun`, multi-device `CUDA_VISIBLE_DEVICES`).
2. No scheduler submission (`sbatch`, `srun`, `salloc`, `qsub`, `bsub`, job
   `kubectl apply`).
3. Expected under ~2 minutes **and** run under a hard `timeout`.
4. Under ~1 GB download.
5. No side effects outside the repo and the existing environment —
   installs included; tracker offline.

- Handing over is a successful step, not a failure.
- A command the human authorises covers that command, in that session only.

## 4. Naming and scope

- A skill whose *workflow* is research-specific is named `research-<thing>`.
- Carve-out: `codebase-map` — it maps any repo, so it keeps the `codebase-*`
  name.
- No domain vocabulary (VLA, robotics) in a description; domain detail goes
  in `references/` (SQ17).
- No machine, cluster or personal workflow named (SQ18).
