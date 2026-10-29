# Project Roadmap — agentic-dev-toolkit

> Long-lived, one per repo. Planned work only: one item per task, each
> designed well enough that a session can pick it up cold, without the
> discussion that produced it. A snapshot, not a log — finished items are
> removed; their trail lives in git history and merged PRs.

_Last updated: 2026-10-29 · turing_

## Items

One item per PR — sized so a `HANDOFF.md` (the `handoff-brief` skill) can be
staged straight from it. Order matters within a track; tracks are independent.

- [ ] **Run `research-experiment-setup` on NCBF** — after the author reviews
      `references/cards.md` and both research `SKILL.md` files; card table
      first, on the author's branch off `pncbf-v2` (NCBF facts: PR #87 body);
      apply the retro to `references/cards.md` as one commit.
      Done when NCBF's `PROJECT_STATUS.md` has the kit start date and the sim
      end-state date, and the cards carry the retro commit.

### Recurring jobs (design: PRs #99–#102, `docs/vibe-jobs.md`)

- [ ] **Kind `gpu` for recurring jobs + catalogue job `eval-regression`** —
      the job queues the canonical eval through `gpu-queue`; the follow-up
      compares the headline metric with the last run. Done when a drop opens
      a roadmap item and the briefing shows both numbers.
- [ ] **Catalogue job `repo-review`; delete `codebase-review`** — monthly,
      `output=report`, Sonnet, 1h: `/code-review high .` on the whole repo;
      toolkit focus lines in `.vibe-jobs/repo-review.md`. Done when one run
      writes a `report.md` with ranked findings and `skills/codebase-review/`
      is gone.

### Vibe queue follow-ups (design: PR for `job-review`)

- [ ] **PR event follow-ups** — on an `agent` PR, your "Request changes"
      review or a `/fix` comment starts a fix job; a red CI check later.
      Done when a `/fix` comment from your login yields one fix job and one
      summary comment on the PR, and a collaborator's comment only a
      briefing line.
- [ ] **Memory cap per job** — the runner starts each job in its own cgroup
      with a memory limit, so one job cannot get the whole
      `vibe-queue.service` killed (oomd incident: runner journal,
      2026-10-29 13:31). Done when a job past its cap ends alone as `failed`
      and the other running jobs keep running.
- [ ] **Re-queue a job whose process died** — the runner sets such a job back
      to `queued` one time, in place of `failed "job process died"`
      (`bin/vibe:1093`), and the job continues in its own worktree. Done when
      a killed job runs again on the next poll, and a second death ends it
      as `failed`.

