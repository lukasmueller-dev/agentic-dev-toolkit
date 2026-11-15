# Spec — agentic-dev-toolkit / ws-place-runpod

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-place-runpod`
- **Written:** 2026-11-15

## Goal

`workspaces/_places/runpod` gives a tool its own RunPod machine under the place contract, and no path leaves a pod alive past its limit.
Feature: ~/.local/state/vibe/features/workspaces.md

## Non-goals

- See the feature file.
- New files only: the place script, `tests/ws-place-runpod.bats`, `docs/workspaces/place-runpod.md`.

## Decisions

- See the feature file.
- Known, from the RunPod docs, not run: create with `runpodctl pod create --name … --gpu-id "<type>" --image <image> --container-disk-in-gb <n> --ports "22/tcp" --cloud-type SECURE|COMMUNITY --docker-args "sleep infinity"`; ready when `runpodctl pod get <id> --output json` has `runtimeStatus` `running`, which does not prove that ssh answers; address from `runpodctl ssh info <id>`; destroy with `runpodctl pod delete <id>`, gone when the pod is not found.
- Copy with `rsync` over direct ssh: the proxy ssh has no scp.
- `--cloud-type` comes from the user's env file; the default is `SECURE`.
- The wait for `running` has its own timeout; on timeout the pod is deleted.
- The recipe names prepaid credit with auto-pay off as the last money stop.

## Milestones

- [x] The place script against stub `runpodctl`, `ssh` and `rsync` — code — done when `bats tests/ws-place-runpod.bats` passes: a failed `up` deletes the pod; `down` deletes after a failed `pull`; `tick` past `limit` deletes; `tick` pulls when `pulled` is 10 min old or more; no secret value is in any stub's argv.
- [x] The recipe `docs/workspaces/place-runpod.md`: requirements, numbered steps, verify, what breaks it — code — done when `grep -c '^## ' docs/workspaces/place-runpod.md` prints 4 or more.
- [ ] End action — code — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

## End action

`delete`. Each decision moves to the PR body.
