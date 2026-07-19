# codex/

Placeholder for [OpenAI Codex CLI](https://github.com/openai/codex)
configuration — empty for now.

## What belongs here

Anything Codex-specific and tool-coupled:

- `config.toml` — Codex CLI configuration
- `AGENTS.md` — Codex's global instruction file
- `prompts/` — reusable custom prompts

## What does *not* belong here

Anything tool-agnostic. Those live at the top level and are shared by every
agent:

| Put it in       | When it is                                                  |
| --------------- | ----------------------------------------------------------- |
| `../skills/`    | A skill — `SKILL.md` is the open Agent Skills standard        |
| `../templates/` | A document template (`HANDOFF.md`, `PROJECT_STATUS.md`)      |
| `../bin/`       | A CLI that any agent (or a human) can run                    |

## Installing

Nothing is linked from here yet. `install.sh` gains a `codex` target once this
directory has real content — the installer discovers what it links, so adding
the files is the only step required.
