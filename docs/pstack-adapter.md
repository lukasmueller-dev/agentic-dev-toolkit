# pstack adapter

Maps the Cursor names in the vendored `cursor-plugins` skills to Claude Code.
Their link `../../docs/harness/claude-code.md` resolves to `vendor/docs/`, which does not exist: read this file instead.

Upstream: `harness/pstack/claude-code/docs/harness/claude-code.md` at the pin in `plugins.lock`.
A `plug update` review compares this file with it.

## Names

| Skill text | Claude Code |
| --- | --- |
| `.cursor/skills/` | `.claude/skills/` |
| Another vendored skill (`/name`, `` `name` ``) | `Read` `~/.claude/skills/<name>/SKILL.md` and follow it |
| Read-only subagent | `Agent`, `subagent_type: "Explore"`; the brief says "do not edit files"; check `git status` after |
| `how`, `why`, `arena` | Not vendored: write `Skipped: <step>. <reason>.` and go on |

## Traps

- The `Skill` tool refuses a vendored skill → all 6 set `disable-model-invocation: true`; a human types `/name`, an agent uses `Read`.
- A write to `.claude/skills/` fails in a sandboxed job → the sandbox denies that path; a human runs `/create-verification-skill` and `/maintain-verification-skill` in an interactive session.

## License

The upstream `LICENSE` files sit above the vendored paths, so `plug` does not copy them.

- pstack: MIT, `Copyright (c) 2026 Lauren Tan`.
- thermos: MIT, `Copyright (c) 2026 Cursor`.
- Permission notice: the text of [`LICENSE`](../LICENSE).
