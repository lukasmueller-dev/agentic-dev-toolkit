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

Track S — SOTA watch (this repo only, nothing installed globally):

- [ ] `agentic-dev-sota` weekly digest: an unattended weekly run that
      surveys the state of the art in agentic development and proposes
      toolkit work as a reviewable PR.
      **Runtime:** a cron entry on a server machine launches a headless
      agent session inside tmux (survives disconnects), in a dedicated
      worktree — chosen over a scheduled cloud routine because the server
      has the full toolkit and repo, and cloud runs cannot rely on
      interactively-authenticated integrations.
      **Flow per run:** branch `sota/<YYYY-Www>` from `main` → web-search
      sweep over a maintained source list (agent-CLI changelogs and
      releases, vendor blogs and model announcements, MCP ecosystem,
      community discussion) → read `PROJECT_STATUS.md` and
      `PROJECT_ROADMAP.md` so proposals are diffed against existing items
      and recorded decisions → write `docs/sota/<YYYY-Www>.md`: the digest
      plus 1–3 recommendations, each formatted as a ready-to-add roadmap
      item → commit, push, open a PR.
      **Notification:** GitHub's own PR email is the "digest is there"
      signal — no new email infrastructure. Rejected: Gmail integration
      (interactive auth only, silently absent in scheduled runs), ntfy
      email forwarding and server-side SMTP (new infrastructure for no
      gain over the PR email).
      **Review gate:** merging the PR. Accepted recommendations are
      promoted into `PROJECT_ROADMAP.md` via `add-roadmap-item`; the
      digest file remains as the record. Digests are prunable dated files.
      **Pieces:** a repo-local `.claude/skills/sota-digest/` skill holding
      the brief (source list, digest format, recommendation bar) — repo-
      local so the installer never ships it to other machines — plus a
      small cron wrapper script and a `docs/` page on enabling the cron
      entry.
      **Verify before building:** web search availability in a headless
      run; behavior when last week's PR is still open (recommendation:
      open the new PR anyway and link the open one).
      **Done when:** a manually-triggered run produces a digest PR end to
      end on the server, and the cron entry is documented and installed on
      one machine.
