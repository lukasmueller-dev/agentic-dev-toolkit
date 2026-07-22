# Sources and search angles

The maintained input list for the weekly sweep. **Edit this file** when a
source stops being useful or a new one appears — the skill body deliberately
holds no URLs, so the list can change without touching the workflow.

Sources are a starting point, not a boundary: web search over the angles
below is the primary instrument, and this list is what you check even when
search turns up nothing.

## 1. Agent CLIs and coding harnesses

What the tools this workflow is built on actually shipped.

- Claude Code releases and changelog — <https://github.com/anthropics/claude-code/releases>
- Claude Code docs (features, hooks, skills, settings) — <https://code.claude.com/docs>
- Agent Skills as an open standard — spec changes, other adopters
- Competing harnesses, for capabilities worth stealing rather than adopting:
  OpenAI Codex CLI, Gemini CLI, Cursor, Aider, OpenHands

**Angle:** does a new feature make something in `bin/`, `skills/`, or
`claude/hooks/` obsolete? A workaround this toolkit maintains that the tool
now does natively is the single most valuable find.

## 2. Models

- Frontier model releases and deprecations from Anthropic, OpenAI, Google
- Context window, pricing, and rate-limit changes
- Anything affecting long-running unattended agents specifically

**Angle:** this repo runs headless loops. Cost, context, and reliability
changes hit `vibe loop` before anything else.

## 3. Protocol and ecosystem

- MCP spec releases and notable servers — <https://modelcontextprotocol.io>
- Agent-to-agent and tool-interop standards
- Sandboxing and permission models for agents

## 4. Practice

How people actually run agents, as opposed to what vendors announce.

- Anthropic engineering blog — <https://www.anthropic.com/engineering>
- Practitioner write-ups on multi-agent workflows, unattended runs, review
  gates, worktree-per-task setups
- Postmortems: agent failures, data loss, prompt injection in dev tooling

**Angle:** this is where the highest-value findings for *this* repo come
from, because the toolkit is a workflow, not a product. A well-argued
critique of a pattern this repo uses outranks any release note.

## 5. Security

- Prompt injection and supply-chain issues in agent tooling
- Vulnerabilities in skills, hooks, MCP servers, or agent CLIs

**Angle:** anything here that touches an installed component of this
toolkit is a recommendation regardless of how quiet the week otherwise was.

## Search hygiene

- Bound the sweep to the **last ~10 days**. Older material has either been
  digested already or is not news.
- Prefer primary sources — release notes, specs, the vendor's own post —
  over aggregators summarizing them.
- Two independent mentions before treating a rumour as a fact. Announced
  ≠ shipped; say which one it is.
