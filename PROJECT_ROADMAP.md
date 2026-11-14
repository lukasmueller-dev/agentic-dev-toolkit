# Project Roadmap — agentic-dev-toolkit

> Long-lived, one per repo. Planned work only: one item per task, each
> designed well enough that a session can pick it up cold, without the
> discussion that produced it. A snapshot, not a log — finished items are
> removed; their trail lives in git history and merged PRs.

_Last updated: 2026-11-09 · queue-verify-skills_

## Items

One item per PR — sized so a `HANDOFF.md` (the `handoff-brief` skill) can be
staged straight from it. Order matters within a track; tracks are independent.

- [ ] **Run `research-experiment-setup` on NCBF** — after the author reviews
      `references/cards.md` and both research `SKILL.md` files; card table
      first, on the author's branch off `pncbf-v2` (NCBF facts: PR #87 body);
      apply the retro to `references/cards.md` as one commit.
      Done when NCBF's `PROJECT_STATUS.md` has the kit start date and the sim
      end-state date, and the cards carry the retro commit.
- [ ] **Keep one whole-repo audit job** — run `repo-review` and `lean-audit`
      on one repo; delete the weaker job's catalogue file and its
      `docs/vibe-jobs.md` row; decide if `codebase-health` keeps its dedup
      and complexity scan. PR for `queue-verify-skills`.
      Done when
      `ls skills/recurring-jobs/references/jobs | grep -cE '^(repo-review|lean-audit)\.md$'`
      prints `1` and `grep -n codebase-health PROJECT_STATUS.md` prints the
      scan decision.

### Vibe queue follow-ups (design: PR for `job-review`)

- [ ] **Repeated roadmap cleanup** — a recurring vibe job per repo deletes
      the roadmap items the repo proves done or dead, with one proof line each.
      Done when one recurring job per repo queues and its PR changes only
      `PROJECT_ROADMAP.md`.

### Health items (repo review of 2026-11-03)

- [ ] **[health] Prove the job write fence** — `blockWritesOutsideWorkingDirectories`
      is in `claude/vibe-job-settings.json`, but the settings reference did not
      list it (`docs/sota/2026-W44.md`) and no test shows a refused write.
      Done when a smoke job's Write outside its worktree and job dir is
      refused, and its `result` and `report.md` still land.
