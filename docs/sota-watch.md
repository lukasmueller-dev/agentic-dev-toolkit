# The SOTA watch

Once a week, unattended, this repo surveys the state of the art in agentic
development and opens a pull request containing a digest and one to three
recommendations. Reviewing that PR is the only manual step; merging it is
the review gate.

**This mechanism is local to this repo.** Nothing in it is installed onto
other machines' `~/.claude` — the skill lives in `.claude/skills/`, not
`skills/`, precisely so `install.sh` never picks it up.

## What a run does

1. `sota-weekly.sh` computes the ISO week (`date -u +%G-W%V`, e.g.
   `2026-W30`) and starts `vibe loop "sota <week>"` — branch and worktree
   `sota-<week>`, off the default branch, on a server inside tmux.
2. Each round the agent is handed
   [`loop-brief.md`](../.claude/skills/sota-digest/loop-brief.md), which
   points it at the [`sota-digest`](../.claude/skills/sota-digest/SKILL.md)
   skill: sweep the sources, diff the findings against
   `PROJECT_ROADMAP.md`, `PROJECT_STATUS.md` and recent digests, write
   `docs/sota/<week>.md`.
3. The stop check is `test -f docs/sota/<week>.md`. The loop commits,
   pushes, and opens the PR.
4. GitHub's own PR-opened email is the notification. There is no other
   channel — deliberately: no mail integration to authenticate, no SMTP to
   run.

The agent never commits, never touches the roadmap, and never edits
anything but its digest file. Those boundaries are stated in both the brief
and the skill, because an unattended run gets no other supervision.

## Enabling it

Two prerequisites on the machine that will run it:

- **It must count as a server.** `vibe` decides that from `$SSH_CONNECTION`
  / `$SSH_TTY`, and cron has neither, so it falls through to the hostname
  check — set `VIBE_SERVER_HOSTNAME` to the machine's own hostname in the
  vibe config file (`~/.config/vibe/config`), not just in a shell profile
  that cron will never read. `vibe where` prints the verdict. Without this
  the loop runs in the foreground of the cron job and dies with it.
- **`gh` must be authenticated non-interactively**, and the agent CLI's
  credentials must be valid, or the run produces a pushed branch with no
  PR. `vibe doctor` checks both.

Then add the cron entry — Mondays at 07:00 local, adjust to taste:

```cron
0 7 * * 1 /path/to/agentic-dev-toolkit/.claude/skills/sota-digest/sota-weekly.sh
```

Point it at the **main checkout**, not a worktree: the script derives the
repo root from its own location and hands it to `vibe`, which creates the
run's worktree itself.

## Running one by hand

```bash
.claude/skills/sota-digest/sota-weekly.sh            # this week
.claude/skills/sota-digest/sota-weekly.sh 2026-W29   # a specific week
```

Identical to what cron does, including the log. Output goes to
`${XDG_STATE_HOME:-~/.local/state}/sota-digest/<week>.log` — the script
redirects its own stdout and stderr there, so a cron job that mails output
mails nothing. The agent's own transcript stays where `vibe loop` puts it,
in the worktree's git dir.

Re-running a week whose worktree still exists **resumes** that loop rather
than starting a second one. That is the intended recovery from a crashed
run: run the script again.

## Reviewing the PR

- **Recommendations are proposals, not decisions.** To accept one, run the
  `add-roadmap-item` skill and promote it into `PROJECT_ROADMAP.md`. To
  reject one, say why in the PR — the next run reads recent digests and the
  status file's decisions, so a recorded rejection stops it coming back.
- **Merge either way.** The digest file is the record of what was surveyed,
  including on a week where nothing was worth acting on. Digests are dated
  files under `docs/sota/`; prune old ones whenever they stop being useful.
- **A still-open PR from last week does not block a new run.** The new PR
  is opened anyway and links the open one — skipping a week silently would
  make the gap indistinguishable from a broken cron entry.

## Tuning what it watches

The source list and search angles are
[`references/sources.md`](../.claude/skills/sota-digest/references/sources.md)
inside the skill. Edit that file; the workflow in `SKILL.md` holds no URLs,
so the list can change without touching the procedure. The bar a
recommendation has to clear lives in `SKILL.md` — raise it if digests start
arriving with three weak items instead of one strong one.
