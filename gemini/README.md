# gemini/

Placeholder for [Gemini CLI](https://github.com/google-gemini/gemini-cli)
configuration. It takes the shared global memory and no config of its
own yet.

## What belongs here

Anything Gemini-specific and tool-coupled:

- `settings.json` — Gemini CLI configuration (`~/.gemini/settings.json`)
- `commands/` — custom slash commands

## What does *not* belong here

Anything tool-agnostic. Those live at the top level and are shared by every
agent:

| Put it in       | When it is                                                  |
| --------------- | ----------------------------------------------------------- |
| `../skills/`    | A skill — `SKILL.md` is the open Agent Skills standard        |
| `../templates/` | A document template (`HANDOFF.md`, `PROJECT_STATUS.md`)      |
| `../bin/`       | A CLI that any agent (or a human) can run                    |
| `../memory/`    | Standing instructions every agent should get (`GEMINI.md` is symlinked from there) |

## Installing

`./install.sh gemini` links the shared global memory to `~/.gemini/GEMINI.md`,
and every file dropped in here to `~/.gemini/<name>`. Nothing else is in this
directory yet — the installer discovers what it links, so adding the files is
the only step required.

`settings.json` is deliberately skipped: the Gemini CLI writes to it, and a
symlink into this repo would turn every setting it rewrites into a git diff
here that syncs to every other machine. `claude/settings.json` hits the same
problem and is merged instead — do that here too when the file appears.
