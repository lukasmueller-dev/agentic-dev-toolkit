# Handoff — agentic-dev-toolkit / fix-attach-bug

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fix-attach-bug`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/fix-attach-bug
- **Last updated:** 2026-07-23 05:20 UTC · server (srv1841294)

## State

`vibe attach` on the server now starts the agent again when it finds the task's
tmux session alive but its pane back at a shell, and says "already in this
session" instead of no-op'ing a `switch-client` onto the session you are
already in. `VIBE_AGENT_RESUME_ARGS` (unset by default) makes that restart
continue the previous conversation instead of opening an empty one. Four new
tests in `tests/vibe.bats`; full suite green (325), shellcheck and shfmt clean.

## Next action

Open the PR and merge. Then decide whether to set
`VIBE_AGENT_RESUME_ARGS=--continue` on this machine — there is no
`~/.config/vibe/config` here yet, so it means creating one from
`templates/vibe.config.example`.

## Blockers

None.

## Gotchas (unpromoted)

- `claude --continue` resumes the most recent conversation for the pane's
  *directory*, and a headless `vibe park` or `vibe loop` round in the same
  worktree writes a transcript there too — so a restart can resume a one-shot
  run rather than the interactive session. Documented in
  `templates/vibe.config.example`; the real fix is vibe recording the
  interactive session id and using `--resume <id>`, not worth building until
  it actually bites.
- A tmux session that has just been killed still answers
  `display-message -p '#{pane_current_command}'` with an empty string and
  exit 0 — it is not an existence check. Noted at the helper in `bin/vibe`.
