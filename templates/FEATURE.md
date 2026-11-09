# Feature — <feature>

> The work order for one feature that spans several repos. Each member is one
> branch, so one PR; the PRs merge together, after the human test. Jobs read
> this file and never change it. Each member's `SPEC.md` holds only its own
> milestones and points here. At the end, the decisions and the contract go
> into the PR bodies, and the file is archived.

**Context:** <context>
**Human test:** _the test you run on all members together before the merge_

## Members

_One line per member: `- <absolute repo path> <branch>`; the PR URL follows once it exists._

## Goal

_One or two lines: what is true when the feature is done._

## Non-goals

_What this feature does not touch, one line each._

## Decisions

_One line per decision: the choice and the reason._

## Contract

_One row per interface that crosses repos. A change to a row needs the user._

| Interface | Owner | Copies |
| --- | --- | --- |
