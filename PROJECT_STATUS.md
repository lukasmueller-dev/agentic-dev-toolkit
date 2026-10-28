# Project Status — agentic-dev-toolkit

> Long-lived, one per repo. The durable *current* picture of the project:
> what it is for, how it is built, what was decided, what is open. A
> snapshot, not a log — git history is the log, so finished work is removed
> rather than archived here.

_Last updated: 2026-10-28 · turing_

## Goal

Personal tooling for agentic development on one always-on workstation, driven
from the Claude app: one repo, installed by symlink, holding the skills,
hooks, templates and agent config every other repo's work runs on.

## Architecture

See `README.md` for the component map and `CLAUDE.md` for the layout
contract and the installer's auto-discovery rules.

## Key decisions

- 2026-10-28: **the queue runs only on the server**: a client's `role` is
  `client <host>`; `vibe queue status|report` and `vibe job list` run there
  over ssh, every other `queue`/`job` command stops. Design: PR body.
- 2026-10-28: **vibe queue replaces the shifts**: one always-on queue
  (`vibe-queue.service`); heavy jobs (timeout > 2h) start only 18:00–07:00;
  `/fill-queue` and `/review-jobs` run any time, `check-in` and `shutdown`
  call them; a fresh briefing per review, no report timers. Design: PR body.
- 2026-10-27: **recurring jobs**: a job is a catalogue prompt plus a schedule;
  `vibe job due` (01:00 timer) adds due jobs to the vibe queue, one PR per
  run on `jobs/<job>`, cap 2 open job PRs per repo, two failures stop a job.
  Output contract for every job: `memory/GLOBAL.md`, `templates/job-*.md`.
  Design: PRs #99 and the `feat/recurring-jobs` PR.
- 2026-10-26: **unattended jobs**: headless Sonnet jobs under a fail-closed
  sandbox; the runner, not the agent, pushes and opens draft PRs. Design: PR body.
- 2026-10-25: **vibe returns, small**: `start`, `sync`, `status --<agent>`;
  work moves between machines through git, so the usage-audit line "no
  machine-to-machine git travel" no longer holds. Servers run only where
  `~/.config/vibe/role` says `server`. PR for `feat/vibe-sync`.
- 2026-10-24: **Research kit v1** — 10 decision cards, no run scripts; Go2
  path deferred to NCBF's hardware stage. Design in PR #82; NCBF facts and Go2
  estimates in PR #87.
- 2026-10-24: **vibe cut.** Sessions run as Claude Code Remote Control
  servers, one per repo, worktree mode, under a systemd user unit; the
  toolkit is skills, hooks, templates and memory only. Pre-cut state: tag
  `pre-vibe-cut`. Rationale in the PR for `cut-vibe`. See
  `docs/remote-sessions.md`.
- 2026-10-24: A global `WorktreeCreate` hook is ruled out: it replaces worktree
  creation for every subagent in every repo. PR for `cut-vibe`.
- 2026-10-24: **Usage-audit cut.** One workstation, no machine-to-machine git
  travel; cut `vibe loop/rc/park/sync`, `status --json`, `loop-brief`,
  `babysit-pr`, `weekly-report`, `repo-scaffold`, `team-up`, all subagents,
  ntfy/session-end/skill-lint-on-edit hooks. Pre-cut state: tag
  `pre-audit-2026-10-24`. Rationale in the PR for `toolkit-audit`.
- 2026-10-24: **Research audit.** Unused in practice: `research-lib.sh`
  (repo-kind, exec-context detection) and roadmap Track C cut; `codebase-map`
  reduced to a one-screen map. PR for `harness-agent-features`.
- 2026-10-24: A research skill whose writes stay in the target repo is
  model-invocable. See `docs/research-skills.md` §1.
- 2026-10-24: `HANDOFF.md`, `PROJECT_STATUS.md` and `PROJECT_ROADMAP.md` are
  the core: they carry context session to session.
- 2026-10-24: `sota-digest` runs on demand only; no cron. See `docs/sota-watch.md`.
- 2026-10-06: Vendored skills may bundle on-demand scripts, never auto-run
  ones; each add/update gets a security review first. See
  `docs/vendoring-external-skills.md`.
- 2026-10-02: External skills are vendored by copy, pinned by SHA, verified
  offline by tree hash. See `docs/vendoring-external-skills.md`.
- 2026-07-26: `research-*` work ships as skills, not agents. See
  `docs/research-skills.md`.
- 2026-07-26: `install.sh` prunes orphaned symlinks (resolve into this checkout
  *and* to nothing). PR for `prune-orphan-symlinks`.
- 2026-07-26: Second install path `.claude-plugin/`, a pure addition. See
  `docs/plugin.md`.
- 2026-07-26: MCP servers are never installed; `~/.claude.json` is untouched.
  See `CLAUDE.md`.
- 2026-07-23: `codebase-review` stages and launches one review round per
  invocation, behind the human merge gate. PR for `align-health-skills`.
- 2026-07-22: Planned work lives in `PROJECT_ROADMAP.md`. PR for `feat-roadmap`.
- 2026-07-21: Global memory is one portable file, `memory/GLOBAL.md`, reached
  from `claude/CLAUDE.md` by an `@` import. See `memory/README.md`.

## Roadmap

Planned work lives in `PROJECT_ROADMAP.md`.

## Open questions

_None._
