# Vibe queue

One queue, always on. Skills and timers add jobs; `vibe-queue.service` runs
each as a headless agent in its own worktree and opens a draft PR. You review
and refill it whenever you like.

| Skill | Does |
| --- | --- |
| [`/fill-queue`](../skills/fill-queue/SKILL.md) | shows the queue; big work grilled into a `SPEC.md` or a feature; sweep, gate, lanes, your approval; `vibe queue add` |
| [`/enqueue`](../skills/enqueue/SKILL.md) | the one item just discussed: a prompt, a `SPEC.md` branch for big work, or a feature; your approval; `vibe queue add` |
| [`/review-jobs`](../skills/review-jobs/SKILL.md) | a fresh briefing; features first; per row ready, requeue, hold, close, ack; archives what it carried out; gives the merge order |
| [`/check-in`](../skills/check-in/SKILL.md) | `/review-jobs`, then `/fill-queue` |
| [`/shutdown`](../skills/shutdown/SKILL.md) | hands off every worktree, then `/fill-queue` |
| 01:00 timer | adds due recurring jobs: [`vibe-jobs.md`](vibe-jobs.md) |

## Requirements

- `gh` logged in, `timeout` (coreutils), systemd user services; `systemd-run --user` for the memory cap.
- The repos trusted once (`docs/remote-sessions.md` step 1).
- A sandbox that starts: `bwrap --ro-bind / / --unshare-net true` exits 0.
  Jobs exit instead of running unsandboxed (`failIfUnavailable`).

## 1. Configure

```bash
mkdir -p ~/.config/vibe
printf '%s\n' thesis pncbf humanoid_bridge >~/.config/vibe/repos   # the sweep, highest rank first
echo ~/knowledge-lab/_inbox/agent-briefings >~/.config/vibe/briefing-dir   # optional: briefing copies
```

`~/.config/vibe/queue.conf`, optional — the defaults:

```ini
slots=4
review_rounds=2
review_trivial=20
review_model=sonnet
review_level=high
review_timeout=1h
after=review
memory_max=25%     # per job: 100% ÷ slots; a systemd size (6G) or infinity
web_port=7341      # the page endpoint, 127.0.0.1 only (step 3)
web_login=         # your tailnet login; empty: every page write gets 403
```

Optional, per repo: a gate the job sandbox cannot run (docker, hardware).
Commit it to the default branch; the runner reads it from there on `origin`.

```bash
echo 'tools/test.sh --docker' >.vibe-jobs/gate    # a shell command; runs unsandboxed in the job's worktree
```

## 2. Install the runner

Server machine only (`~/.config/vibe/role` holds `server`).

```bash
systemctl --user link ~/.claude/systemd/vibe-queue.service ~/.claude/systemd/gpu-queue.service
systemctl --user enable --now vibe-queue.service gpu-queue.service
```

Every other machine: `echo 'client <host>' > ~/.config/vibe/role` (`<host>` takes `ssh <host>`).
There `vibe queue status|report` and `vibe job list` run on the server; other `queue` and `job` commands stop.

## 3. Phone page

The runner writes `~/.local/state/vibe/web/index.html` each pass: tabs Queue, Briefing and Config (settings, `vibe job list`), `pandoc` if present.
A running card shows its last step and the last 10 from `queue/<id>/log` (`jq` if present).
At 1024 px and wider, the page is 15% larger and shows Queue and Briefing side by side.
The page re-fetches itself every 10 s and keeps the filter, open cards and open steps; no change for 2 minutes turns the time stamp red, `stale` (runner or network down). Without JS it needs a reload.
A lane card is a stack of three sheets. One click on it unpacks a job card per job; a click on its header packs it again.
A feature card is a stack too: it unpacks into a lane, job or `no job` card per member.
The header and the chips count `to review` as PRs (one per URL in a `pr` file; a lane or a review chain is one) and `no PR` as ended jobs without a URL (a report-only job too). A `done` job is covered by a URL on its branch, and waits while a job there is queued or running; a failed or blocked job always counts. The `to review` chip links your open `agent` PRs on GitHub.
Serve it on the tailnet once:

```bash
sudo tailscale serve --bg --set-path /queue ~/.local/state/vibe/web   # root: a path, not a port
```

Buttons, server only: `bin/vibe-web` runs one fixed command per route; `web_login` in `queue.conf` first.

```bash
systemctl --user link ~/.claude/systemd/vibe-web.service
systemctl --user enable --now vibe-web.service
sudo tailscale serve --bg --set-path /queue/api http://127.0.0.1:7341   # web_port
curl -s -H 'Tailscale-User-Login: <web_login>' http://127.0.0.1:7341/whoami   # {"login": "<web_login>"}
```

- The page shows buttons only after `GET /queue/api/whoami` returns your login. Server down: the page reads, no buttons.
- A write needs `Tailscale-User-Login` = `web_login`, POST, `Content-Type: application/json` and `Origin` = the host; else 403.
- Each write goes to `actions.log` (time, login, command, exit code); then `vibe queue page` writes the page. The Config tab shows the last 20.
- Buttons, routes and commands: [Page actions](#page-actions).
- The nav links `claude.ai/code` for a new session.
- Body args are checked against a fixed pattern (`ARGS` in `bin/vibe-web`); an absent or bad one → 400, nothing runs.

## 4. Verify

```bash
vibe queue status                                   # header, then per repo each job on two lines; a branch with 2+ jobs is one row: done/total, running or next item, PR
vibe queue report --week                            # the briefing + a Sunday section: per repo PRs merged, jobs run, blockers open (7 days)
journalctl --user -u vibe-queue -f                 # the runner's log
vibe queue run --claude --drain                     # by hand, without the service: until nothing can start
```

## Rules the runner keeps

- FIFO by id `<YYYYMMDD-HHMMSS>-<repo>-<branch>`; a GPU follow-up `<id>-gpu` sorts right after its job.
- Slots: `slots` agents at once. One job per branch at a time.
- `vibe queue add --now` starts the job before the other queued jobs. `vibe queue pause`: no new start; running jobs finish.
- `vibe queue conf <key>=<value>` sets one `queue.conf` key: `slots`, `after`, `review_*`, `memory_max`; other keys and bad values are refused.
- `vibe queue set <id> now=1|after=`, `cancel <id>`: queued jobs only. `cancel`: `skipped`, note `cancelled`.
- `vibe queue retry <id>`: a `failed`, `timeout` or `skipped` job again as a new job (job file, `prompt.md`, its own worktree); the old one is archived.
- `vibe queue stop <id>`: a running job gets a `stop` file; the runner's next pass sends TERM to the agent, and the job ends `failed`, note `stopped`. No requeue, no gate, no push, no WIP commit; a lane item leaves the lane as on `failed`. A recurring job does not count it as a fail.
- `vibe queue unlimit` removes `limit`: jobs start again.
- `vibe queue new <repo> <branch> <done-when> <task>`: a job from [`job-prompt.md`](../skills/fill-queue/references/job-prompt.md), source `new`. No done-when, or a job on the branch queued or running: refused.
- `--line <n> <repo> <branch>`: the item at line `n` of the last `vibe queue roadmap <repo>` listing (its origin commit in `roadmap/`); refused when that item changed or left `origin/<default>` since. Its done-when is the text after `Done when`.
- `--opt-in <job> <repo>`: branch `opt-in-<job>`; the agent runs `vibe job add` in its worktree and commits. The main checkout stays on the default branch.
- Usage limit (a `rejected` `rate_limit_event` in the log): the job goes back to `queued` in its own worktree, nothing pushed; no job starts until the reset. The retry resumes the saved session.
- Gate: after the agent (after the last review round when one is due), before the PR, `bash -c` of `.vibe-jobs/gate` from a fresh fetch of `origin/<default>` — never from the job's branch — in the job's worktree, bounded by the job's `timeout`. Exit code and last 20 lines go to the PR body; a non-zero exit puts a `done` job under "Needs you". No gate file: no step.
- A job pushes nothing itself; the runner pushes and opens a draft PR (label `agent`) when it committed, or replaces the body of the PR open on the branch.
- Timeout: the job gets one more turn in its saved session (`--max-turns 5`) that commits `HANDOFF.md` and writes `result`. Status stays `timeout`.
- Review: a `done` job with commits ahead of its base queues `<id>-review1` before any push. A fresh read-only session runs `/code-review <review_level> origin/<base>...HEAD` inside a prompt (a bare slash command returns no findings); the job's own session fixes or rejects each finding.
- Round 2 (`<id>-review2`) runs only when round 1 found something and its fix changed a file outside `*.md` or more than `review_trivial` lines. `review_rounds` caps it; what stays open goes to the PR body.
- The last review round pushes and opens the PR. Its body carries one `R<n>:` line per round above `<details>`; findings and verdicts sit inside.
- No `structured_output` → `R<n>: review failed`. A round past `review_timeout` → `R<n>: timeout`. The PR opens either way.
- No review for `queued:`, `blocked`, `failed` or `timeout` jobs, `output=report` jobs, or a job without commits. `after=` empty in `queue.conf` or the job file turns it off.
- A `SPEC.md` job that ticks a milestone and leaves one open queues the next, with the same prompt.
- A restart of the service stops only the runner (`KillMode=process`); running jobs finish and write their own status.
- Memory: each agent, and the gate, runs in its own systemd scope with `MemoryMax=<memory_max>`, no swap. Past it the kernel kills the biggest process in that scope; oomd picks one scope too. The agent killed: `failed`, `agent killed (SIGKILL)`; a test it ran: the agent sees the kill and goes on. Other jobs and the runner keep running. `memory_max` is read at runner start.

## Lanes

Related light items run as one lane: one branch, one PR, one row, one review.
`/fill-queue` proposes lanes; you change them before you approve.

- A lane is the unarchived jobs on one branch whose job file has `lane=<one-line context>` and `item=<slug>`. One job and one commit per item, in series.
- Only `code` items, 2h timeout. No GPU job, no `SPEC.md` chain.
- `/fill-queue` adds no item to a lane that is queued or has an open PR. The lane closes when its last item finishes.
- An item that ends `failed`, `blocked` or `timeout` leaves the lane: WIP commit, pushed to `<branch>-<item>` without a PR, lane branch reset to the item's start commit. The next item runs.
- A usage limit only pauses the lane; the job keeps its id.
- `/review-jobs` retries an item out of the lane from the current tip: the lane branch while its PR is open, else `<branch>-<item>-retry` from the default branch. Its prompt names `git diff <start>..<side-branch>`.
- After each item the runner writes the lane PR again: title and TL;DR from the latest done item's `pr.md`, a `<item> → <side-branch>` line per item out of the lane, one `<details>` per item.
- The agent of each item gets `lane-pr.md` (the PR so far) and writes the title and TL;DR for the whole lane.
- `vibe queue status` and the briefing show one row per branch with 2+ jobs (`3/5`); a job row only for a job that needs you. A finished branch shows its newest job's TL;DR in the briefing (a GPU run's metric).

## Features

Branches in several repos that merge together run as one feature: one file, one row, one review decision, one merge batch.
A job still changes only its own repo. `/fill-queue` and `/enqueue` make features: [`references/feature.md`](../skills/fill-queue/references/feature.md).

```bash
vibe feature add <dir>/<slug>.md   # checks each member branch, fills in the open PRs
vibe feature ready <slug>          # the human test passed: the pill shows merge
vibe feature archive <slug>        # all member PRs merged; refuses an open one
vibe queue ready --feature <slug>  # each member PR checked, then ready, then feature ready
```

- A member is a `- <repo> <branch>` line under `## Members` of `features/<slug>.md` ([`templates/FEATURE.md`](../templates/FEATURE.md)). A branch is in one feature at most; the job file has no key.
- A member is one job, a lane, a `SPEC.md` chain, or a PR with no job. Its `SPEC.md` holds only its milestones and a pointer to the feature file.
- At job start the runner adds a `## Feature` block to a member's prompt, once: the file path and the contract rule. A contract change ends the job `blocked: contract …`.
- At publish: a `**Feature:**` line below the TL;DR (siblings as `repo#pr`, else `repo:branch`), the decisions and contract in a `<details>`, the PR URL into the member line. Sibling bodies stay as they are.
- Status, the briefing and the page show a `Features` group first. Member jobs leave their repo groups; in the briefing a member job keeps its row only when it needs you.
- Count: done members / members. Done: a PR, and no job queued, running or in need of you.
- Pill, first match: `needs you` (a member job held, blocked, failed, timed out or skipped; a member with no job and no PR), `running`, `queued`, `your test`, `merge` (`<slug>.ready`).
- No cross-repo gate: the human test in the file is the integration check.

## Page actions

A tap posts to `/queue/api/<route>`; `bin/vibe-web` runs the route's one fixed argv (`ROUTES`). `<arg>` comes from the card's `data-*` or a prompt. ✓: a second tap within 4 s.

| Row (card: button) | Route | Command |
| ------------------ | ----- | ------- |
| Queue: Pause / Resume | `pause`, `resume` | `vibe queue pause` / `resume` |
| Queue: Clear usage limit | `unlimit` | `vibe queue unlimit` |
| Queue: Set config | `conf` | `vibe queue conf <key=value>` |
| Queue: Restart runner ✓ | `restart` | `systemctl --user restart vibe-queue` |
| Queue: Triage PRs | `triage` | `vibe job triage` |
| Queue: Sync worktrees | `sync` | `vibe sync --all` |
| Queue: Servers | `servers` | `vibe status --claude` |
| Queue: Restart server ✓ | `server-restart` | `systemctl --user restart claude-rc@<server>` |
| Queue: Update toolkit ✓ | `update-toolkit` | `vibe update-toolkit`; vibe-web re-execs itself after its reply |
| Queued job: Start next | `now` | `vibe queue set <id> now=1` |
| Queued job: No review | `noreview` | `vibe queue set <id> after=` |
| Queued job: Cancel ✓ | `cancel` | `vibe queue cancel <id>` |
| Running job: Stop ✓ | `stop` | `vibe queue stop <id>` |
| GPU job: Cancel GPU run ✓ | `gpu-cancel` | `gpu-queue cancel <gpu>` |
| Failed, timeout or skipped job: Retry | `retry` | `vibe queue retry <id>` |
| Blocked, failed or timeout job: Answer ✓ | `answer` | `vibe queue answer <id> <text>` |
| Done job with a PR: Fix | `fix` | `vibe queue fix <pr> <text>` |
| Ended job: Hold | `hold` | `vibe queue hold <id> <note>` |
| Ended job: Archive ✓ | `archive` | `vibe queue archive <id>` |
| Job: a file link | `GET job/<id>/<file>` | `report.md`, `pr.md`, `gate.log`, `result`, `note`, `log` (last 64 KB) as text |
| Repo header: Merge order | `merge-order` | `vibe queue merge-order <repo>` |
| Feature in `your test`: Test passed: ready ✓ | `feature-ready` | `vibe queue ready --feature <feature>` |
| Feature in `merge`: Archive ✓ | `feature-archive` | `vibe feature archive <feature>` |
| New work: New job | `new` | `vibe queue new <repo> <branch> <done> <task>` |
| New work: Roadmap | `roadmap` | `vibe queue roadmap <repo>` |
| New work: From roadmap | `roadmap-new` | `vibe queue new --line <line> <repo> <branch>` |
| New work: Opt in | `opt-in` | `vibe queue new --opt-in <job> <repo>` |
| New work: Worktrees | `worktrees` | `cleanup.sh scan <repo>` |
| New work: Remove worktree ✓ | `worktree-remove` | `cleanup.sh remove <path>`: merged or prunable only |
| Recurring job: Run `<job>` | `run` | `vibe job run <repo> <job>` |
| Stopped recurring job: Reset `<job>` | `reset` | `vibe job reset <repo> <job>` |

Not on the page: merge, single-PR ready or close, the `run-ci` label, prompt edits.

Add a route or a button:

- Route: one line in `ROUTES` (`bin/vibe-web`). A body arg is a `"{name}"` slot at an arg's end (`claude-rc@{server}`) plus a pattern in `ARGS`. `TOOLS` maps argv[0] to an argv prefix (`cleanup.sh` runs with `bash`).
- Button: `<button data-act="<route>" [data-confirm] [data-ask="<arg> …" title="<question>|…"]>` in a `<div class="jacts" data-<arg>="…">` inside `#queue`. page.js sends each `data-*` of the nearest `.jacts`, plus one prompt per asked arg.
- Order in a group: read-only buttons, write buttons, then `<hr>` and the `data-confirm` buttons (`btn_rows` in `bin/vibe`). A group is a grid of equal cells.
- The CSP runs only `page.js`: no inline `<script>` or `onclick`.
- A `<details>` inside `#queue` needs a `.repo h2` and a `.job b` above it: page.js keys its open state on them.
- vibe-web runs each command with `VIBE_WEB=1` and kills it after 120 s (`VIBE_WEB_TIMEOUT`).

## Layout

`~/.local/state/vibe/`

| Path | Holds |
| --- | --- |
| `queue/<id>/job`, `prompt.md` | `repo=` `branch=` `model=` `effort=` `timeout=` `context=` `lane=` `item=` `now=` `follow=` `after=` `review=` `review_model=`; the job prompt |
| `queue/<id>/status`, `note` | `queued` `running` `gpu` `done` `blocked` `failed` `timeout` `skipped`; why |
| `queue/<id>/worktree`, `base`, `log`, `pr`, `milestones` | worktree, base branch, agent stream-json, PR URL, open `SPEC.md` milestones at start |
| `queue/<id>/result`, `pr.md`, `report.md` | the agent's `done:`/`queued:`/`blocked:`/`failed:` line; PR title + body (`templates/job-pr.md`); findings (`templates/job-report.md`) |
| `queue/<id>/gate`, `gate.log` | the gate's exit code; `$ <command>`, then its output |
| `queue/<id>/held`, `gpu-job` | `vibe queue hold` note; the `gpu-queue` job id |
| `queue/<id>/session` | the agent's `session_id`; a timeout, a usage-limit retry and a review fix resume it |
| `queue/<id>/agent-pid`, `stop` | the running agent's pid; `vibe queue stop` asked to stop it |
| `queue/<id>/requeued` | time the runner queued the job again after its process died; a second death ends it `failed` |
| `queue/<id>-review<n>/` | review round `n`: `review.json` (reviewer output), `findings`, `verdicts` (`<n>=fixed <sha>` / `rejected <reason>` / `open`), `rounds`, `round-details.md` |
| `queue/<id>/start`, `side`, `lane-pr.md` | lane job: branch tip at start; `<branch>-<item>` after it left the lane; the lane PR so far |
| `archive/<YYYY-MM>/<id>/`, `features/` | reviewed jobs (`vibe queue archive`); archived features (`vibe feature archive`) |
| `features/<slug>.md`, `<slug>.ready` | a feature (`vibe feature add`); the human test passed (`vibe feature ready`) |
| `briefings/<date>-<HHMM>.md` | `vibe queue report`: header (ends with `limit 5h: …`), "Yours", triage lines, per repo Needs you → PR ready → Done (a branch with 2+ jobs is one row), next actions, `--week`: "Week since" section |
| `web/index.html`, `page.js` | the phone page, rewritten each runner pass (`templates/queue-page.*`); its CSP runs only `page.js` |
| `paused` | `vibe queue pause` |
| `roadmap/<repo path, / as %>` | the origin commit `vibe queue roadmap` listed; `new --line` reads it |
| `actions.log` | page writes: time, login, command, exit code (`bin/vibe-web`) |
| `limit` | reset epoch of the last usage limit; no starts before it |

The job finds its dir in `$VIBE_JOB_DIR`. Job settings:
[`claude/vibe-job-settings.json`](../claude/vibe-job-settings.json) — no
unsandboxed retry, no push to `main`/`master`, no `gh pr merge`. File tools
(Write, Edit, NotebookEdit) are fenced to the worktree and the job dir by
`blockWritesOutsideWorkingDirectories`; the runners pass `--add-dir "$VIBE_JOB_DIR"`.

GPU jobs: the agent commits, then `vibe queue gpu -- <cmd>` queues the run in
[`bin/gpu-queue`](../bin/gpu-queue) (status `gpu`). After the run, job
`<id>-gpu` continues on the same branch with the exit code and log.

```bash
gpu-queue status                      # queued, running, finished (exit code)
gpu-queue lock -- python train.py     # a manual run that waits for the queue's GPU job
gpu-queue cancel <id>                 # drop a queued run, TERM a running one; the job ends failed, no <id>-gpu
```

## Cost per job

The PR footer line and the briefing row end with the job's size, from the last `result` event of `queue/<id>/log`:

```text
≈$1.04 API · ≈2% 5h est. · 40 turns · 11m
```

| Field | From |
| --- | --- |
| `≈$ API` | `total_cost_usd`: the API-price equivalent; the subscription pays, nothing bills |
| `≈% 5h est.` | the job's 5h utilization delta (last minus first `rate_limit_event`) × its `$` ÷ the `$` of all jobs that ran at the same time (itself included), each scaled by its overlap time |
| `turns`, `m` | `num_turns`; `duration_ms` in minutes |

- Interactive sessions are not in the sum, so the share is too high.
- No share when `resetsAt` changes during the job, the log has under two events, or a job that overlaps has no `result` event.
- The footer is written at publish: a job still running then has no `result` event, so the briefing row can show a share the footer lacks.
- The briefing header ends with `limit 5h: 46%, resets 14:30`: the newest `rate_limit_event` in any job log.

## What breaks it

- Every job `failed` at once, log mentions login → the claude.ai login expired; run `/login`, or, after an update, `-p` defaults to `--bare`, which does not read the login: give `claude/vibe-job.sh` the opt-out.
- Every job `failed`, log says the sandbox cannot start → AppArmor blocks bwrap; add its profile (code.claude.com/docs/en/sandboxing).
- A job `failed`, note `agent killed (SIGKILL)` → past its memory cap, or oomd under memory pressure; raise `memory_max=` or lower `slots=`, then restart the runner.
- `no systemd user manager` in the runner log → `systemd-run --user --scope true` fails there; jobs run uncapped in the service's cgroup, where one oomd kill takes them all.
- A job `failed`, note `job process died twice` → the process died on both runs (reboot, oomd); read `runner.log` and `log`, then queue it again.
- A job `skipped`, note `uncommitted changes` → that worktree is dirty; commit or clean it.
- `vibe queue run` started inside a sandboxed session → its jobs inherit that sandbox; use the service.
- Another tool uses the GPU → wrap it: `gpu-queue lock -- <cmd>`.
- Page time stamp old → the runner stopped, or runs old code after an update: `systemctl --user restart vibe-queue` (jobs keep running).
- `/queue` returns 404 → no serve path yet; step 3. `401 ... must be root` → run it with `sudo`.
- No buttons on the page → `vibe-web.service` down, no `/queue/api` serve path, or `web_login` is not your login: `journalctl --user -u vibe-web`.
- `no server configured` or `the queue runs on the server` → this machine is a client; step 2, or `ssh <host>`.
- `gh failed` in the sweep → the sandbox hides gh's token; run `sweep.sh` unsandboxed.
