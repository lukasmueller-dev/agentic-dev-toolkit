# Handoff — agentic-dev-toolkit / research-run

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-run`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/research-run
- **Last updated:** 2026-11-17 · turing

## State

Milestones 1 to 5 of `SPEC.md` are done: place runs, `run-result`, `infra`, `price`, the `usd=` gate, `cost`, `vibe queue worker`, the fan-in, the prompt blocks, the template, route Research, the contract table, the IAS answer, `vibe queue stop --research [--now]`.
Member of the feature `parallel-research` with `research-card` (this repo) and `research-setup` (safety-critic).

## Next action

Milestone 6 of `SPEC.md`: the end action (delete).
Done when `git ls-files SPEC.md HANDOFF.md` prints nothing.
First promote the durable gotchas below to `CLAUDE.md` or `docs/vibe-queue.md`, and move each decision of the feature file to `pr.md`.

## Blockers

None.

## Gotchas (unpromoted)

- An IAS worker that ended `blocked` with `paste.md` is `ias_waits`: it counts at `workers=`, and `fan_in` skips it. `vibe queue answer` on it runs `cmd_queue_follow` (`Exit: ias`).
- `vibe queue stop --research` writes `drain` (`drain` or `now`) to each job dir of the slug; `follow_job` and `follow_dir` copy it. New code that makes a follow-up job from scratch must copy it too (`drain_copy`).
- `place_run` polls `drain` each `VIBE_WS_POLL` (10 s) while the run goes; `places()` in `tests/vibe-queue.bats` sets 0.1 s.
- `timeout(1)` leads its own process group: a TERM to the group of a `ws_place … &` job misses it. `place_run` TERMs the job's child too (`pkill -P`).
- In `tests/vibe-queue.bats` a coordinator in status `gpu` that nothing wakes keeps `--drain` from its end: the test hangs. Use `blocked`, or make the coordinator after the first drain.
- Open risk: every sandboxed agent can write every job dir (the sandbox grants the whole queue dir). The place run writes through `fresh` (rm, then noclobber) and keeps its log in the instance state. `status`, `note`, `ended`, `runner.log`, `gate.log` of every job, and the `cost` files the usd gate sums, are still plain writes or reads there. The fix needs one design: a runner-owned state dir, or a sandbox that grants a job only its own dir.
- A place run's log is `workspaces/research-<id>/log` while it runs; `run/log` is a copy at the end.
- A research is its `repo=` plus `research=`: `fan_in`, `vibe queue worker` and `place_gate` match both. New code that joins jobs of one research must too.
- `vibe queue add` appends `references/research.md` to a job with `research=` and no `hid=`. A test coordinator made by `mkjob` has no block.
- The blocks must not hold the text `## GPU run finished` or `## Worker finished`: the agent stub in `tests/vibe-queue.bats` picks its mode from them.
- The coordinator block merges in rounds: it merges and starts workers only when no worker runs. A worker ends `failed: infra: …`, `failed: usd: …` or `failed: stopped: …` for a run that never ran; the coordinator reopens the item under a new hid.
- An empty `usd=` is no limit at the place gate (`place_gate`); route Research writes `usd=0` for a repo with no `## Research` section.
- A coordinator session that started workers must end `queued:` (status `gpu`). A worker end then ends it `done` and queues the next session. A `done:` result starts the review rounds, and a later worker end wakes no one (`fan_in`).
- A worker end appends a `## Worker finished` block (hid, job, branch, end, run-result) to the coordinator's prompt.
- A rerun of an item takes a new hid: `vibe queue worker` refuses a branch that exists.
- A `blocked` worker is final: it does not count against `workers=`, and its end wakes the coordinator. An IAS worker that waits for its answer is the one exception.
- `vibe queue status` counts a `done` worker as `no PR` (`queue_counts`). The card branch owns that display.
- `mkjob` in `tests/vibe-queue.bats` loops with a global `l`: a test variable `l` gets overwritten. Use another name.
- `coord_wt` and `coord` in `tests/vibe-queue.bats` make a coordinator worktree with `RESEARCH.md` and its job; the stub mode `workers` calls `vibe queue worker h1` and `h2 --place runpod`.
- A place run: `vibe queue gpu --place` writes `<job>/run/` (place, commit, cmd); the runner's `place_pass` starts `place_run` in the background, in instance `research-<job id>`. `stop --now` writes `now`, and `place_run` cuts its own run.
- The usd gate (`place_gate`) reads `usd=` and `research=` from the run's own job file; `vibe queue worker` copies both from the coordinator.
- The stub places in `tests/vibe-queue.bats` print `$STUBS/price`; with no file `price` exits 3, so the price is 0 and the gate never refuses.
- `research-card` reads the job keys and the job dir files of the contract; a change to one needs the user. `drain` and `ias.log` are no contract rows: the card cannot show a stopped research yet.
- `$TMPDIR` (`/tmp/claude-1000`) is shared with other sessions: put a test clone in `mktemp -d`, never a fixed name.
