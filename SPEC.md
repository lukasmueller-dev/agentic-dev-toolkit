# Spec — agentic-dev-toolkit / ws-deepscientist

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-deepscientist`
- **Written:** 2026-11-15

## Goal

`workspaces/deepscientist/` starts the DeepScientist daemon in a container with a login, and gives the queue page a link to its UI.
Feature: ~/.local/state/vibe/features/workspaces.md

## Non-goals

- See the feature file.
- New files only: `workspaces/deepscientist/`, `tests/ws-deepscientist.bats`, `docs/workspaces/deepscientist.md`.
- No chat connector is turned on.

## Decisions

- See the feature file.
- Source: `~/.local/state/vibe/tools/deepscientist` at `b36624417f0c6b8238ec02db37b94d6db2faa5b0` (version 1.6.0). Conf: `kind=service`, `gpu=yes`, `ports=20999,21000`, `secrets=CLAUDE_CODE_OAUTH_TOKEN`.
- `start`: `ds --daemon-only --no-browser --host 0.0.0.0 --port 20999 --auth true --runner claude --skip-update-check --home /ws/data`. The place publishes the ports on the tailnet address only.
- `--auth true` is fixed: without it the API takes shell input from anyone who reaches the port.
- `stop`: `ds --stop`. `status`: `GET /api/health`.
- The login token of a launch goes to `/ws/data/.ws-token`; `status` prints the link with it; the page list shows the link without it.
- The Dockerfile does the first-launch download (uv, the Python env) at build time, so a start needs no install.
- The recipe's first check: the Claude runner works from `CLAUDE_CODE_OAUTH_TOKEN` alone, with no `~/.claude` login file.

## Milestones

- [ ] Conf, Dockerfile and the three scripts against a stub `ds` and a stub health endpoint — code — done when `bats tests/ws-deepscientist.bats` passes: the `start` argv holds `--auth true` and `--host 0.0.0.0`; `status` prints `up` on a healthy answer and `down` on none; the token is in `status` output and in no file under `/ws/out`.
- [ ] The recipe `docs/workspaces/deepscientist.md`: requirements, numbered steps, verify, what breaks it — code — done when `grep -c '^## ' docs/workspaces/deepscientist.md` prints 4 or more.
- [ ] End action — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

## End action

`delete`. Each decision moves to the PR body.
