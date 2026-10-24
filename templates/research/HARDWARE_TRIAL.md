# Hardware trial — <platform>

> One per platform, at `docs/hardware/<platform>.md`. The slot fields the
> procedure needs, then one line per gate result. A gate that fails stops the
> trial.

_Started: <date> · against commit <commit>_

## Slot

| Field | Value |
| ----- | ----- |
| Hardware layer | |
| E-stop path | |
| Gate values | |
| Sim | |
| Release tool | |
| Recording | |

_Hardware layer: the process or library that talks to the hardware, with its version. Gate values: latency budget, joint limits, observe-only minutes. Release tool: how a policy version reaches the hardware computer._

## Gates

| Step | Date | Result | Record |
| ---- | ---- | ------ | ------ |
| 1. Sim rehearsal | | | |
| 2. Observe-only | | | |
| 3. Latency | | | |
| 4a. Command stop (G0) | | | |
| 4b. E-stop | | | |
| 4c. Damp on exit | | | |
| 4d. Joint limits | | | |
| 5a. Commanded, support rig | | | |
| 5b. Commanded, ground | | | |
