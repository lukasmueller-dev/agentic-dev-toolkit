# The Claude Code plugin

`install.sh` needs a `$HOME` it can symlink into and a checkout that stays put.
Neither holds in a web session, a cloud sandbox, or a container that is thrown
away at the end of a turn. The plugin is how the toolkit reaches those: the
same files, loaded from the repo directory itself, with nothing written outside
it.

It is a **pure addition**. `.claude-plugin/` is invisible to `install.sh`, and
`install.sh` is invisible to the plugin loader, so a real machine keeps the
symlink install and loses nothing.

```bash
claude --plugin-dir ~/git/agentic-dev-toolkit
```

Repeat the flag to load it beside other plugins. `claude plugin validate .`
checks the manifest, the skill frontmatter, and the hook config.

## What the plugin root already is

The repo's layout was not designed for this, but it lines up almost exactly
with the layout Claude Code expects at a plugin root:

| Plugin default | This repo         | Result                                    |
| -------------- | ----------------- | ----------------------------------------- |
| `skills/`      | `skills/`         | Every skill, no manifest entry needed     |
| —              | `vendor/skills/`  | Listed in the manifest's `skills`, loaded in addition to `skills/` |
| `bin/`         | `bin/`            | `vibe`, `skill-lint` and `plug` join the Bash `PATH` |
| `hooks/hooks.json` | —             | `.claude-plugin/hooks.json`               |

That is not a coincidence worth over-reading — `skills/` at the top level is
the portability rule from `CLAUDE.md`, and `bin/` is where CLIs go — but it
does mean the manifest stays small.

Skills arrive namespaced: `/agentic-dev-toolkit:handoff-brief`, not
`/handoff-brief`. Namespacing is not optional for plugin skills; it is what
stops two plugins colliding.

## The two things a plugin cannot do, and what replaces them

### Global memory

Claude Code reads global instructions from `~/.claude/CLAUDE.md`. No plugin
populates that path, and a `CLAUDE.md` at the plugin root is explicitly not
loaded — `claude plugin validate` warns about this repo's own `CLAUDE.md` for
exactly that reason, which is expected and is why CI does not run the validator
with `--strict`.

The documented answer is "ship instructions as a skill". That is wrong for this
case: a skill loads on demand, and `memory/GLOBAL.md` is standing instruction
that has to be in context *before* the agent decides anything.

So `claude/hooks/inject-global-memory.sh` injects it as `SessionStart`
`additionalContext` — the mechanism `session-start-handoff.sh` already uses for
`HANDOFF.md`, one lifetime tier up. Same `startup`/`clear` source filter, for
the same reason: `resume`, `compact` and `fork` carry context forward, and
re-injecting 5KB of standing instruction on every compaction is a runaway.

The known limit is that injected context is ordinary conversation context, not
a memory file. A long enough session can compact it away, where the symlink
install's `~/.claude/CLAUDE.md` would survive.

`inject-global-memory.sh` is not wired in the symlink install. On a real machine
it is an inert script sitting in `~/.claude/hooks`.

### Permission and sandbox policy

A plugin's `settings.json` supports only the `agent` and `subagentStatusLine`
keys, so the baseline in `claude/settings.json` — permissions, sandbox policy,
the `statusLine` command — cannot travel with the plugin. That is a real gap
and not one worth working around: `docs/vendoring-external-skills.md` argues
that a permission baseline is the one thing that should never arrive from a
package, and the argument does not stop applying when the package is ours.

Under the plugin, sessions run on whatever permission settings the host already
has.

## Known rough edges

- **`skills/_template` loads as a skill.** `install.sh` skips `skills/_*`, and
  that skip is the only thing keeping the template out of `~/.claude/skills`.
  The plugin loader has no equivalent — the manifest's `skills` field (which
  carries `./vendor/skills/`) *adds to* the default `skills/` scan and cannot
  subtract from it. The template carries
  `disable-model-invocation: true`, so the cost is one extra entry in the slash
  picker, not a skill Claude might act on. `skills/_lib` has no `SKILL.md` and
  is ignored.
- **`bin/` joins the Bash `PATH` automatically.** `vibe` in a sandbox with no
  tmux and no persistent worktree root will not do anything useful, but it
  degrades rather than breaking; `vibe where` reports what it detected.
- **Versioning.** `version` is set in the manifest, so the plugin only updates
  when that field is bumped. Left unset, every commit would count as a new
  version.

## Keeping the two install paths honest

Two copies of the hook wiring now exist — `claude/settings.json` for the
symlink install, `.claude-plugin/hooks.json` for the plugin — because the
command paths genuinely differ (`$HOME/.claude/hooks/…` against
`${CLAUDE_PLUGIN_ROOT}/claude/hooks/…`). They are not generated from each
other, so `tests/plugin.bats` asserts they stay in step: every event in the
baseline appears in the plugin config, and every command resolves to a file
that exists.

`claude/agents/` is empty today, so the manifest has no `agents` key. Adding an
agent means adding one: it must be a list of files, not a directory — the
validator rejects a directory — and `tests/plugin.bats` fails until every agent
file is listed.
