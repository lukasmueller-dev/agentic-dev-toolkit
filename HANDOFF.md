# Handoff — agentic-dev-toolkit / feat-roadmap

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `feat-roadmap`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/feat-roadmap
- **Last updated:** 2026-07-22 · server (srv1841294)

## State

The roadmap feature is complete and verified: `templates/PROJECT_ROADMAP.md`,
scaffold support in `project-status-scaffold` (script + skill), the new
`add-roadmap-item` skill, routing updates in `memory/GLOBAL.md` and
`docs/artifact-architecture.md`, CI's template-neutrality guard extended,
and this repo migrated (planned work now in `PROJECT_ROADMAP.md`; finished
tracks removed). New `tests/scaffold.bats` covers the scaffold; full suite,
shellcheck, shfmt and skill-lint pass.

The `agentic-dev-sota` weekly digest is scoped, not built — its full design
(server cron + headless run, digest PR as both artifact and email
notification) is the Track S item in `PROJECT_ROADMAP.md`.

## Next action

Open the PR for this branch. After merge: run `./install.sh` on each machine
so `add-roadmap-item` gets linked, then stage the Track S sota item
(`handoff-brief` from the roadmap entry) when ready to build it.

## Blockers

None.

## Gotchas (unpromoted)

`./install.sh doctor` run from this worktree reports every symlink as "not
ours" — the live links point at the main checkout, which is correct; only a
doctor run from `~/git/github/agentic-dev-toolkit` is meaningful.
