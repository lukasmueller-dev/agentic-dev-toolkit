---
mode: <mode>
commit: <commit>
---

# Codebase Map — <repo>

> Long-lived, one per repo, living at `docs/CODEBASE_MAP.md`. What this
> codebase *is* and where each moving part lives, against a fixed schema — so
> two repos are comparable and a re-run diffs against this file instead of
> replacing it. Every claim carries a `path:line` pointer, because a map
> without one is a summary, and a summary cannot be checked.
>
> The schema is fixed: sections are never dropped. `mode` above decides which
> middle section gets depth, not which ones exist — a research codebase with a
> serving path is normal, and so is the reverse. A section with nothing to
> report says so in one line and keeps its heading.

_Mapped at: <date> · against commit <commit>_

## Orientation

_What this repo is, in two or three sentences: the problem it solves, the
shape of the thing it produces, and the one file a newcomer should read
first. Pointer required._

## Entry points

_Every way execution starts — scripts, console entry points, servers,
schedulers, test runners. One row each. "Reached by" is the command or event
that triggers it, not a description._

| Entry point | Pointer | Reached by | Does |
| ----------- | ------- | ---------- | ---- |
| ... | `path:line` | ... | ... |

## Config resolution chain

_How a value reaches the code, in resolution order, with the pointer to where
each layer is applied. Name the layers this repo actually has — a config file
tree, environment variables and CLI overrides are the common set, but a repo
whose configuration is code has layers too (defaults, the selected
preset/profile, overrides, values derived on access), and mapping it as if it
had files is how a reader concludes there is nothing to find._

| Layer | Pointer | Wins over |
| ----- | ------- | --------- |
| ... | `path:line` | ... |

**Keys that are silently ignored.** _The expensive ones: a key that is read
under a different name, dropped by a schema that rejects unknown fields
without saying so, or shadowed by a later layer. A typo'd override that
changes nothing is the failure this section exists to prevent — list each
with the pointer to where it dies, or write "none found"._

## Dependency graph

_The internal modules that matter and which way the arrows point. Depth over
completeness: the handful of edges that explain the structure, not every
import. Note any cycle explicitly — cycles are where a change lands
somewhere unexpected._

## The research path

_Depth here when `mode: research`; one line per subsection otherwise. Either
way every `###` below keeps its heading — collapsing the shallow half into a
bullet list is what makes two maps stop lining up._

### Data

_From raw source to a batch: where it is read, the transforms in order, and
the **real** shapes, dtypes and value ranges of what the model finally
receives — read them off the code or a recorded run, never assume them.
Normalization statistics get their own pointer: which dataset they were
computed on, and where they are applied._

### Model forward

_The path a batch takes through the model, in order, with a pointer per
stage. Where the architecture has them: the input tokenizer, the vision
encoder, the fusion point, the output head, and how outputs are discretized
or bounded._

### Loss

_What is compared against what, and — the part that is usually undocumented —
**what is masked out of it**. Which positions contribute to the loss, which
are ignored, and where that mask is built._

### Evaluation

_The hook that scores a model, the metric it reports, and whether it runs
in-loop or separately. Pointer to where the number is computed, so the number
can be trusted._

### Checkpoints

_What is written, in what format, on what schedule, and what is needed to
resume from one — including anything kept *outside* the checkpoint that a
resume silently depends on._

## The application path

_Depth here when `mode: application`; one line per subsection otherwise, and
every `###` keeps its heading either way._

### Request lifecycle

_From arrival to response: routing, middleware in order, the handler, and
where the response is serialized._

### State and persistence

_What is stored, where, and who owns the schema. Include caches and anything
in memory that survives a request._

### External services

_Every outbound dependency, what happens when it is unavailable, and where
its credentials come from — by mechanism, never the value._

### Auth boundaries

_Where a request stops being anonymous, what enforces it, and which paths
deliberately bypass it._

### Build and deploy

_How the artifact is produced and how it reaches somewhere it runs._

## How to run it

_The smallest command that proves each thing works, and its preconditions.
Anything long-running or expensive is listed here as a command with its cost,
never as a step to be taken automatically._

| To | Run | Preconditions | Cost |
| -- | --- | ------------- | ---- |
| ... | `...` | ... | ... |

## Landmines

_What will cost someone an afternoon. Each with a pointer and, where it is
known, the symptom it produces — the symptom is what makes this section
searchable later._

| Landmine | Pointer | Symptom |
| -------- | ------- | ------- |
| ... | `path:line` | ... |

_Categories to sweep for deliberately, since none of them announce
themselves: mutable global or module-level state; a library patched at
runtime; a hardcoded absolute path, host, or device; a config branch that can
no longer be reached; a default that differs between two entry points._

## Unmapped

_What was deliberately not covered, and why — vendored trees, generated code,
a subsystem that needs a domain expert. A map that does not admit its edges
gets trusted past them._
