# Spec — <repo> / <branch>

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** <repo>
- **Branch:** `<branch>`
- **Written:** <date>

## Goal

_One or two lines: what is true when the work is done._

## Non-goals

_What this work does not touch, one line each._

## Decisions

_One line per decision from the grilling: the choice and the reason._

## Milestones

_One checkbox per milestone, in order: `- [ ] <what> — <code|gpu> — done when <a check a command can make>`. A gpu milestone names its command, its expected run time and the metric that counts as success. The last milestone is the end action._

## End action

_`delete`, or `rewrite into docs/<topic>.md` (what the code now is, not what was planned). Either way, each decision moves to the PR body._
