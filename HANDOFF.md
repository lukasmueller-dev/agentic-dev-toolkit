# Handoff — agentic-dev-toolkit / ws-autoresearch

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-autoresearch`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-autoresearch
- **Last updated:** 2026-11-15 · turing

## State

Milestone 1 is done: `workspaces/autoresearch/` (conf, Dockerfile, `run`, `stop`, `steer`) and `tests/ws-autoresearch.bats` pass against a stub supervisor. `steer` exits 3. The image is not built. The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The next open milestone of `SPEC.md`: the recipe `docs/workspaces/autoresearch.md` — code — done when `grep -c '^## ' docs/workspaces/autoresearch.md` prints 4 or more. Name in it:

- The secrets file keys, and that any other `KEY=VALUE` line in it reaches the tool.
- The cost of the critic (other providers, paid per token).
- `steer` exits 3, and why.
- The image is unbuilt. It takes the apt packages and the ralph-loop plugin unpinned. The Python packages are fixed by `PIP_CUTOFF`.
- `run` calls `scripts/render_env.py` after it exports the secrets. The tool's MCP preflight fails without that file.
- With the default config the `agent` role is `deepseek-v4-pro`. For a Claude token, set `AR_MODEL_AGENT=claude-opus` in the secrets file (unchecked).
- `stop` exits 1 when `run` has not written the result within 120 s.

## Blockers

None.

## Gotchas (unpromoted)

None.
