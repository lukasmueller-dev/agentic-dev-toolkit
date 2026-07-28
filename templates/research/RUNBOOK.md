# Runbook — <repo>

> Long-lived, one per repo, living at `docs/RUNBOOK.md`. How to get this
> codebase *running*, and every undocumented fix it took to get there —
> the knowledge that exists in no README and otherwise dies in a scrollback.
>
> **Append, never rewrite.** Unlike the status documents, an entry here stays
> true after the session that wrote it ends: a workaround that was needed once
> will be needed again on the next machine. Correct an entry that turns out to
> be wrong, and say what was wrong with it; do not delete it, because someone
> will otherwise rediscover the same dead end.
>
> Anything expensive is written here as a **command to run**, with its cost,
> never as a step something else performs automatically.

_Started: <date>_

## Environment

_One entry per distinct environment this repo has been run in. Detection runs
fresh every session — this is a **cached answer, not configuration**, so a
verdict that contradicts an entry below gets reported and re-asked rather than
trusted._

### <date> — _verdict_

- **Evidence:** _the probe output the verdict came from, verbatim._
- **Resolved by:** _"detected", or "asked — the evidence was ambiguous", with
  the answer given._
- **Devices:** _what is actually available to run on here._

## Getting it running

_The steps, in order, that take a fresh checkout to something that executes.
Each one is a command, not a description. Where a step needs a value that
differs per environment, say which and where it comes from._

| # | Step | Command | Notes |
| - | ---- | ------- | ----- |
| 1 | ... | `...` | ... |

## Versions that actually work

_The combination that resolved, not the ranges the manifests declare. Research
codebases pin loosely and break on the interaction — the runtime, the
framework, the accelerator toolkit, and any component compiled against them
are the ones worth writing down exactly._

| Component | Version | Why this one |
| --------- | ------- | ------------ |
| ... | ... | ... |

## Workarounds

_Every fix that is not in the README. This is the section the runbook exists
for. Add one the moment it is discovered — not at the end, when the session
has forgotten which of the four things it changed was the one that mattered._

### _One line naming the failure_

- **Symptom:** _what it looked like — the error, verbatim where there is one.
  This is what the next person searches for._
- **Cause:** _if known. "Unknown" is an honest and useful answer._
- **Fix:** _the exact command or edit._
- **Applies to:** _which environments — a fix for one accelerator or one
  runtime version is not a fix everywhere._

## The smallest thing that proves it works

_The smoke check: one process, one device, bounded time, committed to the repo
so it can be re-run rather than reconstructed. Record what it covers and what
it deliberately does not._

- **Command:** `...`
- **Runs in:** _wall clock, measured._
- **Proves:** _which parts of the path are exercised._
- **Does not prove:** _what is still untested — the honest half._

## Expensive commands

_The real runs: what they are for, what they cost, and what they need. These
are listed to be **handed over and run deliberately**, never launched as part
of setting something up._

| To | Command | Needs | Cost |
| -- | ------- | ----- | ---- |
| ... | `...` | ... | ... |

## Dead ends

_Approaches that were tried and did not work, with the reason. Without this
section the next session spends its afternoon the same way this one did._

- ...
