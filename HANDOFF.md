# Handoff — agentic-dev-toolkit / loop-prompt-file-setup

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and clear this file back to its headings: a finished task hands
> nothing off.

- **Repo:** agentic-dev-toolkit
- **Branch:** `loop-prompt-file-setup`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/loop-prompt-file-setup
- **Last updated:** 2026-07-20 · server (srv1841294)

## State

The `loop-brief` skill is implemented and green: `skills/loop-brief/`
(SKILL.md + brief.sh), the `ensure_worktree` remote-branch fix in `bin/vibe`,
tests (`tests/loop-brief.bats` plus adoption tests in vibe.bats /
vibe-loop.bats), and doc updates. Full suite passes (114/115; the one
"failure" is the skills/ guard flagging the then-uncommitted new files — green
after commit). shellcheck, shfmt, and `install.sh doctor` clean.

## Next action

Review the two commits, then open a PR to main. After merge, run
`./install.sh` in the main checkout so `~/.claude/skills/loop-brief` gets
linked.

## Blockers

None.

## Gotchas (unpromoted)

Running `bats tests/` on the VPS needs `env -u SSH_CONNECTION -u SSH_TTY -u
SSH_CLIENT -u VIBE_SERVER_HOSTNAME` — otherwise vibe detects "server" and the
tmux paths fire inside tests. CI is unaffected.
