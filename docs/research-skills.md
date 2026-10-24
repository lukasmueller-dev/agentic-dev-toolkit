# Contracts for the `research-*` skill family

Contracts for skills that work in research codebases (`train.py`, a config
tree, a cluster). Shipped today: `codebase-map` (outside the prefix, §7).
Planned items live in `PROJECT_ROADMAP.md`. Change a contract here, in the
same PR, never locally in one skill.

## 1. Skills, not agents

- Every item ships as a skill under `skills/` — portable; `claude/agents/` is
  not.
- A skill may delegate reads to subagents when the host has them; it must
  never require one.
- Model invocation: a skill that mutates the environment or git history sets
  `disable-model-invocation: true` (SQ13). A skill that only reads and writes
  its own `docs/` artifact, diffing instead of overwriting, stays
  model-invocable.

## 2. One template per emitted document

- One copy under `templates/research/` (or the emitting skill's own
  directory, e.g. `templates/codebase/`), rendered per `templates/README.md`.
- The template lands in the same PR as its skill.
- Same PR: a row in `templates/README.md`, and the directory in the
  tool-neutrality loops of `.github/workflows/ci.yml` and
  `tests/install.bats`.
- Templates name no CLI, agent, host or cluster.

## 3. Where emitted artifacts land

- The target repo's `docs/` (or an existing `doc/`, `documentation/`), never
  its root — the root belongs to `PROJECT_STATUS.md`, `PROJECT_ROADMAP.md`,
  `HANDOFF.md`.
- Never write outside the repo.
- `PROJECT_STATUS.md` gets a one-line pointer to each new artifact.

## 4. Repo-kind detection

In `skills/_lib/research-lib.sh`; always exits 0.

```
detect_repo_kind   [DIR]  → research | application | ambiguous
repo_kind_evidence [DIR]  → one "signal: detail" line per matched signal
```

| Side | Signals (each counts once) |
| ---- | -------------------------- |
| research | training entry point (`train.py`, `scripts/train*`, `train` console script); config tree + framework (hydra, gin, draccus, omegaconf, ml_collections); tracker (wandb, mlflow, aim, tensorboard); DL framework (torch, jax, flax, tensorflow); `checkpoints/` or `eval*.py` |
| application | `package.json` with a web framework; route definitions; serving entry point (uvicorn, gunicorn, fastapi, flask, django, express, server `CMD`); deploy config (`k8s/`, `helm/`, `fly.toml`, `vercel.json`, `Procfile`) |

- `research`: research ≥ 2 and application ≤ 1. `application`: the mirror.
  Otherwise `ambiguous` → ask, with the evidence shown.
- No network, shallow-checkout safe, bash 3.2, BSD + GNU, `-maxdepth 3`,
  prune `.git`, `node_modules`, `.venv`.

## 5. Execution-context detection

Same lib; reached through `bash map.sh context`.

```
detect_exec_context      → cluster | workstation | ambiguous
exec_context_evidence    → one "signal: detail" line per probe
```

| Evidence | Verdict |
| -------- | ------- |
| `SLURM_JOB_ID` / `SLURM_JOB_NODELIST` set | `cluster` (inside an allocation) |
| `sbatch`/`srun` on `PATH`, no GPU | `cluster` (login node) |
| `sbatch`/`srun` on `PATH` **and** a GPU | `ambiguous` → ask once |
| no scheduler, GPU | `workstation` |
| no scheduler, no GPU | `workstation` (CPU-only) |

- "GPU" = `nvidia-smi -L` exits 0 and lists a device; present-but-failing
  counts as none.
- Detected every session; print the verdict before acting.

## 6. The smoke-scale rule

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

## 7. Naming and scope

- A skill whose *workflow* is research-specific is named `research-<thing>`.
- Carve-out: `codebase-map` — it has an `application` mode, so it keeps the
  `codebase-*` name.
- No domain vocabulary (VLA, robotics) in a description; domain detail goes
  in `references/` (SQ17).
- No machine, cluster or personal workflow named (SQ18).
