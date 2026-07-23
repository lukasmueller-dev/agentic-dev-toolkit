# Project Roadmap — agentic-dev-toolkit

> Long-lived, one per repo. Planned work only: one item per task, each
> designed well enough that a session can pick it up cold, without the
> discussion that produced it. A snapshot, not a log — finished items are
> removed; their trail lives in git history and merged PRs.

_Last updated: 2026-07-22 · server (srv1841294)_

## Items

One item per PR — sized so a `HANDOFF.md` (the `handoff-brief` skill) or a
`LOOP.md` (the `loop-brief` skill) can be staged straight from it. Order
matters within a track; tracks are independent.

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
- [ ] Decide whether `install.sh` should prune orphaned symlinks. It
      rebuilds its link map from the repo on every run, so a *renamed*
      skill leaves the old link behind pointing at a directory that no
      longer exists — `~/.claude/skills/review-brief` after the
      `codebase-review` rename is the live example, and Claude Code scans
      that directory. `doctor` reports dangling links only for paths still
      in the map, so an orphan is invisible to it. The reason this is a
      decision and not a bug fix: pruning means deleting a symlink the
      current repo does not know about, which is exactly the authority
      `--uninstall`'s ownership check exists to constrain — resolve each
      candidate and skip anything not pointing back into the checkout. Add
      a test alongside the existing ownership one. Until this lands, a
      rename needs manual cleanup on every machine.
