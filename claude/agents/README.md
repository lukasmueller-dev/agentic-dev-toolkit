# claude/agents/

Claude Code [subagent](https://docs.claude.com/en/docs/claude-code/sub-agents)
definitions, installed globally so every repo gets the same roster.

| Agent | Does | Writes? |
| --- | --- | --- |
| [`diff-reviewer`](diff-reviewer.md) | Adversarial review of the working diff, ranked with `file:line` | no |
| [`test-hardener`](test-hardener.md) | Tests aimed at the failure modes the diff just introduced | tests only |
| [`docs-drift`](docs-drift.md) | Finds documentation contradicted by the code beside it | no |
| [`security-sweep`](security-sweep.md) | Secrets, injection shapes, permission widening — and vets third-party skills, agents and hooks before install | no |

Three of the four are read-only by tool allowlist, not just by instruction:
the point of a reviewing subagent is a verdict you can trust, and an agent
that can edit can also make its own findings disappear. `tools:` alone cannot
finish that job — it takes bare tool names, so granting `Bash` grants all of
Bash. Each reviewer therefore carries a frontmatter `PreToolUse` hook running
[`../hooks/readonly-bash.sh`](../hooks/readonly-bash.sh), which holds every
Bash command to a read-only allowlist and blocks the rest with a message
saying what to do instead.

The roster is composed, not imported. `skills/team-up` reads this directory
and the repo's `.claude/agents` at the start of a task and drafts who owns
what; nothing is ever copied between the two, so a repo-local agent stays the
repo's business.

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
