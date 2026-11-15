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

Milestones 1 to 3 of `SPEC.md` are done. A `tool=` job runs the hidden `vibe ws run <tool>-<job id>` in place of a first session, then a closing session with `skills/fill-queue/references/tool-run.md` at the prompt's end. `vibe queue steer` exists. `tests/vibe-queue.bats -f tool` has 9 tool tests.

## Next action

The next open milestone of `SPEC.md`: the "tool run" route of `/enqueue`, the page list, the docs, the layout row in `CLAUDE.md`, the completion — code — done when `./bin/skill-lint --strict skills` and `bats tests/vibe-web.bats tests/vibe-queue.bats` pass and `grep -c 'workspaces/' CLAUDE.md` prints 1 or more.

## Blockers

None.

## Gotchas (unpromoted)

- The `/enqueue` route writes `tool=`, `place=`, `hours=` in the job file and `in/brief.md`, `in/args` in the job dir. `job_prepare` adds `output=report` for `result=folder`.
- No doc names `vibe queue steer`, the tool job flow or `tool-run.md` yet → `docs/vibe-queue.md`, `docs/workspaces.md`, a link from the `/enqueue` skill.
- The completions lack `steer` in the queue verbs → `completions/vibe.bash`, `completions/_vibe`.
- Follow-ups of a tool job: retry runs the tool again with `in/`; answer closes the same run; fix, review rounds and GPU follow-ups run no tool.
- `tool_unsafe` refuses a bundle that changes agent or git config (`.claude/`, `CLAUDE.md`, `.github/` …) → name a new config path there.
- A `runs=host` run is outside the job's memory scope (`MEM_CMD`).
- `shfmt -f .` in a sandboxed job fails on `.claude/` placeholders (`permission denied`) → lint in a `git clone` under `$TMPDIR`.
- `git add -A` fails on the sandbox placeholders (`.bash_profile`) → add files by name.
