# Handoff — agentic-dev-toolkit / ws-surface

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ws-surface`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/ws-surface
- **Last updated:** 2026-11-15 · turing

## State

Milestones 1 to 5 of `SPEC.md` are done. A `tool=` job runs the hidden `vibe ws run <tool>-<job id>` in place of a first session, then a closing session with `skills/fill-queue/references/tool-run.md` at the prompt's end. `/enqueue` has route Tool run; the queue page lists `vibe ws status` under `Tools`. With `steer=1` in `queue.conf`, `vibe queue steer` reaches any running session through the FIFO `<job>/steer`; else a tool job's run.

## Next action

The last milestone of `SPEC.md`: the end action — one line in `PROJECT_STATUS.md`, each decision into `pr.md` — done when `test ! -e SPEC.md -a ! -e HANDOFF.md` and `grep -c workspaces PROJECT_STATUS.md` prints 1 or more.

## Blockers

None.

## Gotchas (unpromoted)

- `steer=1` ran against the stub `claude` only → a human runs one real job with `vibe queue conf steer=1` and steers it.
- `claude/vibe-job.sh` with a FIFO: a stop or a time limit reaches claude through timeout(1)'s process-group TERM only → without timeout(1) a stop ends the hook's shell, not claude.
- Claude's result event has `"type":"result"` mid-line, not first → match it anywhere in the line.
- Follow-ups of a tool job: retry runs the tool again with `in/`; answer closes the same run; fix, review rounds and GPU follow-ups run no tool.
- `tool_unsafe` refuses a bundle that changes agent or git config (`.claude/`, `CLAUDE.md`, `.github/` …) → name a new config path there.
- A `runs=host` run is outside the job's memory scope (`MEM_CMD`).
- The zsh completion has no `queue` verbs; it got `ws` only.
- `bats -j 8` over `tests/vibe-queue.bats` fails 5 review and verify tests under load → run that file without `-j`.
- `shfmt -f .` in a sandboxed job fails on `.claude/` placeholders (`permission denied`) → lint in a `git clone` under `$TMPDIR`.
- `git add -A` fails on the sandbox placeholders (`.bash_profile`) → add files by name.
