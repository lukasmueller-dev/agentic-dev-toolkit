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
- 2026-07-22: Independent review rounds are staged by `skills/review-brief`,
  one round per invocation behind the human merge gate; its
  `references/review-dimensions.md` catalog is where review knowledge
  accumulates (generic core, anchor-gated dimensions, standing rules).
  No unattended variant — a review has no executable stop check.
  Rationale in the PR for `review-brief-skill`.
- 2026-07-21: Global memory is one portable file, `memory/GLOBAL.md`,
  installed to each agent's own instruction path; Claude Code reaches it
  through an `@` import in `claude/CLAUDE.md`, which keeps the
  response-style rules agent-local. Rationale in the PR for
  `portable-global-memory-per-the-project_status.md-roadmap-item`.
- 2026-07-22: General repo scaffolding is one gated, model-invocable skill,
  `skills/repo-scaffold` — read-only audit, phase-3 approval gate on every
  write (second SQ13 exception). Emitted assets live in `templates/`
  (`gitignore/`, `ci/`, `repo/pre-push`, copied verbatim — no placeholder
  tokens); per-ecosystem judgment lives in the skill's `references/`;
  status files stay owned by `project-status-scaffold`. Rationale in the
  PR for `skill-full-scaffold`.
- 2026-07-22: Planned work moved out of this file into
  `PROJECT_ROADMAP.md` (template + scaffold + `add-roadmap-item` skill,
  which holds new items to the pick-up-cold design bar); this file keeps
  only a pointer. Rationale in the PR for `feat-roadmap`.

## Roadmap

Planned work lives in `PROJECT_ROADMAP.md`, one designed item per task —
this file keeps only the pointer. (Track A — unattended execution — and
Track C — verification debt — completed and were removed; their trail is
in the merged PRs.)

## Open questions

- Agent Teams is still experimental in Claude Code; `team-up` targets
  subagents now and adopts teams once the experiment stabilises.
- A foreground `vibe loop` exits 0 whatever the outcome — stalled, maxed
  and timeup are indistinguishable from success for a scripted caller
  (`vibe loop … && next-step`). The state file and ntfy carry the
  outcome, so this may be deliberate; decide and either document it or
  map non-success statuses to a non-zero exit. (Round three, PR #41.)
- `vibe start` on a server without a tty exits 1 *after* creating the
  session and launching the agent, because the final attach fails.
  Harmless interactively; a `--no-attach` analog like `vibe loop`'s
  would make `ssh <host> vibe start <task>` scriptable. (Round three.)
