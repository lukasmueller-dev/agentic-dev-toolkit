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

- [ ] **[health] End `bin/gpu-queue` in an exit group** — bash reads a script
      while it runs; an in-place edit during a long `gpu-queue run` can make it
      read new text after the final `esac` (`unexpected EOF`). `bin/vibe` has
      the `{ case …; exit; }` fix (PR #177).
      Done when a bats test edits a copy of `bin/gpu-queue` in place during a
      run and the run exits 0; the test fails on the old file.
- [ ] **[health] Unique temp names in `bin/vibe`** — 4 writers use a fixed
      `<file>.tmp` (queue page, `feature_set_pr`, `feature_prompt`,
      `cmd_feature_add`); two runners at once share the name. Use `mktemp` in
      the file's directory.
      Done when `grep -nE '"\$[a-z0-9]+\.tmp"' bin/vibe` prints nothing and a
      bats test with two parallel `feature_set_pr` calls leaves a whole file
      and no `.tmp`.
- [ ] **[health] Absolute member paths in `vibe feature add`** — `is_member`
      and `feature_of` compare the member path as a string with the job's
      absolute `repo`; a relative path never matches, so its jobs miss the
      feature. `cmd_feature_add` accepts it.
      Done when a bats test shows `vibe feature add` with member `./repo <branch>`
      exits non-zero and names the path.
- [ ] **[health] Deny `git push` with a combined force flag** — the deny rules
      name `-f` as a whole word, so `git push -uf origin x` passes (and `-fu`,
      if `:*` ends at a word boundary).
      Done when a bats test finds deny rules for `-fu` and `-uf` in
      `claude/settings.json`, and `git push -u origin x` stays allowed.
- [ ] **[health] Prove the job write fence** — `blockWritesOutsideWorkingDirectories`
      is in `claude/vibe-job-settings.json`, but the settings reference did not
      list it (`docs/sota/2026-W44.md`) and no test shows a refused write.
      Done when a smoke job's Write outside its worktree and job dir is
      refused, and its `result` and `report.md` still land.
