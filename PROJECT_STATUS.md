# Project Status — agentic-dev-toolkit

> Long-lived, one per repo. The durable *current* picture of the project:
> what it is for, how it is built, what was decided, what is open. A
> snapshot, not a log — git history is the log, so finished work is removed
> rather than archived here.

_Last updated: 2026-07-26 · server (srv1841294)_

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

- 2026-07-26: The planned `research-*` skill family is settled as **skills,
  not agents** — including `research-cartographer`, whose read-only fan-out
  was the one candidate for `claude/agents/` but loses to portability, since
  an agent directory is Claude-Code-only and a written artifact does not fit
  the read-only-by-allowlist pattern that makes the reviewer agents safe. The
  family's other six contracts (a `templates/research/` entry per emitted
  document, artifacts into the target repo's `docs/`, two shared detections in
  `skills/_lib/`, the smoke-scale never-launch rule, the `research-` prefix)
  are fixed in the same place. See `docs/research-skills.md`; rationale in the
  PR for `roadmap-track-c`.
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
- 2026-07-23: `review-brief` is renamed `skills/codebase-review` and now
  launches the round it stages (`vibe start --no-attach` on a server;
  locally the command is printed, since starting needs a terminal). The
  round still runs in a *separate* session — fresh context is the product,
  so staging was kept and only the launch hop removed. Every staged round
  now carries a scan-only `codebase-health` leg, ordered after blind
  discovery; `skills/codebase-health/references/shell.md` is what makes
  that leg useful on shell repos. Rationale in the PR for
  `align-health-skills`.
- 2026-07-22: Independent review rounds are staged by
  `skills/codebase-review`, one round per invocation behind the human merge
  gate; its `references/review-dimensions.md` catalog is where review
  knowledge accumulates (generic core, anchor-gated dimensions, standing
  rules). No unattended variant — a review has no executable stop check.
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
- 2026-07-22: A foreground `vibe loop` exits with its outcome (0 success,
  2 stalled, 3 maxed, 4 timeup, 5 stopped; 1 stays the generic failure) —
  foreground path only, detached tmux runs unchanged. Rationale in the
  commit body of `d0e6833` and the PR for `review3-followups`.
- 2026-07-22: `vibe start --no-attach` (server only) mirrors the loop
  flag, so `ssh <host> vibe start <task>` is scriptable instead of dying
  on the headless attach after the work is done. See `c96cf2c`.
- 2026-07-22: The repo watches its own state of the art on a weekly cron
  entry — `.claude/skills/sota-digest` (repo-local, never installed
  elsewhere) driven by `vibe loop --pr`, digest at `docs/sota/<YYYY-Www>.md`,
  merging the PR as the review gate and the host's PR email as the only
  notification. Recommendations are promoted by hand via `add-roadmap-item`,
  never written into the roadmap by the run. See `docs/sota-watch.md`;
  rationale in the PR for `agentic-dev-sota`.
- 2026-07-23: `vibe done --rm-branch` gates branch deletion on the work
  having landed — ancestor of the default branch, or remote branch gone —
  and never on `git branch -d`, which counts a pushed branch with an open
  PR as merged. See `bd4eaa2` and the PR for `cleanup-old-branches`.
- 2026-07-22: Planned work moved out of this file into
  `PROJECT_ROADMAP.md` (template + scaffold + `add-roadmap-item` skill,
  which holds new items to the pick-up-cold design bar); this file keeps
  only a pointer. Rationale in the PR for `feat-roadmap`.
- 2026-07-23: `open_session()` now submits a fixed kickoff prompt
  (`Begin per HANDOFF.md.`) as the agent's first turn whenever a genuinely
  fresh launch — a new tmux session, a dead pane restarted with no
  `VIBE_AGENT_RESUME_ARGS`, or the local exec branch — finds real
  `HANDOFF.md` content. The `SessionStart` hook only injects the handoff as
  context and never submits a turn, so `vibe start --no-attach` and any
  scripted start previously left the agent idle with the handoff loaded but
  unread. Rationale in the PR for `fix-handoff-start-bug`. **Narrowed
  2026-07-27** — see below.
- 2026-07-26: `install.sh` prunes orphaned symlinks on every run — a link in
  a managed directory that both resolves into this checkout *and* resolves to
  nothing, which is what a renamed skill leaves in `~/.claude/skills`. It was
  posed as a decision because pruning deletes a link the current map does not
  know about; requiring both conditions makes it a strict subset of what
  `--uninstall` already removes, so it was made automatic rather than opt-in.
  Rationale in the PR for `prune-orphan-symlinks`.
- 2026-07-26: The toolkit has a **second install path**, `.claude-plugin/`, for
  sessions with no `$HOME` to symlink into. Pure addition in both directions —
  `install.sh` never scans it, it never runs `install.sh`. Two things a plugin
  cannot do are replaced by session hooks wired only from the plugin side:
  `memory/GLOBAL.md` is injected as `SessionStart` context (no plugin
  populates `~/.claude/CLAUDE.md`, and a plugin-root `CLAUDE.md` is not
  loaded), and the reviewer agents' Bash allowlist is reapplied by
  `agent_type` from a session-level hook (Claude Code refuses `hooks:` in a
  plugin agent's frontmatter). The permission/sandbox baseline and the
  statusline deliberately do not travel — a plugin may not set them, and a
  permission baseline arriving from a package is the one thing
  `docs/vendoring-external-skills.md` argues should never happen. See
  `docs/plugin.md`; rationale in the PR for `claude-plugin-manifest`.
- 2026-07-26: MCP servers are **documented, never installed**
  (`docs/mcp-servers.md`). User and local scope both live in `~/.claude.json`,
  which Claude Code writes to itself — the same file class as
  `settings.json`'s runtime keys — and the plugin does not ship an `.mcp.json`
  either, on the same grounds as the permission baseline: what an agent can
  reach is the user's decision, not a package's. Project-owned servers still
  have a home, `.mcp.json` at a project root, which is a per-repo choice.
  The doc's actual content is the curation: three servers worth connecting,
  and why most reference servers duplicate a built-in tool — with `Memory`
  singled out, since a per-machine knowledge graph contradicts an artifact
  architecture that keeps state in git. Rationale in the PR for
  `mcp-server-list`.
- 2026-07-27: The kickoff prompt above is **narrowed to `--no-attach`**. It
  now fires only for a fresh launch nobody is attaching to; an attached
  session — server or local — opens with the handoff in context and waits
  for the person who is sitting there. The 2026-07-23 entry read "no tty to
  attach from" as the problem and then keyed on handoff content instead, so
  it also spent the first turn of every attended session on a decision the
  person was about to make. `--no-attach` is the signal for "nobody is
  arriving" and, unlike a tty check, survives a bats run. Shipped with
  `handoff-start`, the sibling of `handoff-brief` that stages the same brief
  and then launches the session. Rationale in the PR for
  `skill-handoff-start`.

## Roadmap

Planned work lives in `PROJECT_ROADMAP.md`, one designed item per task —
this file keeps only the pointer. (Track A — unattended execution — the
original Track C — verification debt — and now Track B — portability —
completed and were removed; their trail is in the merged PRs. The Track C
still listed is the later `research-*` family, which reused the letter.)

## Open questions

- Agent Teams is still experimental in Claude Code; `team-up` targets
  subagents now and adopts teams once the experiment stabilises.
