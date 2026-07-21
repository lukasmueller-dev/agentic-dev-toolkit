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

Roadmap, one PR each. Order matters within a track; tracks are
independent. Each item carries enough design to stage a `HANDOFF.md` (the
`handoff-brief` skill) or a `LOOP.md` (the `loop-brief` skill) from it
without needing the discussion that produced it.

Track A — unattended execution:

- [ ] Sandbox baseline in `claude/settings.json`, so unattended runs stop
      needing `--dangerously-allow-all` *(in progress on
      `claude/agentic-dev-trends-3dws2i`, PR #19)*
- [ ] Ralphify `vibe loop`. Three independent additions to `bin/vibe`:
      (1) `--sandbox`, appending a new `VIBE_LOOP_PERMISSIVE_ARGS`-style
      variable `VIBE_LOOP_SANDBOX_ARGS` to the agent invocation, and
      recommended over `--dangerously-allow-all` in `docs/vibe-loop.md`
      and in the startup warning; (2) `--for <duration>` wall-clock stop
      alongside `--max` (overnight runs are time-bounded, not
      round-bounded) — a fourth row in the stop table, stored in
      `.vibe-loop.state`; (3) one-task-per-round discipline written into
      `templates/LOOP.md`: each round does the smallest complete task and
      stops, keeping per-round context fresh. Tests in
      `tests/vibe-loop.bats`; keep bash 3.2 / BSD+GNU compatibility.
- [ ] `skills/babysit-pr`: a skill that *stages a brief*, not a watcher.
      It renders a `LOOP.md` whose goal is "PR #N is mergeable" and whose
      stop check combines `gh pr checks` with zero unresolved review
      threads, then hands it to `vibe loop` on the server. Escalation to
      the phone reuses the existing ntfy hook. Portable (`gh` only, no
      Claude-specifics) — it belongs in top-level `skills/`.

Track B — portability and team:

- [ ] Portable global memory: split `claude/CLAUDE.md` into the
      agent-agnostic workflow memory (routing table, two-machine setup,
      handoff rules) at a portable top-level home, and the genuinely
      Claude-specific remainder (response style) staying in `claude/`.
      The installer links the portable file to `~/.claude/CLAUDE.md`,
      `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md` — turning `codex/` and
      `gemini/` from placeholders into one-symlink targets. Must land
      before the plugin PR, which snapshots the layout.
- [ ] Global agents in `claude/agents/` (installer auto-links once the
      directory holds more than its README): `diff-reviewer`
      (adversarial review of the working diff), `test-hardener` (writes
      tests biased toward the diff's new failure modes), `docs-drift`
      (do README/docs/CLAUDE.md still match the code — report with
      file:line), `security-sweep` (secrets, injection shapes, permission
      widening; also vets third-party skills before install). Plus
      `skills/team-up`: a *composer*, not an importer — at session start
      it scans `~/.claude/agents` and the repo's `.claude/agents` and
      drafts who owns what; nothing is copied. Decided against promoting
      repo agents into the global roster (drift/sync burden) — revisit
      only if composition proves insufficient.
- [ ] `.claude-plugin/` manifest bundling skills, agents, and hooks so the
      toolkit installs in web/cloud sessions with no `$HOME` symlinks.
      Pure addition beside `install.sh`, which stays the install path on
      real machines.
- [ ] Curated MCP server list in `docs/` (docs-first; `~/.claude.json` is
      Claude-written and stays unmanaged — same file class as
      `settings.json`'s runtime keys)

## Open questions

- Where the portable global memory lives (`memory/`? top level?) — decide
  in its own PR; the layout contract in `CLAUDE.md` is the tiebreaker.
- Agent Teams is still experimental in Claude Code; `team-up` targets
  subagents now and adopts teams once the experiment stabilises.
