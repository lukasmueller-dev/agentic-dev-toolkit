---
name: shutdown
description: "End-of-day shutdown across the active repos: pushes every task branch, finds worktrees with uncommitted work or a missing or stale HANDOFF.md, gets each one handed off, then plans and starts the night shift. Use when the user says 'shutdown', 'end of day', 'wrap up the day', 'call it a day', or stops work and wants every session handed off before the night runs."
disable-model-invocation: true
---

# Shutdown

Evening: leave every worktree pushed and handed off, then start the night.
The night half is the `agent-shift` skill; this skill runs it last.

## Hard boundaries — never do these

- **Never commit, stash or discard uncommitted work without approval of the worktree table.**
- **Never write a handoff from memory.** Write it from the worktree's diff, its log and the user's words.
- **Never write a handoff for a worktree whose session is open.** That session holds the context; ask it.
- **Never stop the machine, an agent server or a session.** "Shutdown" ends the user's day, nothing else.

## Phase 1 — Survey

1. Run `vibe sync --all` outside the sandbox. It pushes committed task
   branches and prints one line per worktree: state, repo/worktree, branch, notes.
2. For each worktree line other than the main checkout, `merged` and
   `missing`, get its path from `git -C <repo> worktree list`, then the handoff state:

   ```bash
   git -C <wt> log -1 --format=%ct -- HANDOFF.md   # empty: never committed
   git -C <wt> log -1 --format=%ct                  # newest commit
   ```

   `none` — no `HANDOFF.md` and the branch has commits; `stale` — newer
   commits than the handoff's; `fresh` — else.

## Phase 2 — Propose

Keep the worktrees that are `dirty`, `local`, or have handoff `none` or
`stale`. One action per worktree:

| Action | When | Does |
| --- | --- | --- |
| `session` | its session is open | the user sends it: `Update HANDOFF.md, commit and push.` |
| `wip` | no session holds it | handoff from the diff and log, `wip:` commit, push |
| `leave` | not for tonight | nothing; the agent-shift gate skips a dirty worktree |

Show one table: `# · worktree · branch · state · handoff · action`. Ask which
sessions are open. **Stop and wait for approval.** Apply every change the user
asks for, then show the table again.

## Phase 3 — Hand off

1. `wip` rows, one by one:
   1. Read `git -C <wt> status`, `git -C <wt> diff` and the branch's log since the default branch.
   2. No `HANDOFF.md`: run `../project-status-scaffold/scaffold.sh` in the worktree.
   3. Overwrite `## State`, `## Next action` and `## Blockers`.
      Mark a guess about intent as `(from the diff)`.
   4. `git -C <wt> add -A`, commit `wip: <what is half done>`, push.
2. `session` rows: wait until the user says they are done.
3. Run Phase 1 again. Show only the rows that changed.

## Phase 4 — Night

Read `../agent-shift/SKILL.md` and run its phases 0–6. Its approval gate
holds: show its table and wait. If the user declines the night, stop there.

## Done

Done when every row is handed off or `leave`, and the night started or the
user declined it. Report in at most 6 lines: handed off, left, the night's
job count and deadline, and `Decisions/risks:`.
