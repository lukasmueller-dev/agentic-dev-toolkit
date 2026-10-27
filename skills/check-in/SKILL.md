---
name: check-in
description: "Morning check-in on the night's agent jobs: reads today's briefing, proposes one action per job that needs a human or has a PR ready — merge, answer and requeue for tonight, take into a daytime session, close — and carries out only the actions the user approves. Use when the user says 'check in', 'morning check-in', 'go through the briefing', 'what did the night do', or starts the day and wants the night's results triaged."
disable-model-invocation: true
---

# Check-in

Morning: turn the briefing into decisions, carry them out, list what the
day's sessions should take. Briefing and night layout: `docs/night-shift.md`
in the toolkit.

## Hard boundaries — never do these

- **Never merge, close, comment or push without approval of the action table.**
- **Never merge a PR whose checks fail**, or one the user has not seen the TL;DR of.
- **Never change code.** You edit only a job's `HANDOFF.md`, with the user's words.
- **Never start a session or a night.** The day plan is a list; the user starts the work.

## Phase 1 — Read

1. Read `${XDG_STATE_HOME:-~/.local/state}/night-shift/briefings/<today>.md`.
   No file: run `vibe night report`, then read it.
2. For each row under "Needs you" and "PR ready", read what the row links:
   the job's `report.md`, the `## <night>/<job>` block (next action, blockers),
   and for a PR `gh pr view <url> --json title,body,isDraft,statusCheckRollup`.
   If `gh` fails, run it again outside the sandbox.

## Phase 2 — Propose

One action per row:

| Action | When | Does |
| --- | --- | --- |
| `merge` | PR ready, checks pass or none, Verify line is a quick look | `gh pr ready`, then `gh pr merge` with the method of the repo's last merges |
| `tonight` | blocked on a decision the user can give now | writes the answer into the job's `HANDOFF.md`, commits, pushes; the night-shift sweep picks it up |
| `day` | needs a human: review a big diff, hardware, judgment | goes on the day plan |
| `close` | wrong direction or superseded | `gh pr close` with a one-line reason |
| `log` | `failed`, `timeout` | read the log tail; propose one of the actions above with the cause |

Show one table: `# · job · status · TL;DR · action · why`. For a `tonight`
row, ask the question the job is blocked on. **Stop and wait for approval.**
Apply every change the user asks for, then show the table again.

## Phase 3 — Carry out

Work the approved rows top to bottom. Report each one as one line. A failed
command stops that row only: report the error and go on.

For `tonight`: under `## Next action` and `## Blockers` of the job's
`HANDOFF.md`, put the user's answer in place of the block. Commit
`docs(handoff): <job> unblocked` and push the job's branch.

Merged and closed branches keep their worktrees: `/worktree-cleanup` removes them.

## Phase 4 — Day plan

List the `day` rows, then each handoff next action in the active repos that
names a person or needs a session (`../night-shift/sweep.sh`, its "handoffs"
part). One line each: repo · task · first step.

## Done

Done when every approved row is carried out and the day plan is shown.
Report in at most 6 lines: merged, requeued, closed, the day plan count, and
`Decisions/risks:`.
