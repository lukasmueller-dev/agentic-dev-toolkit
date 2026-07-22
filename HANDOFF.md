# Handoff — agentic-dev-toolkit / agentic-dev-sota

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `agentic-dev-sota`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/agentic-dev-sota
- **Last updated:** 2026-07-22 19:41 UTC · server (srv1841294)

## State

Not started. The design was settled in the `feat-roadmap` session
(2026-07-22) and is recorded as the Track S item in `PROJECT_ROADMAP.md` —
that file lands with the `feat-roadmap` PR; until it merges, read it from
the `feat-roadmap` branch.

Decided, with rejected alternatives:

- A weekly unattended run surveys the state of the art in agentic
  development and opens a PR: branch `sota/<YYYY-Www>` from `main`, digest
  at `docs/sota/<YYYY-Www>.md`, containing 1–3 recommendations, each
  formatted as a ready-to-add roadmap item and diffed against
  `PROJECT_ROADMAP.md` and `PROJECT_STATUS.md` decisions, so nothing
  already planned or previously rejected is re-proposed.
- Runtime: a cron entry on a server machine launching a headless agent
  session inside tmux, in a dedicated worktree. Rejected: a scheduled
  cloud routine — no toolkit install there, and interactively
  authenticated integrations are unreliable headless.
- Notification: the PR-opened email from the git host is the "digest is
  there" signal. Rejected: mail-provider integration (interactive auth
  only), ntfy email forwarding and server-side SMTP (new infrastructure
  for no gain).
- Review gate: merging the PR. Accepted recommendations are promoted via
  the `add-roadmap-item` skill; the digest file stays as the record.
  Digests are prunable dated files.
- Pieces: a **repo-local** `.claude/skills/sota-digest/` skill holding the
  brief (source list, digest format, recommendation bar) — repo-local so
  the installer never ships it to other machines — plus a small cron
  wrapper script and a `docs/` page on enabling the cron entry.

Done when: a manually-triggered run produces a digest PR end to end on the
server, and the cron entry is documented and installed on one machine.

## Next action

Verify the enabling assumption before building anything: on the server, run
a one-shot headless agent session with a prompt that can only be answered
by live web search (e.g. "what is the latest released version of X") and
confirm search works unattended. If it does not, switch the design's sweep
step to fetching a fixed list of source URLs (changelogs, release feeds)
directly, and record that change in the roadmap item.

## Blockers

None hard. The `feat-roadmap` PR (roadmap file + `add-roadmap-item` skill)
is unmerged; only the promotion step depends on it, so building can start
regardless.

## Gotchas (unpromoted)

- When last week's digest PR is still open, open the new PR anyway and
  link the open one — never silently skip a run.
- The cron wrapper must survive having no tty, and must not collide with
  an existing `sota/<week>` worktree left by a crashed run.
