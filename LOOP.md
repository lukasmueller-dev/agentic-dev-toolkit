# Loop — agentic-dev-toolkit / babysit-pr

> A task run unattended: each round an agent works toward the goal below, then
> a stop check decides whether it is done. This document is the brief the agent
> is handed every round, so keep the goal and done-criteria precise — they are
> the only instructions it gets.

- **Repo:** agentic-dev-toolkit
- **Branch:** `babysit-pr`
- **Worktree:** `/root/git/worktrees/agentic-dev-toolkit/babysit-pr`
- **Started:** 2026-07-21 16:28 UTC · server (srv1841294)
- **Stop check:** `test -f docs/babysit-pr.md && skill-lint --strict skills/ && bats tests/babysit-pr.bats && shfmt -d -i 2 -ci . && shfmt -f . | xargs shellcheck`
- **Max rounds:** 10

## Goal

Add `skills/babysit-pr/`, a portable skill that *stages a brief* for an
unattended loop that drives a pull request to mergeable — it never watches or
polls a PR itself. Given a PR number it renders a `LOOP.md` from
`templates/LOOP.md` through the shared helpers in `skills/_lib/vibe-lib.sh`,
exactly the way `skills/loop-brief/brief.sh` does (that script is the model to
follow: `create` renders and seeds, `publish` validates, commits and pushes,
and the refined prose never crosses the argv boundary). The rendered brief's
Goal is "PR #N is mergeable", its Done-when is that PR's CI and review state,
and its `--until` invokes a bundled `skills/babysit-pr/pr-ready.sh <N>`.

`pr-ready.sh <N>` exits 0 only when `gh pr checks <N>` reports no failing and
no pending checks **and** the PR has zero unresolved review threads — read via
`gh api graphql` over `pullRequest { reviewThreads { nodes { isResolved } } }`
and counted with `jq`. It exits non-zero on anything else, *including* `gh`
being absent, unauthenticated, or erroring: a broken environment must never
read as "done" and end the loop early.

The skill commits and pushes the brief and prints the `vibe loop … --no-attach`
start command. It must never start the loop, and never merge, close, review, or
comment on the PR. Escalation to the phone is the existing ntfy hook
(`claude/hooks/notify-ntfy.sh`, `docs/notifications.md`) — reference it, do not
reimplement it.

Ship `tests/babysit-pr.bats` covering `pr-ready.sh` against a stub `gh` placed
early on `PATH` (clean PR → 0; failing check → non-zero; pending check →
non-zero; unresolved review thread → non-zero; `gh` missing or erroring →
non-zero) plus the staging script's `create`/`publish` paths, and a
`docs/babysit-pr.md` narrative page. Finally tick the `skills/babysit-pr`
checkbox under Track A in `PROJECT_STATUS.md`.

## Done when

This command, run from the worktree root, exits 0:

```
test -f docs/babysit-pr.md && skill-lint --strict skills/ && bats tests/babysit-pr.bats && shfmt -d -i 2 -ci . && shfmt -f . | xargs shellcheck
```

It proves all four deliverables landed together: the docs page exists, the new
`SKILL.md` clears the mechanical half of the skill quality bar
(`docs/skill-quality.md`), the skill's own bats suite passes, and every shell
file in the repo — including the two new ones — is `shfmt -i 2 -ci` formatted
and shellcheck-clean. It exits 1 today, on the missing docs page.

## Constraints

- **Portable half only.** `SKILL.md`'s description and body must not name
  Claude Code or any other specific agent; `gh` and `jq` are the only external
  dependencies. The skill belongs in top-level `skills/`, never `claude/`.
- **Never embed a document in a heredoc.** The rendered brief comes from
  `templates/`. Do not edit `templates/LOOP.md`, `skills/loop-brief/`,
  `bin/vibe`, `install.sh`, or `claude/settings.json` — the installer
  auto-discovers a new `skills/<name>/` directory with no change to it.
- **bash 3.2 and BSD + GNU userland.** No `mapfile`, no associative arrays, no
  `${var,,}`, no `readlink -f`. Any script resolves its own location with the
  `script_dir()` symlink walk, because it is reached through a symlink in the
  agent's skills directory.
- **Tests never touch the network or the real `$HOME`.** `gh` is always a stub
  under `$BATS_TEST_TMPDIR`; no test may call the real GitHub API or write to
  the real skills directory, `~/bin`, or the worktree root.
- **Never run `vibe loop`**, `gh pr merge`, `gh pr comment`, `gh pr review`, or
  push to `main`. All work stays on the `babysit-pr` branch.
- `disable-model-invocation: true` in the frontmatter — the skill commits and
  pushes, so it is invoked deliberately, never auto-triggered.

## Iteration log

_One line per round that changed something, newest last._
