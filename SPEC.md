# Spec — agentic-dev-toolkit / ws-kapso

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-kapso`
- **Written:** 2026-11-15

## Goal

`workspaces/kapso/` runs one Kapso campaign as a queue job: `run`, `stop`, `steer`, and a branch as result.
Feature: ~/.local/state/vibe/features/workspaces.md

## Non-goals

- See the feature file.
- New files only: `workspaces/kapso/`, `tests/ws-kapso.bats`, `docs/workspaces/kapso.md`.

## Decisions

- See the feature file.
- Source: `~/.local/state/vibe/tools/kapso` at `8b897c7330fdf02bc9080e492a768b70b18fbf0d`. Conf: `kind=run`, `gpu=yes`, `result=branch`, `secrets=CLAUDE_CODE_OAUTH_TOKEN`.
- `run`: `kapso build --brief /ws/in/brief.md --repo /ws/in/repo --evaluation <dir from args> --output /ws/data/campaign --budget-experiments <n> --budget-minutes <from WS_HOURS> --config <override>`.
- The override file sets `inbox.enabled: false` and `inference.default.cli: claude_code`: no pause for a human, no Codex.
- Exit 0 also means "waits on you": `run` reads `/ws/data/campaign/.kapso/solution.json` (`branch`, `commit`, `score`, `goal_achieved`, `stopped_reason`), bundles that branch into `/ws/out/repo.bundle`, and writes the report with `kapso report`.
- `stop`: `kapso build --output /ws/data/campaign --stop`. `steer`: `kapso inbox note <campaign> "<text>"`; the next agent session reads it.

## Milestones

- [x] Conf, Dockerfile and the three scripts against a stub `kapso` — code — done when `bats tests/ws-kapso.bats` passes: `run` writes `result`, `report.md`, `repo.bundle`, `branch` and `score`; a `solution.json` without `goal_achieved` gives `failed:`; `stop` and `steer` call the commands above.
- [x] The recipe `docs/workspaces/kapso.md`, with the small test repo for the human test — code — done when `grep -c '^## ' docs/workspaces/kapso.md` prints 4 or more.
- [ ] End action — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

## End action

`delete`. Each decision moves to the PR body.
