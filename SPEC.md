# Spec — agentic-dev-toolkit / hypothesisloop-bringup

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `hypothesisloop-bringup`
- **Written:** 2026-11-16

## Goal

HypothesisLoop runs on turing with agent sandboxes and rented GPU machines, and its first objective improves the val mode A score of RHSC-state and RHSC-state-action in safety-critic.

## Non-goals

- No final paper runs: those stay on IAS (safety-critic `PROJECT_STATUS.md`, R11).
- No change to the safety-critic main line: experiments live on their own branches.
- No queue job: most steps are interactive (accounts, sign-in, approvals).

## Decisions

- HypothesisLoop over Kapso: one safety-critic run takes 6–13 h on turing, and only HypothesisLoop runs seeds and variants in parallel.
- Full stack with `make dev` (podman), not only `vibe ws start`: the compose stack has no agent sandboxes and no job machines.
- Job machines are rented (vast.ai or RunPod), not turing: a cluster on turing can use the GPU outside the `gpu-queue` lock.
- Score = val mode A, mean over seeds: one seed (0.306 vs 0.330) is inside the seed noise.
- Recipe today: `docs/workspaces/hypothesisloop.md`; safety-critic state: its branch `lukas/critic-diagnostic`, `HANDOFF.md`.

## Milestones

- [x] Clone HypothesisLoop at `70135ef89035c15a7969c957740690524d6dc7f2` — code — done when `git -C <checkout> rev-parse HEAD` prints that commit and `HLOOP_REPO=<checkout>` is in `~/.config/vibe/workspaces/hypothesisloop.env` (mode 600).
- [x] Install Go 1.25.8, npm (Node 22 or newer) and podman with `podman-compose` — code — done when `go version`, `npm -v`, `podman --version` and `podman compose version` print. `kubectl` and `helm` are not needed: only `make k3s-up` uses them.
- [x] Accounts and `.env` per recipe Requirements: Claude token, Supabase, GitHub OAuth App, GitHub App — code — done when `make -s render-settings` in the checkout prints nothing.
- [x] Control plane by the workspace: recipe steps 2–4 — code — done when `workspaces/hypothesisloop/status` prints `up` and the phone signs in at `http://<tailnet hostname>:3000` (`turing.tail7118f4.ts.net`; Supabase's firewall blocks the sign-in on the raw tailnet IP).
- [x] `make dev` with podman and `cloudflared` (it opens public quick tunnels, which the rented machines need), the platform images published to a registry that the rented machines pull from (`IMAGE_REGISTRY`, `IMAGE_TAG`; `make publish` builds every image and both charts, so it needs `helm`), one sandbox provider and one GPU provider in `CLOUD_COMPUTE_PROVIDERS` — code — done when the demo `tests/experiments/dummy-data-search-demo` ends a trial.
- [ ] Safety-critic job image (JAX/MJX) and objective: RHSC-state and RHSC-state-action, val mode A, mean over seeds; decide with the user the steps per trial (5e8, or a short proxy) and the spend cap — gpu — done when one trial on a rented GPU reports a score next to the control (0.306, G1 state-action, seed 42).
- [ ] Start the safety-critic objective — gpu — `hl platform-experiments start <dir>`; run time and budget from the previous milestone — done when the UI shows the objective with its first finished trials.
- [ ] Toolkit: the recipe and the workspace cover the `make dev` route — code — done when `docs/workspaces/hypothesisloop.md` holds it and `bats tests/ws-hypothesisloop.bats` passes.
- [ ] End action — done when the PR carries the decisions and this file is gone.

## End action

Rewrite into `docs/workspaces/hypothesisloop.md` (what the setup now is); each decision moves to the PR body.
