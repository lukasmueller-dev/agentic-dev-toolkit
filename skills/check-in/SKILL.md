---
name: check-in
description: "Morning check-in on the night's agent jobs: reads today's briefing, proposes one action per job that needs a human or has a PR ready — merge, answer and requeue, take into a daytime session, close — shows the whole table grouped by repo, then walks the repos one at a time and carries out only the actions the user approves, then plans the day shift: the night shift, stopped by 12:30. Use when the user says 'check in', 'morning check-in', 'go through the briefing', 'what did the night do', or starts the day and wants the night's results triaged."
disable-model-invocation: true
---

# Check-in

Morning: turn the briefing into decisions, carry them out, list what the
day's sessions should take, start the day shift. Briefing, night and day
shift layout: `docs/night-shift.md` in the toolkit.

## Hard boundaries — never do these

- **Never merge, close, comment or push without approval of that repo's rows.**
- **Never merge a PR whose checks fail**, or one the user has not seen the TL;DR of.
- **Never merge a PR whose diff still holds `SPEC.md` or `HANDOFF.md`.**
- **Never change code.** You edit only a job's `HANDOFF.md`, with the user's words.
- **Never start a session.** The day plan is a list; the user starts the work.
- **Never start the day shift without approval of its table.**

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
| `requeue` | blocked on a decision the user can give now | writes the answer into the job's `HANDOFF.md`, commits, pushes; the day shift or the agent-shift sweep picks it up |
| `day` | needs a human: review a big diff, hardware, judgment | goes on the day plan |
| `close` | wrong direction or superseded | `gh pr close` with a one-line reason |
| `log` | `failed`, `timeout` | read the log tail; propose one of the actions above with the cause |

Show the whole action table first, grouped by repo like the briefing: one
`### <repo>` heading per repo, then its rows as `# · job · status · context ·
TL;DR · action · why`. Do not ask for approval yet.

## Phase 3 — Walk each repo

Take the repos one at a time, in table order. For each repo:

1. Show its rows again with the full context of each: the `Context` line,
   the TL;DR, the Verify line of a PR, and the blocker of a blocked job.
2. For a `requeue` row, ask the question the job is blocked on.
3. **Stop and wait for approval of this repo's rows.** Apply every change the
   user asks for, then show the rows again.
4. Carry out the approved rows top to bottom. Report each one as one line. A
   failed command stops that row only: report the error and go on.

Then go to the next repo.

For `requeue`: under `## Next action` and `## Blockers` of the job's
`HANDOFF.md`, put the user's answer in place of the block. Commit
`docs(handoff): <job> unblocked` and push the job's branch.

Merged and closed branches keep their worktrees: `/worktree-cleanup` removes them.

## Phase 4 — Day shift

First, every approved `merge` row must be merged: the sweep reads the
roadmaps on main, and new jobs branch from main. For a merge the user does,
ask and wait until the user says it is done.

Then read `../agent-shift/SKILL.md` and do every phase of it with the argument `day`.
Its sweep finds the `requeue` answers as handoff next actions. Its approval
table is the day shift's. The user declines → go to Phase 5.

## Phase 5 — Day plan

List the `day` rows, then each handoff next action in the active repos that
names a person or needs a session (`../agent-shift/sweep.sh`, its "handoffs"
part). One line each: repo · task · first step.

## Done

Done when every repo is walked and its approved rows are carried out, the day shift is started or
declined, and the day plan is shown. Report in at most 6 lines: merged,
requeued, closed, day shift jobs, the day plan count, and `Decisions/risks:`.
