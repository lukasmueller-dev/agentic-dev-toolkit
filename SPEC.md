# Spec — agentic-dev-toolkit / cross-repo-features

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `cross-repo-features`
- **Written:** 2026-11-02

## Goal

A feature that spans several repos (teleop: bridge, commander, VLA) is one unit: one spec, one row, one review decision, one merge batch.

## Non-goals

- No job that writes to two repos; a job stays in one repo.
- No cross-repo gate; the integration test stays the user's step.
- No live PR state (draft, checks) on the page.
- No command to change a feature's member list; the user edits the file.

## Decisions

- Model A: each job stays in one repo; a feature connects branches across repos. B (one job, N repos) costs ~12 core runner functions and serial slots; the teleop check found no interface that must change in one commit.
- A feature's PRs merge together, after the human test its Verify line names; work that can merge in parts is separate PRs.
- No feature gate until a feature has an integration test a machine can run.
- A member is `repo + branch` (one PR), listed in the feature file; no `feature=` key in job files — a PR with no job is still in the batch.
- A member can be a single job, a lane, a SPEC chain, or a PR with no job.
- The feature file holds a contract table (interface, owner repo, each copy as `repo:path`); a job never changes a row, it ends `blocked:` with the proposal; the user decides in `/review-jobs`.
- Feature file: `~/.local/state/vibe/features/<slug>.md` from `templates/FEATURE.md`; each member's `SPEC.md` holds only its milestones and a pointer line.
- A feature shows like a lane across repos: a `Features` group on top of the page, status and briefing; member jobs show only in the feature card.
- Card count = done members / members; done = has a PR, no job queued, running or in need of the user.
- Pill order: `needs you`, `running`, `queued`, `your test`, `merge` — members run in parallel, so a block is urgent.
- The runner adds a feature block to a member job's prompt at start (path + contract rule); skills do not write it.
- At publish the runner writes a `**Feature:**` line below the TL;DR (siblings as `repo#pr`, else `repo:branch`) and a `<details>` with the decisions and contract; sibling bodies stay untouched.
- The runner writes a member's PR URL into the feature file at publish; `vibe feature add` fills PRs that exist.
- `vibe feature add|ready|archive`; `/review-jobs` runs `ready` after the human test and `archive` once all member PRs merged.
- `/fill-queue` Phase 1 and `/enqueue` create a feature through one shared reference.
- `/review-jobs`: per-member actions under `needs you`, a `contract` action, one "Did your human test pass?" under `your test`, `close` closes each member PR.

## Milestones

- [x] `templates/FEATURE.md`, `vibe feature add|ready|archive` and bats tests — code — done when `bats tests/vibe-queue.bats` passes with the new feature tests
- [x] The runner: the prompt block, the PR body, the PR URL write-back — code — done when the bats tests for prompt, body and URL pass
- [ ] The `Features` group in status, briefing and page — code — done when the bats tests for status, report and page pass
- [ ] The shared reference, `/fill-queue` (with a `feature` column), `/enqueue`, `/review-jobs` — code — done when `./bin/skill-lint --strict skills` passes
- [ ] `docs/vibe-queue.md` `## Features`; delete `SPEC.md` and `HANDOFF.md` — code — done when the four gate commands of `CLAUDE.md` pass and neither file is on the branch

## End action

`delete`; each decision moves to the PR body.
