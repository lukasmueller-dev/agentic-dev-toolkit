# Handoff — agentic-dev-toolkit / fix-handoff-start-bug

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fix-handoff-start-bug`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/fix-handoff-start-bug
- **Last updated:** 2026-07-23 17:07 UTC · server (srv1841294)

## State

Not started. Diagnosed live while running `codebase-review` round 1 on
`portfolio-site`: `vibe start fresh-review-1 --no-attach` created a tmux
session that looked empty on `vibe attach` — sitting at a bare prompt doing
nothing.

Root cause: `open_session()` in `bin/vibe` (line 1695) launches
`$VIBE_AGENT_CMD` (plain `claude`) with no prompt argument, from both
`cmd_start` (line 1644) and `cmd_attach` (line 1807) — they funnel through
this one function. The `claude/hooks/session-start-handoff.sh` `SessionStart`
hook only injects `HANDOFF.md`'s content as `additionalContext`; it never
submits a user turn. With `--no-attach` there is no tty for a human to type
the first message, so the agent sits idle indefinitely with the handoff
loaded but unread.

The manual workaround used live — `tmux send-keys -t <session> "<text>" C-m`
— needed a *second*, bare `C-m` afterward to actually submit; the first
Enter arrived before the freshly-launched TUI was reading stdin and just
landed as literal text in the input box. Do not replicate this race in the
fix.

Better mechanism, confirmed via `claude --help`: the CLI takes a positional
`[prompt]` argument (`claude [options] [prompt]`) that is submitted as the
session's first turn while staying interactive afterward. This sidesteps the
tmux-timing race entirely and works identically for a fresh tmux pane and a
local (non-tmux) `exec`.

Skill-level scope, already checked so this session doesn't have to re-derive
it:
- `codebase-review` (Phase 5) and `handoff-brief` (Phase 5, which only
  prints the `vibe start <task>` line for the user to run) both go through
  `open_session()` for their eventual launch — neither reimplements it, so
  the `bin/vibe` fix alone should make both work with no skill-file changes.
  Confirm this after the fix lands rather than assuming.
- `loop-brief` launches through `run_loop()`/`cmd_start`'s loop path, which
  is headless (`-p`) and always passes an explicit prompt per iteration
  already (`VIBE_AGENT_HEADLESS_ARGS`, line ~1112) — it does not look
  affected by this bug. Verify rather than assume; if it turns out to share
  the bug, extend the same fix there.

## Next action

1. `git rebase origin/main`.
2. Read `open_session()` (bin/vibe:1695) and `handoff_carries_content()`
   (bin/vibe:1635) — the launch function to fix and the existing
   template-vs-real-content check to reuse.
3. Implement: when a session is about to start genuinely fresh — a brand
   new tmux session (`tmux_ensure_session`, line 495), the "agent not
   running there" relaunch branch inside `open_session` *when
   `VIBE_AGENT_RESUME_ARGS` is not in play*, and the local non-tmux `exec`
   branch — and `handoff_carries_content "$dir/HANDOFF.md"` is true, append
   a fixed kickoff prompt (`Begin per HANDOFF.md.`) as a genuine argv
   element to the agent invocation, not string-concatenated, so `claude`
   receives it as its `[prompt]` positional and submits it as the first
   turn. Do not send it when resuming an existing conversation, or when the
   handoff is only the empty template.
4. Check `tests/` for an existing harness that execs a fake agent and
   inspects argv — extend it rather than adding a parallel one.
5. Verify end to end: `vibe start <throwaway> --no-attach` against a
   worktree with a real `HANDOFF.md`, then `vibe attach` and confirm the
   agent is already acting instead of sitting at an idle prompt; separately
   confirm a worktree whose `HANDOFF.md` is only the template scaffold gets
   no auto-kickoff.
6. Skim `codebase-review`'s and `handoff-brief`'s `SKILL.md` for any prose
   that documents "attach and type a message to kick it off" as a manual
   step, and correct it now that it happens automatically.

## Blockers

None known.

## Gotchas (unpromoted)

- The tmux double-`C-m` race described above under State — the fix avoids
  it by using the CLI's own `[prompt]` argument instead of typing into the
  pane after launch; if a future change goes back to `send-keys` for some
  reason, this race returns with it.
- `open_session()` is the single choke point for `cmd_start` *and*
  `cmd_attach` — a fix must hold for both call sites, including the
  "relaunch a dead agent" branch inside `open_session` itself.
