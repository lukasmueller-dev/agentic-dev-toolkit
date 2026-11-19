# Vibe queue

One queue, always on. Skills and timers add jobs; `vibe-queue.service` runs
each as a headless agent in its own worktree and opens a draft PR. You review
and refill it whenever you like.

| Skill | Does |
| --- | --- |
| [`/fill-queue`](../skills/fill-queue/SKILL.md) | shows the queue; up to 3 research proposals; big work grilled into a `RESEARCH.md`, a `SPEC.md` or a feature; sweep, gate, lanes, your approval; `vibe queue add` |
| [`/enqueue`](../skills/enqueue/SKILL.md) | the one item just discussed: a prompt, a `SPEC.md` branch for big work, a research job, or a feature; your approval; `vibe queue add` |
| [`/review-jobs`](../skills/review-jobs/SKILL.md) | the report of `vibe queue report`; features first, then repos, with a "Next: …?" stop before each; per row ready, requeue, hold, close, ack; archives what it carried out; gives the merge order |
| [`/check-in`](../skills/check-in/SKILL.md) | `/review-jobs`, then `/fill-queue` |
| [`/shutdown`](../skills/shutdown/SKILL.md) | hands off every worktree, then `/fill-queue` |
| 01:00 timer, hourly timer | adds due recurring jobs; triages agent PRs: [`vibe-jobs.md`](vibe-jobs.md) |

## Requirements

- `gh` logged in, `timeout` (coreutils), systemd user services; `systemd-run --user` for the memory cap.
- The repos trusted once (`docs/remote-sessions.md` step 1).
- A sandbox that starts: `bwrap --ro-bind / / --unshare-net true` exits 0.
  Jobs exit instead of running unsandboxed (`failIfUnavailable`).

## 1. Configure

```bash
mkdir -p ~/.config/vibe
printf '%s\n' thesis pncbf humanoid_bridge >~/.config/vibe/repos   # the sweep, highest rank first
```

`~/.config/vibe/queue.conf`, optional — the defaults:

```ini
slots=4
review_rounds=2
review_trivial=20
review_model=sonnet
review_level=high
review_timeout=1h
after=review       # code: /code-review only, no lean-review; empty: no review
memory_max=25%     # per job: 100% ÷ slots; a systemd size (6G) or infinity
web_port=7341      # the page endpoint, 127.0.0.1 only (step 3)
web_login=         # your tailnet login; empty: every page write gets 403
pr_login=          # the GitHub login whose /fix starts a fix job; empty: gh's login
steer=             # 1: vibe queue steer reaches a running session; read at each session start
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
There `vibe queue status|report`, `vibe job list` and `vibe ws list|status` run on the server; other `queue`, `job` and `ws` commands stop.

## 3. Page

The runner writes `~/.local/state/vibe/web/` each pass: `index.html`, `page.js` and `fonts/`, from `templates/queue-page.*`.
`pandoc` renders the Markdown if present. Raw HTML in the text shows as code; a link or image with a scheme other than `http`, `https` or `mailto` shows as text.
Serve it on the tailnet once:

```bash
sudo tailscale serve --bg --set-path /queue ~/.local/state/vibe/web   # root: a path, not a port
```

The page is a monitor with one-click decisions. Its labels: [Page words](#page-words); its buttons: [Page actions](#page-actions).

| Part | Shows |
| --- | --- |
| Top bar | glider, `vibe queue`, the tabs, the status, Pause or Resume |
| Tabs | Jobs with the Needs-you count, Recurring, Workspaces (a dot while a tool runs), Settings, Help ↗ (Page words on GitHub, from the `origin` URL) |
| Status | lamp, `3 of 4 jobs run`; wider than a phone also `paused`, the Claude usage or limit, `GPU busy: <holder>`; `Runner stopped` when the page is older than 2 min |
| Jobs | Needs you and Running open; Queued, On hold, PR problems (`triage.md`) and Done folded in one card, each only with a row |
| Row | lamp, title, progress, one line (the reason, or the repo and the running step), run time, one primary button |
| Job panel | the block of the row the URL names (`#job-<key>`): state, title, repo · branch · run time; steps; one result line; buttons; task (3 lines, then a fold); files; activity |
| Recurring | per repo: job, schedule, last run, state, Run; Skip for a due or not-due job, Undo while it skips its next run, Reset only when stopped |
| Workspaces | a card per tool. Services: state, time up and left (amber under 30 min), Start, or Open UI ↗ and Stop. Tools that run as a job: Idle or the live job, Recipe ↗; no Start, no last run |
| Settings | Slots, Claude usage limit (Clear usage limit while reached), any other `key=value`; Restart queue runner; a Restart and a Remove (two taps) per `claude-rc@` unit file |

- Needs you: a job blocked, failed, timed out or skipped; a done job with a failed gate or verify, `push failed`, `PR not created` or a PR to review; a lane with such an item; a feature that needs you, in `your test` or in `merge`.
- A lane, a feature, a tool job and an outside GPU run are one row each. The block folds a card per lane job or feature member.
- The primary button, first match: Answer, Run again, Open PR ↗, Test passed, Archive. Answer opens the block at its note field. The other buttons are in the panel.
- The phase line, in `vibe queue status`: `✓ Agent · ✓ R1 2 fixed · ▶ R2 · ○ Verify app · ○ Gate · ○ PR`.
  ✓ done, ▶ running, ○ to come, ✗ failed (red). R2 shows once queued, Verify only with `verify=`; a report job shows `Agent · Report`.
  Gate and PR drop once the chain's last job ended without them. A lane shows its running job's chain, else the latest one.
- The panel's steps are the phase line in page words: `✓ Work — ✓ Review 1 — ▶ Review 2 — ○ Verify — ○ Checks — ○ PR`. A step's tooltip says what it does, with its detail (`2 fixed`) and the review passes.
- Activity: when a block shows, page.js fetches the last 5 agent texts and the last 5 tool calls of its `log` (`GET job/<id>/activity`).
- The GPU holder, first match: a running `gpu` job, a running outside `gpu-queue` run, a workspace that holds the lock, a running `gpu=yes` tool job on turing; else `busy`.
- Workspaces Start: a place and hours form for a tool with 2+ places, else one button. While the lock is held, the turing option names the GPU holder for a `gpu=yes` tool.
- Layout: centered, at most 1440 px. From 1200 px the job list (at most 600 px) has the panel as a right column, always open, with Close only under a button's output. Under 1200 px one column, the panel a modal over the list; on a phone a bottom sheet, the tabs on a line of their own.
- `j`/`k` move the selection; no single key writes. In a field, `⌘↵` or `Ctrl↵` sends and `Esc` clears.
- The page fetches itself every 10 s and swaps each part that changed; open folds stay. After a write it fetches every 2 s until the write's card changes, at most 60 s. A field in focus or with a changed value stays as it is, and so does its panel block; the rest of its part swaps. Without JS it needs a reload.
- The tab title is `(N) vibe`, N the Needs-you count. The glider moves while a job runs, except with reduced motion. Light and dark follow the system; one indigo accent, red only for a failure.

Buttons, server only: `bin/vibe-web` runs one fixed command per route; `web_login` in `queue.conf` first.

```bash
systemctl --user link ~/.claude/systemd/vibe-web.service
systemctl --user enable --now vibe-web.service
sudo tailscale serve --bg --set-path /queue/api http://127.0.0.1:7341   # web_port
curl -s -H 'Tailscale-User-Login: <web_login>' http://127.0.0.1:7341/whoami   # {"login": "<web_login>"}
```

- The page shows buttons only after `GET /queue/api/whoami` returns your login. Server down: the page reads, no buttons.
- A write needs `Tailscale-User-Login` = `web_login`, POST, `Content-Type: application/json` and `Origin` = the host; else 403.
- Each write goes to `actions.log` (time, login, command, exit code). The answer comes right after the command.
  Then `vibe queue page` writes the page in the background: one render for all the writes that arrive during a render.
- Buttons, routes and commands: [Page actions](#page-actions).
- A button's output and a file link open under the block in the panel.
- A `.md` in the panel keeps raw tags: `style` elements go, and every attribute except `href`, `src`, `alt`, `title`, `type`, `checked`, `start`. Its buttons do nothing; CSP blocks scripts and frames.
- Body args are checked against a fixed pattern (`ARGS` in `bin/vibe-web`); an absent or bad one → 400, nothing runs.

## 4. Verify

```bash
vibe queue status                                   # header, then per repo each job on two lines, then its phases; a branch with 2+ jobs is one row: done/total, running or next item, PR
vibe queue report                                   # on stdout: header (ends with `limit 5h: …`), "Yours", triage lines, per repo Needs you → PR ready → Done, next actions
journalctl --user -u vibe-queue -f                 # the runner's log
vibe queue run --claude --drain                     # by hand, without the service: until nothing can start
```

The status header counts `to review` as PRs (one per URL in a `pr` file; a lane or a review chain is one) and `no PR` as ended jobs without a URL (a report-only job too).
A `done` job is covered by a URL on its branch, and waits while a job there is queued or running; a failed or blocked job always counts.

## Rules the runner keeps

- FIFO by id `<YYYYMMDD-HHMMSS>-<repo>-<branch>`; a GPU follow-up `<id>-gpu` sorts right after its job and starts once its job has an `ended` file. A `done` job with a dead process and no `ended` file gets one on the next runner pass. `vibe queue archive` and the report skip a final job that has a `pid` file and no `ended` file: its process still writes.
- Slots: `slots` agents at once. One job per branch at a time.
- `vibe queue add --now` starts the job before the other queued jobs. `vibe queue pause`: no new start; running jobs finish.
- `vibe queue add --at HH:MM <dir>...`: the jobs wait until that local time (tomorrow's when it has passed today), then start as normal jobs. The job file gets `at=YYYY-MM-DD HH:MM`; `vibe queue status` and the page show `starts <that time>`. `--now` with `--at`, and a time the clock change skips, are refused; `vibe queue set <id> now=1` starts a waiting job at once; `retry` drops `at=`. A start is up to one runner poll (30 s) late.
- `vibe queue conf <key>=<value>` sets one `queue.conf` key: `slots`, `after`, `review_*`, `memory_max`, `steer`; other keys and bad values are refused.
- `vibe queue set <id> now=1|after=`, `cancel <id>`: queued jobs only. `cancel`: `skipped`, note `cancelled`.
- `vibe queue retry <id> [<note>]`: a `failed`, `timeout` or `skipped` job again as a new job (job file, `prompt.md`, its own worktree); the old one is archived. A note ends the task as `Note: <note>`. A `blocked` job needs one; with a `HANDOFF.md`, a lane side branch or a slurm run it goes through `queue answer`.
- `vibe queue stop <id>`: a running job gets a `stop` file; the runner's next pass sends TERM to the agent, and the job ends `failed`, note `stopped`. No requeue, no gate, no push, no WIP commit; a lane item leaves the lane as on `failed`. A recurring job does not count it as a fail.
- `vibe queue steer <id> <text>` with `steer=1`: each session starts with `--input-format stream-json` and reads the FIFO `<job>/steer`. The running session gets the text as a user message at its next boundary. Its first result event ends the input; `vibe queue steer` refuses a text after it. A tool job's run: [Tool jobs](#tool-jobs).
- `vibe queue unlimit` removes `limit`: jobs start again.
- `vibe queue new <repo> <branch> <done-when> <task>`: a job from [`job-prompt.md`](../skills/fill-queue/references/job-prompt.md), source `new`. No done-when, or a job on the branch queued or running: refused.
- `--line <n> <repo> <branch>`: the item at line `n` of the last `vibe queue roadmap <repo>` listing (its origin commit in `roadmap/`); refused when that item changed or left `origin/<default>` since. Its done-when is the text after `Done when`.
- `--opt-in <job> <repo>`: branch `opt-in-<job>`; the agent runs `vibe job add` in its worktree and commits. The main checkout stays on the default branch.
- Usage limit (a `rejected` `rate_limit_event` in the log): the job goes back to `queued` in its own worktree, nothing pushed; no job starts until the reset. The retry resumes the saved session.
- Gate: after the agent (after the last review round and the verify step when due), before the PR, `bash -c` of `.vibe-jobs/gate` from a fresh fetch of `origin/<default>` — never from the job's branch — in the job's worktree, bounded by the job's `timeout`. Exit code and last 20 lines go to the PR body; a non-zero exit puts a `done` job under "Needs you". No gate file: no step.
- A job pushes nothing itself; the runner pushes and opens a draft PR (label `agent`) when it committed, or replaces the body of the PR open on the branch.
- A failed push writes `push failed` (git-lfs: `push failed (git-lfs: push by hand)`) to `pr`; a failed `gh pr create` writes `PR not created`. The `done` job shows under "Needs you" with that note, not under "Done". A failing gate keeps its row and gains the note. A feature member whose last `pr` holds either note shows it as its state, and the feature `needs you`.
- Each runner git call on a job's tree, the checkout of a resumed branch and `vibe sync` run with `core.hooksPath=/dev/null` (`agent_git` in `skills/_lib/lib.sh`): no repo hook runs, the job's own hooks included. A relative `core.hooksPath` would run them unsandboxed. `agent_push` refuses a push when `git-lfs` is installed and a commit to push adds or changes a path that `filter=lfs` maps (any `.gitattributes`, `.git/info/attributes`): the pre-push hook that uploads the LFS objects is off. A push that changes no LFS path goes through.
- Timeout: the job gets one more turn in its saved session (`--max-turns 5`) that commits `HANDOFF.md` and writes `result`. Status stays `timeout`.
- Review: a `done` job with commits ahead of its base queues `<id>-review1` before any push. A fresh read-only session runs `/code-review <review_level> origin/<base>...HEAD` inside a prompt (a bare slash command returns no findings), then the [`lean-review`](../skills/lean-review/SKILL.md) rubric from its system prompt. The job's own session fixes or rejects each finding of both passes. `after=code`: `/code-review` only, no `lean-review`; the `**Review:**` line ends `(/code-review only)`.
- Round 2 (`<id>-review2`) runs only when round 1 found something and its fix changed a file outside `*.md` or more than `review_trivial` lines. `review_rounds` caps it; what stays open goes to the PR body.
- The last review round, or the verify step after it, pushes and opens the PR. Its body carries a `**Review:**` line above `<details>`: one `R<n>:` per round, then `V:`. Findings, verdicts and verify checks sit inside.
- No `structured_output` → `R<n>: review failed`. A reviewer past `review_timeout` → `R<n>: timeout`. The PR opens either way.
- A fix session past `review_timeout`, with a non-zero exit, or with an error result (a 429 spend limit) → `failed`, note `R<n>: … → fix failed: API error 429; <worktree> has uncommitted changes`. No PR; `vibe queue retry <id>` adopts the worktree.
- No review for `queued:`, `blocked`, `failed` or `timeout` jobs, `output=report` jobs, or a job without commits. `after=` empty in `queue.conf` or the job file turns it off. `vibe queue add` refuses an `after=` other than `review`, `code` or empty.
- Verify: `verify=app`, `blast-radius` or `app,blast-radius` (`/enqueue`, `/fill-queue` on request) queues `<id>-verify` after the last review round. A fresh read-only session runs `claude/vibe-verify.sh` with `review_model` and `review_timeout`.
- `app` follows the repo's `.claude/skills/verify-*/SKILL.md` (a human writes it: `/create-verification-skill`); none → `V: no verify skill`. `blast-radius` follows the vendored skill.
- Verify reports only: a moved HEAD or a changed tracked file → `V: dirty`: no gate, no push, no PR, and the worktree stays as it is. `V: fail`, `dirty`, `timeout` or `verify failed` put a `done` job under "Needs you", like a non-zero gate.
- `vibe queue add` refuses `verify=` on a lane job, a job with no review, or another value.
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
- `vibe queue status` and the report show one row per branch with 2+ jobs (`3/5`); a job row only for a job that needs you. A finished branch shows its newest job's TL;DR in the report (a GPU run's metric).

## Features

Branches in several repos that merge together run as one feature: one file, one row, one review decision, one merge batch.
A job still changes only its own repo. `/fill-queue` and `/enqueue` make features: [`references/feature.md`](../skills/fill-queue/references/feature.md).

```bash
vibe feature add <dir>/<slug>.md   # checks each member path and branch, fills in the open PRs
vibe feature ready <slug>          # the human test passed: the pill shows merge
vibe feature archive <slug>        # all member PRs merged; refuses an open one
vibe queue ready --feature <slug>  # each member PR checked, then ready, then feature ready
```

- A member is a `- <repo> <branch>` line (the repo path as `cd <repo> && pwd` prints it; `feature add` refuses a relative path or one with `..`, `.` or `//`) under `## Members` of `features/<slug>.md` ([`templates/FEATURE.md`](../templates/FEATURE.md)). A branch is in one feature at most; the job file has no key.
- A member is one job, a lane, a `SPEC.md` chain, or a PR with no job. Its `SPEC.md` holds only its milestones and a pointer to the feature file.
- At job start the runner adds a `## Feature` block to a member's prompt, once: the file path and the contract rule. A contract change ends the job `blocked: contract …`.
- At publish: a `**Feature:**` line below the TL;DR (siblings as `repo#pr`, else `repo:branch`), the decisions and contract in a `<details>`, the PR URL into the member line. Sibling bodies stay as they are.
- Status and the report show a `Features` group first. Member jobs leave their repo groups; in the report a member job keeps its row only when it needs you. The page shows a feature as one row.
- Count: done members / members. Done: a PR, and no job queued, running or in need of you.
- Pill, first match: `needs you` (a member job held, blocked, failed, timed out or skipped, or done with a failed gate; a member whose last `pr` is `push failed` or `PR not created`; a member with no job and no PR), `running`, `queued`, `your test`, `merge` (`<slug>.ready`).
- No cross-repo gate: the human test in the file is the integration check.

## Research jobs

An open question with a metric, a budget and a backlog of experiments runs as a coordinator job and parallel workers. The coordinator picks the next runs from the last results.
`/enqueue` makes one: route Research. `/fill-queue` proposes up to 3 from each repo's open questions and metric items; a picked one goes through that route.

| Contract | Holds |
| -------- | ----- |
| Coordinator job keys | `research=<slug>` `question=` `usd=` `workers=` (default 3) `better=higher\|lower` `deadline=` |
| Worker job keys | `research=` `hid=` `place=` `idea=` `builds=<hid\|root>` |
| Worker job dir files | `run-result` (the `RESULT` JSON), `cost` (USD), `paste.md` (a slurm worker's steps), `infra` |
| `vibe queue stop --research <slug> [--now]` | drain: no new worker, each run finishes; `--now`: no new run, each place run runs `stop`, `pull`, `down` |
| The repo's `.claude/research/` | `workspace.conf` (`kind=run`, `result=folder`), `Dockerfile`, `run`, `stop`, `job.sbatch` (the slurm job); [workspace contract](workspaces.md) |
| A run | the command `/ws/in/cmd` runs in `/ws/in/repo`; its last output line is `RESULT {"metric": <number>}`; `stop` adds `"partial": true` |
| A run's progress (optional) | `PROGRESS {"done": <n>, "total": <n>, "at": <epoch>, "run": "<name>"}` lines in its output; the last one wins |
| `## Research` in the repo's instruction file | Places, Metric command, Smoke check, Data, Tracker, Cost limit: [`research.md`](../skills/fill-queue/references/research.md) |

- Work order and lab book: `RESEARCH.md` in the worktree ([`templates/RESEARCH.md`](../templates/RESEARCH.md)): question, metric, budget, limits, how a run is made, known facts, backlog, own ideas, ledger, end action.
- Prompt: `job-prompt.md` plus a block. `vibe queue add` appends [`references/research.md`](../skills/fill-queue/references/research.md) to a coordinator (`research=`, no `hid=`); `vibe queue worker` appends [`references/research-worker.md`](../skills/fill-queue/references/research-worker.md).
- The coordinator asks for the baseline run itself (`vibe queue gpu`), then starts up to `workers=` workers at a time. A session ends `queued:` while a worker runs; each worker end wakes it.
- A worker: session 1 writes the code, runs the smoke check and queues one run; session 2 commits `runs/<hid>/row.md`, the ledger row the coordinator checks against `run-result`.
- `vibe queue gpu --place runpod|vast -- <cmd>` runs on a rented place. The workspace folder is the repo's `.claude/research/` (`kind=run`, `result=folder`, `hours=`, `image=`, `commit=`, an executable `run`). The run takes the worktree's HEAD, so the folder and every tracked file must be committed. Each refusal is one error line.
- Secrets and `VAST_*` settings: `~/.config/vibe/workspaces/research-<repo folder>.env`, mode 600, one file per repo. `vibe queue gpu --place` refuses a run when it lacks a `secrets=` name of the conf.
- The runner fetches only the worktree's HEAD (depth 1) to `/ws/in/repo` and writes the command to `/ws/in/cmd`. In instance `research-<id>` it runs `up`, `exec run`, `pull` and `down`, then the follow-up job.
- The run stops 300 s (`VIBE_WS_STOP_SECS`) before the limit of its `hours`. Then the `stop` script runs, then `pull` and `down`.
- `pull` and `down` each stop after 600 s (`VIBE_WS_TICK_SECS`). An instance that is still up then goes down at its limit through `vibe ws tick`.
- After each run the runner writes `run-result`: the JSON of the last `RESULT {` line of the run log, on turing too. With no such line, bad JSON or a metric that is no finite number (`NaN`, `Infinity`), there is no `run-result` and the run failed.
- A failed `price` or `up` writes `infra` with the reason, and the follow-up gets `Exit: infra`. A run whose process died (a reboot) gets `infra` too; its instance goes down at its limit.
- The runner pushes and writes the PR after each session. The review rounds run once, after the last session's `done:`.
- `deadline=YYYY-MM-DD HH:MM` (local time) in the job file: past it `vibe queue gpu` asks for nothing, and the runner queues no run from a session that started past it. The next session ends the job. `vibe queue add` refuses another format.
- The agent adds its own experiments only under the "Own ideas" rules of the file. A pass criterion never changes after its run.
- Kind `gpu` only; no lane, no `SPEC.md` chain.
- `usd=` in the job file gates each place run. Before `up` the runner reads the place's `price` (USD per hour). It refuses the start when spent + `hours` × price is above `usd`, and the follow-up gets `Exit: usd` and the reason. `vibe queue add` refuses a `usd=` that is no number.
- Spent is the sum of `cost` over the live and archived jobs with the same `repo=` and `research=`. A start writes `cost` = `hours` × price, so a running run counts at its full `hours`.
- At the end of a place run, `cost` is price × the time from `up` to `down`. A run on turing costs 0.
- `vibe queue worker <hid> [--place turing|runpod|vast|slurm]`, from inside the coordinator job (`research=`, no `hid=`), queues a worker for item `### <hid> <name>` of the committed `RESEARCH.md`. Its branch `research/<slug>/<hid>` starts at the worktree's HEAD.
- The worker job: the coordinator's `repo=` `model=` `effort=` `timeout=` `research=` `usd=` `deadline=`, then `hid=` `place=` (default `turing`) `idea=` (the item's name) `builds=` (the first word of its `Builds on:` line, else `root`) and `after=`. The runner pushes it and opens no PR.
- Each refusal is one error line, and nothing is queued: past `deadline=`; a stopped research; `workers=` (default 3) workers of the repo's research with a job that has not ended or a slurm run out; no ledger row with the id `baseline`; no such item; a branch git refuses (it exists, or a branch `research/<slug>` does). A rerun takes a new hid.
- A worker end wakes the coordinator, once per worker job (`fan`). The end: the job is final and has no `<id>-gpu` session 2.
- The newest coordinator job with the worker's `repo=` and `research=` decides the wake. Queued: it gets a `## Worker finished` block. `gpu` (it ended `queued:`) or `timeout`: a follow-up job gets the block, and a `gpu` one ends `done`.
- Running, `blocked`, `failed` or `skipped`: the wake waits for its end, `vibe queue answer` or `retry`. `done` or archived: no wake.
- In a job, `vibe queue gpu --place` and `vibe queue worker` only check and ask: `agent/run/`, `agent/workers`. After a `queued:` session the runner takes the run (`place_take`) and queues each worker under the lock `queue/.workers.lock`, as of the session start. A refusal goes to `workers.log`; when each asked worker is refused, the job fails.
- A `place=slurm` worker's session 1 commits `runs/<hid>/job.sbatch` (from the repo's `.claude/research/job.sbatch`), writes `paste.md` and ends `blocked:`. The runner pushes its branch. Until the answer it wakes no coordinator.
- `vibe queue answer <id> '<output>'` on that worker writes the text to `slurm.log` and its last `RESULT` line to `run-result`, then queues session 2 (`<id>-gpu`, `Exit: slurm`). No `RESULT` line: the run failed. A `RESULT {` line that does not parse is refused.
- `vibe queue stop --research <slug>` writes `drain` to each job of the research in the queue; a follow-up job copies it. Drain: `vibe queue worker` refuses, and each run finishes.
- `--now` writes `now`: `vibe queue gpu` refuses too, and each place run ends as at its limit (TERM, `stop`, `pull`, `down`; `run/exit` 124). A place run not up yet ends `stopped`: no `up`, cost 0. A turing run finishes: Cancel GPU run on the page.
- shortcut: the slug alone names the research, so a slug two repos share stops both; add `--repo` when that bites.
- The close runs past `deadline=` and `usd=`: session 2, a slurm answer, a worker's wake and the coordinator's last session. Only `vibe queue gpu`, `vibe queue worker` and the place gate check them.
- shortcut: the runner enforces the deadline and `usd=` only; compute hours on turing and the run count are the agent's ledger. Add a runner check when a job overruns them.

## Research card

A job with `research=<slug>` is in no repo group: the page shows one card per slug. A coordinator has `question=`, a worker `hid=`. The card reads job files, job dir files and a live run's instance dir `workspaces/research-<id>/`, never `RESEARCH.md`.

- Head: question, best metric with its hid (`better=`, a `run-result` without a number is none), USD spent of `usd=` (the `cost` files of the coordinator chain, the workers and their archived jobs; a box that is up counts price × (now − started)), `deadline=`.
- State line: `<state> · <reason> · <run> on <place> · <done> of <total> steps · eta <time> · box until <time>`, empty fields dropped. Status and the report print it too.
- State, first match: `needs you`, `drained` (a `drain` file while a job runs or waits, or nothing runs or waits and the coordinator is not `done`), `on <place>` (a live run), `coding`, `closing`, `thinking` (the coordinator runs), `queued`, `done`.
- Reason: for `needs you` what needs you (`paste <hid>`, `<hid> blocked`, `coordinator blocked`); for `drained`, first match, `stop now`, `stop question`, then from the coordinator's own run and job `smoke failed`, `run at its limit`, `run over usd=`, `deadline passed`, `stopped` (its `stop` file). A job that `vibe queue stop` ended needs no answer.
- Run: the newest live run, else the newest ended one. Its name: the `PROGRESS` line's `run`, else a worker's hid. A live run drops `on <place>`: the state holds it. `box until`: a live run's box limit.
- Steps: the last `PROGRESS` line of the run log, else the last `Step: <n>` before `Average time:` (shortcut: safety-critic's log words). `eta`: a live run only, from the last two `PROGRESS` lines; one line gives none.
- Pill: the state word. Look: `thinking`, `coding`, `closing` → `running`; `on <place>` → `gpu`; `drained` → `held`; `needs you` → `blocked`.
- Worker row: the latest job of its `hid=`. State: `queued`, `coding` (session 1), `running` (the run: status `gpu`), `closing` (session 2: a follow-up job or a `run-result`), `paste`, `infra` (`failed` with an `infra` file), else the job status. A `builds=<hid>` row sits indented below its parent.
- A worker in `paste`: each non-blank line of its `paste.md` is a step (a list marker and a fence line are dropped) with a Copy button. One field posts the RESULT line to `answer` for that worker. A `blocked` worker with no `paste.md` has the `answer` field. The card shows Stop question and Stop now until the question drains or is done. Drained: Stop now while a run lives, Archive once each job has settled. Done: Archive.
- Count: workers `done` / workers; before the first worker, `0 of <workers=> workers`. A failed worker alone does not need you.
- Status and the report: a `Research` group after `Features`, a line (report: a row) per question, `hid · place  state  metric · USD` per worker. A done worker keeps no report row of its own.
- The `no PR` count of the status header skips a done research job with no PR.

## Tool jobs

An outside research tool (`kind=run` under `workspaces/`) does the first part of a job; a session closes its run.
`/enqueue` makes one: route Tool run. Contract: [`docs/workspaces.md`](workspaces.md).

- Keys, input and output files: [Queue job](workspaces.md#queue-job). `place=` defaults to the first of its `places`, `hours=` to its `hours`.
- At start the runner checks the tool's conf, its secrets, `kind=run`, the place and `hours`. A fail ends the job `failed` with the reason, before the worktree.
- The run: instance `<tool>-<id>`, `/ws/in/repo` a clone of the job's worktree. `hours=` limits it; `timeout=` limits the closing session. `gpu=yes` on turing: under the `gpu-queue` lock.
- One `gpu=yes` tool job on turing runs its tool at a time. The next one stays `queued` and takes no slot.
- After the run the runner removes each link from `out/`. No `out/result` → `failed`. An `out/result` of `failed: …` → `failed` with that line, no closing session.
- `result=branch`: the runner fast-forwards the job's branch to `out/branch` of `out/repo.bundle`. No fast-forward, or a commit in agent or git config (`.claude/`, `CLAUDE.md`, `.github/` …) → `failed`.
- `result=folder`: a report job (`output=report`); the files stay in `out/files/`.
- The closing session reads `close.md`: `prompt.md`, then [`tool-run.md`](../skills/fill-queue/references/tool-run.md). It checks the tool's score with the repo's metric command; a tool commit that changes the metric fails the job. Review, gate and PR as for any job.
- `vibe queue stop <id>` during the run: TERM to it, the stop script, then `down`; no closing session.
- `vibe queue steer <id> <text>`: the text to the tool's `steer` script while the run is up; exit 3 there → `not supported`.
- Retry runs the tool again with `in/`; answer closes the same run again; fix, review rounds and GPU follow-ups run no tool.
- The page: one row with a `<tool> · <place>` chip. While the tool runs, the block has a Message to `<tool>` field when the tool's `steer` script is not a bare `exit 3`. Its files: Tool log, then Tool report and Output files after the run.
- shortcut: the run has no memory limit (`MEM_CMD` covers sessions and gates only); add one at the place when a tool runs the machine out of RAM.

## Page words

The page's labels and the raw words that the CLI, the job files and `vibe queue status` keep.
Each state and step has its one-sentence tooltip on the page: `st_tip` and `page_steps` in `bin/vibe`.

| Page word | Raw |
| --- | --- |
| Queued · Running · On the GPU | `queued` · `running` · `gpu` |
| Waits for the GPU | `parked` (a `gpu-queue` run) |
| On hold | `held` (`vibe queue hold`) |
| Has a question · Failed · Ran out of time | `blocked` · `failed` · `timeout` |
| Skipped: (reason) | `skipped` |
| Done · PR #N to review | `done` · `done` with a PR |
| Checks failed (exit N) | gate exit N |
| Verify: (verdict) | `V: fail`, `dirty`, `timeout` |
| push failed, PR not created | the `pr` file |
| Needs you | `needs you` (lane, feature, research) |
| Test it yourself · Ready to merge · No job | `your test` · `merge` · `no job` (feature) |
| Finished · Failed, exit N · Cancelled | a GPU run's exit 0 · exit N · `cancelled` |
| Work · Review N · Verify · Checks · PR · Report | the steps `Agent` · `RN` · `Verify` · `Gate` · `PR` · `Report` |
| N of M items | a lane, feature or research progress (`9/9`) |
| Milestone K of T | a branch of jobs with a `SPEC.md`: K the first open box |
| N of M jobs | a branch of jobs without `lane=` and `SPEC.md` |
| GPU run · `<name>` | an outside `gpu-queue` run `<YYYYMMDD-HHMMSS-n>-<name>` |
| N of M jobs run | running jobs of `slots` |
| Claude usage N%, resets HH:MM | `limit 5h: N%, resets HH:MM` |
| Claude usage limit, resets HH:MM | the `limit` file: no job starts before it |
| GPU busy: `<holder>` | the `gpu-queue` lock holder |
| Runner stopped | the page is older than 2 min |
| PR problems | `triage.md` ([triage](vibe-jobs.md)) |
| Tools that run as a job | `kind=run` tools ([workspaces](workspaces.md)) |
| Runs on | `places=` of `workspace.conf` |
| Report · PR text · Note · Result | `report.md` · `pr.md` · `note` · `result` |
| Checks log · Tool log · Full log | `gate.log` · `tool.log` · `log` |
| Tool report · Output files | `out/report.md` · `out/files/` |

Buttons: [Page actions](#page-actions).

## Page actions

A tap posts to `/queue/api/<route>`; `bin/vibe-web` runs the route's one fixed argv (`ROUTES`). `<arg>` comes from the `data-*` of the nearest `.jacts` or from a field. ✓: a second tap within 4 s.

| Where: button | Route | Command |
| ------------- | ----- | ------- |
| Top bar: Pause / Resume | `pause`, `resume` | `vibe queue pause` / `resume` |
| Settings, Slots or Other setting: Set | `conf` | `vibe queue conf <key=value>`; Slots sends `slots=<n>` |
| Settings, limit reached: Clear usage limit | `unlimit` | `vibe queue unlimit` |
| Settings: Restart queue runner ✓ | `restart` | `systemctl --user restart vibe-queue` |
| Settings, session server: Restart ✓ | `server-restart` | `systemctl --user restart claude-rc@<server>`; one per unit file |
| Settings, session server: Remove ✓ | `server-remove` | `vibe server-remove <server>`: `systemctl --user disable --now`, then the unit symlink goes; a `.service.d/` drop-in stays |
| Recurring: Run | `run` | `vibe job run <repo> <job>` |
| Recurring, stopped job: Reset | `reset` | `vibe job reset <repo> <job>` |
| Recurring, due or not-due job: Skip | `skip` | `vibe job skip <repo> <job>` |
| Recurring, job that skips: Undo | `skip-undo` | `vibe job skip <repo> <job> --undo` |
| Queued job: Start next | `now` | `vibe queue set <id> now=1` |
| Queued job with a review: Skip review | `noreview` | `vibe queue set <id> after=` |
| Queued job: Cancel ✓ | `cancel` | `vibe queue cancel <id>` |
| Running job: Stop ✓ | `stop` | `vibe queue stop <id>` |
| Running tool job: Message to `<tool>`, Send | `steer` | `vibe queue steer <id> <text>` |
| Job on the GPU: Cancel GPU run ✓ | `gpu-cancel` | `gpu-queue cancel <gpu>` |
| Has a question, Failed, Ran out of time, Skipped: Run again | `retry` | `vibe queue retry <id> [<note>]`; the note field is optional, needed for Has a question |
| Same job, not On hold: Put on hold | `hold` | `vibe queue hold <id> <note>`; the same note field, needed |
| Ended job: Archive ✓ | `archive` | `vibe queue archive <id>` |
| Job panel: Activity | `GET job/<id>/activity` | the last 5 agent texts and 5 tool calls of `log`, newest first, as JSON; no `log`: 404 |
| Job panel, Files: a link | `GET job/<id>/<file>` | `report.md`, `pr.md`, `gate.log`, `result`, `note`, `out/report.md` as text; `log`, `tool.log`: the last 64 KB; `out/files`: its file list; a `.md` with `?html` rendered |
| Feature, Test it yourself: Test passed ✓ | `feature-ready` | `vibe queue ready --feature <feature>` |
| Feature, Ready to merge: Archive ✓ | `feature-archive` | `vibe feature archive <feature>` |
| Research card, done: Archive ✓ | `research-archive` | `vibe queue archive --research <research>`: every job of the question, none unless each has ended |
| Research card: Stop question | `research-stop` | `vibe queue stop --research <research>`: no new worker, each run finishes |
| Research card: Stop now ✓ | `research-stop-now` | `vibe queue stop --research <research> --now` |
| Research worker in `paste` or Has a question: Send answer | `answer` | `vibe queue answer <id> <text>` |
| Research worker in `paste`: Copy | none: `page.js` | the step's text to the clipboard |
| Workspaces: Start | `ws-start` | `vibe ws start <name> [--place=<place>] [--hours=<hours>]` |
| Workspaces: Stop ✓ | `ws-stop` | `vibe ws stop <name>` |
| Any write: the output | `GET writes` | `{"writes": <n>, "render": <true or false>}`: the writes that hold or wait for the lock; a render runs or waits |

The output of a write, under the block:

- While it runs: the command as the page sends it (the route and its values), a seconds counter, and `1 write before yours` while another write holds or waits for the lock. The page reads the count again each second.
- The answer: `Done in N s` or `Failed (exit N)`, then the command output. A refused write shows `refused: <error>`.
- No answer, for example a dropped connection: `No answer. The command can still run.`
- The button is off with a verb (`Starting…`, `Archiving…`) while the write runs.
  After the write worked or got no answer, the button stays off until a fetched page shows a change in its card, at most 60 s. A failed or refused write turns it on again.

Not on the page (the CLI has them): merge, single-PR ready or close, the `run-ci` label, prompt edits, tool-job creation, new jobs, fix jobs (a `/fix` comment starts one), triage (an hourly timer runs it), merge order, worktree cleanup, sync, toolkit update.

Add a route or a button:

- Route: one line in `ROUTES` (`bin/vibe-web`). A body arg is a `"{name}"` slot at an arg's end (`claude-rc@{server}`) plus a pattern in `ARGS`. A `"{name?}"` slot drops its arg when the body has no `name`. `TOOLS` maps `vibe` and `gpu-queue` to this checkout's `bin/`.
- Button: `<button data-act="<route>" [data-confirm]>` in a `<div class="jacts" data-<arg>="…">` inside `main` or a panel block. A text arg is a field: `ask` in `bin/vibe`.
- page.js sends each `data-*` of the nearest `.jacts`, then each named field of the button's `.ask`, its `data-pre` (`slots=`) before the value.
  An empty field stops the send, except one with `data-opt` when the button has no `data-need`.
- Order in a group: read-only buttons, write buttons, then `<hr>` and the `data-confirm` buttons (`btn_rows` in `bin/vibe`). A group is a grid of equal cells.
- The CSP runs only `page.js`: no inline `<script>` or `onclick`.
- A `<details>` keeps its open state by its nearest `data-k` or `id` and its place among that node's folds.
- A new page part that the poll swaps needs its path from `body` in `parts` (page.js).
- vibe-web runs each command with `VIBE_WEB=1` and kills it after 120 s (`VIBE_WEB_TIMEOUT`).

## Layout

`~/.local/state/vibe/`

| Path | Holds |
| --- | --- |
| `queue/<id>/job`, `prompt.md` | `repo=` `branch=` `model=` `effort=` `timeout=` `deadline=` `research=` `usd=` `workers=` `hid=` `place=` `idea=` `builds=` `context=` `lane=` `item=` `now=` `follow=` `parent=` `after=` `review=` `review_model=` `verify=` `event=` (the PR comment or review it answers: [triage](vibe-jobs.md)), a tool job's keys ([Queue job](workspaces.md#queue-job)); the job prompt |
| `queue/<id>/status`, `note` | `queued` `running` `gpu` `done` `blocked` `failed` `timeout` `skipped`; why |
| `queue/<id>/worktree`, `base`, `log`, `pr`, `milestones` | worktree, base branch, agent stream-json, PR URL, open `SPEC.md` milestones at start |
| `queue/<id>/agent/` | `$VIBE_JOB_DIR`, the one job-state dir the job sandbox may write; copies of `job`, `base`, `lane-pr.md`, `worktree`, `drain`, fresh each session; the asks `run/` and `workers` ([research](#research-jobs)); a tool job's closing session also gets `in/`, `out/`, `tool.log`, `tool-exit` |
| `queue/<id>/result`, `pr.md`, `report.md` | the agent's `done:`/`queued:`/`blocked:`/`failed:` line; PR title + body (`templates/job-pr.md`); findings (`templates/job-report.md`). The runner copies them, `verdicts`, `gpu-cmd` and `paste.md` from `agent/` after each session, plain files only |
| `queue/<id>/gate`, `gate.log` | the gate's exit code; `$ <command>`, then its output |
| `queue/<id>/held`, `gpu-cmd`, `gpu-job` | `vibe queue hold` note; the run `vibe queue gpu` asked for (NUL-ended args); the `gpu-queue` job id |
| `queue/<id>/session` | the agent's `session_id`; a timeout, a usage-limit retry and a review fix resume it |
| `queue/<id>/agent-pid`, `stop` | the running agent's pid; `vibe queue stop` asked to stop it |
| `queue/<id>/requeued` | time the runner queued the job again after its process died; a second death ends it `failed` |
| `queue/<id>-review<n>/` | review round `n`: `review.json` (reviewer output), `findings`, `verdicts` (`<n>=fixed <sha>` / `rejected <reason>` / `open`), `rounds`, `round-details.md` |
| `queue/<id>-verify/` | the verify step: `verify.json` (checker output), `verify` (the `V:` verdict), `agent/evidence/` (screenshots, logs) |
| `queue/<id>/run/` | a place run (`vibe queue gpu --place`): `place`, `commit`, `cmd` (from `agent/run/`); the runner adds `pid`, `price` (USD per hour), `started` and `limit` (epochs, after `up`), `log` (at the end; while the run goes: `workspaces/research-<id>/log`), `exit` |
| `queue/<id>/run-result`, `infra`, `cost`, `out/` | [research](#research-jobs): the JSON of the last `RESULT` line; why `price` or `up` failed; the USD of the run; the pulled `/ws/out` |
| `queue/<id>/drain`, `paste.md`, `slurm.log` | [research](#research-jobs): `drain` or `now` (`vibe queue stop --research`); a slurm worker's steps; the output its answer gave |
| `queue/<id>/workers.log` | [research](#research-jobs) coordinator: the output of each worker the runner queued or refused |
| `queue/<id>/fan` | [research](#research-jobs) worker: the coordinator job its end woke, `follow-up <id>-gpu`, `no wake: <id> done\|archived`, or `no coordinator` |
| `queue/<id>/close.md` | [tool job](#tool-jobs): the closing prompt; its other files: [Queue job](workspaces.md#queue-job) |
| `workspaces/<instance>/`, `workspaces/tick.log` | a tool's state ([workspaces](workspaces.md#state-on-turing)); the log of `vibe ws tick` |
| `queue/<id>/start`, `side`, `lane-pr.md` | lane job: branch tip at start; `<branch>-<item>` after it left the lane; the lane PR so far |
| `archive/<YYYY-MM>/<id>/`, `features/` | reviewed jobs (`vibe queue archive`); archived features (`vibe feature archive`) |
| `features/<slug>.md`, `<slug>.ready` | a feature (`vibe feature add`); the human test passed (`vibe feature ready`) |
| `web/index.html`, `page.js`, `fonts/` | the queue page, rewritten each runner pass (`templates/queue-page.*`); its CSP runs only `page.js` |
| `paused` | `vibe queue pause` |
| `roadmap/<repo path, / as %>` | the origin commit `vibe queue roadmap` listed; `new --line` reads it |
| `actions.log` | page writes: time, login, command, exit code (`bin/vibe-web`) |
| `limit` | reset epoch of the last usage limit; no starts before it |

The job finds its dir in `$VIBE_JOB_DIR` (`queue/<id>/agent/`). Job settings:
[`claude/vibe-job-settings.json`](../claude/vibe-job-settings.json) — no
unsandboxed retry, no push to `main`/`master`, no `gh pr merge`. File tools
(Write, Edit, NotebookEdit) are fenced to the worktree and the job dir by
`blockWritesOutsideWorkingDirectories`; the runners pass `--add-dir "$VIBE_JOB_DIR"`.
The sandbox may not write `queue/` or `~/.local/state/gpu-queue`: the runner runs git in `worktree` and TERMs `agent-pid` unsandboxed.

GPU jobs: the agent commits, then `vibe queue gpu -- <cmd>` asks for the run (`agent/gpu-cmd`).
After the session ends `queued:`, the runner queues it in [`bin/gpu-queue`](../bin/gpu-queue), cwd the worktree (status `gpu`).
After the run, job `<id>-gpu` continues on the same branch with the exit code and log.
A `gpu-queue` run that no job's `gpu-job` names (a manual `submit`) shows in a `GPU` block of `vibe queue status`: elapsed time, dir, last log line, command, `then`, wandb link.
The block adds the 3 latest `finished/` runs (exit code, end time) and the `held/` and `parked/` runs (`gpu-queue` does not write those dirs yet); only running and queued runs count in "on the GPU".
On the page each such run is a row in Running, Queued or On hold, and the 3 latest finished runs are rows in Done.

```bash
gpu-queue status                      # queued, running, finished (exit code)
gpu-queue lock -- python train.py     # a manual run that waits for the queue's GPU job
gpu-queue cancel <id>                 # drop a queued run, TERM a running one; the job ends failed, no <id>-gpu
```

## Cost per job

The PR footer line and the report row end with the job's size, from the last `result` event of `queue/<id>/log`:

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
- The footer is written at publish: a job still running then has no `result` event, so the report row can show a share the footer lacks.
- The report header ends with `limit 5h: 46%, resets 14:30`: the newest `rate_limit_event` in any job log.
- A final job keeps its share in `queue/<id>/limit-pct` once each job it overlaps is final. Delete the file to compute the share again.

## What breaks it

- Every job `failed` at once, log mentions login → the claude.ai login expired; run `/login`, or, after an update, `-p` defaults to `--bare`, which does not read the login: give `claude/vibe-job.sh` the opt-out.
- Every job `failed`, log says the sandbox cannot start → AppArmor blocks bwrap; add its profile (code.claude.com/docs/en/sandboxing).
- A job `failed`, note `agent killed (SIGKILL)` → past its memory cap, or oomd under memory pressure; raise `memory_max=` or lower `slots=`, then restart the runner.
- `no systemd user manager` in the runner log → `systemd-run --user --scope true` fails there; jobs run uncapped in the service's cgroup, where one oomd kill takes them all.
- A research job ended `failed` or `timeout` between two runs → `vibe queue retry <id>`; the new session reads `RESEARCH.md` and `HANDOFF.md` and goes on.
- A job `failed`, note `job process died twice` → the process died on both runs (reboot, oomd); read `runner.log` and `log`, then queue it again.
- A job `skipped`, note `uncommitted changes` → that worktree is dirty; commit or clean it.
- Your `pre-push` hook does not run on the runner's push → move a test into `.vibe-jobs/gate`. A push that adds or changes an LFS-tracked file: the runner and `vibe sync` refuse it (`git-lfs: push by hand`) → push the branch yourself.
- `vibe queue run` started inside a sandboxed session → its jobs inherit that sandbox; use the service.
- Another tool uses the GPU → wrap it: `gpu-queue lock -- <cmd>`.
- The page shows `Runner stopped` → the runner stopped, or runs old code after an update: `systemctl --user restart vibe-queue` (jobs keep running).
- `/queue` returns 404 → no serve path yet; step 3. `401 ... must be root` → run it with `sudo`.
- No buttons on the page → `vibe-web.service` down, no `/queue/api` serve path, or `web_login` is not your login: `journalctl --user -u vibe-web`.
- `no server configured` or `the queue runs on the server` → this machine is a client; step 2, or `ssh <host>`.
- `vibe queue steer` prints `takes no steer now` → the session started before `steer=1`, or its first turn ended; `steer=1` acts from the next session on.
- `gh failed` in the sweep → the sandbox hides gh's token; run `sweep.sh` unsandboxed.
