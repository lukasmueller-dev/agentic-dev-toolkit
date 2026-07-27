---
name: research-first-run
description: Gets an unfamiliar research codebase actually running — resolves the environment (runtime, framework, accelerator toolkit and the compiled wheels that must match all three), then reaches the smallest thing that proves the training loop works, and commits it as a smoke check. Use when setting up a research repo for the first time, when an install or a first run fails on dependency or accelerator errors, or when asked to get training working on a new machine. Logs every undocumented workaround into docs/RUNBOOK.md. Never launches a real training run.
disable-model-invocation: true
---

# Research first run

## Boundaries

Read these before running anything. This skill installs packages, builds
wheels and executes commands — it is the one in the family that changes the
machine, which is why it is user-invoked only.

- **Never launch the expensive thing.** A command may be executed only when
  *all five* tests in `docs/research-skills.md` §6 hold: one process on one
  device; no scheduler submission; expected under about two minutes **and**
  run under a hard `timeout`; under roughly 1 GB of download; no side effects
  outside the repo and the environment that already exists. Anything failing
  one of the five is **handed over** — printed verbatim, copy-pasteable, with
  the reason it was not run and what it needs.
- **Handing a command over is the successful outcome of that step.** Not a
  failure to complete it, and never something to apologise for. A guessed
  multi-GPU launch spends GPU-hours and queue priority belonging to other
  people; a wrong multi-hour run is discovered when the day is gone. The cost
  of stopping is one paste.
- **A command the human authorises in the moment covers that command, in that
  session.** It is never recorded, never generalised into "runs are fine now".
- **Never modify the repo's own code to make something run.** Environment
  fixes go in the environment; a change the repo genuinely needs is a finding
  for the runbook, not an edit made in passing.
- **Never install into a shared or system environment** without saying so
  first. Research repos pin aggressively, and a wheel built for one project
  breaks the next.
- **Never write outside the target repo**, and never above its root.

## 1. Detect the execution context, and say so

```bash
bash env.sh detect
```

Prints `cluster`, `workstation` or `ambiguous` and the evidence behind it —
scheduler environment variables, schedulers on `PATH`, and what `nvidia-smi`
actually reports. **Print this before doing anything else.** A silent guess
here burns an allocation.

- **`cluster`** — nothing GPU-shaped runs *here*. Everything below still
  applies to resolving the environment; the running part is prepared and
  handed over as a submission script.
- **`workstation`** — proceed, within the §6 bar.
- **`ambiguous` means ask, once, with the evidence and both candidate
  verdicts.** A scheduler *and* a visible GPU is either an interactive
  allocation or a workstation with cluster access, and those want opposite
  things. This is the common case, not an error.

The answer, and the evidence that was ambiguous, get recorded under
`## Environment` in the repo's `docs/RUNBOOK.md` (phase 2). That is a **cached
answer, not configuration**: detection runs again next session, and a fresh
verdict contradicting the record is reported and re-asked, never trusted.

## 2. Seed the runbook

```bash
bash env.sh seed [DIR]
```

Creates the repo's `docs/RUNBOOK.md` from the toolkit's template if it does
not exist, and leaves it alone if it does. Never write this document from
memory.

**Then write into it as you go, not at the end.** By the end of a session the
one change that mattered is indistinguishable from the three that did not.
Every phase below has something to append.

## 3. Resolve the environment before running anything

Research repos fail at install far more often than at runtime, and the failure
is almost always an *interaction* rather than a single wrong version.

1. **Read what the repo asks for** — the manifests, the lockfile if there is
   one, and the README's install section. A lockfile is authoritative; prefer
   the tool that produced it.
2. **Read what the machine has** — runtime version, accelerator driver and
   toolkit version, and the package manager already in use.
3. **Resolve the chain, in this order**, because each link constrains the
   next: runtime version → framework build → accelerator toolkit → any
   component *compiled against* both. That last link is where first runs
   actually die: attention kernels, fused optimizers and custom operators ship
   per-version wheels, and a mismatch surfaces as an import error or a crash
   far from its cause. Match the wheel to the framework build and the runtime
   version — never install the newest and hope.
4. **Prefer an isolated environment**, and say which one you are creating.

Record the combination that worked in **Versions that actually work**, and
every undocumented fix in **Workarounds**, as you find them.

## 4. Reach the smallest thing that proves it works

In this order, stopping to record each result. Do not skip ahead: each step
makes the next failure interpretable.

1. **Import the package.** Cheapest possible check that the environment
   resolved.
2. **Build the model on one device**, without data. Catches the accelerator
   toolkit and the compiled components.
3. **Load one batch** and print real shapes, dtypes and value ranges. Where a
   `docs/CODEBASE_MAP.md` exists, compare against what it recorded; where it
   does not, this is the first real look at the data path.
4. **One training step**, one process, one device, smallest config, under a
   hard `timeout`. A loss that comes back finite is the bar — not a loss that
   is *good*.
5. **A few steps**, to see the loss move at all.

Every one of these must satisfy §6 on its own. If step 2 already needs more
memory than one device has, that is the answer: stop and hand it over.

Set the experiment tracker offline for anything at this scale, so a smoke run
never appears in a shared dashboard.

## 5. Commit the smoke check

The deliverable. Write `scripts/smoke.sh` in the target repo — the sanctioned
shape of the *allowed* side of §6: the thing that may run gets a name, a
budget and a home in the repo.

It must:

- run in **under about two minutes**, measured, not estimated;
- use one process and one device, with a hard `timeout` inside the script;
- exit non-zero on failure, so it is usable as a check rather than read as
  output;
- print what it proved;
- carry a comment saying what it deliberately does **not** cover.

Then record it under **The smallest thing that proves it works** in the
runbook, with its measured wall clock.

## 6. Hand over what could not run here

Everything real — full training, multi-device runs, anything scheduler-bound —
goes into **Expensive commands** in the runbook: the command verbatim, what it
needs, and what it costs. On a cluster, that includes the submission script,
written but **not submitted**.

## Done

- `docs/RUNBOOK.md` exists and records: the environment verdict with its
  evidence, the version combination that actually resolved, every workaround
  found, and the dead ends.
- `scripts/smoke.sh` is committed, runs in under about two minutes on this
  machine, exits non-zero on failure, and has been run — with its measured
  time in the runbook.
- Every command that could not run here is written down as a command, with its
  cost, rather than attempted.
- `PROJECT_STATUS.md` points at the runbook.

Stop there. A real training run is the human's to start.
