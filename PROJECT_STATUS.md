# Project Status — agentic-dev-toolkit

> Long-lived, one per repo. The durable *current* picture of the project:
> what it is for, how it is built, what was decided, what is open. A
> snapshot, not a log — git history is the log, so finished work is removed
> rather than archived here.

_Last updated: 2026-10-24 · turing_

## Goal

Personal tooling for agentic development on one workstation, reached at the
keyboard or over SSH: one repo, installed by symlink, holding the CLIs,
skills, templates and agent config every other repo's work runs on.

## Architecture

See `README.md` for the component map and `CLAUDE.md` for the layout
contract and the installer's auto-discovery rules.

## Key decisions

- 2026-10-24: Remote Control is opt-in at launch (`VIBE_REMOTE_CONTROL=1`), a
  view on the tmux session, which stays the source of truth. PR for
  `vibe-remote-control`.
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
- 2026-10-24: `vibe status`, `HANDOFF.md`, `PROJECT_STATUS.md` and
  `PROJECT_ROADMAP.md` are the core: they carry context session to session.
- 2026-10-24: `sota-digest` runs on demand only; no cron. See `docs/sota-watch.md`.
- 2026-10-06: Vendored skills may bundle on-demand scripts, never auto-run
  ones; each add/update gets a security review first. See
  `docs/vendoring-external-skills.md`.
- 2026-10-02: External skills are vendored by copy, pinned by SHA, verified
  offline by tree hash. See `docs/vendoring-external-skills.md`.
- 2026-08-02: `vibe done` finishes a task whose worktree directory is gone
  (prunes git's record, kills the session, keeps the branch). See `docs/vibe.md`.
- 2026-07-27: `--no-attach` implies tmux on any machine; `vibe attach` joins a
  live session wherever one runs. PR for `roadmap-track-d`.
- 2026-07-27: The kickoff prompt fires only under `--no-attach`. PR for
  `skill-handoff-start`.
- 2026-07-26: `research-*` work ships as skills, not agents. See
  `docs/research-skills.md`.
- 2026-07-26: `install.sh` prunes orphaned symlinks (resolve into this checkout
  *and* to nothing). PR for `prune-orphan-symlinks`.
- 2026-07-26: Second install path `.claude-plugin/`, a pure addition. See
  `docs/plugin.md`.
- 2026-07-26: MCP servers are never installed; `~/.claude.json` is untouched.
  See `CLAUDE.md`.
- 2026-07-23: `vibe done --rm-branch` deletes only landed work (ancestor of the
  default branch, or remote branch gone). See `docs/vibe.md`.
- 2026-07-23: `codebase-review` stages and launches one review round per
  invocation, behind the human merge gate. PR for `align-health-skills`.
- 2026-07-22: Planned work lives in `PROJECT_ROADMAP.md`. PR for `feat-roadmap`.
- 2026-07-21: Global memory is one portable file, `memory/GLOBAL.md`, reached
  from `claude/CLAUDE.md` by an `@` import. See `memory/README.md`.

## Roadmap

Planned work lives in `PROJECT_ROADMAP.md`.

## Open questions

_None._
