# Handoff — agentic-dev-toolkit / ws-hypothesisloop

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-hypothesisloop`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-hypothesisloop
- **Last updated:** 2026-11-15 · turing

## State

Milestone 1 is done: `workspaces/hypothesisloop/` (conf, `start`, `stop`, `status`, `hloop.sh`, `compose.tailnet.yml`) and `tests/ws-hypothesisloop.bats` (6 tests, green). Design reasons: the commit body of `feat(workspaces): hypothesisloop conf, start, stop and status`.

## Next action

The second milestone of `SPEC.md`: the recipe `docs/workspaces/hypothesisloop.md` (accounts, keys, first objective, what it rents) — code — done when `grep -c '^## ' docs/workspaces/hypothesisloop.md` prints 4 or more.

## Blockers

None.

## Gotchas (unpromoted)

- The compose stack rents nothing: only `make dev` (`localdev/dev.sh`) renders the sandbox and cloud_compute sections. Hosted agents need `make dev`. The recipe must say so.
- The UI (port 3000) is `npm run dev` from `localdev/dev.sh ui`, outside compose. `next dev` binds every interface.
- `start` needs `localdev/.image-tag` and `localdev/.host-address`: one `make local-images` and one `make render-settings` by hand. Both default to podman; docker needs `CONTAINER_ENGINE=docker IMAGE_PLATFORM=linux/amd64` (Makefile comment).
- `start` binds to `LOCAL_REACHABLE_ADDRESS` of the checkout's `.env`: it must be `tailscale ip -4`.
- `compose.tailnet.yml` needs docker compose 2.24.4 or later (`!override`); turing has v5.7.1.
