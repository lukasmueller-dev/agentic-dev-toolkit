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

Track C — verification debt (opened by the 2026-07-22 review pass):

- [ ] **GitHub Actions is billing-blocked**, so nothing has been verified
      by CI since 2026-07-21. PRs #33–#35 merged unverified, and the macOS
      leg — the only place bash 3.2 and BSD userland are exercised — has
      not run since. This blocks confidence in every change, so it comes
      before the rest of this track.
- [ ] Assert bash 3.2 rather than assume it. The macOS leg does run
      3.2.57 today, but `ci.yml` only *prints* `bash --version`; scripts
      use `#!/usr/bin/env bash`, so a runner-image change would retire the
      portability guarantee with a green build.
- [ ] `install.sh` chmods `+x` inside the developer's own checkout
      (`:704-705`), and `tests/install.bats` runs the real installer ~25×
      per suite run. Harmless today — every such file is already
      executable — but a deliberately non-executable `*.sh` under a skill
      would have its mode flipped by running the tests, and the guard at
      `tests/install.bats:101` filters mode-only changes by design.
- [ ] `tests/helper.bash` never redirects `HOME` (only `install.bats`
      does), contra `CLAUDE.md`. No test escapes `$BATS_TEST_TMPDIR` today
      — verified by marker-file diff — but the defaults are one forgotten
      wrapper away from the real worktree root.
- [ ] Cover the server side of `cmd_loop` / `cmd_loop_run` / `cmd_rc`,
      `--uninstall --dry`, both jq-absent degrade paths, `vibe list`, and
      a *conflicting* `resume --rebase`. Strengthen four assertions that
      pass vacuously: `install.bats:172`, `vibe-loop.bats:100`,
      `hooks.bats:322`, `vibe-ui.bats:50`.
- [ ] Residual doc drift: `docs/vibe.md:170` (`--force` does not override
      the running-loop guard) · `project-status-scaffold/SKILL.md:29`
      (points at a template that is not there) ·
      `implement-test-suite/SKILL.md:13,103` (`codebase-healthiness` →
      `codebase-health`) · `docs/vibe-loop.md:20-29` (a fifth stop
      condition, diverged remote, is missing from the table).

## Open questions

- Agent Teams is still experimental in Claude Code; `team-up` targets
  subagents now and adopts teams once the experiment stabilises.
