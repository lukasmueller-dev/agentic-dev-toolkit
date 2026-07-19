# claude/agents/

Claude Code [subagent](https://docs.claude.com/en/docs/claude-code/sub-agents)
definitions. Empty for now.

## What belongs here

One Markdown file per subagent, `<agent-name>.md`, with YAML frontmatter:

```markdown
---
name: my-agent
description: When this subagent should be invoked. Written for the model to match on.
tools: Read, Grep, Glob        # optional — omit to inherit all tools
model: sonnet                  # optional — omit to inherit the session model
---

The subagent's system prompt goes here.
```

The filename (minus `.md`) is the name used to invoke it.

## Subagent or skill?

Both extend the agent, but they load differently — pick by what the job needs:

- **Skill** (`../../skills/`) — instructions loaded *into the current context*
  on demand. Use when the work should stay in the main conversation and share
  its history. Portable across tools: `SKILL.md` is an open standard.
- **Subagent** (here) — a *separate* context with its own tool allowlist and
  model. Use to isolate a large or noisy job (broad searches, long test runs)
  so its output does not crowd the main context. Claude Code-specific.

Reach for a skill first. Add a subagent when the isolation is the point.

## Installing

`install.sh`'s `claude` target links this directory to `~/.claude/agents`. The
link is created whenever the directory has content beyond this README, so
dropping a `.md` file in and re-running the installer is the only step needed.
