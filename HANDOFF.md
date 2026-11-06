# Handoff — agentic-dev-toolkit / repo-review-fixes

- **Repo:** agentic-dev-toolkit
- **Branch:** `repo-review-fixes`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/repo-review-fixes
- **Last updated:** 2026-11-07 · job

## State

Milestones 1 (findings 1, 2), 2 (finding 3), 3 (finding 4), 4 (finding 5) and 5 (findings 6, 7) done.
Full `bats tests/` passes in a clone (369 tests, 0 failures).
Milestone 5 (commit `97ece80`): `job_due` returns `queued` while an unfinished copy is in the queue (`job_live`); `job_end` keeps a final status when asked for `gpu`; a follow-up records `parent=` and the runner starts it once the parent has an `ended` file.

## Next action

Milestone 6 of `SPEC.md`: small fixes (findings 8–10) — `ff_main_quiet` (`skills/_lib/lib.sh`) prints the git error and the reason and keeps the non-zero exit; `feature_row` (`bin/vibe`) counts a member job with gate exit ≠ 0 as `needs you`; pandoc runs with `-f markdown-raw_html`. Done when one bats test per fix passes.
Then milestone 7, the end action: delete `SPEC.md` and `HANDOFF.md`, move each decision to `pr.md`, add the 4 low items of the review to `PROJECT_ROADMAP.md` as `[health]` items.

Carry to the final `pr.md`:

- Finding 3: `agent_git` (`skills/_lib/lib.sh`) wraps every unsandboxed git call on an agent tree: `bin/vibe` runner calls (`open_worktree`, `job_start`, `job_gate`, `lane_leave`, `job_publish`, review, `triage_merge`), `sync_wt` (`vibe sync`, run by the shutdown skill), and `ensure_worktree` for the two cases that check out an existing branch.
- Finding 3, not wrapped: `gh`'s own git calls (before auth only `git remote`, `git config`; `pr create` after auth unchecked). Main-checkout reads and fetch. New-branch `worktree add` (content is the base).
- Finding 3: `git status` and `git add` run `post-index-change`, so read-only calls are wrapped too.
- Finding 3 risk: no repo hook runs on the runner's push or on `vibe sync`. A test in `pre-push` moves to `.vibe-jobs/gate` (`docs/vibe-queue.md`).
- Finding 3, review round 3: `agent_push` (`skills/_lib/lib.sh`) wraps the 5 pushes and refuses a tree that declares git-lfs (`filter=lfs` in a `.gitattributes` at HEAD, `git-lfs` installed): the hook that uploads LFS objects is off. `vibe sync` reports `error`, `job_publish` writes the reason into `pr`. Push such a branch by hand.
- Finding 4, review round 3, rejected: `git pull *`, `git clone *`, `git push *` stay in `sandbox.excludedCommands`. None is in `permissions.allow`, so a prompt shows the full command (`--upload-pack`); fetch had an allow rule, so no prompt. They need the user's credentials outside the sandbox. Risk: "yes, don't ask again" on `git pull` adds `Bash(git pull:*)`, and the hole is open again. Your call: drop `git pull *` and `git clone *` from the exclusions, as for fetch (private repos then need the unsandboxed retry).
- Finding 3, review round 4: `vibe sync` rates a linked worktree on the default branch `ahead` and never pushes it (the repo's `pre-push` guard is off). The runner needs no rule: `job_start` fails a job on the default branch; triage heads are job branches.
- Finding 3, review round 4: `publish_handoff` (`/handoff-brief`) uses `agent_git` and `agent_push`; `uses_lfs` also finds a `pre-push` hook that runs git-lfs (covers `.git/info/attributes`, a global attributes file, an uncommitted `.gitattributes`).
- Finding 1, review round 4: `pr_landed` accepts a PR commit equal to HEAD (PR head moved on from another machine); `--limit 100`.
- Review round 4, rejected: `ignored_keep` lists every ignored file. Measured 77 ms for 100k ignored files; `--directory` would collapse `.claude/` and break the `settings.local.json` allowlist.
- Review round 4, rejected: `HANDOFF.md` and `SPEC.md` on the branch. Job rule 13 keeps them until the last milestone; the end action deletes both before the merge (CI fails on a stray `HANDOFF.md`).
- Finding 3, review round 1: `cleanup.sh remove` classified every worktree per path (N×N `gh` calls); `scan_lines` now takes the path.
- Finding 3, review round 2: `cleanup.sh remove` resolves a relative path before the `cd`; the shutdown survey checks a `gone` branch with `cleanup.sh scan` and skips it only when rated `merged` or `ignored`.
- Finding 6: `job_live` (`bin/vibe`) counts any non-final copy (`queued`, `running`, `gpu`) of the same repo and `recurring=` name; `vibe job list` shows `queued`. The test "job due: adds due jobs" now expects one `crashy` copy, not two.
- Finding 7: `queue follow` writes status and note only, no `ended`, while its parent has no `ended` file; the parent's `job_end` writes it. A runner that dies in that window leaves the follow-up waiting (counted as `waiting`, so `--drain` does not stop).
- Finding 7: the test stub `gpurace` runs `queue follow` inside the agent; before the fix both tests fail (parent stays `gpu`, follow-up starts with the parent not ended).
- Review of milestone 4 test: `ls -t | head` (SC2012) replaced by a glob loop; CI shellcheck covers `.bats` files.
- Finding 5: measured `vibe queue report` (18 queue jobs, 300 archived): 20.3 s before, 2.5 s after; 2.3 s with none archived (the rest is the 18 jobs that overlap each other).
- Finding 5: the window is the job's own start, not "last 5 h from now" (spec wording). A now-relative window drops the `≈N% 5h est.` of last night's jobs from the morning briefing.
- Finding 5 risk: strings compare, so one hour of a DST fall-back night can skip an overlapping job; the result is an estimate (`≈`).
- Finding 4: allow rules `git fetch:*` and `git ls-remote:*` stay; fetch now runs sandboxed. Deny rules for `--upload-pack` rejected (mid-command wildcards unverified).
- Finding 4 risk: a sandboxed fetch of a private repo can fail with `Authentication failed`; the trap list in `claude/CLAUDE.md` says to run it unsandboxed.
- Finding 4 risk: the `retired` list deletes the entry on every install, so a user who wants `git fetch *` excluded again must not rely on the settings file.

## Blockers

None.

## Gotchas (unpromoted)

- In the sandbox worktree, 3 `install.bats` tests fail on `.claude/` placeholders (known, `CLAUDE.md`); they pass in a clone under `$TMPDIR`.
- `shfmt -d .` fails on the sandbox's `.claude/` placeholders; name the tracked directories instead.
