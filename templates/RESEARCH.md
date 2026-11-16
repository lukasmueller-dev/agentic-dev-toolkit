# Research — <repo> / <branch>

> The work order and lab book of one research job: a question, a budget and
> a backlog of experiments. An unattended agent works it off, one run at a
> time, and may add its own experiments under "Own ideas". The ledger only
> grows. Its end action removes this file before the merge.

- **Repo:** <repo>
- **Branch:** `<branch>`
- **Written:** <date>

## Question

_One or two lines: what the research must answer, and what a human does with the answer._

## Metric

_The number that decides, and the command or files that give it. The reference values. The noise of one measurement, so a difference can be read._

## Budget

_The deadline (date and time), the compute (hours, on what), the most long runs, the most own ideas with a long run._

## Limits

_What no experiment may change or do, one line each: frozen code, protocols, data, comparisons that must stay fair._

## How a run is made

_The snapshot of one commit, the launch command, the smoke check that runs first, the evaluation, where outputs go, the expected run time._

## Known facts

_One line per fact that holds, with the file that shows it. An experiment that only repeats one is wasted._

## Backlog

_One block per experiment, best first: `### <id> <name> — open`. Then one line each: Idea · Evidence · Code · Cost · Pass (the criterion, written before the run) · Then (what a pass and a fail lead to). States: open, running, passed, failed, dropped._

## Own ideas

_What the agent may add with no human: the scope, when, how many. What always needs a human._

## Ledger

| id | commit | run | cost | result | verdict | evidence |
| --- | --- | --- | --- | --- | --- | --- |

## End action

_`rewrite into docs/<topic>.md` (the results and what they mean), or `delete`. Either way the open decisions go to the PR body._
