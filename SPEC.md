# Spec — agentic-dev-toolkit / ws-autoresearchclaw

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-autoresearchclaw`
- **Written:** 2026-11-15

## Goal

`workspaces/autoresearchclaw/` runs one AutoResearchClaw pipeline as a queue job, from a topic to a paper folder.
Feature: ~/.local/state/vibe/features/workspaces.md

## Non-goals

- See the feature file.
- New files only: `workspaces/autoresearchclaw/`, `tests/ws-autoresearchclaw.bats`, `docs/workspaces/autoresearchclaw.md`.

## Decisions

- See the feature file.
- Source: `~/.local/state/vibe/tools/autoresearchclaw` at `be4ba4755bf1b52220f25e13b2293b5956590070`. Conf: `kind=run`, `gpu=yes`, `result=folder`.
- `run`: `researchclaw run -c <config> -t "<topic from brief.md>" -o /ws/data/artifacts/$WS_INSTANCE --auto-approve --skip-noncritical-stage`, under `timeout` from `WS_HOURS`.
- The config sets `experiment.mode: sandbox`. Never `simulated`: it writes fake data. Never `docker`: the container is the sandbox.
- The config sets `llm.provider: acp` with the Claude agent; the recipe says how to check that the login token works there.
- Exit 0 does not prove a paper: `run` reads `pipeline_summary.json`; `deliverables/` goes to `/ws/out/files/`.
- `steer`: `researchclaw guide <run dir> --stage <next stage from checkpoint.json> --message "<text>"`. `stop`: TERM to the process; a later run uses `--resume`.
- The tool's cost limits are dead code: the hour limit is the only stop.
- The recipe says what it is not for: its RL prompt allows only small classic-control tasks.

## Milestones

- [x] Conf, config file, Dockerfile and the three scripts against a stub `researchclaw` — code — done when `bats tests/ws-autoresearchclaw.bats` passes: a `pipeline_summary.json` with a failed stage gives `failed:` at exit 0; `steer` names the next stage; `grep -c 'mode: sandbox' workspaces/autoresearchclaw/*.yaml` prints 1.
- [ ] The recipe `docs/workspaces/autoresearchclaw.md`: requirements, numbered steps, verify, what breaks it — code — done when `grep -c '^## ' docs/workspaces/autoresearchclaw.md` prints 4 or more.
- [ ] End action — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

## End action

`delete`. Each decision moves to the PR body.
