# Working on this repo

This is a toolkit, not an application. Its users are agents and a human across
several machines, and everything in it is installed by symlink into `$HOME`. That
shapes every convention below: a mistake here does not fail a test suite, it
quietly changes how every other repo behaves.

For the *personal workflow* this toolkit serves — the local/server split across
machines, handoffs, `vibe` — see `memory/GLOBAL.md`, the global memory this repo installs into
every agent. This file is only about changing the toolkit itself.

## Layout contract

| Directory     | Holds                                              | Tool-specific? |
| ------------- | -------------------------------------------------- | -------------- |
| `bin/`        | CLIs any agent or human can run                     | No             |
| `skills/`     | Agent Skills (`SKILL.md` is an open standard)       | No             |
| `templates/`  | Documents the tools emit                            | No             |
| `completions/`| Shell completions for `bin/` tools                  | No             |
| `memory/`     | Global memory installed into every agent            | No             |
| `claude/`     | Claude Code config: settings, hooks, agents, response style | Yes     |
| `codex/`, `gemini/` | Same idea, other agents (no config yet)       | Yes            |
| `vscode/`     | VS Code settings fragments                          | Yes            |
| `tmux/`       | tmux snippet for server sessions                    | Yes            |
| `docs/`       | Narrative docs, one file per topic                  | —              |
| `tests/`      | bats suites                                         | —              |
| `.githooks/`  | Git hooks for developing *this* repo (not installed)| —              |

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
if `templates/HANDOFF.md`, `templates/LOOP.md`, `templates/LOOP_PR.md`, or
`templates/PROJECT_STATUS.md` mentions one.

## Global memory lives in `memory/`

`memory/GLOBAL.md` is installed to three different paths, one per agent, so it
must not name any of them — CI and `tests/install.bats` both check. Anything
agent-coupled (response style, model choice, tool-use habits) goes in that
agent's directory instead.

Claude Code reads one global memory file, so `claude/CLAUDE.md` is what gets
symlinked to `~/.claude/CLAUDE.md` and reaches the shared half through an
`@~/.claude/global-memory.md` import on its first line. Delete that line and
Claude Code silently loses the workflow memory while every symlink still
reports `ok`; `./install.sh doctor` fails on it for that reason. The other two
agents symlink `memory/GLOBAL.md` directly.

## Installer auto-discovery contract

`install.sh` rebuilds its link map from the repo on every run. Adding
something should never require editing the installer:

| Add                        | Gets linked to                          |
| -------------------------- | --------------------------------------- |
| a file in `bin/`           | `~/bin/<name>`                          |
| a directory in `skills/`   | `~/.claude/skills/<name>`               |
| a file in `claude/`        | `~/.claude/<name>`                      |
| a script in `claude/hooks/`| nothing new — the directory is linked   |
| a file in `codex/`, `gemini/` | `~/.codex/<name>`, `~/.gemini/<name>` |

`memory/GLOBAL.md` is the one exception: each agent reads its global
instructions from a different hard-coded path, so that fan-out is spelled out
in `build_map` rather than derived from a naming convention. A config file the
agent's own CLI writes to (`codex/config.toml`, `gemini/settings.json`) is
skipped for the same reason `claude/settings.json` is — see below.

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

### The two files that are merged, not symlinked

`vscode/*.jsonc` and `claude/settings.json` are both merged with `jq` into
files you already have, because symlinking either one would be wrong:

- **`vscode/*.jsonc`** are *fragments*. Symlinking would replace every
  unrelated setting in your VS Code config.
- **`claude/settings.json`** is written by Claude Code itself. `/model`
  rewrites `model`, "yes, don't ask again" appends to `permissions.allow`, and
  feature flags appear unprompted. As a symlink, every one of those becomes a
  git diff in this repo and syncs to every other machine.

So the repo holds a **baseline** — permissions, sandbox policy, hooks,
statusLine — and the installer merges it into the live file. Two rules
follow:

1. **Runtime state stays out of the baseline.** `model`, `effortLevel`, and
   feature flags are deliberately absent, which is what stops the merge
   clobbering the live values. Do not add them back.
2. **Permission and sandbox arrays are unioned, not replaced.** `jq`'s `*`
   replaces arrays wholesale, which would discard every rule accumulated
   through "don't ask again" and every sandbox domain or exclusion added by
   hand. `claude_settings_merged()` unions and dedupes them instead.

Merging must be idempotent in both directions: creating the file from scratch
and merging into an existing one produce byte-identical output, so a second
run reports `already applied` and leaves no backup. Creating by copying broke
this once — the copy's arrays were unsorted while the merge sorts them.

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
  `stat -c %Y` and `stat -f %m`. `tr` is in the same bucket: replacing an
  ASCII character with a multi-byte one (e.g. `tr ' ' '─'`) has been observed
  producing mangled bytes even under `LANG=C.UTF-8` — build strings like that
  by slicing a literal constant (`"${bank:0:n}"`) instead of piping through
  `tr`.

The version skew cuts the other way too: `${var//pat/rep}` is not literal
about `&` on bash ≥ 5.2, where the default-on `patsub_replacement` expands an
unescaped `&` in *rep* to whatever *pat* matched. Escaping is not portable —
under 3.2 the backslash survives into the output — so unset the option around
the substitution instead, guarding both halves
(`shopt -u patsub_replacement 2>/dev/null || true`) because 3.2 exits non-zero
on an option it does not know. `render_template` in `bin/vibe` and
`skills/_lib/vibe-lib.sh` does this; note that CI's macOS leg cannot catch the
bug, only the Linux one.

Both of these have already caused real bugs. The bats suite runs on macOS in
CI for exactly this reason.

**A `set -e` trap that isn't bash-3.2-specific but bites in this style of
script:** `[[ cond ]] && cmd` and `((cond)) && cmd` are safe as bare
statements or as the last line of a `for`/`while` body — the `&&`-list
exemption covers them. They stop being safe the moment they're the *last
statement of a function*, because the function's own exit status becomes
that command's, and the function call itself (`myfunc`) is an ordinary
simple command with no exemption. Use `if cond; then cmd; fi` for anything
that can end up as a function's tail statement.

**The subshell sibling of that trap:** running a function as a tested
condition — `if (myfunc); then …` or `(myfunc) || failed=1` — switches
errexit off through the *whole* subshell, not just at the call site. Every
non-`die` failure inside then falls through to the next line, so a command
whose failure must stop the function needs its own `|| die` when the
function can be called this way. This produced a real false success:
multi-task `vibe done` printed "removed worktree" and exited 0 after git
refused the removal.

**The `pipefail` sibling of that trap, which has bitten three times here:**
`x="$(cmd | … | head -1)"`. `head` closes the pipe as soon as it has its line,
so the producer is still writing and dies of SIGPIPE (141) — and under
`set -o pipefail` that 141, not `head`'s success, becomes the assignment's
status, which `set -e` then unwinds. It is invisible in tests, because the
producer only outruns `head` once the input is bigger than a pipe buffer, and
fixtures are small. The same shape hides in `grep -q` (exits early on match)
and in `grep -v` (exits **1** when it filters everything out, so a
blank-but-valid input fails). Any pipeline whose consumer can finish or fail
early needs `|| true` on the assignment and a fallback for the empty value —
see `loop_pr_title` and `wait_for_pane_idle` in `bin/vibe`. Where the script
must degrade to bare bash, do it in-process instead: `frontmatter_closed` in
`bin/skill-lint` reads the file line by line for exactly this reason.

Scripts invoked through a symlink (`bin/*`, skill scripts, hooks) must resolve
their own location by walking the symlink chain — `$0` and `$PWD` both point
somewhere useless. Copy the `script_dir()` helper from `bin/vibe`.

## Authoring a skill

Start from `skills/_template/SKILL.md`. The quality bar every skill is held to —
each rule with a stable ID and its rationale — lives in `docs/skill-quality.md`;
that is the one file to edit when a criterion changes. `bin/skill-lint` enforces
the mechanical rules (run it, or let CI's `--strict` pass catch you); the
`skill-audit` skill grades the judgment ones.

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

**The suite must never look like the server.** `tests/helper.bash` unsets
`SSH_*`, points `VIBE_SERVER_HOSTNAME` at an unmatchable value, and puts a stub
`tmux` early on `PATH` — otherwise a run over SSH takes `detect_env`'s server
path and every `vibe start`/`vibe loop` leaves a real tmux session, and a real
agent, running against a worktree bats has already deleted. It also unsets the
runner's `VIBE_*` variables and redirects `VIBE_CONFIG_FILE`, so the developer's
own config cannot flip an assertion. A test that exercises the server path
asserts against `$VIBE_TEST_TMUX_LOG`, never the live tmux server.

## Protecting main

This repo is private on GitHub Free, which has no branch protection or
rulesets for private repos — `gh api repos/.../branches/main/protection`
returns 403 "Upgrade to GitHub Pro". `.githooks/pre-push` is the local
substitute: it refuses `git push` targeting `refs/heads/main` (or `master`),
so a direct push has to go through a PR instead. It is real friction, not a
guarantee — `--no-verify`, or a clone that skipped the step below, bypasses
it entirely.

New clone, one time:

```bash
git config core.hooksPath .githooks
```

`.git/hooks` is never tracked by git, so this does not happen automatically
on `git clone` or `git pull` — every clone (this machine, the other one, a
fresh checkout) needs it run once.

## Before committing

```bash
shfmt -f . | xargs shellcheck     # lint
shfmt -d -i 2 -ci .               # formatting
bats tests/                       # tests
./install.sh doctor               # the live machine still resolves
```

Conventional Commits. The body should say *why* — a commit that fixes a
data-loss bug should explain what was being lost.

## CI is opt-in per PR

GitHub Actions minutes are billed on this private repo, and the macOS test leg
bills at 10×. So the workflow does **not** run on a PR unless the PR carries
the `run-ci` label — add it (`gh pr edit <n> --add-label run-ci`) and the run
starts; `gh workflow run ci.yml --ref <branch>` is the manual equivalent.
Push-to-`main` still runs unconditionally, so a merge is always verified.

That makes the four commands above the real gate, not CI: an unlabeled PR
shows no checks at all, and GitHub's merge box reads a skipped job as passing.
Required checks cannot compensate — they are not configurable on a private
Free-plan repo.
