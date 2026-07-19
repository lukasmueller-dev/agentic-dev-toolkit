# Working on this repo

This is a toolkit, not an application. Its users are agents and a human on two
machines, and everything in it is installed by symlink into `$HOME`. That
shapes every convention below: a mistake here does not fail a test suite, it
quietly changes how every other repo behaves.

For the *personal workflow* this toolkit serves — the Mac/VPS split, handoffs,
`vibe` — see `claude/CLAUDE.md`, which is the global memory this repo installs.
This file is only about changing the toolkit itself.

## Layout contract

| Directory     | Holds                                              | Tool-specific? |
| ------------- | -------------------------------------------------- | -------------- |
| `bin/`        | CLIs any agent or human can run                     | No             |
| `skills/`     | Agent Skills (`SKILL.md` is an open standard)       | No             |
| `templates/`  | Documents the tools emit                            | No             |
| `completions/`| Shell completions for `bin/` tools                  | No             |
| `claude/`     | Claude Code config: settings, hooks, agents, memory | Yes            |
| `codex/`, `gemini/` | Same idea, other agents (placeholders)        | Yes            |
| `vscode/`     | VS Code settings fragments                          | Yes            |
| `tmux/`       | tmux snippet for server sessions                    | Yes            |
| `docs/`       | Narrative docs, one file per topic                  | —              |
| `tests/`      | bats suites                                         | —              |

**The top-level split is the point.** Anything portable stays at the top
level; anything that only makes sense for one agent goes in that agent's
directory. Before adding a file, ask which side it belongs on. A skill that
names Claude Code in its trigger description has been put on the wrong side.

`bin/` and `skills/` must stay where they are — live symlinks in `~/bin` and
`~/.claude/skills` point at those paths.

## Templates live in `templates/`

Any document a tool writes into a user's repo — `HANDOFF.md`,
`PROJECT_STATUS.md` — has exactly one copy, in `templates/`, rendered through
the placeholder contract in `templates/README.md`.

Never embed a document in a heredoc, and never paste one into a `SKILL.md` as
an example. That is precisely how the three divergent copies of `HANDOFF.md`
came about. If a tool needs to emit a document, it reads `templates/`.

Templates must not name a specific CLI, machine, or agent. CI fails the build
if `templates/HANDOFF.md` or `templates/PROJECT_STATUS.md` mentions one.

## Installer auto-discovery contract

`install.sh` rebuilds its link map from the repo on every run. Adding
something should never require editing the installer:

| Add                        | Gets linked to                          |
| -------------------------- | --------------------------------------- |
| a file in `bin/`           | `~/bin/<name>`                          |
| a directory in `skills/`   | `~/.claude/skills/<name>`               |
| a file in `claude/`        | `~/.claude/<name>`                      |
| a script in `claude/hooks/`| nothing new — the directory is linked   |

Rules the installer keeps, which any change must preserve:

- **Idempotent.** A second run creates nothing and reports everything `ok`.
- **Never deletes a real file.** A non-symlink at a managed path is moved to
  `~/.agentic-dev-toolkit-backups/<timestamp>/`.
- **`--uninstall` removes only what this repo owns.** Every symlink is
  resolved first and skipped unless it points back into this checkout.
- **`skills/_*` is skipped.** Claude Code does *not* ignore underscore-prefixed
  skill directories, so the installer is the only thing keeping `_template`
  out of `~/.claude/skills`.
- **`claude/*/` is linked only once it holds more than a README**, so an empty
  `agents/` does not drop a stray README where Claude Code scans.

`vscode/` is the deliberate exception: those files are fragments, merged with
`jq` into settings you already have. Symlinking would replace every unrelated
setting in the file.

## Shell

Every shell file must pass **shellcheck** and be formatted with
**`shfmt -i 2 -ci`**. CI enforces both over every file `shfmt -f .` discovers,
which is by shebang — so `bin/vibe` is covered despite having no extension.

Two constraints that are not optional:

- **bash 3.2.** macOS still ships it. No `mapfile`, no associative arrays, no
  `${var,,}`. Expanding a possibly-empty array under `set -u` aborts, so use
  `"${arr[@]+"${arr[@]}"}"`.
- **BSD *and* GNU userland.** `sed -E`, never `\|` alternation in a BRE — BSD
  sed silently matches nothing. No `readlink -f`. `stat` needs both
  `stat -c %Y` and `stat -f %m`.

Both of these have already caused real bugs. The bats suite runs on macOS in
CI for exactly this reason.

Scripts invoked through a symlink (`bin/*`, skill scripts, hooks) must resolve
their own location by walking the symlink chain — `$0` and `$PWD` both point
somewhere useless. Copy the `script_dir()` helper from `bin/vibe`.

## Authoring a skill

Start from `skills/_template/SKILL.md`; it carries the frontmatter rules and a
pre-commit checklist. The essentials:

- `name` must match the directory, lowercase with single hyphens. CI checks it.
- `description` is the only thing the model sees when choosing a skill: third
  person, what *and* when, most important trigger first.
- Keep the workflow in `SKILL.md` and put everything ecosystem-specific in
  `references/<language>.md`, so adding a language is adding a file. When a
  skill supports one language and its sibling supports two, that is a gap
  worth closing.
- `disable-model-invocation: true` for anything with side effects.

## Claude Code config

`claude/settings.json` is real JSON — no comments, and CI parses it. Two
things about permission rules that are easy to get wrong:

- **`*` spans spaces.** `Bash(git *)` allows `git push --force`. Name
  read-only subcommands individually.
- **A leading `/` in a path rule anchors to the settings file's own
  directory**, not the project. In user settings, `Read(/secrets/**)` protects
  `~/.claude/secrets`, not anything in your repo. Use `**/` patterns.

Hooks run inside a live session. They must exit 0 and stay silent when a
dependency is missing rather than failing — see `claude/hooks/README.md`.

## Testing

`bats tests/` — everything runs in throwaway git repos and a temp `HOME` under
`$BATS_TEST_TMPDIR`. No test may touch the real `~/.claude`, `~/bin`, or
worktree root.

Add a test when you add a guard. The `vibe done` guard, the installer's
ownership check, and every hook's degrade-to-no-op path each have one, because
each protects against silent data loss.

## Before committing

```bash
shfmt -f . | xargs shellcheck     # lint
shfmt -d -i 2 -ci .               # formatting
bats tests/                       # tests
./install.sh doctor               # the live machine still resolves
```

Conventional Commits. The body should say *why* — a commit that fixes a
data-loss bug should explain what was being lost.
