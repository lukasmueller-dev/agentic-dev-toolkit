# agentic-dev-toolkit

Personal tooling for agentic development on one always-on workstation, driven
from the Claude app through one Remote Control server per repo
([docs](docs/remote-sessions.md)). Installed by symlink, so `git pull` updates
it in place.
Inspired by [this video](https://www.youtube.com/watch?v=trg1FRbpnys).

```bash
git clone <this-repo-url> ~/github/agentic-dev-toolkit
cd ~/github/agentic-dev-toolkit && ./install.sh
./install.sh doctor
```

## What's in it

| Component | What it is |
| --- | --- |
| [`bin/vibe`](bin/vibe) | One worktree per task in VS Code; `sync` carries it between machines. [Docs](docs/remote-sessions.md) |
| [`bin/plug`](bin/plug) | Vendors external skills into `vendor/skills/`, pinned in `plugins.lock`. [Docs](docs/vendoring-external-skills.md) |
| [`bin/skill-lint`](bin/skill-lint) | Lints `SKILL.md` files. [Docs](docs/skill-lint.md) |
| [`skills/`](skills/) | Agent Skills (open `SKILL.md` format, not agent-specific) |
| [`templates/`](templates/) | The documents the tools emit — one copy each |
| [`memory/GLOBAL.md`](memory/GLOBAL.md) | Global memory for every agent: where information goes, handoff discipline. [README](memory/README.md) |
| [`claude/`](claude/) | Claude Code config: settings baseline (merged, not symlinked), `CLAUDE.md`, hooks, the Remote Control server unit |
| [`.claude-plugin/`](.claude-plugin/) | The same skills and hooks as a Claude Code plugin, for sessions with no `$HOME`. [Docs](docs/plugin.md) |

### Skills

| Skill | Does |
| --- | --- |
| [`project-status-scaffold`](skills/project-status-scaffold/) | Keeps `HANDOFF.md`, `PROJECT_STATUS.md`, `PROJECT_ROADMAP.md` current across sessions |
| [`add-roadmap-item`](skills/add-roadmap-item/) | Turns a discussed idea into one roadmap item: task + done-when |
| [`handoff-brief`](skills/handoff-brief/) | Distills a discussion into a `HANDOFF.md` on its own task branch |
| [`codebase-health`](skills/codebase-health/) | Duplication, complexity, drifted docs — then fixes only what you approve |
| [`codebase-review`](skills/codebase-review/) | Stages an independent review round for a fresh session |
| [`codebase-map`](skills/codebase-map/) | Maps an unfamiliar repo into `docs/CODEBASE_MAP.md`, including how to get it running |
| [`research-experiment-setup`](skills/research-experiment-setup/) | Makes every run of a research project recorded, comparable and reported: 10 decision cards |
| [`research-hardware-trial`](skills/research-hardware-trial/) | First hardware runs of a trained policy, through fixed safety gates |
| [`implement-test-suite`](skills/implement-test-suite/) | Stands up or extends a test suite, plan-first |
| [`commit-push-pr`](skills/commit-push-pr/) | Stage, commit, push, open a PR |
| [`sync-with-main`](skills/sync-with-main/) | Rebases a topic branch onto a default branch that moved |
| [`worktree-cleanup`](skills/worktree-cleanup/) | Removes worktrees (and their branches) whose work has landed, after you approve the list |

Vendored: `grilling`, `grill-me`, and four academic-writing skills
([docs](docs/academic-writing.md)). New skill: copy
[`skills/_template/`](skills/_template/SKILL.md).

## Installing

```bash
./install.sh                 # everything
./install.sh --dry           # show what would happen
./install.sh bin skills      # targets: all bin skills claude codex gemini
./install.sh doctor          # verify, report drift
./install.sh --uninstall     # remove only the symlinks this repo owns
claude --plugin-dir ~/github/agentic-dev-toolkit   # no $HOME: load as a plugin
```

- Never deletes a real file: it moves to `~/.agentic-dev-toolkit-backups/<timestamp>/`.
- Prunes its own dangling symlinks (a renamed skill) on every run.
- Merges `claude/settings.json` with `jq`; your `model`, `effortLevel` and
  permission rules stay.

After installing:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc   # ~/.bashrc under bash
```

Then start a server per repo: [docs/remote-sessions.md](docs/remote-sessions.md).

## Docs

- [remote sessions](docs/remote-sessions.md) · [artifact architecture](docs/artifact-architecture.md)
  · [skill quality](docs/skill-quality.md) · [skill-lint](docs/skill-lint.md)
- [vendoring](docs/vendoring-external-skills.md) · [academic writing](docs/academic-writing.md)
  · [plugin](docs/plugin.md) · [SOTA digest](docs/sota-watch.md)
  · [research skills](docs/research-skills.md)
- [CLAUDE.md](CLAUDE.md) — conventions for agents working *on* this repo

## Requirements

- Hard: `git`, `bash` (3.2+, BSD or GNU userland).
- `jq` for the settings merge and hooks; `tmux` and systemd for the
  Remote Control servers; `gh` (optional) for PRs.
- Sandboxed Bash on Linux: `bubblewrap` and `socat`; without them commands run
  unsandboxed under the normal permission rules.

## License

[MIT](LICENSE)
