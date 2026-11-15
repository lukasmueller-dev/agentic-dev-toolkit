# Handoff — agentic-dev-toolkit / ws-place-runpod

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-place-runpod`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-place-runpod
- **Last updated:** 2026-11-15 · turing

## State

Milestone 1 is done: `workspaces/_places/runpod` and `tests/ws-place-runpod.bats` (10 tests, all pass). The script header lists its config keys.

## Next action

The second milestone of `SPEC.md`: the recipe `docs/workspaces/place-runpod.md` (requirements, numbered steps, verify, what breaks it) — code — done when `grep -c '^## ' docs/workspaces/place-runpod.md` prints 4 or more. Put each gotcha below into the recipe.

## Blockers

None.

## Gotchas (unpromoted)

- Config: `~/.config/vibe/places/runpod.env`, mode 600, `RUNPOD_GPU_ID` (needed), `RUNPOD_API_KEY` (else `~/.runpod/config.toml`), `RUNPOD_CLOUD_TYPE`, `RUNPOD_DISK_GB`, `RUNPOD_WAIT`, `RUNPOD_POLL`.
- The image must start sshd from its entrypoint (key from `PUBLIC_KEY`) and hold rsync: `--docker-args "sleep infinity"` replaces the CMD.
- `up` copies `$WS_STATE/in/` to `/ws/in/` and fails a `kind=run` without it; the contract names no source for `/ws/in`.
- `runpodctl` output formats come from its source, not a real run. The recipe's first verify step creates a pod on the cheapest GPU, checks that `.id` is not empty, runs `runpodctl ssh info <id>` (`ip`, `port`, `ssh_key.path`), checks that `runpodctl pod list` is a JSON array with `id` and `name`, then deletes the pod. `gone` and the cleanup after a failed create read that list.
- `url`: `ControlPath too long` when `$WS_STATE/tunnel.sock` is over 104 characters → keep service instance names short.
- A dropped ssh ends a long `exec run`: the remote command gets SIGPIPE.
- Last money stop (spec decision): prepaid credit, auto-pay off.
- Open for the user (review 2, finding 4): at the limit, `down` pulls with no time bound before the delete. A bound trades the last data for money and frees the runner pass.
