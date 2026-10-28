# Recurring jobs

A job is a prompt plus a schedule. At 01:00 `vibe job due` adds every due
job to the vibe queue (`docs/vibe-queue.md`); `/review-jobs` shows the
result. Skill: [`skills/recurring-jobs/`](../skills/recurring-jobs/SKILL.md).

## Requirements

- The vibe queue running (`docs/vibe-queue.md`).
- Repos sit under `~/github` (`VIBE_ROOT`). A repo with `.vibe-jobs/*.md` is opted in; `~/.config/vibe/repos` is the fill-queue sweep only.

## 1. Opt a repo in

```bash
vibe job add <repo> codebase-health      # writes <repo>/.vibe-jobs/codebase-health.md
```

Edit the file (keys override the catalogue; the body is repo-specific
instruction), commit it. `/recurring-jobs add <job>` does the same in a session.

## 2. Install the timer

Server machine only (`~/.config/vibe/role` holds `server`).

```bash
systemctl --user link ~/.claude/systemd/vibe-jobs.service ~/.claude/systemd/vibe-jobs.timer
systemctl --user enable --now vibe-jobs.timer
```

## 3. Verify

```bash
vibe job list                            # repo × job: schedule, last run, due / stopped / invalid
vibe job list --all                      # also the catalogue jobs each repo has not opted into
vibe job due --dry                       # what the next 01:00 run queues
vibe job run <repo> <job>                # one job now; then: vibe queue status
systemctl --user list-timers vibe-jobs.timer
```

## Catalogue

| Job | Schedule | Output | Does |
| --- | --- | --- | --- |
| `codebase-health` | weekly, sun | pr, 2h | `codebase-health` unattended: docs-drift fixes as commits, dedup/complexity as roadmap items |
| `stale-state` | weekly, sun | report, 30m | stale `PROJECT_STATUS.md`, roadmap items without a done-when, handoffs and worktrees on merged branches |
| `toolkit-check` | weekly, sat | report, 30m | toolkit repo: `install.sh doctor`, `plug verify`, upstream vendor commits, lint, tests |
| `experiment-hygiene` | weekly, sun | report, 1h | research repo: runs without a record, big unrecorded run dirs, tracker sync |
| `sota-digest` | weekly, sun | pr, 2h | toolkit repo: the week's `docs/sota/<week>.md` by the repo-local `sota-digest` skill |

New entry: copy `skills/recurring-jobs/references/jobs/_template.md`.

## Layout

| Where | Holds |
| --- | --- |
| `skills/recurring-jobs/references/jobs/<job>.md` | catalogue: frontmatter `schedule` `day` `output` `model` `timeout`, then the task |
| `<repo>/.vibe-jobs/<job>.md` | opt-in; frontmatter overrides the same keys; body = repo instructions. No catalogue entry: needs `schedule` and a body |
| `~/.local/state/vibe/jobs/<repo>/<job>/last-run`, `fails` | epoch of the last `done`; failures in a row |
| `~/.local/state/vibe/queue/<id>/` | the queued job (`docs/vibe-queue.md`) |
| `job` | `repo=` `branch=jobs/<job>` `model=` `timeout=` `recurring=<job>` `output=pr\|report` |

Rules the dispatcher keeps:

- Due: `daily` ≥20 h, `weekly` ≥6 d, `monthly` ≥27 d since `last-run`; `day` (`sun`…`sat`) must match today.
- At most `--max` 4 jobs a run, oldest `last-run` first.
- `last-run` is written on `done` only. Two `failed`/`timeout` in a row stop the job: it shows as `stopped`, and lands in the queue once as `skipped` under "Needs you".
- Output `pr` drops to `report` when the repo has 2 open PRs with the `agent` label on `jobs/*` branches and this job's branch is not one of them.
- One branch per job, `jobs/<job>`, reused while its PR is open; the runner replaces the PR body.
- A job's `timeout` over the queue's `heavy` (2h) makes it heavy: it starts only in the night window.

## What breaks it

- `vibe job list` says `invalid: no schedule` → the job is not in the catalogue and the repo file sets no `schedule`.
- `stopped: 2 failures` → read the last job's `log`, then `rm ~/.local/state/vibe/jobs/<repo>/<job>/fails`.
- Every job drops to `report` → two job PRs are open in that repo; merge or close one.
- The timer fired, nothing ran → `~/.config/vibe/role` is not `server`, or `vibe job due --dry` lists nothing, or `vibe-queue.service` is not running.
- `gh` fails inside the dispatcher → the sandbox hides the token; the cap check then counts 0 open PRs.
