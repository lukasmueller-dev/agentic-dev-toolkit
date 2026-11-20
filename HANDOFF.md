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

Milestone 1 is done. `vibe` finds extensions (`ext_list`), routes a described command (`ext_route`) and sends `pass` (`ext_event`). `extensions/research/research` is a stub that owns nothing. `docs/vibe-extensions.md` holds the contract, the site map and the three function lists.

## Next action

Milestone 2 of `SPEC.md`: move `ws` and tool jobs into `extensions/research/research` behind the contract (the ws list and the `prepare`, `start`, `steer`, `holder`, `card`, `follow` rows of `docs/vibe-extensions.md`). Done when `grep -cE 'ws_|WS_|workspace' bin/vibe` prints 0 and `bats tests/vibe-ws.bats tests/ws-*.bats` and the tool tests of `tests/vibe-queue.bats` pass.

## Blockers

None.

## Gotchas (unpromoted)

- Two research jobs are live until 2026-11-22 20:00: the branch must not merge while a research run is live.
- Research tests in `tests/vibe-queue.bats` pick the stub `claude` mode from prompt lines (`CLAUDE.md`, "Before committing").
- A suite run inside a queue job inherits `VIBE_JOB_DIR`: `vibe queue gpu` in a test then writes `gpu-cmd` into the live job dir. `unset VIBE_JOB_DIR` in setup.
- The extension executable must not read stdin at `describe` or `event`: `ext_call` gives it `/dev/null`.
