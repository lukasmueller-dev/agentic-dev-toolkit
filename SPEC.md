# Spec — agentic-dev-toolkit / ws-hypothesisloop

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-hypothesisloop`
- **Written:** 2026-11-15

## Goal

`workspaces/hypothesisloop/` starts and stops the HypothesisLoop server stack on turing from the user's own checkout, and links its UI.
Feature: ~/.local/state/vibe/features/workspaces.md

## Non-goals

- See the feature file.
- New files only: `workspaces/hypothesisloop/`, `tests/ws-hypothesisloop.bats`, `docs/workspaces/hypothesisloop.md`.
- No install of its bare-metal GPU agent: that writes a root systemd unit.
- No run as a queue job: its `hl` CLI can do that later.

## Decisions

- See the feature file.
- Source: `~/.local/state/vibe/tools/hypothesisloop` at `70135ef89035c15a7969c957740690524d6dc7f2`. Conf: `kind=service`, `runs=host`, `places=turing`, `gpu=no`.
- The stack is its own compose file (`localdev/controlplane/docker-compose.yml`: two services, Postgres, Memgraph, GreptimeDB, an S3 store, registries). `start` and `stop` drive that file in the checkout named by `HLOOP_REPO` in the user's env file.
- `start` refuses when `CLOUD_COMPUTE_PROVIDERS` is not set by the user: the tool's default lists `vast runpod`, and a listed entry is the consent to rent.
- `start` refuses when a required key is missing: the sandbox provider with its key, `MODEL_ANTHROPIC_OAUTH_TOKEN`, `GIT_HOST_PROVIDER`.
- Read the UI port and the health check from the source. What the source does not say becomes a step for the human in the recipe; never a guess.
- The services bind to the tailnet address, not to all interfaces.

## Milestones

- [x] Conf and the three scripts against a stub `docker` — code — done when `bats tests/ws-hypothesisloop.bats` passes: `start` refuses an unset `CLOUD_COMPUTE_PROVIDERS` and each missing key by name; `start` and `stop` call compose on the file under `HLOOP_REPO`; `status` prints `up` or `down`.
- [ ] The recipe `docs/workspaces/hypothesisloop.md`: the accounts it needs, the keys, the first objective, what it rents — code — done when `grep -c '^## ' docs/workspaces/hypothesisloop.md` prints 4 or more.
- [ ] End action — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

## End action

`delete`. Each decision moves to the PR body.
