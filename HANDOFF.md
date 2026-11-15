# Handoff — agentic-dev-toolkit / ws-deepscientist

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-deepscientist`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-deepscientist
- **Last updated:** 2026-11-15 · turing

## State

Milestone 1 is done: `workspaces/deepscientist/` (conf, Dockerfile, `start`, `stop`, `status`) and `tests/ws-deepscientist.bats` (11 tests pass). The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The second open milestone of `SPEC.md`: the recipe `docs/workspaces/deepscientist.md` — requirements, numbered steps, verify, what breaks it — done when `grep -c '^## ' docs/workspaces/deepscientist.md` prints 4 or more.

Facts the recipe needs:

- First check: the Claude runner works from `CLAUDE_CODE_OAUTH_TOKEN` alone, with no `~/.claude` login file.
- `status` prints `up — /?token=<token>`: a path, not a host. Add the address from the place's `url` verb.
- The image build runs `ds init`; `runtime/` moves to `/opt/ds-seed/runtime`; each `start` links its entries into `/ws/data/runtime`.
- `pull` copies links, not the Python env. A place that dereferences links copies the env again.
- `start` keeps the launch-card log out of `/ws/data`. The token is in `.ws-token` and `runtime/daemon.json`, both mode 600.
- Trap: `IS_SANDBOX=1` in the image lets Claude Code run as root; without it the runner refuses all permissions.
- Trap: `run` and `steer` have no script; the surface must treat a missing script as exit 3.

## Blockers

None. One open question for the user: `workspace.conf` has `ports=20999,21000`, as `SPEC.md` decides. Nothing in DeepScientist binds 21000 (help text only). Drop it, or keep it?

## Gotchas (unpromoted)

None.
