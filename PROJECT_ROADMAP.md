# Project Roadmap — agentic-dev-toolkit

> Long-lived, one per repo. Planned work only: one item per task, each
> designed well enough that a session can pick it up cold, without the
> discussion that produced it. A snapshot, not a log — finished items are
> removed; their trail lives in git history and merged PRs.

_Last updated: 2026-10-28 · turing_

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

- [ ] **Catalogue job `dependency-update`** — `uv` first, minor and patch
      only, one PR per repo per week when the suite is green, majors in the
      report. Done when a repo with an outdated lock gets one draft PR with a
      green suite, and a red suite yields a report line naming the package.
- [ ] **Catalogue job `flaky-tests`** — runs the suite N times, reports tests
      that fail in some runs. Done when a seeded flaky test shows up as one
      report line with its pass/fail counts.
- [ ] **Catalogue job `codebase-map`** — refreshes `docs/CODEBASE_MAP.md`
      after upstream pulls via the `codebase-map` skill. Done when a changed
      entry point produces one docs-only commit on `jobs/codebase-map`.
- [ ] **Kind `gpu` for recurring jobs + catalogue job `eval-regression`** —
      the job queues the canonical eval through `gpu-queue`; the follow-up
      compares the headline metric with the last run. Done when a drop opens
      a roadmap item and the briefing shows both numbers.
- [ ] **Catalogue job `fresh-env`** — `uv sync` in a clean env plus one smoke
      step. Done when a missing dependency yields one report line with the
      failing import.
- [ ] **Catalogue job `bib-check`** — bib entries vs arXiv (new versions,
      venue), dead DOIs; corrected entries as one commit. Done when a stale
      preprint entry becomes a commit and a dead DOI a report line.
- [ ] **Catalogue job `config-drift`** — config keys no code reads, code
      flags no config sets; roadmap items only. Done when one unread key
      yields one roadmap item with a grep-checkable done-when.
- [ ] **Briefing `--week`** — a Sunday section of `vibe queue report`: PRs
      merged, jobs run, blockers open, per repo. Done when
      `vibe queue report --week` renders it from the week's briefings and PRs.
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

