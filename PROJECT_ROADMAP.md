# Project Roadmap — agentic-dev-toolkit

> Long-lived, one per repo. Planned work only: one item per task, each
> designed well enough that a session can pick it up cold, without the
> discussion that produced it. A snapshot, not a log — finished items are
> removed; their trail lives in git history and merged PRs.

_Last updated: 2026-11-02 · docker-gate-sessions_

## Items

One item per PR — sized so a `HANDOFF.md` (the `handoff-brief` skill) can be
staged straight from it. Order matters within a track; tracks are independent.

- [ ] **Run `research-experiment-setup` on NCBF** — after the author reviews
      `references/cards.md` and both research `SKILL.md` files; card table
      first, on the author's branch off `pncbf-v2` (NCBF facts: PR #87 body);
      apply the retro to `references/cards.md` as one commit.
      Done when NCBF's `PROJECT_STATUS.md` has the kit start date and the sim
      end-state date, and the cards carry the retro commit.

- [ ] **Count PRs in "to review"** — `queue_counts` in `bin/vibe` counts
      each distinct URL in the `pr` files once and puts ended jobs with no
      URL in `no PR`; the page chip links the open `agent` PRs on GitHub.
      Done when `bats tests/vibe-queue.bats` passes with the new tests and
      the chip row shows the PR count with the GitHub link below it.

### Vibe queue follow-ups (design: PR for `job-review`)

- [ ] **PR event follow-ups** — on an `agent` PR, your "Request changes"
      review or a `/fix` comment starts a fix job; a red CI check later.
      Done when a `/fix` comment from your login yields one fix job and one
      summary comment on the PR, and a collaborator's comment only a
      briefing line.
