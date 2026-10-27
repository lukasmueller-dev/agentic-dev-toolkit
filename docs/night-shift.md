# Night shift

Evening: `/night-shift` plans unattended jobs across the active repos; after
approval, `vibe night` runs each as a headless agent in its own worktree and
opens a draft PR. Skill: [`skills/night-shift/`](../skills/night-shift/SKILL.md).
Scheduled jobs ride the same runner: `docs/recurring-jobs.md`.

| When | Skill | Does |
| --- | --- | --- |
| Morning | [`/check-in`](../skills/check-in/SKILL.md) | works the briefing: merge, answer and requeue, take into a day session, close |
| Evening | [`/shutdown`](../skills/shutdown/SKILL.md) | pushes and hands off every worktree, then runs `/night-shift` |

## Requirements

- `tmux`, `gh` logged in, `timeout` (coreutils).
- The repos trusted once (`docs/remote-sessions.md` step 1).
- A sandbox that starts: `bwrap --ro-bind / / --unshare-net true` exits 0.
  Night jobs exit instead of running unsandboxed (`failIfUnavailable`).

## 1. List the active repos

```bash
mkdir -p ~/.config/night-shift
printf '%s\n' thesis pncbf humanoid_bridge >~/.config/night-shift/repos   # highest rank first
```

## 2. Plan and start

```text
/night-shift            # in a session; approve the table it shows
```

It writes the night dir and runs `vibe night start --claude <dir>`.

## 3. Install the morning briefing

Server machine only (`~/.config/vibe/role` holds `server`).

```bash
systemctl --user link ~/.claude/systemd/night-shift-report.service ~/.claude/systemd/night-shift-report.timer
systemctl --user enable --now night-shift-report.timer
echo ~/notes/_inbox/agent-jobs-briefings >~/.config/night-shift/briefing-dir   # optional: a copy for your notes
```

At 07:00: `vibe night report --claude --new` writes
`~/.local/state/night-shift/briefings/<date>.md` over every night active in
the last 24 h (the planned night and the recurring jobs' night), copies it to
the briefing dir, and opens a Remote Control session `briefing <date>` that
pushes the summary to the phone.

## 4. Verify

```bash
vibe night status       # latest night: one line per job
tmux -L night-shift attach -t night
vibe night report --claude    # today's briefing now; the session replaces the last one
systemctl --user list-timers night-shift-report.timer
```

## Layout

`~/.local/state/night-shift/<date>/jobs/<NN-branch>/`

| File | Written by | Holds |
| --- | --- | --- |
| `job`, `prompt.md` | skill | `repo=`, `branch=`, `model=`; the job prompt |
| `status`, `note` | runner | `queued` `running` `gpu` `done` `blocked` `failed` `timeout` `skipped`; why |
| `worktree`, `base`, `log`, `pr` | runner | worktree path, base branch, agent stream-json, PR URL |
| `result`, `pr.md`, `report.md` | agent | `done:`/`queued:`/`blocked:`/`failed:` line; PR title + body (`templates/job-pr.md`); findings outside the diff (`templates/job-report.md`) |
| `gpu-job` | `vibe night gpu` | the `gpu-queue` job id |
| `briefings/<date>.md` (under `night-shift/`) | `vibe night report` | the day's briefing: counts, rows ranked Needs you → PR ready → Done with links, next action of each unfinished job |

Runner: at most `--jobs` (4) agents at once, none started after `--until`
(06:30), each stopped after `--timeout` (3h). It pushes the branch and opens a
draft PR only when the job committed; the agent itself never pushes. Every PR
it opens carries the label `agent`; a PR open on the branch already gets its
body replaced instead.

GPU jobs: the agent commits, then `vibe night gpu -- <cmd>` queues the run in
[`bin/gpu-queue`](../bin/gpu-queue) (status `gpu`). After the run, the queue's
`--then` adds job `<id>-gpu` on the same branch with the exit code and log; the
runner starts it before the deadline. One machine-wide lock:
`~/.local/state/gpu-queue/gpu.lock`.

```bash
gpu-queue status                      # queued, running, finished (exit code)
gpu-queue lock -- python train.py     # a manual run that waits for the night's GPU job
```

Night job settings: [`claude/night-shift-settings.json`](../claude/night-shift-settings.json)
— no unsandboxed retry, no push to `main`/`master`, no `gh pr merge`.

## What breaks it

- Another tool uses the GPU at night → wrap it: `gpu-queue lock -- <cmd>`, or
  `flock ~/.local/state/gpu-queue/gpu.lock <cmd>`.
- A `<id>-gpu` job stays `queued` → its run ended after `--until`; start it: `vibe night start --claude <dir>`.

- Every job `failed` at once, log mentions login → the claude.ai login expired;
  `claude` shows `Your login expires in N days` beforehand — run `/login`.
- A briefing lists one night only → the other night's job files are older than 24 h; name both: `vibe night report <dir> <dir>`.
- No push in the morning → `/config` "Push when Claude decides" is off, or the
  report session is focused in a terminal.
- The report session ignores its prompt → a variadic flag (`--add-dir`) after
  it swallowed the prompt; keep it first in `claude/vibe-night-report.sh`.

- Every job `failed`, log says the sandbox cannot start → Ubuntu's AppArmor
  blocks bwrap; add its profile (code.claude.com/docs/en/sandboxing), sudo once.
- A job `skipped`, note `uncommitted changes` → that worktree is dirty; commit or clean it.
- `a night already runs` → `tmux -L night-shift attach -t night`; wait or kill it.
- `vibe night start` run inside a sandboxed session → jobs inherit that sandbox; start it unsandboxed.
- `gh failed` in the sweep → the sandbox hides gh's token; run `sweep.sh` unsandboxed.
