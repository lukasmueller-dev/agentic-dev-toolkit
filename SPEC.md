# Spec — agentic-dev-toolkit / ws-place-vast

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-place-vast`
- **Written:** 2026-11-15

## Goal

`workspaces/_places/vast` gives a tool its own Vast.ai machine under the place contract, on datacenter hosts only, and no path leaves an instance alive past its limit.
Feature: ~/.local/state/vibe/features/workspaces.md

## Non-goals

- See the feature file.
- New files only: the place script, `tests/ws-place-vast.bats`, `docs/workspaces/place-vast.md`.

## Decisions

- See the feature file.
- Known, from the Vast.ai docs, not run: offers with `vastai search offers '<query> verified=true rentable=true datacenter=True' -o dph --raw`; create with `vastai create instance <offer> --image <image> --disk <n> --ssh --direct --cancel-unavail`, the id is `new_contract`; state from `vastai show instance <id> --raw`, field `actual_status` (one page names it `status`: read both); `exited`, `unknown` and `offline` never become `running`; copy with `vastai copy`; destroy with `vastai destroy instance <id>`.
- A stopped instance still bills storage: the script never stops, it destroys.
- Interruptible offers are never used: a run of hours must not be killed by a bid.
- The recipe names prepaid credit with no saved card as the last money stop.

## Milestones

- [ ] The place script against stub `vastai`, `ssh` and `rsync` — code — done when `bats tests/ws-place-vast.bats` passes: the search query holds `datacenter=True`; a status that never reaches `running` ends in a destroy; `down` destroys after a failed `pull`; `tick` past `limit` destroys; no secret value is in any stub's argv.
- [ ] The recipe `docs/workspaces/place-vast.md`: requirements, numbered steps, verify, what breaks it — code — done when `grep -c '^## ' docs/workspaces/place-vast.md` prints 4 or more.
- [ ] End action — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

## End action

`delete`. Each decision moves to the PR body.
