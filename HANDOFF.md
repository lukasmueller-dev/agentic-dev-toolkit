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

Milestones 1 to 4 of `SPEC.md` are done. A `tool=` job runs the hidden `vibe ws run <tool>-<job id>` in place of a first session, then a closing session with `skills/fill-queue/references/tool-run.md` at the prompt's end. `vibe queue steer` takes a tool job only. `/enqueue` has route Tool run; the queue page lists `vibe ws status` under `Tools`; `docs/vibe-queue.md` has `## Tool jobs`.

## Next action

The next open milestone of `SPEC.md`: steer for plain jobs — code — done when `bats tests/vibe-queue.bats -f steer` passes: with `steer=` unset the agent's argv is unchanged; with `steer=1` the stub agent receives the text of `vibe queue steer`.

## Blockers

None.

## Gotchas (unpromoted)

- `cmd_queue_steer` (`bin/vibe`) dies on a job with no `tool=` → the plain-job branch goes there, behind `steer=1` in `queue.conf`.
- Follow-ups of a tool job: retry runs the tool again with `in/`; answer closes the same run; fix, review rounds and GPU follow-ups run no tool.
- `tool_unsafe` refuses a bundle that changes agent or git config (`.claude/`, `CLAUDE.md`, `.github/` …) → name a new config path there.
- A `runs=host` run is outside the job's memory scope (`MEM_CMD`).
- The zsh completion has no `queue` verbs; it got `ws` only.
- `bats -j 8` over `tests/vibe-queue.bats` fails 5 review and verify tests under load → run that file without `-j`.
- `shfmt -f .` in a sandboxed job fails on `.claude/` placeholders (`permission denied`) → lint in a `git clone` under `$TMPDIR`.
- `git add -A` fails on the sandbox placeholders (`.bash_profile`) → add files by name.
