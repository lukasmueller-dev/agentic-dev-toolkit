# Remote sessions

One Claude Code Remote Control server per repo, on the always-on machine, in
worktree mode. Sessions start, run and end from the Claude app or
claude.ai/code. Unit: [`claude/systemd/claude-rc@.service`](../claude/systemd/claude-rc@.service).
VS Code sessions on any machine: `bin/vibe`, below.

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

Servers machine only — on every other machine the unit skips itself.

```bash
mkdir -p ~/.config/vibe && echo server > ~/.config/vibe/role   # other machines: client <host>
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
vibe status --claude               # every server: state, restarts, since
tmux -L claude-rc-<repo> attach    # the server's screen; detach: Ctrl-b d
```

The app's new-session picker offers the repo on this machine.

## Task flow

| Step | How |
| --- | --- |
| Start | New session in the app → own worktree `<repo>/.claude/worktrees/<name>`, branch `worktree-<name>` |
| Start in VS Code | `vibe start <task>` → worktree `<repo>/.claude/worktrees/<task>`, branch `<task>`, opened in VS Code; prints the open PR; sessions there show as `<repo>-<task>-<two words>` |
| Change machine | `vibe sync` before you leave (`--wip` commits dirty task branches), `vibe start <task>` on the other |
| Brief for a later session | `/handoff-brief <task>` → `vibe start <task>`, or in a new app session: `git switch <task>, then begin per HANDOFF.md.` |
| Finish | `/commit-push-pr`, merge; a clean worktree is removed when its session ends |
| Leftovers | `/worktree-cleanup` — removes merged worktrees and their branches after you approve |
| Update the toolkit | `vibe update-toolkit` — pull (ff-only, clean `main` only), `install.sh`, `doctor`; reloads systemd if the unit changed; on a server restarts `vibe-queue.service` if `bin/vibe` or `skills/_lib/lib.sh` changed (running jobs keep going). `vibe sync` never pulls the toolkit |

`vibe sync [--all]` result per worktree: `pushed`, `pulled`, `ok`, `empty`
(no commits, not pushed), `gone` (upstream deleted, never pushed again —
`/worktree-cleanup` checks for a merged PR), `local` (app session branch `worktree-*`, never
pushed), `behind`/`diverged`/`detached`/`missing` (left
alone), `ahead` (main checkout, never pushed). Note `off main`: the main checkout is
off the default branch — work belongs in a worktree. `--all`: every repo next to
the toolkit (`VIBE_ROOT`). Every `vibe` call warns once when the toolkit
checkout is behind `origin/main` (fetch: every `sync`, else at most every 5 min), off `main`, or dirty.
Fix: `vibe update-toolkit`.

## What breaks it

- `systemctl --user status claude-rc@<repo>` says `condition failed` → no
  `server` in `~/.config/vibe/role`; step 2.
- A VS Code session is named `turing-<words>`, not `<repo>-<task>-<words>` →
  the worktree predates the name file; run `vibe start <task>` once and start a
  new session. Exact name without the two words: `/rename <task>`.

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

## Docker gate in sessions

An interactive session (app or VS Code) runs a repo's Docker test gate
(example: humanoid_bridge `tools/test.sh --docker`) without approval. Only the
gate command leaves the sandbox; the rootful daemon stays. Vibe jobs: last
bullet of "What breaks it".

### Requirements

- `docker` on `PATH`, and your user in the `docker` group.
- The gate passes on the host.

### 1. Commit the repo setting

The sandbox denies agent writes to `<repo>/.claude/settings.json`, so you write
it. Swap in the repo's gate command.

```json
{"permissions": {"allow": ["Bash(tools/test.sh --docker)", "Bash(tools/test.sh --docker --rebuild)"]},
 "sandbox": {"excludedCommands": ["tools/test.sh --docker", "tools/test.sh --docker --rebuild"]}}
```

### 2. Verify

In a new session, the agent runs `tools/test.sh --docker` with no prompt; it
exits 0.

### What breaks it

- `cd`, a redirect, `$(...)` or a `./` prefix changes the call text → the call
  stays sandboxed → `permission denied` on `/var/run/docker.sock`.
- `sandbox.network.allowUnixSockets` is macOS-only; Linux ignores it (the
  seccomp filter blocks `socket(AF_UNIX)`). `allowAllUnixSockets` opens D-Bus
  (`systemd-run --user` → unsandboxed command). Use neither.
- Accepted risk: an agent can edit the excluded script or the Dockerfile;
  Docker then runs that code outside the sandbox with root-equivalent access
  to the host (`docker` group).
- A vibe job ignores this setting (`--settings` with `allowUnsandboxedCommands`
  false makes the sandbox admin-required) and has no unsandboxed retry → commit
  `.vibe-jobs/gate`; the runner runs it unsandboxed after the agent
  ([`docs/vibe-queue.md`](vibe-queue.md)).
