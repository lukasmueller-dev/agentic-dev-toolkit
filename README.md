# agentic-dev-toolkit

Personal tooling for agentic development across a local Mac and a remote Linux
VPS. One repo, one `install.sh`, synced to both machines with `git pull`.

## Layout

```
bin/                     CLI tools → symlinked to ~/bin/
  vibe                   worktree + tmux + git-sync workflow
skills/                  Claude Code skills → symlinked to ~/.claude/skills/
  project-status-scaffold/   keeps HANDOFF.md + PROJECT_STATUS.md current
settings/                VS Code settings snippets (copy in by hand)
install.sh               symlinks everything; auto-discovers new tools/skills
```

Add a new tool by dropping a file in `bin/`, or a new skill as a folder in
`skills/<name>/` (with its own `SKILL.md`). Re-run `./install.sh` — it picks up
new entries automatically, no edits to the installer needed.

## Install (run on BOTH machines)

```bash
git clone <this-repo-url> ~/git/agentic-dev-toolkit
cd ~/git/agentic-dev-toolkit
./install.sh                     # or ./install.sh --dry to preview
```

`install.sh` symlinks `bin/*` into `~/bin/` and each `skills/*/` into
`~/.claude/skills/`. Because they're symlinks, updating later is just:

```bash
cd ~/git/agentic-dev-toolkit && git pull && ./install.sh
```

Make sure `~/bin` is on your PATH (installer warns if not):

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc   # server; ~/.zshrc on mac
```

On the **server only**, help environment detection with a hostname fallback:

```bash
echo 'export VIBE_SERVER_HOSTNAME="$(hostname)"' >> ~/.bashrc
```

Then wire up the VS Code auto-status terminal — see `settings/`. Mac snippet
goes in User Settings, server snippet in Remote Settings.

## The vibe workflow

- `vibe start <task>` — new branch + worktree under `~/git/worktrees/<repo>/<task>`,
  seeds `HANDOFF.md`, launches the agent (in a persistent tmux session on the
  server, plain locally).
- `vibe status` — environment, worktrees, tmux sessions, open PRs.
- `vibe attach <task>` — re-enter a task's session/worktree.
- `vibe sync` — commit handoff files (own commit) + the rest, then push.
  Aborts on divergence.
- `vibe resume` — fast-forward pull only. Aborts if the tree is dirty or diverged.
- `vibe done <task>` — remove the worktree (branch kept).
- `vibe list` / `vibe where`.

### Switching machines

On the machine you leave:

```bash
# tell the agent to update HANDOFF.md, then:
vibe sync
```

On the machine you arrive at:

```bash
cd <repo> && vibe resume && vibe attach <task>
```

The handoff travels through git — nothing uncommitted crosses machines.

### Seeing sessions from your phone

The agent runs in tmux on the VPS, so it survives disconnects. Two ways in from
mobile:

- **Claude Code Remote Control**: in the running session type `/rc`, then open
  the Claude app → Code tab → find the session by name (or scan the QR shown on
  spacebar). The session stays on the VPS; the phone is just a window into it.
