# First run — filling "How to run it" for a research repo

Use in step 2.4 when the repo is a research repo, or when an install or a
first run fails on dependency or accelerator errors. Results land in **How to
run it**; traps land in **Landmines**. Every command obeys
`docs/research-skills.md` §3: run it, or hand it over.

## 1. Execution context

Decide from the evidence and print the verdict and the evidence before you
run anything:

| Evidence | Verdict |
| -------- | ------- |
| `SLURM_JOB_ID` set | cluster, inside an allocation |
| `sbatch`/`srun` on `PATH`, no GPU | cluster login node — hand every run over as a written, unsubmitted job script |
| `sbatch`/`srun` on `PATH` and a GPU | ask once |
| no scheduler | workstation — the ladder below may run, within §3 |

GPU = `nvidia-smi -L` exits 0 and lists a device.

## 2. Environment chain (read, do not install)

Resolve in order; each link constrains the next:

1. Runtime version (manifests, lockfile, README install section).
2. Framework build.
3. Accelerator toolkit the machine actually has.
4. Every part compiled against 2 and 3 (attention kernels, fused optimizers,
   custom ops). Match the wheel to the framework build, never "newest".

A lockfile is authoritative. Record the combination that resolves under
*Needs*. Installs fail §3 test 5: hand them over, in order, for an isolated
environment.

## 3. Smallest proof, in order

Stop at the first failure and record it.

| # | Proves | Shape |
| - | ------ | ----- |
| 1 | Environment resolved | import the package |
| 2 | Toolkit + compiled parts | build the model on one device, no data |
| 3 | Data path | load one batch, print shapes, dtypes, ranges |
| 4 | Training step | one step, smallest config, under `timeout`; a finite loss is the bar |
| 5 | Learning at all | a few steps, loss moves |

Set the tracker offline (`WANDB_MODE=offline`). If step 2 needs more memory
than one device has, hand it over.

## 4. Record

- Each step that ran: its command and measured wall clock in **How to run it**.
- Each undocumented fix: one **Landmines** line — verbatim error → cause or
  "unknown", fix.
- Full training, multi-device and scheduler runs: rows with their cost, never
  run.
