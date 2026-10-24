# vibe

One task = one git branch + one git worktree + one agent session, under
`$VIBE_WORKTREE_ROOT/<repo>/<task>` (default `~/git/worktrees`). Over SSH each
task runs in its own tmux session `vibe-<repo>-<branch>`, so the agent outlives
the connection. Every worktree carries a `HANDOFF.md` from session to session.

## Commands

| Command | Does |
| --- | --- |
| `vibe start <task> [--no-attach]` | Branch + worktree + `HANDOFF.md`, then launch the agent |
| `vibe attach [--rebase] [<task>]` | Fast-forward when safe, then attach; no task → picker (fzf or menu) |
| `vibe done [--force] [--discard-handoff] [--rm-branch] [<task>...]` | Remove the worktree(s); branch kept unless `--rm-branch` |
| `vibe status [--all]` | Worktrees + sync state + `HANDOFF.md` age, tmux sessions, open PRs |
| `vibe doctor` | Tools, paths, config, environment, upstream |

`vibe help <cmd>` prints one command's full usage. `done` infers the task from
the cwd inside a worktree.

## start

```bash
cd ~/git/myproject
vibe start "fix login bug"   # branch fix-login-bug, ~/git/worktrees/myproject/fix-login-bug
```

- Task names are slugged: `"Fix Login Bug"` = `fix-login-bug`.
- Reuses a local branch, else tracks `origin/<branch>`, else cuts from the main
  checkout's HEAD after a best-effort fast-forward (`VIBE_START_PULL_MAIN=0` off).
- Over SSH: tmux session. At the machine: the agent runs in this terminal.
- `--no-attach`: start the tmux session and return (needs tmux, any machine).
  That session takes its first turn from `HANDOFF.md` by itself; an attached one
  waits for you.
- From a discussion in another session: `handoff-brief` stages the brief,
  `handoff-start` stages it and launches the session.

## attach

- Clean tree, behind upstream → `merge --ff-only`. Dirty, diverged, no
  upstream, fetch fails → one line why, attach anyway. Never refuses.
- `--rebase`: `git pull --rebase` when diverged; a conflict is reported and
  left for you in the session.
- A live tmux session for the task is always joined, never exec'd over.
- Pane back at a shell (agent exited) → the agent is started again;
  `VIBE_AGENT_RESUME_ARGS=--continue` continues the old conversation.
- Pulls to the branch's own upstream, not `main` — use `sync-with-main` for that.

## done

```bash
vibe done "fix login bug"            # removes the worktree, keeps the branch
vibe done task-a task-b              # each in turn; non-zero if any failed
vibe done --rm-branch "fix login bug"
```

Refuses while any of these hold (`--force` overrides all):

| Guard | Clear it with |
| --- | --- |
| Uncommitted changes | commit, or `--force` |
| Commits on no remote | `git push` |
| `HANDOFF.md` carries content | promote it, then `git rm HANDOFF.md` |
| `HANDOFF.md` still on the branch | `git rm HANDOFF.md`, commit, push (`--discard-handoff` skips both handoff guards) |

- Worktree directory already gone: prunes git's record and kills the tmux
  session; no `--force` needed. Nothing left → refuses.
- `--rm-branch` fetches `--prune`, then deletes only if the branch is an
  ancestor of the default branch or its remote branch is gone (squash merge).
  `git branch -d` is not used: it deletes a pushed, unmerged branch.
- Clear a backlog of merged branches:

  ```bash
  git fetch --prune
  git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads |
    awk '$2 == "[gone]" {print $1}' | xargs -r git branch -d
  ```

## status

Dot per worktree: `✗` directory gone · `○` no tmux session · green clean ·
cyan merged (upstream gone) · yellow dirty/unsynced · red diverged. Reads local
refs only, never the network (except `gh pr list`). `--all` scans every repo and
works outside any repo.

## Configuration

Precedence: env var > `~/.config/vibe/config` (plain `KEY=VALUE`) > default.
Template: `templates/vibe.config.example`; `vibe doctor` validates it.

| Variable | Default | Purpose |
| --- | --- | --- |
| `VIBE_WORKTREE_ROOT` | `~/git/worktrees` | Where worktrees go |
| `VIBE_AGENT_CMD` | `claude` | Agent to launch (any command) |
| `VIBE_AGENT_RESUME_ARGS` | unset | Continue the old conversation when `attach` restarts a dead agent |
| `VIBE_TMUX_PREFIX` | `vibe` | tmux session name prefix |
| `VIBE_START_PULL_MAIN` | `1` | Fast-forward the main checkout before cutting a new branch |
| `VIBE_REMOTE_CONTROL` | `0` | `1`: start the agent with `--remote-control <tmux session>` (Claude Code) |

## tmux and VS Code

```bash
echo 'source-file ~/git/agentic-dev-toolkit/tmux/tmux.conf' >> ~/.tmux.conf
./install.sh vscode   # new integrated terminals open with 'vibe status'
```

## Remote Control (Claude app, claude.ai/code)

```bash
# ~/.config/vibe/config
VIBE_REMOTE_CONTROL=1
VIBE_AGENT_RESUME_ARGS=--continue
```

- The app only shows the `claude` process in the tmux pane; tmux keeps it alive.
- Session gone from the app → `vibe attach <task>` over SSH; a dead agent resumes.
- Agent alive, link dropped → `/remote-control` in the session reconnects it.
- Host offline about 10 min, or asleep → the agent exits; keep the host awake.

## What breaks it

- A session over SSH without tmux installed → `vibe doctor` fails on it.
- `vibe` started from inside tmux → `attach` switches the client instead of
  nesting.
