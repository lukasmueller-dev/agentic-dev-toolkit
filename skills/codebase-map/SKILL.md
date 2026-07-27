---
name: codebase-map
description: Maps an unfamiliar codebase into docs/CODEBASE_MAP.md against a fixed schema — entry points, config resolution, dependency graph, how to run it, and the landmines that cost an afternoon. Use when picking up a codebase nobody in the session knows, when asked to explain, orient in, or onboard onto a repo, when asked where the data path, training loop, request lifecycle or config actually lives, and to refresh an existing map after an upstream pull. Reads and writes only its own map; never runs the expensive thing.
---

# Codebase map

## Boundaries

- **Never run the expensive thing.** Reading the repo is the job. A command
  may be executed only if it passes all five tests in
  `docs/research-skills.md` §6 — one process on one device, no scheduler
  submission, under about two minutes behind a hard `timeout`, under roughly
  1 GB of download, no side effects outside the repo. Anything else is
  **handed over**: printed verbatim, copy-pasteable, with the reason it was
  not run. Handing a command over is a successful outcome of a step, not a
  failure to complete it.
- **Never write outside the target repo**, and never above its root. The map
  goes in the repo's documentation directory, never its root.
- **Never overwrite an existing map.** A repo that already has one gets a
  diff, not a replacement — that is the whole reason the schema is fixed.
- **Never change code.** No fixes, no cleanups, not even a typo. Everything
  worth fixing goes in the map as a landmine.
- **Never guess a pointer.** Every claim in the map carries a `path:line`
  that was actually read. A section with nothing behind it says "none found"
  — an unsupported claim is worse than a gap, because a gap is visible.

## 1. Classify the repo

```bash
bash map.sh detect [DIR]
```

Prints the verdict — `research`, `application` or `ambiguous` — and one
evidence line per matched signal, from both sides. Do not re-derive this by
reading files: the point of a shared detection is that every skill in the
family classifies a repo the same way.

**`ambiguous` means ask, and it is a normal path, not an error.** Show the
evidence lines and the two candidate verdicts, and let the human pick. A
repo with signals on both sides is the common case, not a broken one.

The mode decides which middle section of the schema gets **depth**, not which
sections exist. A research codebase with a serving path is normal, and so is
the reverse.

## 2. Seed the artifact

```bash
bash map.sh seed research|application [DIR]
```

Creates the repo's `docs/CODEBASE_MAP.md` from the toolkit's template — an
empty schema with the mode and the commit recorded in its frontmatter. Never
write this document from memory: one copy of the schema lives in
`templates/codebase/CODEBASE_MAP.md`, and copies drift.

If it prints `exists:`, the repo already has a map. **Skip to phase 6** — the
job is now an update, not a mapping.

## 3. Read, in this order

The order is chosen so each phase makes the next one cheaper. Where the host
offers subagents, delegate the per-subsystem reads so their file dumps stay
out of the main context; where it does not, read sequentially. Nothing here
requires a subagent.

1. **Entry points.** Every way execution starts. Grep the manifests for
   console scripts and run targets before grepping the source — a declared
   entry point is authoritative, a plausible-looking `main()` is not.
2. **Config resolution.** Follow one real value from its default to the code
   that consumes it, through every layer that can override it. Then look for
   the keys that go nowhere: read under a different name, dropped by a schema
   that ignores unknown fields, or shadowed by a later layer. **This is the
   highest-value section of the map** — a typo'd override that silently
   changes nothing costs more debugging time than anything else in a config
   tree, and it is invisible from the config file alone.
3. **The middle section for the mode.** Follow the actual path, in order,
   with a pointer per stage. For a research repo that is data → model forward
   → loss → eval → checkpoints; for an application repo, request lifecycle →
   state → external services → auth → build and deploy. Read shapes, dtypes
   and ranges off the code or a recorded run — never assume them, and say so
   where they could not be established.
4. **Dependency graph.** Only the edges that explain the structure. Note
   cycles explicitly.
5. **How to run it.** The smallest command that proves each thing works.
   Anything expensive is listed with its cost, per the boundary above.
6. **Landmines.** Sweep deliberately for each category the template lists —
   mutable global state, runtime patching of a library, hardcoded paths,
   hosts and devices, unreachable config branches, a default that differs
   between two entry points. None of these announce themselves, which is why
   they get their own pass rather than being noticed in passing.

## 4. Fill the schema

Fill every section in place. Sections are never dropped or reordered: a
fixed schema is what makes two repos comparable and a re-run diffable.

- A section with nothing to report keeps its heading and says so in one line.
- Anything deliberately not covered goes under **Unmapped**, with the reason.
  A map that does not admit its edges gets trusted past them.
- Replace the template's italic guidance lines as you go. A leftover
  guidance line is an unfilled section, and reads as one.

## 5. Verify every pointer

**Do this before reporting the map as finished, not as a spot check.** Read
back the line each `path:line` actually names and confirm it says what the map
claims. A pointer landing one line off — on the comment above a field, on a
blank line, on the `if` above the branch — is the normal failure, because line
numbers get recorded while reading and the reading moves on. It is also the
worst kind of error the map can carry: confidently wrong, and trusted.

Two mechanical checks worth running rather than eyeballing:

- Every `path:line` resolves, and the line is not blank.
- Every `###` heading from the template is still present. A section quietly
  collapsed into a bullet list is a section that no longer lines up against
  the same section in another repo's map.

## 6. Record it in the project status

Add a one-line pointer to the map in the repo's `PROJECT_STATUS.md`, beside
whatever else lives under its docs pointers. That line is how a session that
starts cold finds a map it did not know existed.

## 7. Updating an existing map

Re-running on a mapped repo is a **diff**, never a regeneration.

1. Read the `commit` in the existing map's frontmatter and diff the repo
   against it — `git diff --stat <commit>..HEAD` names which subsystems
   actually moved.
2. Re-read only those. A section no change touched keeps its existing text
   and its existing pointers.
3. Verify the pointers in the sections you did re-read: a `path:line` that
   has drifted is worse than no pointer, because it is confidently wrong.
4. Update the `commit` in the frontmatter and the `Mapped at` line.
5. Report what changed as a summary of the diff — which sections moved and
   why — not as a fresh map.

## Done

- Every schema section is filled, and every claim carries a `path:line` that
  was actually read — and verified per phase 5.
- Every `###` heading the template ships with is still there.
- Every remaining italic guidance line is gone.
- `PROJECT_STATUS.md` points at the map.
- On a re-run: the map's frontmatter names the new commit, and the report is
  a diff of what moved rather than a new document.

Stop there. Fixing what the map found is a different task — the landmines
section is the handoff to it.
