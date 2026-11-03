# Spec — agentic-dev-toolkit / repo-review-fixes

- **Repo:** agentic-dev-toolkit
- **Branch:** `repo-review-fixes`
- **Written:** 2026-11-03
- **Source:** repo-review report of 2026-11-03, findings 1–10 (copied below).

## Goal

The 10 findings of the repo review are repaired, each with a bats test that fails before the fix.

## Non-goals

- The 4 low items of the report (shared `.tmp` name, member paths not absolute, `git push -fu` deny match, `blockWritesOutsideWorkingDirectories`): they go to the roadmap as `[health]` items.
- No new runner features; no change to the queue layout.

## Findings

1. `skills/worktree-cleanup/cleanup.sh:155` — `git worktree remove` deletes git-ignored files; `classify` (:61) does not check for them.
2. `skills/worktree-cleanup/cleanup.sh:82` — a `[gone]` upstream is rated `merged` with no merge check; `remove` runs `branch -D`.
3. `bin/vibe:703` (also :2389-2390) — the runner runs `git push` and the triage `merge`/`push` unsandboxed in a tree the agent wrote; a relative `core.hooksPath` runs the agent's hook with the user's credentials.
4. `claude/settings.json:27,180` — allow `git fetch:*` plus sandbox exclusion `git fetch *`: `git fetch --upload-pack='<cmd>' .` runs `<cmd>` outside the sandbox. Same for `ls-remote` (:20). The installer unions arrays.
5. `bin/vibe:635` (`job_limit_pct`) — each job scans every queued and archived job: `vibe queue report` takes 28 s with 300 archived jobs; the runner calls it each pass.
6. `bin/vibe:2137` (`job_due`) — no check for a queued or running copy: a paused queue queues one copy per night.
7. `bin/vibe:1264` with `:1042` — `queue follow` ends the parent `done`, then `job_end … gpu` overwrites it (no guard, :347); the follow-up can start while the parent still pushes.
8. `skills/_lib/lib.sh:112` — `ff_main_quiet` ends in `merge && info`; a failed merge stops the caller under `set -e` with no message.
9. `bin/vibe:1864` (`feature_row`) — ignores the gate: a member `done` with gate exit 1 counts as done.
10. `bin/vibe:1487` — pandoc passes raw HTML from job-written text into the queue page.

## Decisions

- Finding 1: an allowlist of regenerable ignored paths (`.venv`, `node_modules`, `__pycache__`, `.pytest_cache`, `.claude/settings.local.json`, build caches) in `cleanup.sh`; any other ignored file → new state `ignored` (keep), reason names up to 3 paths; `remove` refuses it.
- Finding 2: `[gone]` is `merged` only when `gh pr list --head <branch> --state merged --json headRefOid` finds a PR whose head equals the local HEAD or has it as ancestor; `gh` fails or no merged PR → `unpushed`. Keeps squash-merged branches removable.
- Finding 3: one small wrapper adds `-c core.hooksPath=/dev/null` to every unsandboxed git call the runner makes on an agent tree; the PR body lists each call. `--no-verify` rejected: `post-merge`/`post-checkout` still run.
- Finding 4: remove the `git fetch *` sandbox exclusion; keep the allow rules, so fetch runs sandboxed without a prompt. Deny rules for `--upload-pack` rejected: mid-command wildcards are unverified.
- Finding 4 migration: the installer gets a `retired` list of entries it deletes from `~/.claude/settings.json` at each install.
- Finding 5: `job_limit_pct` reads only jobs whose `ended` time is in the last 5 h.
- Finding 6: `job_due` skips a recurring job when a queued or running job with the same `recurring=` name exists.
- Finding 7: `job_end` keeps a status a follow-up already wrote; the runner starts a follow-up only after its parent has an `ended` file.
- Finding 8: `ff_main_quiet` prints the git error and the reason, and keeps the non-zero exit.
- Finding 9: `feature_row` counts a member job with gate exit ≠ 0 as `needs you`.
- Finding 10: pandoc runs with `-f markdown-raw_html`; raw HTML shows as text.
- One branch, one PR; one milestone per area, one commit each. Behavior changes update `docs/vibe-queue.md` or the skill docs in place.

## Milestones

Each milestone also passes the repo gate: `shellcheck`, `shfmt -d -i 2 -ci`, `skill-lint --strict skills`, `bats tests/`.

- [ ] `cleanup.sh` ignored-file allowlist and `[gone]` check (findings 1, 2) — code — done when new tests in `tests/worktree-cleanup.bats` show: a worktree with `runs/x.ckpt` is `ignored`, a `[gone]` branch without a merged PR is `unpushed`, a squash-merged branch is `merged`
- [ ] Runner hooks wrapper (finding 3) — code — done when a bats test with a relative `pre-push` hook that writes a marker finds no marker after `job_publish` and `triage_merge`
- [ ] Fetch rules and installer `retired` list (finding 4) — code — done when an `install.bats` test shows `git fetch *` gone from a user settings file that held it
- [ ] `job_limit_pct` 5 h window (finding 5) — code — done when a bats test with 300 old archived jobs shows none is read; PR body gives the measured `vibe queue report` time
- [ ] Queue state: `job_due` copies, `job_end` guard, follow-up waits for `ended` (findings 6, 7) — code — done when one bats test per rule passes
- [ ] Small fixes: `ff_main_quiet`, `feature_row` gate, pandoc `-raw_html` (findings 8–10) — code — done when one bats test per fix passes
- [ ] End action — code — done when `git ls-files SPEC.md` prints nothing, each decision is in the PR body, and `PROJECT_ROADMAP.md` holds the 4 low items as `[health]` items

## End action

`delete`. Each decision moves to the PR body.
