# gemini/

Placeholder for [Gemini CLI](https://github.com/google-gemini/gemini-cli)
configuration — empty for now.

## What belongs here

Anything Gemini-specific and tool-coupled:

- `settings.json` — Gemini CLI configuration (`~/.gemini/settings.json`)
- `GEMINI.md` — Gemini's global context file
- `commands/` — custom slash commands

## What does *not* belong here

Anything tool-agnostic. Those live at the top level and are shared by every
agent:

| Put it in       | When it is                                                  |
| --------------- | ----------------------------------------------------------- |
| `../skills/`    | A skill — `SKILL.md` is the open Agent Skills standard        |
| `../templates/` | A document template (`HANDOFF.md`, `PROJECT_STATUS.md`)      |
| `../bin/`       | A CLI that any agent (or a human) can run                    |

## Installing

Nothing is linked from here yet. `install.sh` gains a `gemini` target once this
directory has real content — the installer discovers what it links, so adding
the files is the only step required.
