# Project Status — agentic-dev-toolkit

> Long-lived, one per repo. The durable *current* picture of the project:
> what it is for, how it is built, what was decided, what is open. A
> snapshot, not a log — git history is the log, so finished work is removed
> rather than archived here.

_Last updated: 2026-07-22 · server_

## Goal

Personal tooling for agentic development across any number of machines —
those you sit at and those you reach over SSH: one repo, installed by
symlink on each machine, holding the CLIs, skills, templates, and agent
config that every other repo's work runs on.

## Architecture

See `README.md` for the component map and `CLAUDE.md` for the layout
contract (portable at top level, agent-specific per agent directory) and
the installer's auto-discovery rules.

## Key decisions

- 2026-07-21: `local` and `server` are **roles a session plays**, not two
  named machines or two operating systems — the same box is local when you
  sit at it and a server when you SSH in, and any number of machines can
  play either role. `VIBE_SERVER_HOSTNAME` is per-machine (each names
  itself), so nothing in the code counts machines. The vocabulary was kept
  rather than renamed, to avoid breaking existing configs. Rationale in the
  PR for `harden-repo`.
- 2026-07-21: Adopted a two-track roadmap from the mid-2026 agentic-trends
  review — sandbox-first unattended execution, then cross-agent
  portability. Rationale in the PR for `claude/agentic-dev-trends-3dws2i`.
- 2026-07-21: The global agent roster is *composed*, never imported —
  `skills/team-up` reads `~/.claude/agents` and a repo's `.claude/agents`
  and assigns work; nothing is copied between them. Rationale in the PR
  for `global-agents-per-project-status-md`.
- 2026-07-21: Reviewing subagents are read-only by tool allowlist, not
  just by instruction — an agent that can edit can make its own findings
  disappear. `test-hardener` is the one exception and may write tests
  only. See `claude/agents/README.md`.
- 2026-07-21: Global memory is one portable file, `memory/GLOBAL.md`,
  installed to each agent's own instruction path; Claude Code reaches it
  through an `@` import in `claude/CLAUDE.md`, which keeps the
  response-style rules agent-local. Rationale in the PR for
  `portable-global-memory-per-the-project_status.md-roadmap-item`.

## TODOs

Roadmap, one PR each. Order matters within a track; tracks are
independent. Each item carries enough design to stage a `HANDOFF.md` (the
`handoff-brief` skill) or a `LOOP.md` (the `loop-brief` skill) from it
without needing the discussion that produced it.

Track A — unattended execution:

- [x] Sandbox baseline in `claude/settings.json`, so unattended runs stop
      needing `--dangerously-allow-all` *(landed in `63c5a0e`: `sandbox`
      block with `credentials`, `network.allowedDomains`, `excludedCommands`)*
- [x] Ralphify `vibe loop` *(PR #27)*. Three independent additions to
      `bin/vibe`:
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
- [x] `skills/babysit-pr`: a skill that *stages a brief*, not a watcher.
      It renders a `LOOP.md` whose goal is "PR #N is mergeable" and whose
      stop check combines `gh pr checks` with zero unresolved review
      threads, then hands it to `vibe loop` on the server. Escalation to
      the phone reuses the existing ntfy hook. Portable (`gh` only, no
      Claude-specifics) — it belongs in top-level `skills/`.

Track B — portability and team:

- [ ] `.claude-plugin/` manifest bundling skills, agents, hooks, and
      `memory/GLOBAL.md` so the toolkit installs in web/cloud sessions
      with no `$HOME` symlinks. Pure addition beside `install.sh`, which
      stays the install path on real machines. Note the `@` import in
      `claude/CLAUDE.md` resolves against `~/.claude`, which a plugin does
      not populate.
      **A 228-line design doc for this exists but was never merged:**
      `docs/plugins.md` on `origin/claude/open-source-alternatives-2yiha7`
      (2 commits, no PR ever opened). Recover it before starting, and
      before any branch pruning.
- [ ] Curated MCP server list in `docs/` (docs-first; `~/.claude.json` is
      Claude-written and stays unmanaged — same file class as
      `settings.json`'s runtime keys)

Track C — verification debt (opened by the 2026-07-22 review pass; CI
billing was resolved the same day — main `4cb588c` ran green on all four
jobs, macOS leg on bash 3.2.57, so merges are verified again):

Track C additions from the 2026-07-22 second review pass (round two;
fixed findings landed in that round's PR — these are the ones left open
because each needs an owner decision or a design):

- [ ] `render_template` substitutes tokens sequentially, so a task string
      that itself contains a later token (`vibe loop "document the
      <machine> placeholder"`) is re-substituted inside the rendered
      brief. Low impact; the fix is order-independent rendering in both
      `bin/vibe` and `skills/_lib/vibe-lib.sh`.
- [ ] Skill-structure grades below the bar in `docs/skill-quality.md`:
      `commit-push-pr` keeps its stop conditions at the end of the file
      instead of opening with them; `project-status-scaffold` never
      defines "done"; `codebase-health`'s step-5 approval gate is not
      bold-marked; `implement-test-suite`'s description has no trigger
      phrases. One small pass, guided by the quality doc.

## Open questions

- Agent Teams is still experimental in Claude Code; `team-up` targets
  subagents now and adopts teams once the experiment stabilises.
