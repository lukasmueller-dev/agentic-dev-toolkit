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

Milestones 1 to 4 of `SPEC.md` are done: place runs, `run-result`, `infra`, `price`, the `usd=` gate, `cost`, `vibe queue worker`, the fan-in, the coordinator and worker prompt blocks, the template, route Research, the contract table.
Member of the feature `parallel-research` with `research-card` (this repo) and `research-setup` (safety-critic).

## Next action

Milestone 5 of `SPEC.md`: IAS and stop.
Done when `bats tests/vibe-queue.bats` passes with an answer test, a drain test, a now test and a past-deadline close test.

## Blockers

None.

## Gotchas (unpromoted)

- `references/research-worker.md` has no IAS step yet. Milestone 5 adds it: a `place=ias` worker writes `runs/<hid>/job.sbatch` and `paste.md`, then ends `blocked:`.
- `vibe queue stop --research` is not in the contract table of `docs/vibe-queue.md` § Research jobs yet. Add its row with the command.
- `vibe queue add` appends `references/research.md` to a job with `research=` and no `hid=`. A test coordinator made by `mkjob` has no block.
- The blocks must not hold the text `## GPU run finished` or `## Worker finished`: the agent stub in `tests/vibe-queue.bats` picks its mode from them.
- The coordinator block merges in rounds: it merges and starts workers only when no worker runs. A worker ends `failed: infra: …` or `failed: usd: …` for a run that never ran; the coordinator reopens the item under a new hid.
- An empty `usd=` is no limit at the place gate (`place_gate`); route Research writes `usd=0` for a repo with no `## Research` section.
- A coordinator session that started workers must end `queued:` (status `gpu`). A worker end then ends it `done` and queues the next session. A `done:` result starts the review rounds, and a later worker end wakes no one (`fan_in`).
- A worker end appends a `## Worker finished` block (hid, job, branch, end, run-result) to the coordinator's prompt.
- A rerun of an item takes a new hid: `vibe queue worker` refuses a branch that exists.
- A `blocked` worker is final: it does not count against `workers=`, and its end wakes the coordinator. IAS may need it live.
- `vibe queue status` counts a `done` worker as `no PR` (`queue_counts`). The card branch owns that display.
- `mkjob` in `tests/vibe-queue.bats` loops with a global `l`: a test variable `l` gets overwritten. Use another name.
- `coord_wt` and `coord` in `tests/vibe-queue.bats` make a coordinator worktree with `RESEARCH.md` and its job; the stub mode `workers` calls `vibe queue worker h1` and `h2 --place runpod`.
- A place run: `vibe queue gpu --place` writes `<job>/run/` (place, commit, cmd); the runner's `place_pass` starts `place_run` in the background, in instance `research-<job id>`. `stop --now` acts on that instance.
- The usd gate (`place_gate`) reads `usd=` and `research=` from the run's own job file; `vibe queue worker` copies both from the coordinator.
- The stub places in `tests/vibe-queue.bats` print `$STUBS/price`; with no file `price` exits 3, so the price is 0 and the gate never refuses.
- `research-card` reads the job keys and the job dir files of the contract; a change to one needs the user.
- `$TMPDIR` (`/tmp/claude-1000`) is shared with other sessions: put a test clone in `mktemp -d`, never a fixed name.
