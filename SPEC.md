# Spec — agentic-dev-toolkit / queue-page-actions

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** /home/lukas-mueller/github/agentic-dev-toolkit
- **Branch:** `queue-page-actions`
- **Written:** 2026-11-04

## Goal

The phone page acts on the queue: each row below is a button or form that runs one
`vibe`, `gpu-queue`, `gh` or `systemctl --user` command, for your tailnet login only.
Rows (2026-11-04 list): F1–F5, 1–12, 14, 18, 20–22, 24–29, 31, 33–37, 39.

## Non-goals

- No merge route (19): you merge on GitHub.
- No single-PR ready or close (15, 16), no `run-ci` label (17).
- No prompt editor for queued jobs (13), no contract answers (23).
- No due dry-run (30), GPU status (32), machine health (38), rows 40–45.
- No change to the static page path: with the server down, the page still reads, with no buttons.
- No client machines: the server runs only where `~/.config/vibe/role` is `server`.

## Decisions

- Route: a `SPEC.md` chain, one branch, one PR. A lane cannot carry a `SPEC.md` (`docs/vibe-queue.md`, Lanes).
- Server: `bin/vibe-web`, python3 stdlib only, on `127.0.0.1:<web_port>` (`queue.conf`, default 7341).
- Rejected: socat + bash (HTTP and JSON parse in bash); GitHub comments only (PR rows only, poll delay).
- The server is a router: one route → one argv list; no shell string, no `shell=True`.
- New logic goes into `vibe` and `gpu-queue` subcommands: the CLI and the page do the same thing; bats tests the logic.
- Mount: `tailscale serve --bg --set-path /queue/api http://127.0.0.1:<web_port>`; the static `/queue` mount stays.
- The server accepts paths with and without the `/queue/api` prefix.
- Auth (F2): every request needs `Tailscale-User-Login` equal to `web_login` (`queue.conf`); no `web_login` → 403.
- A write also needs POST, `Content-Type: application/json` and `Origin` equal to the request host: the tailnet identity rides on the device, so a cross-site form post from another tab carries it.
- Local forgery: a process on the server can forge the header; job sandboxes have their own network namespace and cannot reach host `127.0.0.1`.
- The page shows buttons only after `GET whoami` returns your login.
- Action log (F3): `$QROOT/actions.log`, outside `web/`: time, login, argv, exit code per write. The page shows the last 20.
- Refresh (F4): after each write the server runs the new `vibe queue page` (writes `web/index.html` now).
- Confirm (F5): a second tap for cancel, stop, archive, answer, feature archive, worktree remove, restarts, update-toolkit, GPU cancel.
- Unit: `claude/systemd/vibe-web.service`, with the `ExecCondition` of `vibe-queue.service`; `vibe update-toolkit` restarts it when `bin/vibe-web` changed.
- Stop (12): a `stop` file in the job dir; the runner ends the job `failed`, note `stopped`, no requeue, no WIP commit.
- Ready (21): `vibe queue ready <url>` refuses a failing check and a diff with `SPEC.md` or `HANDOFF.md`; feature ready runs it per member PR, then `vibe feature ready`.
- Answer (10): `vibe queue answer` does the `requeue` of `/review-jobs`, lane side jobs included, then archives the original.
- Fix (18): `vibe queue fix <url> <text>`; the roadmap item "PR event follow-ups" can reuse it later.
- New work (24, 25): `vibe queue new` renders `skills/fill-queue/references/job-prompt.md`; it needs a done-when and refuses a branch that is queued or running.
- Opt-in (31): a `vibe queue new` job with a fixed prompt (`vibe job add <worktree> <job>`, commit); the runner opens the PR; the main checkout stays on the default branch.
- Worktree remove (35): `skills/worktree-cleanup/cleanup.sh`; only `merged` and `prunable`.
- Model: Opus for each milestone: an unsandboxed endpoint with many guards needs design judgment.

## Milestones

- [x] M1 server, auth, action log, refresh, confirm (F1–F5), pause/resume (1) — code — done when `bats tests/vibe-web.bats` passes with: right login → `paused` exists, `actions.log` has one line; wrong or absent login, foreign `Origin`, non-JSON body, absent `web_login` → 403 and no `paused`; `GET whoami` returns the login; and `grep -q 'set-path /queue/api' docs/vibe-queue.md`
- [ ] M2 queue control and job cards (2–9, 11, 12, 14) — code — done when bats tests pass for `vibe queue conf` (refuses an unknown key and a bad value), `unlimit`, `set <id> now=1|after=` (queued jobs only), `retry`, `cancel` (queued only), `stop` (runner ends it `failed`, no requeue), and one route test per row (3: stub `systemctl` gets `restart vibe-queue`)
- [ ] M3 review and feature actions (10, 18, 20, 21, 22) — code — done when bats tests with a stub `gh` pass for `vibe queue answer` (answer in `HANDOFF.md`, commit, push, follow-up queued, original archived; lane side job → `-retry` branch rules), `vibe queue fix` (refuses a queued or running branch), `vibe queue ready` (refuses a failing check, and `SPEC.md` or `HANDOFF.md` in the diff), `vibe queue merge-order <repo>`, and the feature archive route (refuses an open member PR)
- [ ] M4 new work and recurring jobs (24–29, 31) — code — done when bats tests pass for `vibe queue new` (no `<…>` slot left in `prompt.md`; refuses no done-when and a queued branch), the roadmap route (items of a fixture repo's `origin`, with their line), `vibe job reset <repo> <job>` (removes `fails`), the run, triage and opt-in routes; and `grep -q 'claude.ai/code' templates/queue-page.html`
- [ ] M5 GPU, machine and job files (33–37, 39) — code — done when bats tests pass for `gpu-queue cancel <id>` (queued and running; the vibe job ends `failed`, no follow-up), the servers route (stub `systemctl` restarts `claude-rc@<name>`), worktree remove (refuses `dirty`, `unpushed`, `locked`), the sync and update-toolkit routes, the job-file route (only `report.md`, `gate.log`, `pr.md`, `result`, `note`, log tail; `../` → 404)
- [ ] M6 end action — code — done when `test ! -f SPEC.md`, `docs/vibe-queue.md` has a `## Page actions` table (row → route → command), the `PROJECT_STATUS.md` line "the queue has a read-only phone page" names the write endpoint, and shellcheck, shfmt and `bats tests/` pass

## End action

`rewrite into docs/vibe-queue.md` (`## Page actions`: row → route → command, and the setup in step 3); each decision moves to the PR body.
