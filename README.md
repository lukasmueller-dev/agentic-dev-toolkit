# agentic-dev-toolkit

Personal tooling for agentic development across as many machines as you work
on — the one in front of you, and any you reach over SSH and want to keep
working after you disconnect. One repo, one `install.sh`, kept in sync on every
machine with `git pull`. Inspired by [this video](https://www.youtube.com/watch?v=trg1FRbpnys).

Installed by symlink, so updating is just pulling — nothing is ever copied into
place and left to drift.

```bash
git clone <this-repo-url> ~/git/agentic-dev-toolkit
cd ~/git/agentic-dev-toolkit && ./install.sh
```

Then `./install.sh doctor` to check it landed.

## What's in it

| Component | What it is |
| --- | --- |
| [`bin/vibe`](bin/vibe) | One branch + worktree + tmux session per task, with `park`/`attach` handoff between machines over git — and `vibe loop` to run a task unattended. [Docs](docs/vibe.md) · [Loops](docs/vibe-loop.md) |
| [`skills/`](skills/) | Agent Skills — portable `SKILL.md`, not Claude Code-specific |
| [`templates/`](templates/) | The documents the tools emit — handoff, loop brief, loop PR body, project status — single source of truth for each |
| [`claude/`](claude/) | Claude Code config: permissions, hooks, statusline, global memory |
| [`completions/`](completions/) | zsh and bash completions for `vibe` |
| [`vscode/`](vscode/) | Terminal profile that opens every window with `vibe status` |
| [`tmux/`](tmux/) | tmux snippet tuned for detached agent sessions |
| [`install.sh`](install.sh) | Install, verify and uninstall, per target |

### Skills

| Skill | Does |
| --- | --- |
| [`project-status-scaffold`](skills/project-status-scaffold/) | Keeps `HANDOFF.md` and `PROJECT_STATUS.md` current across sessions and machines |
| [`codebase-health`](skills/codebase-health/) | Non-behavioral health check — duplication, complexity, drifted docs — then fixes only what you approve |
| [`implement-test-suite`](skills/implement-test-suite/) | Stands up or extends a test suite, plan-first, delivered as a PR |
| [`commit-push-pr`](skills/commit-push-pr/) | Stage, commit, push, open a PR |
| [`loop-brief`](skills/loop-brief/) | Refines a rough idea into an unattended-loop brief on its own task branch, ready to run |
| [`babysit-pr`](skills/babysit-pr/) | Stages an unattended-loop brief that drives a pull request to mergeable — green checks, no unresolved threads. [Docs](docs/babysit-pr.md) |
| [`handoff-brief`](skills/handoff-brief/) | Distills a discussion into a `HANDOFF.md` on its own task branch, ready for a dedicated session |
| [`team-up`](skills/team-up/) | Composes a delegation plan from the subagents already installed — who owns what, in what order |
| [`sync-with-main`](skills/sync-with-main/) | Rebases a topic branch onto a default branch that moved, resolving textual and semantic conflicts |
| [`skill-audit`](skills/skill-audit/) | Grades a repo's skills against the quality criteria in [`docs/skill-quality.md`](docs/skill-quality.md), read-only until fixes are approved |

Skills use the open [Agent Skills](https://agentskills.io) format, so they are
not tied to Claude Code. Start a new one from
[`skills/_template/`](skills/_template/SKILL.md).

### Global memory

[`memory/GLOBAL.md`](memory/GLOBAL.md) is the standing instruction set every
agent gets in every repo: where each kind of information is written, the
local/server split across machines, the handoff discipline. One file, installed
to each agent's global instruction path — `~/.claude/global-memory.md` (imported by
`~/.claude/CLAUDE.md`), `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`. It names
no agent, which is what lets one file serve all three; see
[`memory/README.md`](memory/README.md).

### Claude Code config

| File | Does |
| --- | --- |
| [`claude/settings.json`](claude/settings.json) | Baseline permissions, hook wiring, statusline — *merged* into your real settings, not symlinked |
| [`claude/CLAUDE.md`](claude/CLAUDE.md) | Imports the global memory, then adds the Claude-only response-style rules |
| [`claude/hooks/`](claude/hooks/) | Session-end handoff reminder, [phone notifications](docs/notifications.md), `repo · branch · task` statusline |
| [`claude/agents/`](claude/agents/) | Global subagents: `diff-reviewer`, `test-hardener`, `docs-drift`, `security-sweep` |

`codex/` and `gemini/` hold no config yet — each is a one-symlink target,
taking the shared memory and nothing else. The layout keeps portable things at
the top level so adding a second agent is a directory, not a rewrite.

## Installing

```bash
./install.sh                 # everything
./install.sh --dry           # show what would happen, change nothing
./install.sh bin skills      # just these targets
./install.sh doctor          # verify, report drift
./install.sh --uninstall     # remove only the symlinks this repo owns
```

Targets: `all` (default), `bin`, `skills`, `claude`, `codex`, `gemini`,
`vscode`.

Adding a tool means dropping a file in `bin/`, or a directory in `skills/`.
The installer rebuilds its link map every run — no edits needed.

It will not delete anything you own: a real file at a managed path is moved to
`~/.agentic-dev-toolkit-backups/<timestamp>/` first, and `--uninstall` removes
a symlink only after confirming it points back into this checkout.

The one thing it does remove unasked is its own litter. Rename a skill and the
old symlink stays behind in `~/.claude/skills`, pointing at a directory that no
longer exists — in a directory Claude Code scans. Every run prunes symlinks
that both point into this checkout *and* resolve to nothing, so a rename needs
no manual cleanup on any machine. `--dry` shows them without removing, and
`doctor` reports them.

Two things are merged rather than symlinked, both with `jq` and both backed up
first: `vscode/*.jsonc`, because those are fragments; and
`claude/settings.json`, because Claude Code writes to that file itself — a
symlink would turn every `/model` switch and every "don't ask again" into a
diff in this repo. The versioned baseline covers permissions, sandbox
policy, hooks and the statusline; your `model`, `effortLevel` and
accumulated permission rules are left alone, and the permission and sandbox
arrays are unioned rather than replaced.

### After installing

Put `~/bin` on your PATH:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc    # ~/.bashrc under bash
```

On any machine that should count as a **server** — one you reach over SSH,
where tasks run detached in tmux — help environment detection along:

```bash
echo 'export VIBE_SERVER_HOSTNAME="$(hostname)"' >> ~/.bashrc
```

Each machine names *itself* here, so this scales to any number of them.

For zsh completions, add this above `compinit` in `~/.zshrc`:

```bash
fpath=(~/.zsh/completions $fpath)
```

Optional: [phone notifications](docs/notifications.md), and
`source-file ~/git/agentic-dev-toolkit/tmux/tmux.conf` in `~/.tmux.conf`.

## Docs

- [The vibe workflow](docs/vibe.md) — tasks, machine switching, phone access,
  configuration
- [Phone notifications](docs/notifications.md) — ntfy.sh setup
- [Babysitting a pull request](docs/babysit-pr.md) — staging a loop that drives
  a PR to mergeable
- [The SOTA watch](docs/sota-watch.md) — the weekly unattended digest this repo
  runs on itself
- [Vendoring external skills](docs/vendoring-external-skills.md) — design
  draft, not implemented
- [CLAUDE.md](CLAUDE.md) — conventions for agents working *on* this repo

## Requirements

`git` and `bash` are the only hard requirements. `tmux` is needed on the
server for persistent sessions; `jq` for the VS Code merge and the Claude Code
hooks; `gh` is optional, for PR info in `vibe status`. Sandboxed Bash (part
of the settings baseline) needs `bubblewrap` and `socat` on Linux — without
them Claude Code falls back to unsandboxed commands under the normal
permission rules, so nothing breaks; macOS needs nothing extra.

Everything is bash 3.2 compatible and works on both BSD and GNU userland, so
the same scripts run unchanged on macOS and Linux. CI checks shellcheck,
`shfmt`, and the bats suite on both.

## License

[MIT](LICENSE)
