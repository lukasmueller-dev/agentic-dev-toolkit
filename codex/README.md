# codex/

Placeholder for [OpenAI Codex CLI](https://github.com/openai/codex)
configuration. It takes the shared global memory and no config of its
own yet.

## What belongs here

Anything Codex-specific and tool-coupled:

- `config.toml` — Codex CLI configuration
- `prompts/` — reusable custom prompts

## What does *not* belong here

Anything tool-agnostic. Those live at the top level and are shared by every
agent:

| Put it in       | When it is                                                  |
| --------------- | ----------------------------------------------------------- |
| `../skills/`    | A skill — `SKILL.md` is the open Agent Skills standard        |
| `../templates/` | A document template (`HANDOFF.md`, `PROJECT_STATUS.md`)      |
| `../bin/`       | A CLI that any agent (or a human) can run                    |
| `../memory/`    | Standing instructions every agent should get (`AGENTS.md` is symlinked from there) |

## Installing

`./install.sh codex` links the shared global memory to `~/.codex/AGENTS.md`,
and every file dropped in here to `~/.codex/<name>`. Nothing else is in this
directory yet — the installer discovers what it links, so adding the files is
the only step required.

`config.toml` is deliberately skipped: the Codex CLI writes to it, and a
symlink into this repo would turn every setting it rewrites into a git diff
here that syncs to the other machine. `claude/settings.json` hits the same
problem and is merged instead — do that here too when the file appears.
