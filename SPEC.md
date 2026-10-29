# Spec — agentic-dev-toolkit / job-review

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `job-review`
- **Written:** 2026-10-29

## Goal

Every queue job that ends `done` with commits gets up to 2 adversarial review rounds before its draft PR opens; the PR body shows each round.
A job past its timeout commits a handoff, and the retry after a usage limit resumes its session.

## Non-goals

- PR comment and CI triggers — roadmap item "PR event follow-ups"; its design is the last line of Decisions.
- `/code-review ultra` — in `-p` it exits without findings and can bill credits.
- A whole-repo review — roadmap item `repo-review`.
- Codex and Gemini runners — `claude/` only.

## Decisions

- Trigger: `done` with commits ahead of the base, incl. SPEC milestones and a GPU follow-up's `done`. No review for `queued:`, `blocked`, `failed`, `timeout`, report-only jobs, or no commits.
- Default on: `after=review` in `queue.conf`; the `job` file overrides it (`after=` empty = none). Catalogue `sota-digest` sets `after=` empty: a digest doc has no correctness to review.
- The review runs before the push: a parent job with a review due does not publish; the last review follow-up does. One PR body, nothing sent to GitHub twice.
- Mechanism: generalize `cmd_queue_follow` (the GPU follow-up). `<id>-review<n>` dirs sort right after their parent, use its worktree, the same slots and briefing rows. No new dispatcher.
- Reviewer: a fresh session, `claude/vibe-review.sh` (Claude-specific, so beside `vibe-job.sh`): `/code-review <review_level> <base>...HEAD`, `--disallowedTools Edit,Write,NotebookEdit`, `--output-format json --json-schema` with findings `file`, `line`, `summary`, `failure_scenario`. The runner reads `structured_output.findings`.
- Review model: `review_model=sonnet`, `review_level=high` in `queue.conf`; a job file may set `review_model=opus`. The fresh context and the review recipe carry the adversarial value, not a stronger model; Opus would double the usage per job.
- Fixer: the job's own session, resumed with `--resume <session_id>`: it knows why it made each change. It marks each finding `fixed <sha>`, `rejected <reason>` or `open`.
- Rounds: R1 always. R2 only when R1 found something and the fix is not trivial: more than `review_trivial=20` changed lines, or a file outside `*.md`. Max `review_rounds=2`; what stays open goes to the PR body, not to a round 3.
- PR body: one line per round above `<details>` (`R1: 4 findings → 3 fixed, 1 rejected · R2: 0 findings`); findings and verdicts inside `<details>`. The PR is the main interface: it carries everything the check-in needs.
- Failures: no `structured_output` → `R<n>: review failed`; a round past `review_timeout=1h` → `R<n>: timeout`. The PR opens either way.
- Timeout (exit 124) and usage limit reuse the resume helper: a timeout gets one resume turn (`--max-turns 5`) that commits `HANDOFF.md` and writes `result`; a limit retry resumes instead of a new session. SIGTERM from `timeout` ends the turn with no result, so rule 12 of the job prompt cannot run today.
- One queue entry: the runner chains the milestones (`job_chain`), a fresh session each.
- Cut from v1, for the roadmap item "PR event follow-ups": only your `gh api user` login triggers (others → briefing line); trigger = a "Request changes" review or a comment that starts with `/fix`; your comments since the last batch go to one fix job; a fresh session gets the PR body, the diff and the batch; the runner posts one summary comment (`fixed in <sha>` / `rejected: <reason>`) and a `C<n>:` line in the PR body; the fix job gets the same review rounds; a `handled` timestamp per PR under `~/.local/state/vibe/prs/` stops a repeat; `vibe job triage` moves into the runner loop every `poll=15m`.

## Milestones

- [x] Resume helper: the runner keeps each job's `session_id` (from the `system/init` event) in `queue/<id>/session`; `vibe-job.sh` takes an optional session to resume — code — done when a test in `tests/vibe-queue.bats` shows the stub `claude` got `--resume <that id>`
- [ ] Timeout handoff: on exit 124 the runner resumes the session for one turn (`--max-turns 5`) that commits `HANDOFF.md` and writes `result` — code — done when a test with a stub past its timeout ends `timeout` with `HANDOFF.md` committed on the branch
- [ ] Limit resume: the retry after a usage limit resumes the session — code — done when a test shows the retry of a limited job got `--resume`
- [ ] Review loop: `claude/vibe-review.sh`, follow-ups `<id>-review<n>`, verdicts, the PR-body round lines; keys `after`, `review_rounds`, `review_trivial`, `review_model`, `review_level`, `review_timeout`; catalogue key `after` and `sota-digest` with `after=` empty — code — done when tests show: 2 stub findings → a fix resume, an R2, a PR body with `R1`/`R2` lines; no `structured_output` → the PR opens with `R1: review failed`; `after=` empty → no review
- [ ] Docs and end action: rules and layout rows in `docs/vibe-queue.md`, the catalogue key in `docs/vibe-jobs.md`, one decision line in `PROJECT_STATUS.md`; delete this spec — code — done when `shfmt -d -i 2 -ci .`, `shfmt -f . | xargs shellcheck` and `bats tests/` pass

## End action

`delete`. Each decision moves to the PR body.
