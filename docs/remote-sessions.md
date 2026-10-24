# Remote sessions

One Claude Code Remote Control server per repo, on the always-on machine, in
worktree mode. Sessions start, run and end from the Claude app or
claude.ai/code. Unit: [`claude/systemd/claude-rc@.service`](../claude/systemd/claude-rc@.service).

## Requirements

- `claude auth login` with a claude.ai subscription — API keys and
  `setup-token` tokens cannot start Remote Control.
- `tmux` and a systemd user session.
- `./install.sh claude` has run, so `~/.claude/systemd/` exists.

## 1. Trust the repo once

```bash
cd ~/github/<repo> && claude    # accept the trust prompt, then /exit
```

## 2. Install the unit

```bash
systemctl --user link ~/.claude/systemd/claude-rc@.service
loginctl enable-linger "$USER"    # servers keep running with nobody logged in
```

## 3. Start a server per repo

```bash
systemctl --user enable --now claude-rc@<repo>
```

Repo outside `~/github`: `systemctl --user edit claude-rc@<repo>` and set
`[Service]` `WorkingDirectory=/path/to/repo`.

## 4. Verify

```bash
systemctl --user status claude-rc@<repo>
tmux -L claude-rc-<repo> attach    # the server's screen; detach: Ctrl-b d
```

The app's new-session picker offers the repo on this machine.

## Task flow

| Step | How |
| --- | --- |
| Start | New session in the app → own worktree `<repo>/.claude/worktrees/<name>`, branch `worktree-<name>` |
| Brief for a later session | `/handoff-brief <task>` → in a new session: `git switch <task>, then begin per HANDOFF.md.` |
| Review round | `/codebase-review` → same start message, branch `fresh-review-<n>` |
| Finish | `/commit-push-pr`, merge; a clean worktree is removed when its session ends |
| Leftovers | `git worktree list`; `git worktree remove <path>` once merged |

## What breaks it

- `Workspace not trusted` on the server screen → step 1, then
  `systemctl --user restart claude-rc@<repo>`.
- Every session of a repo stopped → the server stopped; the unit restarts it
  after 10 s and it brings the sessions back (within about 4 h).
- Servers stop at logout → `loginctl enable-linger "$USER"`.
- No network for about 10 min → the server exits; the unit restarts it.
- `systemctl --user` cannot find `claude` → it is not under `~/.local/bin`;
  set `Environment=PATH=…` in `systemctl --user edit claude-rc@<repo>`.
- `git switch`, `git worktree add` or `git push` refused in a session → the
  sandbox; approve the unsandboxed retry in the app.
