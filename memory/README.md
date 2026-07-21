# memory/

Global memory: the standing instructions every agent gets in every repo, on
both machines. One file, `GLOBAL.md`, installed to each agent's global
instruction path.

| Agent       | Installed to               |
| ----------- | -------------------------- |
| Claude Code | `~/.claude/global-memory.md`, pulled in by `~/.claude/CLAUDE.md` |
| Codex CLI   | `~/.codex/AGENTS.md`       |
| Gemini CLI  | `~/.gemini/GEMINI.md`      |

Claude Code loads exactly one global memory file, and this repo also has
Claude-only response-style rules to deliver. So `claude/CLAUDE.md` is the file
symlinked to `~/.claude/CLAUDE.md`, and its first line is an
`@~/.claude/global-memory.md` import of the portable half. The other two agents
symlink `GLOBAL.md` directly. If that import line is ever dropped, Claude Code
silently loses the workflow memory while everything still looks installed —
`./install.sh doctor` checks for it.

## What belongs here

Instructions that are true of *my workflow*, not of one agent: where each kind
of information is written, the two-machine setup, the handoff discipline, how
`vibe` structures a task.

## What does *not* belong here

- **Anything naming a specific agent or vendor.** CI fails the build if
  `GLOBAL.md` does. Referring to `CLAUDE.md`/`AGENTS.md`/`GEMINI.md` as
  filenames is fine — those are the open conventions each agent reads.
- **Response style, model choice, tool-use habits** — agent-coupled, so they
  belong in that agent's directory (`claude/CLAUDE.md`).
- **Repo-specific conventions** — those go in the repo's own instruction file.
- **Anything a skill or template already says.** Global memory is loaded in
  every session of every repo; it is the most expensive place to put a fact.
  Keep it short and point downward.
