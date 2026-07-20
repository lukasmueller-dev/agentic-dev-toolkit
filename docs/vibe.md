# The vibe workflow

`vibe` exists to solve one problem: **I work on the same repos from two
machines, and I want an agent to keep working when I close the laptop.**

- **Mac (local)** — where I usually start. Interactive, no tmux forced.
- **Linux VPS (server)** — reached over SSH. Every task runs in its own
  persistent tmux session, so the agent survives a disconnect.

Everything below follows from that.

## One task, one branch, one worktree

`vibe start <task>` creates a git branch *and* a git worktree for it, under
`$VIBE_WORKTREE_ROOT/<repo>/<task>` (default `~/git/worktrees`):

```bash
cd ~/git/myproject
vibe start "fix login bug"
# branch:   fix-login-bug
# worktree: ~/git/worktrees/myproject/fix-login-bug
# seeds HANDOFF.md, then launches the agent
```

A worktree rather than a branch checkout, because tasks overlap. Two agents on
two branches of one repo need two working directories; switching branches
under a running agent is how you corrupt a session. The task name is slugged
into a branch-safe form, so `"Fix Login Bug"` and `fix-login-bug` are the same
task.

On the **server** this opens a tmux session named `vibe-<repo>-<branch>` and
starts the agent inside it. On the **Mac** it just drops you into the worktree
and launches the agent — no tmux, because nothing needs to survive.

## Commands

| Command                        | Does                                                       |
| ------------------------------ | ---------------------------------------------------------- |
| `vibe start <task>`            | Branch + worktree + `HANDOFF.md`, then launch the agent    |
| `vibe attach <task>`           | Re-enter an existing task's session or worktree            |
| `vibe pickup <task>`           | Fast-forward the task's *own* worktree, then attach        |
| `vibe park [<task>]`           | Refresh `HANDOFF.md` via the agent, then sync              |
| `vibe status`                  | Environment, worktrees, tmux sessions, open PRs            |
| `vibe list`                    | Task names for this repo                                   |
| `vibe sync [<task>]`           | Commit handoff files separately, then the rest, then push  |
| `vibe resume [<task>]`         | Fast-forward pull only                                     |
| `vibe rc <task>`               | Enable Remote Control on a running task (server only)      |
| `vibe done [--force] [<task>]` | Remove the worktree, keeping the branch                    |
| `vibe where`                   | Which environment was detected, and why                    |
| `vibe doctor`                  | Check tools, paths, config, upstream state                 |

`sync`, `resume`, `park` and `done` infer the task from your cwd when you run
them inside its worktree, so no argument is needed there. Pass a task name to
act on that worktree from anywhere else — the main checkout, or another task.

## Switching machines

This is the whole point, and it is two verbs — one to leave, one to arrive.

On the machine you are **leaving**:

```bash
vibe park          # from inside the worktree
vibe park <task>   # or from anywhere else
```

`park` runs the agent once, headlessly, to refresh `HANDOFF.md`, then syncs.
You no longer have to remember to ask the agent to write the handoff before you
sync — that was the step that got skipped.

On the machine you **arrive** at:

```bash
vibe pickup <task>   # works from anywhere, including the main checkout
```

`pickup` fast-forwards the *task's own worktree* and drops you into it.

> **Why `pickup` and not `resume`?** `vibe resume` fast-forwards *the branch you
> are standing on*. Run from a task's worktree that is fine, but run from the
> main checkout — the natural place to land after `cd <repo>` — it would
> fast-forward `main`, not your task, and the earlier "`cd <repo> && vibe resume
> && vibe attach`" advice walked you straight into that. `pickup` takes the task
> name and `git -C`s into the right worktree, so where you are standing never
> matters.

**The handoff travels through git.** Nothing uncommitted crosses machines —
which is exactly why `vibe sync` (and therefore `park`) commits `HANDOFF.md`
and `PROJECT_STATUS.md` as their own `chore: handoff` commit before committing
anything else. The handoff is legible in the log instead of being buried in a
"wip" commit.

If the agent is missing or its headless run fails, `park` warns and syncs the
existing `HANDOFF.md` anyway — a flaky agent never strands your work locally.

Everything here refuses to guess. `sync` aborts if the remote has moved ahead
or the branches have diverged; `pickup` and `resume` only ever fast-forward,
and refuse outright if the working tree is dirty. Divergence is a decision, not
something a sync tool should resolve for you — `vibe resume --rebase` is the one
explicit escape hatch when you have decided.

## Finishing a task

```bash
vibe done "fix login bug"      # removes the worktree, keeps the branch
```

`done` refuses if the worktree has uncommitted changes, or if the branch holds
commits that exist on no remote:

```
vibe: branch 'fix-login-bug' has 2 commit(s) that are on no remote.
  Run 'vibe sync' to push them, or re-run with --force to remove the
  worktree anyway (the branch is kept, so the commits stay reachable).
```

`--force` overrides both checks. The branch is always kept, so even a forced
removal leaves the commits reachable.

## Seeing sessions from your phone

The agent runs in tmux on the VPS, so it survives disconnects. Two ways in:

**Claude Code Remote Control** — makes a running session reachable from the
Claude app → Code tab (pick it by name, or scan the QR shown on spacebar). The
session stays on the VPS; the phone is just a window into it. Three ways to turn
it on, in increasing remoteness:

- In the session itself, type `/rc`.
- From another shell on the server (or over SSH from anywhere):
  ```bash
  vibe rc <task>            # ssh <vps> vibe rc <task> from the Mac
  ```
  `vibe rc` finds the task's tmux session, waits for the agent to look idle
  (polling the pane, not a blind sleep), then sends `/rc` for you. It is a
  no-op on local — there is no persistent session to reach — and says so.
- Have it on from the start: set `VIBE_RC_ON_START=1` (server only) and every
  `vibe start` launches the agent with Remote Control already enabled, so you
  never have to reach for `/rc` at all. This appends Claude Code's
  `--remote-control` flag; leave it at `0` for an agent that lacks one.

**Push notifications** — so you know *when* to look. See
[notifications.md](notifications.md); it is a `Notification` hook that pushes
to ntfy.sh when Claude Code wants your attention.

## Configuration

Everything is configurable, nothing is hardcoded. Precedence: environment
variable > `~/.config/vibe/config` > built-in default.

```bash
mkdir -p ~/.config/vibe
cp templates/vibe.config.example ~/.config/vibe/config
chmod 600 ~/.config/vibe/config
vibe doctor        # validates the file and shows the resulting values
```

| Variable                   | Default           | Purpose                              |
| -------------------------- | ----------------- | ------------------------------------ |
| `VIBE_WORKTREE_ROOT`       | `~/git/worktrees` | Where worktrees are created          |
| `VIBE_AGENT_CMD`           | `claude`          | The agent to launch                  |
| `VIBE_AGENT_HEADLESS_ARGS` | `-p`              | Args that make the agent run one-shot (`vibe park`) |
| `VIBE_TMUX_PREFIX`         | `vibe`            | tmux session name prefix             |
| `VIBE_SERVER_HOSTNAME`     | unset             | Fallback server detection            |
| `VIBE_NTFY_TOPIC`          | unset             | Phone notifications (off when unset) |
| `VIBE_RC_ON_START`         | `0`               | Launch server sessions with Remote Control on |

`VIBE_AGENT_CMD` is why nothing here says "Claude". Point it at any command
and the workflow is unchanged.

## Environment detection

`vibe` treats an SSH session as the server (`$SSH_CONNECTION` or `$SSH_TTY`),
falling back to comparing the hostname against `$VIBE_SERVER_HOSTNAME`.

Set the hostname fallback on the server. Without it, a shell that is *on* the
VPS but not *over SSH* — a cron job, a tmux session started at boot — looks
local, and you get no persistent session:

```bash
echo 'export VIBE_SERVER_HOSTNAME="$(hostname)"' >> ~/.bashrc
```

`vibe where` prints the verdict and the reason, which is the first thing to
check when a command behaves as though it is on the wrong machine.

## tmux on the server

`tmux/tmux.conf` is a snippet tuned for detached agent sessions: deep
scrollback, `aggressive-resize` so a phone client does not squeeze your laptop
view, and session names left alone so `vibe-<repo>-<branch>` stays readable.

It is never symlinked over `~/.tmux.conf`. Source it:

```bash
echo 'source-file ~/git/agentic-dev-toolkit/tmux/tmux.conf' >> ~/.tmux.conf
```

## The VS Code terminal

`vscode/` makes every new integrated terminal open with `vibe status`, so
opening a window tells you what is in flight. `./install.sh vscode` merges it
into your real settings with `jq`, backing the file up first — Mac User
settings, or `~/.vscode-server/data/Machine/settings.json` over SSH.
