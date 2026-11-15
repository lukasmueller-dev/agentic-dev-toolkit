# Handoff — agentic-dev-toolkit / ws-autoresearchclaw

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-autoresearchclaw`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-autoresearchclaw
- **Last updated:** 2026-11-15 · turing

## State

Milestone 1 is done: `workspaces/autoresearchclaw/` (conf, `config.yaml`, Dockerfile, `run`, `steer`, `stop`) and `tests/ws-autoresearchclaw.bats` (28 tests pass). The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The first open milestone of `SPEC.md`: the recipe `docs/workspaces/autoresearchclaw.md` — requirements, numbered steps, verify, what breaks it — done when `grep -c '^## ' docs/workspaces/autoresearchclaw.md` prints 4 or more.
Put these in it:
- Token check: `claude setup-token` gives `CLAUDE_CODE_OAUTH_TOKEN`; test it in the container with `acpx claude exec "say ok"`.
- Limits: `steer` works at stages 8 and 9 only; cost limits are dead code, the hour limit is the only stop; no LaTeX in the image, so no PDF.
- Not for: its RL prompt allows only small classic-control tasks.
- Resume: the tool counts only the stages of its own call, so the numbers after a resume cover the last part (the result line says so). A finished run (checkpoint 23) is not started again.
- Token risk: the agent (`--approve-all`) and the experiment code run as root in one container and can read `CLAUDE_CODE_OAUTH_TOKEN` and `/ws/secrets.env`. Say so, and advise a token you can revoke.

## Blockers

None.

## Gotchas (unpromoted)

None.
