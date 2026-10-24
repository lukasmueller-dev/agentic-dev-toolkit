# agentic-dev-toolkit

Personal tooling for agentic development on one workstation, reached at the
keyboard or over SSH. Installed by symlink, so `git pull` updates it in place.
Inspired by [this video](https://www.youtube.com/watch?v=trg1FRbpnys).

```bash
git clone <this-repo-url> ~/git/agentic-dev-toolkit
cd ~/git/agentic-dev-toolkit && ./install.sh
./install.sh doctor
```

## What's in it

| Component | What it is |
| --- | --- |
| [`bin/vibe`](bin/vibe) | One branch + worktree + agent session per task; `vibe status` is the overview. [Docs](docs/vibe.md) |
| [`bin/plug`](bin/plug) | Vendors external skills into `vendor/skills/`, pinned in `plugins.lock`. [Docs](docs/vendoring-external-skills.md) |
| [`bin/skill-lint`](bin/skill-lint) | Lints `SKILL.md` files. [Docs](docs/skill-lint.md) |
| [`skills/`](skills/) | Agent Skills (open `SKILL.md` format, not agent-specific) |
| [`templates/`](templates/) | The documents the tools emit — one copy each |
| [`memory/GLOBAL.md`](memory/GLOBAL.md) | Global memory for every agent: where information goes, handoff discipline. [README](memory/README.md) |
| [`claude/`](claude/) | Claude Code config: settings baseline (merged, not symlinked), `CLAUDE.md`, hooks |
| [`.claude-plugin/`](.claude-plugin/) | The same skills and hooks as a Claude Code plugin, for sessions with no `$HOME`. [Docs](docs/plugin.md) |
| [`completions/`](completions/), [`vscode/`](vscode/), [`tmux/`](tmux/) | `vibe` completions, a terminal profile that opens with `vibe status`, a tmux snippet |

### Skills

| Skill | Does |
| --- | --- |
| [`project-status-scaffold`](skills/project-status-scaffold/) | Keeps `HANDOFF.md`, `PROJECT_STATUS.md`, `PROJECT_ROADMAP.md` current across sessions |
| [`add-roadmap-item`](skills/add-roadmap-item/) | Turns a discussed idea into one roadmap item: task + done-when |
| [`handoff-brief`](skills/handoff-brief/) | Distills a discussion into a `HANDOFF.md` on its own task branch |
| [`handoff-start`](skills/handoff-start/) | The same brief, then starts the session that picks it up |
| [`codebase-health`](skills/codebase-health/) | Duplication, complexity, drifted docs — then fixes only what you approve |
| [`codebase-review`](skills/codebase-review/) | Stages and launches an independent review round in a fresh session |
| [`codebase-map`](skills/codebase-map/) | Maps an unfamiliar repo into `docs/CODEBASE_MAP.md`, including how to get it running |
| [`implement-test-suite`](skills/implement-test-suite/) | Stands up or extends a test suite, plan-first |
| [`commit-push-pr`](skills/commit-push-pr/) | Stage, commit, push, open a PR |
| [`sync-with-main`](skills/sync-with-main/) | Rebases a topic branch onto a default branch that moved |

Vendored: `grilling`, `grill-me`, and four academic-writing skills
([docs](docs/academic-writing.md)). New skill: copy
[`skills/_template/`](skills/_template/SKILL.md).

## Installing

```bash
./install.sh                 # everything
./install.sh --dry           # show what would happen
./install.sh bin skills      # targets: all bin skills claude codex gemini vscode
./install.sh doctor          # verify, report drift
./install.sh --uninstall     # remove only the symlinks this repo owns
claude --plugin-dir ~/git/agentic-dev-toolkit   # no $HOME: load as a plugin
```

- Never deletes a real file: it moves to `~/.agentic-dev-toolkit-backups/<timestamp>/`.
- Prunes its own dangling symlinks (a renamed skill) on every run.
- Merges `vscode/*.jsonc` and `claude/settings.json` with `jq`; your `model`,
  `effortLevel` and permission rules stay.

After installing:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc                       # ~/.bashrc under bash
echo 'fpath=(~/.zsh/completions $fpath)' >> ~/.zshrc                   # above compinit
echo 'source-file ~/git/agentic-dev-toolkit/tmux/tmux.conf' >> ~/.tmux.conf
```

## Docs

- [vibe](docs/vibe.md) · [artifact architecture](docs/artifact-architecture.md)
  · [skill quality](docs/skill-quality.md) · [skill-lint](docs/skill-lint.md)
- [vendoring](docs/vendoring-external-skills.md) · [academic writing](docs/academic-writing.md)
  · [plugin](docs/plugin.md) · [SOTA digest](docs/sota-watch.md)
  · [research skills](docs/research-skills.md)
- [CLAUDE.md](CLAUDE.md) — conventions for agents working *on* this repo

## Requirements

- Hard: `git`, `bash` (3.2+, BSD or GNU userland).
- `tmux` over SSH and for `--no-attach`; `jq` for the merges and hooks; `gh`
  (optional) for PRs in `vibe status`.
- Sandboxed Bash on Linux: `bubblewrap` and `socat`; without them commands run
  unsandboxed under the normal permission rules.

## License

[MIT](LICENSE)
