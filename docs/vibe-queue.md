# Vibe queue

One queue, always on. Skills and timers add jobs; `vibe-queue.service` runs
each as a headless agent in its own worktree and opens a draft PR. You review
and refill it whenever you like.

| Skill | Does |
| --- | --- |
| [`/fill-queue`](../skills/fill-queue/SKILL.md) | shows the queue; big work grilled into a `SPEC.md`; sweep, gate, your approval; `vibe queue add` |
| [`/review-jobs`](../skills/review-jobs/SKILL.md) | a fresh briefing; per row merge, requeue, hold, close, ack; archives what it carried out |
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
```

## 2. Install the runner

Server machine only (`~/.config/vibe/role` holds `server`).

```bash
systemctl --user link ~/.claude/systemd/vibe-queue.service ~/.claude/systemd/gpu-queue.service
systemctl --user enable --now vibe-queue.service gpu-queue.service
```

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
- A job pushes nothing itself; the runner pushes and opens a draft PR (label `agent`) when it committed, or replaces the body of the PR open on the branch.
- A `SPEC.md` job that ticks a milestone and leaves one open queues the next, with the same prompt.
- A restart of the service stops only the runner (`KillMode=process`); running jobs finish and write their own status.

## Layout

`~/.local/state/vibe/`

| Path | Holds |
| --- | --- |
| `queue/<id>/job`, `prompt.md` | `repo=` `branch=` `model=` `timeout=` `context=` `now=` `follow=`; the job prompt |
| `queue/<id>/status`, `note` | `queued` `running` `gpu` `done` `blocked` `failed` `timeout` `skipped`; why |
| `queue/<id>/worktree`, `base`, `log`, `pr`, `milestones` | worktree, base branch, agent stream-json, PR URL, open `SPEC.md` milestones at start |
| `queue/<id>/result`, `pr.md`, `report.md` | the agent's `done:`/`queued:`/`blocked:`/`failed:` line; PR title + body (`templates/job-pr.md`); findings (`templates/job-report.md`) |
| `queue/<id>/held`, `gpu-job` | `vibe queue hold` note; the `gpu-queue` job id |
| `archive/<YYYY-MM>/<id>/` | reviewed jobs (`vibe queue archive`) |
| `briefings/<date>-<HHMM>.md` | `vibe queue report`: header, "Yours", per repo Needs you → PR ready → Done, next actions |
| `paused` | `vibe queue pause` |

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
- `gh failed` in the sweep → the sandbox hides gh's token; run `sweep.sh` unsandboxed.
