# Handoff — agentic-dev-toolkit / ws-place-vast

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-place-vast`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-place-vast
- **Last updated:** 2026-11-15 · turing

## State

Milestone 1 is done: `workspaces/_places/vast` and `tests/ws-place-vast.bats` (5 tests, stub `vastai`, `ssh`, `rsync`). The commit body of `feat(workspaces): add the vast place script` holds the reasons.

## Next action

The next open milestone of `SPEC.md`: the recipe `docs/workspaces/place-vast.md`. Done when `grep -c '^## ' docs/workspaces/place-vast.md` prints 4 or more.

## Blockers

None.

## Gotchas (unpromoted)

Facts for the recipe, read in the `vastai` 1.11.0 source, not run:

- `destroy instance` without `-y` asks, then prints `Aborted.` and exits 0. The script passes `-y`; the recipe pins `vastai` 1.11.0 or newer.
- `vastai` exits 0 on an HTTP error. The script reads the JSON instead.
- `vastai copy` ignores the exit code of its `rsync`. The script copies with `rsync` over ssh, so the image needs `rsync`.
- The account needs an ssh key (`vastai create ssh-key`) and an API key (`vastai set api-key`). The script passes neither.
- Settings in `~/.config/vibe/workspaces/<name>.env`: `VAST_QUERY` (default `num_gpus=1 cpu_arch=amd64`), `VAST_DISK` (GB, default 50).
- `url` binds the tunnel to `tailscale ip -4` on the first port. The same port in use on turing fails the tunnel.
- `/ws/in` comes from `$WS_STATE/in`. The contract names no source; `ws-surface` must write it there.
- Recovery: `vastai show instances` lists a leaked instance by its label, the instance name.
