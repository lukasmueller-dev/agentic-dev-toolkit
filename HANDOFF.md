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

Milestones 1 and 2 are done: `workspaces/deepscientist/`, `tests/ws-deepscientist.bats` (11 tests pass) and the recipe `docs/workspaces/deepscientist.md` (6 `## ` headings). The feature file ~/.local/state/vibe/features/workspaces.md holds the decisions and the contract.

## Next action

The third open milestone of `SPEC.md`, the end action `delete`: move each decision to `pr.md`, then `git rm SPEC.md HANDOFF.md` — done when `test ! -e SPEC.md -a ! -e HANDOFF.md`.

Decisions for `pr.md`:

- `--auth true` is fixed: without it the API takes shell input from anyone who reaches the port.
- The login token goes to `/ws/data/.ws-token` and `runtime/daemon.json` (mode 600); the page list shows the link without the token.
- The launch-card log is a temp file. The daemon prints the token into `logs/daemon.log`, so `start` links `/ws/data/logs` to `${TMPDIR:-/tmp}/ds-logs`: `pull` skips it. A place that follows links copies it.
- `run` and `steer` are scripts that `exit 3`: the runpod place maps a missing script to 3, the vast place does not (127).
- The image build runs `ds init`; `runtime/` lives in `/opt/ds-seed` and each `start` links it into `/ws/data/runtime`.
- `start` sets `PATH` and `IS_SANDBOX=1` itself, because an ssh exec channel may not carry the image `ENV`.
- The recipe names `vibe ws start|stop` and the place verbs `exec status` and `url` with `WS_INSTANCE`, `WS_STATE`, `WS_DIR`. `ws-surface` `SPEC.md` milestone 2 adds `vibe ws build|start|stop` and `workspaces/_places/turing`; they do not exist yet, and the feature PRs merge together. Check recipe steps 1, 3 and 4 and the stop line against the merged `bin/vibe` before the human test. `WS_DIR` is the workspace folder (the vast place copies it to `/ws/scripts`).

## Blockers

None. Two open questions for the user, both fixed by `SPEC.md`:

- `ports=20999,21000`: nothing in DeepScientist binds 21000 (help text only), and the place publishes it with no login. A quest agent could serve `/ws` there, secrets included. Drop it (conf, `tests/ws-deepscientist.bats`, last recipe bullet), or keep it?
- `.ws-token` duplicates `runtime/daemon.json`. `status` could read `daemon.json` and `start` drop the file and its test lines (about 8 lines). A hand-run `ds` on a running daemon rotates the token (`bin/ds.js:4963`) and leaves `.ws-token` stale: `status` then prints `down`. Keep the file, or drop it?

## Gotchas (unpromoted)

None.
