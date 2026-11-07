# Spec — agentic-dev-toolkit / queue-verify-skills

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `queue-verify-skills`
- **Written:** 2026-11-07

## Goal

Queue jobs run more skills with no human step, and the page and `vibe queue status` show each phase by name.

## Non-goals

- `poteto-mode`, its playbooks, the principle skills, the pstack agents.
- ponytail hooks, ports and `ponytail-map.js`; a native plugin install.
- `interrogate`, `arena`, `swarm`: subagent worktrees are untested in the job sandbox.
- A fix round after verify.
- A `verify=` default in `queue.conf`; new `review_*` keys.
- `verify=` on a lane job or a job without a review: `vibe queue add` refuses it.
- A `verify-<app>` skill in any repo: a human runs `/create-verification-skill`.
- Deletion of `repo-review`, or a change to `codebase-health`: a roadmap item decides that.

## Decisions

- Vendor with `plug`, pinned by SHA: reviewed diffs; marketplaces are rejected in `docs/vendoring-external-skills.md`.
- Source `cursor-plugins` (`https://github.com/cursor/plugins`, `main`).
- Vendor from `harness/pstack/claude-code/skills/`: `create-verification-skill`, `maintain-verification-skill`, `blast-radius`, `unslop`, `correct`.
- Vendor from `thermos/skills/`: `thermo-nuclear-code-quality-review`.
- Local adapter `docs/pstack-adapter.md`: the upstream link points to `vendor/docs/`, which does not exist. A `plug update` review compares it with upstream.
- `ponytail-review` and `ponytail-audit` become local `skills/lean-review/` and `skills/lean-audit/`, with `disable-model-invocation: true` and the MIT notice (`Copyright (c) 2026 DietrichGebert`): a vendored copy loads in every session and triggers on "code review".
- Job prompt: apply `unslop` to `pr.md` and docs; `unslop` rule 16 is exempt, because the PR TL;DR uses label lines.
- `memory/GLOBAL.md`: the ponytail ladder, the "never cut" list and the `shortcut: <limit>, <when to upgrade>` comment replace "Prefer the cut", in own words, with no agent name.
- Each review round runs `/code-review` and the `lean-review` rubric. Findings go into the same fix loop, so a later round checks the fixes. `/code-review` stays.
- `verify=app`, `verify=blast-radius` or both: opt-in per job, set by `/enqueue` and `/fill-queue`.
- Verify runs as `<id>-verify` after the last review round and before the gate, with `review_model` and `review_timeout`.
- Verify reports only: `V:` joins the `**Review:**` line, commands and outputs go inside `<details>`, evidence stays in the job dir.
- `V: fail` puts the job under "Needs you", like a non-zero gate. A repo without the skill gets `V: no verify skill`.
- Verify changes no tracked file: HEAD moved or a dirty tree gives `V: dirty`, and the runner touches nothing.
- One function, `job_phases`, feeds the page and `vibe queue status`: `✓ Agent · ✓ R1 2 fixed · ▶ R2 · ○ Verify app · ○ Gate · ○ PR`.
- `R2` shows once queued; `Verify` only with the key; a report job shows `Agent · Report`; `✗` in red marks a failed phase; the open card names the passes.
- A lane card gets one phase line. Feature members keep their own cards.
- New catalogue jobs, opt-in per repo: `shortcut-debt` (weekly, report, one `git grep`), `verify-maintain` (monthly, PR), `correct` (monthly, PR, past review findings as evidence), `thermo-quality` (weekly, report, merged diff), `lean-audit` (monthly, report).
- Trap: a server from one Bash call is unreachable from the next. The verify prompt says: start and drive in one call.
- Trap: `claude/*.sh` runs through a symlink. Find the rubric with `script_dir()`, not `$here`.
- Trap: the job cannot write the `plug` cache. Set `PLUG_CACHE_DIR` under `$TMPDIR`.
- Trap: `create-verification-skill` writes to `.claude/skills/`, which the sandbox denies. Name this in the adapter.

## Milestones

- [x] Vendor the 6 skills, run `/security-review` over the new tree (a finding stops the job as blocked), add `docs/pstack-adapter.md`, add a pointer line to it in `claude/CLAUDE.md` — code — done when `./bin/plug verify && bats tests/plug.bats tests/plugin.bats` passes
- [ ] Add `skills/lean-review/` and `skills/lean-audit/`, and run the rubric in `claude/vibe-review.sh` — code — done when `./bin/skill-lint --strict skills && bats tests/vibe-queue.bats` passes with a test that the review prompt names both passes
- [ ] Add the `unslop` rule to `skills/fill-queue/references/job-prompt.md`, and replace "Prefer the cut" in `memory/GLOBAL.md` — code — done when `grep -q unslop skills/fill-queue/references/job-prompt.md && ! grep -q '^# Prefer the cut' memory/GLOBAL.md` passes and `bats tests/install.bats` passes in a clone under `$TMPDIR`
- [ ] Add the `verify=` key, `claude/vibe-verify.sh`, the `<id>-verify` step, and the field in `/enqueue` and `/fill-queue` — code — done when `bats tests/vibe-queue.bats` passes with tests for: key set, no key, no skill, `V: fail`, `V: dirty`, refused lane job
- [ ] Add `job_phases`, the page line with its CSS, and the status line — code — done when `bats tests/vibe-queue.bats tests/vibe-web.bats` passes with a test per phase state, in the page HTML and in the status output
- [ ] Add the 5 catalogue jobs and the `docs/vibe-jobs.md` rows, and add a roadmap item: compare `repo-review` with `lean-audit` on one repo, delete the loser, decide the `codebase-health` dedup and complexity scan — code — done when `bats tests/vibe-jobs.bats` passes and `grep -q lean-audit PROJECT_ROADMAP.md` passes
- [ ] Update `docs/vibe-queue.md` and `docs/vendoring-external-skills.md`, add one line to `PROJECT_STATUS.md`, do the end action — code — done when `shfmt -f . | xargs shellcheck && shfmt -d -i 2 -ci . && bats tests/ && ./bin/skill-lint --strict skills && ./bin/plug verify` passes

## End action

`delete`. Each decision moves to the PR body.
