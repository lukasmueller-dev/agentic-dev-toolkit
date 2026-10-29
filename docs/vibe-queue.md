# Vibe queue

One queue, always on. Skills and timers add jobs; `vibe-queue.service` runs
each as a headless agent in its own worktree and opens a draft PR. You review
and refill it whenever you like.

| Skill | Does |
| --- | --- |
| [`/fill-queue`](../skills/fill-queue/SKILL.md) | shows the queue; big work grilled into a `SPEC.md`; sweep, gate, your approval; `vibe queue add` |
| [`/enqueue`](../skills/enqueue/SKILL.md) | the one item just discussed: a prompt, or a `SPEC.md` branch for big work; your approval; `vibe queue add` |
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
slots=4
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

## 3. Verify

```bash
vibe queue status                                   # header, then one line per job by repo
vibe queue report --week                            # the briefing + a Sunday section: per repo PRs merged, jobs run, blockers open (7 days)
journalctl --user -u vibe-queue -f                 # the runner's log
vibe queue run --claude --drain                     # by hand, without the service: until nothing can start
```

## Rules the runner keeps

- FIFO by id `<YYYYMMDD-HHMMSS>-<repo>-<branch>`; a GPU follow-up `<id>-gpu` sorts right after its job.
- Slots: `slots` agents at once. One job per branch at a time.
- `vibe queue add --now` starts the job before the other queued jobs. `vibe queue pause`: no new start; running jobs finish.
- Usage limit (a `rejected` `rate_limit_event` in the log): the job goes back to `queued` in its own worktree, nothing pushed; no job starts until the reset. The retry is a new session.
- Gate: after the agent, before the PR, `bash -c` of `.vibe-jobs/gate` from a fresh fetch of `origin/<default>` — never from the job's branch — in the job's worktree, bounded by the job's `timeout`. Exit code and last 20 lines go to the PR body; a non-zero exit puts a `done` job under "Needs you". No gate file: no step.
- A job pushes nothing itself; the runner pushes and opens a draft PR (label `agent`) when it committed, or replaces the body of the PR open on the branch.
- A `SPEC.md` job that ticks a milestone and leaves one open queues the next, with the same prompt.
- A restart of the service stops only the runner (`KillMode=process`); running jobs finish and write their own status.

## Layout

`~/.local/state/vibe/`

| Path | Holds |
| --- | --- |
| `queue/<id>/job`, `prompt.md` | `repo=` `branch=` `model=` `effort=` `timeout=` `context=` `now=` `follow=`; the job prompt |
| `queue/<id>/status`, `note` | `queued` `running` `gpu` `done` `blocked` `failed` `timeout` `skipped`; why |
| `queue/<id>/worktree`, `base`, `log`, `pr`, `milestones` | worktree, base branch, agent stream-json, PR URL, open `SPEC.md` milestones at start |
| `queue/<id>/result`, `pr.md`, `report.md` | the agent's `done:`/`queued:`/`blocked:`/`failed:` line; PR title + body (`templates/job-pr.md`); findings (`templates/job-report.md`) |
| `queue/<id>/gate`, `gate.log` | the gate's exit code; `$ <command>`, then its output |
| `queue/<id>/held`, `gpu-job` | `vibe queue hold` note; the `gpu-queue` job id |
| `archive/<YYYY-MM>/<id>/` | reviewed jobs (`vibe queue archive`) |
| `briefings/<date>-<HHMM>.md` | `vibe queue report`: header (ends with `limit 5h: …`), "Yours", triage lines, per repo Needs you → PR ready → Done, next actions, `--week`: "Week since" section |
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
- A job `skipped`, note `uncommitted changes` → that worktree is dirty; commit or clean it.
- `vibe queue run` started inside a sandboxed session → its jobs inherit that sandbox; use the service.
- Another tool uses the GPU → wrap it: `gpu-queue lock -- <cmd>`.
- `no server configured` or `the queue runs on the server` → this machine is a client; step 2, or `ssh <host>`.
- `gh failed` in the sweep → the sandbox hides gh's token; run `sweep.sh` unsandboxed.
