# Vibe queue

One queue, always on. Skills and timers add jobs; `vibe-queue.service` runs
each as a headless agent in its own worktree and opens a draft PR. You review
and refill it whenever you like.

| Skill | Does |
| --- | --- |
| [`/fill-queue`](../skills/fill-queue/SKILL.md) | shows the queue; big work grilled into a `SPEC.md`; sweep, gate, your approval; `vibe queue add` |
| [`/review-jobs`](../skills/review-jobs/SKILL.md) | a fresh briefing; per row ready, requeue, hold, close, ack; archives what it carried out; gives the merge order |
| [`/check-in`](../skills/check-in/SKILL.md) | `/review-jobs`, then `/fill-queue` |
| [`/shutdown`](../skills/shutdown/SKILL.md) | hands off every worktree, then `/fill-queue` |
| 01:00 timer | adds due recurring jobs: [`vibe-jobs.md`](vibe-jobs.md) |

## Requirements

- `gh` logged in, `timeout` (coreutils), systemd user services.
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
night=18:00-07:00
slots_day=2
slots_night=4
heavy=2h
review_rounds=2
review_trivial=20
review_model=sonnet
review_level=high
review_timeout=1h
after=review
```

## 2. Install the runner

Server machine only (`~/.config/vibe/role` holds `server`).

```bash
systemctl --user link ~/.claude/systemd/vibe-queue.service ~/.claude/systemd/gpu-queue.service
systemctl --user enable --now vibe-queue.service gpu-queue.service
```

Every other machine: `echo 'client <host>' > ~/.config/vibe/role` (`<host>` takes `ssh <host>`).
There `vibe queue status|report` and `vibe job list` run on the server; other `queue` and `job` commands stop.

## 3. Verify

```bash
vibe queue status                                   # header, then one line per job by repo
journalctl --user -u vibe-queue -f                 # the runner's log
vibe queue run --claude --drain                     # by hand, without the service: until nothing can start
```

## Rules the runner keeps

- FIFO by id `<YYYYMMDD-HHMMSS>-<repo>-<branch>`; a GPU follow-up `<id>-gpu` sorts right after its job.
- Heavy job: `timeout` > `heavy`. It starts only in the night window, before light jobs; it may run into the day.
- Slots: `slots_day`, `slots_night` agents at once. One job per branch at a time.
- `vibe queue add --now` skips the window. `vibe queue pause`: no new start; running jobs finish.
- Usage limit (a `rejected` `rate_limit_event` in the log): the job goes back to `queued` in its own worktree, nothing pushed; no job starts until the reset. The retry resumes the saved session.
- A job pushes nothing itself; the runner pushes and opens a draft PR (label `agent`) when it committed, or replaces the body of the PR open on the branch.
- Timeout: the job gets one more turn in its saved session (`--max-turns 5`) that commits `HANDOFF.md` and writes `result`. Status stays `timeout`.
- Review: a `done` job with commits ahead of its base queues `<id>-review1` before any push. A fresh read-only session runs `/code-review <review_level> origin/<base>...HEAD`; the job's own session fixes or rejects each finding.
- Round 2 (`<id>-review2`) runs only when round 1 found something and its fix changed a file outside `*.md` or more than `review_trivial` lines. `review_rounds` caps it; what stays open goes to the PR body.
- The last review round pushes and opens the PR. Its body carries one `R<n>:` line per round above `<details>`; findings and verdicts sit inside.
- No `structured_output` → `R<n>: review failed`. A round past `review_timeout` → `R<n>: timeout`. The PR opens either way.
- No review for `queued:`, `blocked`, `failed` or `timeout` jobs, `output=report` jobs, or a job without commits. `after=` empty in `queue.conf` or the job file turns it off.
- A `SPEC.md` job that ticks a milestone and leaves one open queues the next, with the same prompt.
- A restart of the service stops only the runner (`KillMode=process`); running jobs finish and write their own status.

## Layout

`~/.local/state/vibe/`

| Path | Holds |
| --- | --- |
| `queue/<id>/job`, `prompt.md` | `repo=` `branch=` `model=` `effort=` `timeout=` `context=` `now=` `follow=` `after=` `review=` `review_model=`; the job prompt |
| `queue/<id>/status`, `note` | `queued` `running` `gpu` `done` `blocked` `failed` `timeout` `skipped`; why |
| `queue/<id>/worktree`, `base`, `log`, `pr`, `milestones` | worktree, base branch, agent stream-json, PR URL, open `SPEC.md` milestones at start |
| `queue/<id>/result`, `pr.md`, `report.md` | the agent's `done:`/`queued:`/`blocked:`/`failed:` line; PR title + body (`templates/job-pr.md`); findings (`templates/job-report.md`) |
| `queue/<id>/held`, `gpu-job` | `vibe queue hold` note; the `gpu-queue` job id |
| `queue/<id>/session` | the agent's `session_id`; a timeout, a usage-limit retry and a review fix resume it |
| `queue/<id>-review<n>/` | review round `n`: `review.json` (reviewer output), `findings`, `verdicts` (`<n>=fixed <sha>` / `rejected <reason>` / `open`), `rounds`, `round-details.md` |
| `archive/<YYYY-MM>/<id>/` | reviewed jobs (`vibe queue archive`) |
| `briefings/<date>-<HHMM>.md` | `vibe queue report`: header, "Yours", triage lines, per repo Needs you → PR ready → Done, next actions |
| `paused` | `vibe queue pause` |
| `limit` | reset epoch of the last usage limit; no starts before it |

The job finds its dir in `$VIBE_JOB_DIR`. Job settings:
[`claude/vibe-job-settings.json`](../claude/vibe-job-settings.json) — no
unsandboxed retry, no push to `main`/`master`, no `gh pr merge`.

GPU jobs: the agent commits, then `vibe queue gpu -- <cmd>` queues the run in
[`bin/gpu-queue`](../bin/gpu-queue) (status `gpu`). After the run, job
`<id>-gpu` continues on the same branch with the exit code and log.

```bash
gpu-queue status                      # queued, running, finished (exit code)
gpu-queue lock -- python train.py     # a manual run that waits for the queue's GPU job
```

## What breaks it

- A heavy job never starts → it waits for the window; `vibe queue status` shows it. Now: `vibe queue add --now`.
- Every job `failed` at once, log mentions login → the claude.ai login expired; run `/login`.
- Every job `failed`, log says the sandbox cannot start → AppArmor blocks bwrap; add its profile (code.claude.com/docs/en/sandboxing).
- A job `skipped`, note `uncommitted changes` → that worktree is dirty; commit or clean it.
- `vibe queue run` started inside a sandboxed session → its jobs inherit that sandbox; use the service.
- Another tool uses the GPU → wrap it: `gpu-queue lock -- <cmd>`.
- `no server configured` or `the queue runs on the server` → this machine is a client; step 2, or `ssh <host>`.
- `gh failed` in the sweep → the sandbox hides gh's token; run `sweep.sh` unsandboxed.
