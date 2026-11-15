# Spec — agentic-dev-toolkit / ws-autoresearch

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-autoresearch`
- **Written:** 2026-11-15

## Goal

`workspaces/autoresearch/` runs one EvoMap AutoResearch project as a queue job with a folder as result.
Feature: ~/.local/state/vibe/features/workspaces.md

## Non-goals

- See the feature file.
- New files only: `workspaces/autoresearch/`, `tests/ws-autoresearch.bats`, `docs/workspaces/autoresearch.md`.
- No idea generation step: the brief is the idea file.

## Decisions

- See the feature file.
- Source: `~/.local/state/vibe/tools/autoresearch` at `21f591298aca78690722686c38984ac2b7d6f7e6`. Conf: `kind=run`, `gpu=yes`, `result=folder`; `secrets` holds the Claude token and the provider keys the critic needs.
- `run`: from `ar-runtime/`, `scripts/ar-supervisor.sh <idea> <project_root> <max_restarts> <attempt_timeout>`, with `/ws/in/brief.md` as the idea and `/ws/data/project` as the project root.
- Result: `results/`, `review.md`, `critic.md`, `blind_review.md`, `state.md` and `decisions.log` go to `/ws/out/files/`.
- `steer`: look in the source for a file the coordinator reads again at each unit; with none, `steer` exits 3.
- `run_pending_forge.py` is never called: it can push to `gh-pages`.
- The recipe names the cost: the critic uses models of other providers, paid per token.

## Milestones

- [x] Conf, Dockerfile and the three scripts against a stub supervisor — code — done when `bats tests/ws-autoresearch.bats` passes: `run` hands over the idea and the project root, copies the six result paths, and writes `failed:` when the supervisor exits non-zero; `grep -rc run_pending_forge workspaces/autoresearch` prints only zeros.
- [x] The recipe `docs/workspaces/autoresearch.md`: requirements, numbered steps, verify, what breaks it — code — done when `grep -c '^## ' docs/workspaces/autoresearch.md` prints 4 or more.
- [ ] End action — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

## End action

`delete`. Each decision moves to the PR body.
