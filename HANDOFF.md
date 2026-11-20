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

Milestones 1 and 2 are done. `extensions/research/research` owns `vibe ws`, tool jobs and the place run (`queue gpu --place`, `place_pass`, `place_run`, `place_gate`). `vibe` sends `pass`, `prepare`, `start`, `steer`, `holder` and `card`, and reads `readonly` and `help`. `docs/vibe-extensions.md` marks the rest as planned.

## Next action

Milestone 3 of `SPEC.md`: move the research lifecycle (the engine list of `docs/vibe-extensions.md`) into the extension. Wire the planned events `add`, `end`, `answer` and `follow`, and the `card=` and `publish=push` keys. Done when `bin/vibe` defines no function of the engine list and `bats tests/vibe-queue.bats` passes.

## Blockers

None.

## Gotchas (unpromoted)

- Two research jobs are live until 2026-11-22 20:00: the branch must not merge while a research run is live.
- The `follow` rows (answer copies `out/`, `tool-exit`, `tool.log`, `close.md`; fix and `follow_job` drop `tool=`) still sit in `bin/vibe`: milestone 2 needed no `follow` event.
- `research_cost` and `research_line` read the live box through `vibe ws box <job>` (`run_box`). The card milestone removes it.
- A place run is a fork of the extension's `pass` event: `run_alive` matches `*/research event pass`. `$WS_STATES/run.<job id>` holds a copy of the run pid until `run/exit` exists.
- Research tests in `tests/vibe-queue.bats` pick the stub `claude` mode from prompt lines (`CLAUDE.md`, "Before committing").
- A suite run inside a queue job inherits `VIBE_JOB_DIR`: `vibe queue gpu` in a test then writes `gpu-cmd` into the live job dir. `unset VIBE_JOB_DIR` in setup.
- The extension executable must not read stdin at `describe` or `event`: `ext_call` gives it `/dev/null`.
