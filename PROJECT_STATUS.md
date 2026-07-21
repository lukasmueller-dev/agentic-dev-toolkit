# Project Status — agentic-dev-toolkit

> Long-lived, one per repo. The durable *current* picture of the project:
> what it is for, how it is built, what was decided, what is open. A
> snapshot, not a log — git history is the log, so finished work is removed
> rather than archived here.

_Last updated: 2026-07-21 · server_

## Goal

Personal tooling for agentic development across a local Mac and a remote
Linux VPS: one repo, installed by symlink on both machines, holding the
CLIs, skills, templates, and agent config that every other repo's work runs
on.

## Architecture

See `README.md` for the component map and `CLAUDE.md` for the layout
contract (portable at top level, agent-specific per agent directory) and
the installer's auto-discovery rules.

## Key decisions

- 2026-07-21: Adopted a two-track roadmap from the mid-2026 agentic-trends
  review — sandbox-first unattended execution, then cross-agent
  portability. Rationale in the PR for `claude/agentic-dev-trends-3dws2i`.

## TODOs

Roadmap, one PR each. Order matters within a track; tracks are independent.

Track A — unattended execution:

- [ ] Sandbox baseline in `claude/settings.json`, so unattended runs stop
      needing `--dangerously-allow-all` *(in progress on
      `claude/agentic-dev-trends-3dws2i`)*
- [ ] Ralphify `vibe loop`: `--sandbox` (new `VIBE_LOOP_SANDBOX_ARGS`),
      `--for <duration>` wall-clock budget, one-task-per-round discipline
      in `templates/LOOP.md`
- [ ] `skills/babysit-pr`: stage a PR-babysitting brief (CI green, review
      threads resolved) and hand it to `vibe loop` on the server

Track B — portability and team:

- [ ] Portable global memory: move the agent-agnostic parts of
      `claude/CLAUDE.md` to a top-level home; installer links it to
      `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`
- [ ] Global agents in `claude/agents/`: `diff-reviewer`, `test-hardener`,
      `docs-drift`, `security-sweep` — plus a `team-up` composer skill
      that drafts a team from global + repo-local agents at session start
- [ ] `.claude-plugin/` manifest bundling skills, agents, and hooks so the
      toolkit installs in web/cloud sessions with no `$HOME` symlinks
- [ ] Curated MCP server list in `docs/` (docs-first; `~/.claude.json` is
      Claude-written and stays unmanaged)

## Open questions

- Where the portable global memory lives (`memory/`? top level?) — decide
  in its own PR; the layout contract in `CLAUDE.md` is the tiebreaker.
- Agent Teams is still experimental in Claude Code; `team-up` targets
  subagents now and adopts teams once the experiment stabilises.
