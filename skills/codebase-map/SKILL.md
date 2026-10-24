---
name: codebase-map
description: Maps an unfamiliar codebase into a one-screen docs/CODEBASE_MAP.md — entry points, how to run it, config, where the data goes, and landmines, one fact per line with a path:line pointer. Use when picking up a codebase nobody in the session knows, when asked to explain, orient in, or onboard onto a repo, when asked where the data path, training loop, request lifecycle or config actually lives, when a research repo's install or first run fails on dependency or accelerator errors, and to refresh an existing map after an upstream pull. Writes only its own map; runs at most a bounded smoke step and hands every install and real run over.
---

# Codebase map

## Boundaries

- Run a command only if it passes the smoke-scale rule
  (`docs/research-skills.md` §3). Hand anything else over verbatim, with the
  reason. A handover is a successful step.
- Write only the map, in the repo's docs directory. Never change code:
  anything worth a fix becomes a landmine line.
- Never overwrite an existing map — update it (step 5).
- Every line carries a `path:line` you actually read. Nothing found → "none
  found".
- One screen: one fact per line, no paragraphs. A section past ~10 lines
  keeps the facts that would cost a newcomer most.

## 1. Seed

```bash
bash map.sh seed [DIR]
```

`created:` → fill it. `exists:` → step 5.

## 2. Read, in this order

1. **Entry points** — manifests before source; a declared entry point beats
   a plausible `main()`.
2. **Config** — follow one real value from its default to its consumer
   through every override layer. Then list the keys that go nowhere. This is
   the highest-value section.
3. **Where the data goes** — the real path, one stage per line. Read shapes
   and dtypes off the code or a recorded run; never assume them.
4. **How to run it** — the smallest command that proves each thing. For a
   research repo, or a failed install or first run: `references/first-run.md`.
5. **Landmines** — sweep each category the template names.

Delegate per-subsystem reads to subagents where the host has them.

## 3. Fill

- Replace every italic guidance line; a leftover one is an unfilled section.
- Keep every `##` heading of the template, in order.
- Not covered: one line `Not mapped: <what> — <why>` in its section.

## 4. Check, then record

- Read back each `path:line`: the line exists, is not blank, and says what
  the map claims. One line off is the usual error.
- Add a one-line pointer to the map in the repo's `PROJECT_STATUS.md`.

## 5. Update an existing map

1. `git diff --stat <commit>..HEAD`, with `commit` from the map's frontmatter.
2. Re-read only what moved; other lines keep their text and pointers.
3. Check the pointers you touched; set `commit` and `Mapped at`.
4. Report the diff — which sections moved and why — not a new map.

## Done

- Every section is filled or says "none found"; no guidance line is left.
- Every pointer is checked; `PROJECT_STATUS.md` points at the map.

Stop there. Fixing a landmine is a different task.
