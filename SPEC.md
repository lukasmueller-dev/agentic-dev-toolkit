# Spec — agentic-dev-toolkit / vibe-lanes

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `vibe-lanes`
- **Written:** 2026-10-29

## Goal

Related queue items run as one lane: one branch, one PR, one row in the views, one review decision.
A failed item leaves the lane; the lane continues.

## Non-goals

- A recurring job's own PR and the fix lane from its roadmap items stay 2 PRs.
- No hard cap on lane size; no GPU or heavy items in a lane.
- No lane id: the branch is the lane.
- No change to merges: the user merges.

## Decisions

- A lane is the unarchived jobs on one branch: one PR, one job and one commit per item, in series — one review and one merge instead of N.
- `/fill-queue` proposes lanes from one tag (`[health]`) or one roadmap heading; the user changes the `lane` column before approval — only the user knows what belongs in one PR.
- Each lane job carries `lane=<one-line context>` and `item=<slug>` — the row and the PR need a lane line, the side branch an item name.
- Light, non-GPU items only — a `gpu` job does not mark its branch busy (runner loop in `bin/vibe`); a reviewer reads a big lane commit by commit.
- A lane closes when its last item finishes; no new item joins — else an unmerged PR grows each week.
- A `failed`, `blocked` or `timeout` item leaves the lane: WIP commit, push `<branch>-<item>` without a PR, reset the lane branch to the item's start commit, continue — today's isolation without a stop.
- The failure path runs before `job_publish`, so the lane branch never needs a force push.
- A usage limit only pauses the lane: the job keeps its id and FIFO place.
- A retry starts from the current tip: the lane branch while its PR is open, else a new branch from the default branch; the side branch is only a reference — an old base conflicts in `PROJECT_ROADMAP.md`.
- Views show one row per branch with progress (`3/5`); a job row only for a job that needs the user; `SPEC.md` chains and recurring runs group the same way.
- The runner writes the lane PR again after each item, in the `templates/job-pr.md` shape — today the last body replaces the others.
- `/review-jobs` gives one decision per lane, only when each item is done or out of the lane.

## Milestones

- [x] Lane PR: `job_publish` builds title and body of a lane PR from every unarchived job on the branch — title `agent(<branch>): <lane line>` (≤60 characters), Context = `lane=`, Changed = one line per done item plus `<item> → <side-branch>` per item out of the lane, Verify and Decisions/risks without duplicates, one `<details>` per item. A branch without `lane=` keeps today's behavior. — code — done when `bats tests/vibe-queue.bats` passes with a new test: 2 done lane jobs give one PR body with both Changed lines.
- [ ] Failure path: `job_prepare` records the start commit in the job dir; a lane job that ends `failed`, `blocked` or `timeout` gets a WIP commit of uncommitted changes, branch `<branch>-<item>` at its HEAD pushed without a PR (name in the job dir), and the lane worktree reset to the start commit — all before `job_publish`. Usage limit unchanged. — code — done when `bats tests/vibe-queue.bats` passes with a new test: a failed lane job leaves the lane branch at its start commit and its work on `<branch>-<item>`, and the next lane job runs.
- [ ] Lane rows: `vibe queue status` and `vibe queue report` show one row per repo and branch with 2+ jobs — `<branch> · <done>/<total> · <running or next item> · <PR>` and the `lane=` line (else the latest context); below it one row per job that needs the user (`blocked`, `failed`, `timeout`, `skipped`, out of the lane with its side branch). A one-job branch prints as today. — code — done when `bats tests/vibe-queue.bats` passes with a new test: a 3-job lane prints one row in `vibe queue status`.
- [ ] `/fill-queue` + docs: Phase 4 proposes lanes (one tag or one roadmap heading, light non-GPU items); the Phase 5 table gets a `lane` column; Phase 6 writes `lane=` and `item=` and one job per item on the lane branch; the queued-branch rule admits the jobs of one new lane, and no item joins a queued or open lane branch. `docs/vibe-queue.md` gets the lane rules and both keys. — code — done when `./bin/skill-lint --strict skills` and `bats tests/` pass, and `grep -c 'lane=' docs/vibe-queue.md skills/fill-queue/SKILL.md` prints ≥1 for each file.
- [ ] `/review-jobs`: a lane row gets one decision (ready, requeue, hold, close), offered only when each item is done or out of the lane; until then the row shows its progress. A requeue of an item out of the lane queues it on the lane branch while the lane PR is open, else on a new branch from the default branch; its prompt names `git diff <start>..<side-branch>` as an earlier try. — code — done when `./bin/skill-lint --strict skills` and `bats tests/` pass, and `grep -c 'lane' skills/review-jobs/SKILL.md` prints ≥3.
- [ ] End action: delete `SPEC.md`, move each decision to `pr.md`. — code — done when `test ! -e SPEC.md` and `test ! -e HANDOFF.md`.

## End action

`delete` — `docs/vibe-queue.md` holds the rules after milestone 4. Each decision moves to the PR body.
