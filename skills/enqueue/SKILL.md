---
name: enqueue
description: "Puts the one item just discussed in this session on the vibe queue as a single headless job that ends in a draft PR. Use when the user says 'enqueue this', 'queue this', 'put this on the queue', 'let the queue run this', or a discussion has scoped one feature or task that an unattended agent should do instead of this session. A small item becomes a job prompt; a big item (several milestones, a GPU run) becomes a SPEC.md on its own branch; an open question with a metric and a budget becomes a research job (a RESEARCH.md backlog the agent works off); work on several branches that merge together becomes a feature, one job per member. Adds one item; never sweeps the repos."
disable-model-invocation: true
argument-hint: "[<task name>]"
---

# Enqueue

Queue the one item the conversation just settled. `/fill-queue` is the batch
version; this is the single-item version. Runner and layout:
`docs/vibe-queue.md` in the toolkit. Gate, job dir and prompt template:
`skills/fill-queue/SKILL.md` — this skill points there and copies nothing.

## Hard boundaries — never do these

- **Never add a job without explicit approval of the full draft.**
- **Never create, write or push anything before that approval.**
- **Never queue more than one item**: one job, or one job per member of one feature. Never sweep or rank other items.
- **Never write a `SPEC.md` or a `RESEARCH.md` for a section the user did not settle** — grill the gap first.
- **Never queue an item that fails the gate** (`fill-queue` Phase 3). Show the failed rule and stop.
- **Never queue a branch that is already queued or running** (`vibe queue status`).
- **Never change the repo yourself** on the small route.

## Phase 1 — Harvest

The raw material is the discussion. Collect the goal, the decisions and the
rejected options with the reason, the files that matter, the constraints and
the first step. If the discussion settled no item, say so and stop.

- Repo: the main checkout of the current repo, as an absolute path. In a worktree, use the parent of `git rev-parse --git-common-dir`.
- Source: `PROJECT_ROADMAP.md:<line>` when the item is on the roadmap; else `new`.
- Task name: `$ARGUMENTS`, else a short slug. It becomes the branch.

## Phase 2 — Route

- **Small:** one done-when. Route: prompt only.
- **Big:** several milestones, or a GPU run. Route: `SPEC.md`.
- **Research:** an open question with one metric, a budget and 2 or more candidate experiments; the next run depends on the last result. Route: `RESEARCH.md`.
- **Feature:** 2 or more branches that merge together, most often in several repos. Route: `skills/fill-queue/references/feature.md`.

Propose the route in the draft. The user may change it.

## Phase 3 — Draft

Check `vibe queue status` and the gate. Then fill the draft:

- Task, verbatim for the job. Context: the problem and the idea, ≤25 words.
- Done-when: a check a command can make. Kind: `code` or `gpu`.
- Branch slug, model, timeout. Defaults and the Opus rule: `fill-queue` Phase 4. `effort=` only when the user names one.
- Verify: `-`, unless the user asks for it. Values and limits: `fill-queue` Phase 4 step 8.
- Small: add the harvest (decisions, rejected options, files, first step) to the Task section of the prompt.
- Big: the full `SPEC.md` from `templates/SPEC.md`. Take each section from the conversation. Run the `grilling` skill on the sections it left open, and on those only. The gate applies to each milestone.
- Research: the full `RESEARCH.md` from `templates/RESEARCH.md`. Take each section from the conversation; grill only the open sections.
  Each backlog item has its pass criterion in the draft. Kind `gpu`. `deadline=`: the deadline of its Budget section.
- Feature: the feature file and each member's `SPEC.md`, per the reference's step 1; grill only the open sections.

## Phase 4 — Approve

Show the draft as one piece: route, job line, and for a big item the whole
`SPEC.md`; for a research item the whole `RESEARCH.md`; for a feature the feature file and each member's `SPEC.md`. **Stop and wait for explicit approval.** Apply each change the user
asks for, then show the draft again.

## Phase 5 — Stage (big, research and feature)

Big: do `fill-queue` Phase 1 step 5: worktree and branch, `SPEC.md`, `HANDOFF.md`
(next action: the first milestone with its done-when), commit
`docs(spec): <slug>`, push. Research: the same with `RESEARCH.md` in place of `SPEC.md`;
commit `docs(research): <slug>`. Feature: the reference's steps 2 and 3.

## Phase 6 — Add

Write one job dir (`mktemp -d`) as `fill-queue` Phase 6 describes: `job` and
`prompt.md` from `skills/fill-queue/references/job-prompt.md`, every `<…>`
filled; `verify=` only when the draft sets it. Research: append
`skills/fill-queue/references/research.md` to `prompt.md`, and add `deadline=YYYY-MM-DD HH:MM` to `job`. A feature: one job dir per member with a `SPEC.md`. Then, outside the
sandbox: `vibe queue add <dir>...`. Add `--now` only when the user asked for it.

## Done

Done when `vibe queue add` printed one `queued` line per job. Report in 2 lines:
the job ids and route, `vibe queue status`.
