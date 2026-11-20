# Handoff — agentic-dev-toolkit / extension-seam

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `extension-seam`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/extension-seam
- **Last updated:** 2026-11-20 · turing

## State

Milestones 1 to 3 are done. `extensions/research/research` owns `vibe ws`, tool jobs, place runs and the research lifecycle (the engine list, `queue worker`, `stop --research`, `archive --research`). `vibe` sends every event of `docs/vibe-extensions.md` but `status` and `report`. Left in `bin/vibe`: the card list, `branch_ok`, `pr_check`, the `research=` readers that `card=` replaces, and the `drain=now` text of `cmd_queue_gpu`.

## Next action

Milestone 4 of `SPEC.md`: move the research card, status, report and web routes behind the contract (the card list and the site map rows left in `docs/vibe-extensions.md`). Wire `card=`, `status`, `report`, `branch`, `route` and `wip`. Done when `grep -ciE 'research|workspace' bin/vibe bin/vibe-web templates/queue-page.html templates/queue-page.js` prints 0 for each file and `bats tests/vibe-queue.bats tests/vibe-web.bats` pass.

## Blockers

None.

## Gotchas (unpromoted)

- Two research jobs are live until 2026-11-22 20:00: the branch must not merge while a research run is live.
- `card=` is not written yet: the extension must write `card=research` at `add` (coordinator) and in `cmd_worker`; archived research jobs have no `card=`, so `report_rows` and `triage_archive` must still find them.
- `research_row` holds the `archived_costs` awk inline and its own `RESEARCH_WORKERS=3`; both go with the card list.
- `research_cost` and `research_line` read the live box through `vibe ws box <job>` (`run_box`). The card milestone removes it.
- A place run is a fork of the extension's `pass` event: `run_alive` matches `*/research event pass`. `$WS_STATES/run.<job id>` holds a copy of the run pid until `run/exit` exists.
- Research tests in `tests/vibe-queue.bats` pick the stub `claude` mode from prompt lines (`CLAUDE.md`, "Before committing").
- A suite run inside a queue job inherits `VIBE_JOB_DIR`: `vibe queue gpu` in a test then writes `gpu-cmd` into the live job dir. `unset VIBE_JOB_DIR` in setup.
- The extension executable must not read stdin at `describe` or `event`: `ext_call` gives it `/dev/null`.
- `tests/vibe-queue.bats` runs about 3 times slower in this worktree than in a `git clone` under `$TMPDIR` (7 min there): run the full file in a clone.
- `vibe-web.bats` fails `routes skip and skip-undo` and `route server-remove` on the base commit too: not this branch.
