---
name: research-experiment-setup
description: Sets up a research project so every run is recorded, comparable and reported from day one — run record and comparison key, counted vs. uncounted runs, execution route, raw data, tracker grouping, repo boundaries, report, host effects, eval protocol and doctor checks. Use when starting a new research project or experiment repo, when asked to make runs reproducible or comparable, to set up experiment tracking or wandb grouping, to decide what counts as a result, or when results from different runs cannot be compared. Maps the repo's existing parts first, adds only the gaps, and asks the human each decision.
---

# Research experiment setup

## Boundaries

- Ask the human each decision. A card default is your recommendation, never
  a silent choice.
- Adapt to the host: its language, names, layout, scheduler. Add only gaps;
  never rewrite a part that already does the job.
- Write only inside the target repo (`docs/research-skills.md` §2). Commands
  obey §3: run a smoke step; hand a counted run over.
- The kit ships no run scripts — you write them in the host's style. Script
  a step when it has one correct result, runs more than once, and fails
  silently; else write one line in the repo's instruction file.

## 0. Map

Read `docs/CODEBASE_MAP.md`. If there is none, run the `codebase-map` skill
first.

## 1. Seed

```bash
bash seed.sh [DIR]
```

- `created:` → add `Experiment setup started <date> — docs/EXPERIMENT_SETUP.md`
  to the repo's `PROJECT_STATUS.md`.
- `exists:` → resume at the first row whose State is not `built`/`exists`.

## 2. Map the cards — no code yet

For each card in `references/cards.md`, fill its row: the path that already
does it (State `exists`), a partial part (`partial`) or `gap`. Show the table
and stop until the human approves it.

## 3. Decide

Ask one numbered round: every `gap` or `partial` card, the card default as
your recommendation, its evidence line. Write each answer in **Decision**.
Cards 1, 2, 4 and 6 must be decided before the first counted run.

## 4. Build the gaps, in card order

- One commit per card; the body states the decision.
- A test for each script, where the repo has tests.
- Set State to `built` and **Lives at** to the path.

## 5. Bring-up and smoke run

1. Prove the model and sim run: the smallest-proof ladder in `codebase-map`'s
   `references/first-run.md`.
2. Smoke run through the chosen route (card 3). It writes a record (card 1),
   shows in the tracker under its key (card 5) and in the report (card 7).

Run it when it passes §3; else hand it over.

## 6. Counted run

Hand it over: the tag, the clean-tree check, the command. Then read it back
with the report. At the sim end state — smoke and counted run recorded,
grouped and reported — add `Sim end state reached <date>` to
`PROJECT_STATUS.md`.

## 7. Retro

Write at most 3 lines under **Retro**: what a card got wrong or missed. Tell
the human to apply them to this skill's `references/cards.md` as one commit.

## Done

- Every row has a Decision, and State `built` or `exists`.
- Smoke and counted run are recorded, grouped and reported.
- Both dates are in `PROJECT_STATUS.md`; the retro is written.
