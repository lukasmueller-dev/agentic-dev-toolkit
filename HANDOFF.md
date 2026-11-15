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

Milestone 1 is done: `workspaces/hypothesisloop/` (conf, `start`, `stop`, `status`, `hloop.sh`, `compose.tailnet.yml`) and `tests/ws-hypothesisloop.bats` (10 tests, green). Design reasons: the commit bodies of `feat(workspaces): hypothesisloop conf, start, stop and status` and of the review fix after it.

## Next action

The second milestone of `SPEC.md`: the recipe `docs/workspaces/hypothesisloop.md` (accounts, keys, first objective, what it rents) — code — done when `grep -c '^## ' docs/workspaces/hypothesisloop.md` prints 4 or more.

## Blockers

None.

## Gotchas (unpromoted)

- The compose stack rents nothing: only `make dev` (`localdev/dev.sh`) renders the sandbox and cloud_compute sections. Hosted agents need `make dev`. The recipe must say so.
- The UI (port 3000) is `npm run dev` from `localdev/dev.sh ui`, outside compose. `next dev` binds every interface. The recipe holds the UI step (review finding 7, open); `status` names a missing UI.
- `start` needs two images on this host, `$(cat localdev/.host-address):5000/hypothesisloop-{control-service,metrics-service}:$(cat localdev/.image-tag)`. Its refusals point to the recipe for the build.
- turing has docker and no podman. `make local-images` hard-codes `podman compose` for `registry-up` and pushes to the LAN registry over HTTP, which docker refuses. The recipe needs a docker-only build that writes `.image-tag`; nobody has run one yet.
- `start` does not start the `registry` service: the images are local, and only remote clusters pull from it.
- `start` binds to `LOCAL_REACHABLE_ADDRESS` of the checkout's `.env` and refuses anything but an IPv4: it must be `tailscale ip -4`.
- `compose.tailnet.yml` needs docker compose 2.24.4 or later (`!override`); turing has v5.7.1.
