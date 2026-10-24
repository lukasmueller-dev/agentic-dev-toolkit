---
name: research-hardware-trial
description: Takes a trained policy from simulation to its first runs on physical hardware through fixed gates — sim rehearsal with the real hardware layer, an observe-only recorded run, a latency check, stop and limit gates on a support rig, then a commanded run. Use when a policy is ready for its first hardware test, when a new hardware platform joins a project, or when asked to plan or check a hardware bring-up. Fills one slot file per platform and hands every hardware command to the human.
disable-model-invocation: true
---

# Research hardware trial

## Boundaries

> **Warning:** never send a command that can move the hardware. Hand each one
> to the human, verbatim, with the gate it belongs to.

- One gate passes before the next starts. A failed gate stops the trial; record
  it.
- Hardware runs use the project's run record (`research-experiment-setup`
  card 1) with their own run kind. Cards 1, 3 and 5 must be `built` in
  `docs/EXPERIMENT_SETUP.md`; else run that skill first.
- Write only inside the target repo (`docs/research-skills.md` §2).

## 1. Seed the slot

```bash
bash seed.sh PLATFORM [DIR]
```

Fill each slot field with the human — ask each one, guess none. `exists:` →
resume at the first gate without a result.

## 2. Procedure

| Step | Does | Passes when | Records |
| ---- | ---- | ----------- | ------- |
| 1. Sim rehearsal | the real hardware layer (same process, same messages) drives the sim | N episodes, no layer error, outputs inside joint limits | run record, kind `sim-rehearsal` |
| 2. Observe-only | policy runs on hardware; nothing writes the command channel | the state stream has no gap above budget for the slot's minutes | run record + raw stream |
| 3. Latency | observation → action timing | one JSON line `{p50, p99, max}`, p99 inside budget | the JSON line in the record |
| 4. Gates, on the support rig | the human tests each once: G0 (zero command stops motion), e-stop, damp on process exit, joint limits held by the layer | each gate passes | one line per gate |
| 5. Commanded run | support rig first, then ground; short episodes; the human at the e-stop | episodes end without an e-stop | run record, kind `commanded` |

Write each result in the slot file's **Gates** table, with the date and the
record it points to.

## Done

- Every slot field is filled.
- Every gate has a date, a result and a record.
- A commanded ground run is recorded, or the gate that stopped the trial is.
