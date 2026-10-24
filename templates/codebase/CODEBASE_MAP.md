---
commit: <commit>
---

# Codebase Map — <repo>

> One per repo, at `docs/CODEBASE_MAP.md`. One fact per line, each with a
> `path:line` pointer. A re-run diffs against this file. A section with
> nothing to report says "none found" and keeps its heading.

_Mapped at: <date> · against commit <commit>_

## Entry points

_One line each: `command` → what it does · `path:line`. Manifests (console scripts, run targets) first._

## How to run it

| To prove | Run | Needs | Cost |
| -------- | --- | ----- | ---- |
| ... | `...` | ... | ... |

## Config

_One line per layer, in resolution order, with the pointer where it is applied. Then one line per key that is silently ignored (renamed, dropped by a schema, shadowed), with the pointer where it dies._

## Where the data goes

_One line per stage, in order, with its pointer. Research: raw data → batch → model → loss (what is masked) → eval → checkpoint. Application: request → handler → state → external services → auth. Real shapes, dtypes and ranges where they matter._

## Landmines

_One line each: symptom → cause · `path:line`. Sweep for mutable global state, a library patched at runtime, hard-coded paths, hosts or devices, dead config branches, defaults that differ between entry points._
