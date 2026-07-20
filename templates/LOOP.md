# Loop — <repo> / <branch>

> A task run unattended: each round an agent works toward the goal below, then
> a stop check decides whether it is done. This document is the brief the agent
> is handed every round, so keep the goal and done-criteria precise — they are
> the only instructions it gets.

- **Repo:** <repo>
- **Branch:** `<branch>`
- **Worktree:** `<worktree>`
- **Started:** <date> · <machine>
- **Stop check:** `<until>`
- **Max rounds:** <max>

## Goal

<goal>

## Done when

_The single, checkable condition that means this task is finished. If a stop
check command is set above, it should succeed exactly when this holds — the
loop trusts that command over anything written here._

## Constraints

_What the agent must not do: files to leave alone, scope limits, commands that
are off-limits. The loop runs with no one watching, so anything not ruled out
here is permitted._

## Iteration log

_One line per round that changed something, newest last._
