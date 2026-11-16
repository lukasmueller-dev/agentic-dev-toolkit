# Project Roadmap — agentic-dev-toolkit

> Long-lived, one per repo. Planned work only: one item per task, each
> designed well enough that a session can pick it up cold, without the
> discussion that produced it. A snapshot, not a log — finished items are
> removed; their trail lives in git history and merged PRs.

_Last updated: 2026-11-16 · workspace bring-up_

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

- [ ] **Update the mattpocock vendor pin** — the pin `59db609` is 7 commits
      behind upstream `main`; `7739eae` changes one line of `grilling`. Run
      `bin/plug update mattpocock`; commit conf, lock and `vendor/` together.
      Done when `bin/plug verify` passes on the new pin and
      `bin/skill-lint --strict skills` reports 0 errors.

### Vibe queue follow-ups (design: PR for `job-review`)

- [ ] **Opt every roadmap repo into `roadmap-cleanup`** — the catalogue job
      exists, but only this repo opts in, and it has never run. In each repo
      with a `PROJECT_ROADMAP.md`: `vibe job add <repo> roadmap-cleanup`, commit.
      Done when
      `for r in ~/github/*/PROJECT_ROADMAP.md; do [ -f "${r%/*}/.vibe-jobs/roadmap-cleanup.md" ] || echo "$r"; done`
      prints nothing, and `gh pr diff <n> --name-only` on the first
      `jobs/roadmap-cleanup` PR prints only `PROJECT_ROADMAP.md`.

### Health items (repo review of 2026-11-03)

- [ ] **[health] Deny any short force-flag cluster in `git push`** — deny rules
      match whole tokens and `*` spans spaces, so `-vf`, `-fv`, `-qf` and `-fuv`
      still pass; `git push -*f*` would also block `git push -u origin feature`.
      Done when a `PreToolUse` hook denies a `git push` flag cluster that holds
      `f`, a bats test shows `-vf` and `-fuv` denied and `git push -u origin
      feature` allowed, and the hook is wired in `claude/settings.json` and
      `.claude-plugin/hooks.json`.
- [ ] **[health] Prove the job write fence** — `blockWritesOutsideWorkingDirectories`
      is in `claude/vibe-job-settings.json`, but the settings reference did not
      list it (`docs/sota/2026-W44.md`) and no test shows a refused write.
      Done when a smoke job's Write outside its worktree and job dir is
      refused, and its `result` and `report.md` still land.

### Workspace first runs (recipes: `docs/workspaces/<tool>.md`)

- [ ] **First AutoResearchClaw run** — at the first real use, queue recipe
      step 3 on turing (`tool=autoresearchclaw`, `hours=4`). The image and
      `autoresearchclaw.env` exist; step 2 passed on 2026-11-16. Revoke the
      token after the run.
      Done when `out/result` starts with `done:` and the recipe holds what
      the run proved wrong.
- [ ] **First AutoResearch run** — at the first real use, queue recipe
      step 5 on turing (`tool=autoresearch`). The image and `autoresearch.env`
      (OpenRouter route) exist; `ar-preflight-mcp.sh` passed on 2026-11-16.
      Done when `out/result` starts with `done:`, `out/files` holds the six
      paths, and the recipe holds what the run proved wrong.
