# First run — filling "How to run it" for a research repo

Use in phase 3, step 5, when the repo is `research` or when an install or a
first run fails on dependency or accelerator errors. Everything here lands in
the map's **How to run it** table (and **Landmines** for traps). Every command
obeys the boundary in `SKILL.md`: run it only if it passes all five tests in
`docs/research-skills.md` §6, otherwise hand it over.

## 1. Execution context

```bash
bash map.sh context
```

Prints `cluster`, `workstation` or `ambiguous` plus the evidence. Print it
before running anything.

- `cluster` — nothing GPU-shaped runs here; every run is handed over (a
  submission script, written, never submitted).
- `workstation` — the ladder below may run, step by step, within §6.
- `ambiguous` — ask once, with the evidence and both verdicts.

## 2. Resolve the environment chain (read, do not install)

Research repos fail at install more than at runtime, and the failure is an
interaction, not one wrong version. Resolve in this order; each link
constrains the next:

1. Runtime version (from the manifests, lockfile, README install section).
2. Framework build.
3. Accelerator toolkit (what the machine actually has).
4. Every component compiled against 2 and 3 — attention kernels, fused
   optimizers, custom ops. First runs die here: match the wheel to the
   framework build and runtime, never "newest".

A lockfile is authoritative. Record the combination that resolves in **How to
run it** under *Preconditions*. Installing or building wheels changes the
environment, so it fails §6 test 5: hand the install commands over, in order,
for an isolated environment.

## 3. Smallest proof, in order

Stop at the first failure and record it; each step makes the next failure
readable.

| # | Proves | Shape |
| - | ------ | ----- |
| 1 | Environment resolved | import the package |
| 2 | Toolkit + compiled parts | build the model on one device, no data |
| 3 | Data path | load one batch, print shapes, dtypes, ranges |
| 4 | Training step | one step, one process, one device, smallest config, under `timeout`; a finite loss is the bar |
| 5 | Learning at all | a few steps, loss moves |

Set the experiment tracker offline (`WANDB_MODE=offline` or equivalent). If
step 2 already needs more memory than one device has, hand it over.

## 4. Record

- Each step that ran: its command and measured wall clock in **How to run
  it**.
- Each undocumented fix: one **Landmines** entry — symptom (verbatim error),
  cause or "unknown", fix, which environments it applies to.
- Full training, multi-device and scheduler runs: rows in **How to run it**
  with their cost, never run.
