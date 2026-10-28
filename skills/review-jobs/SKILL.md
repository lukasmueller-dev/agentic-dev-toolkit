---
name: review-jobs
description: "Reviews the finished agent jobs in the queue: writes a fresh briefing, proposes one action per job that needs a human or has a PR ready — merge, answer and requeue, hold for the user, close, archive — shows the table grouped by repo, then walks the repos one at a time and carries out only the actions the user approves. Use when the user says 'review the jobs', 'what did the agents do', 'go through the briefing', 'merge the agent PRs', or wants the queue's results triaged."
disable-model-invocation: true
---

# Review jobs

Turn the finished jobs into decisions and carry them out. Queue layout and
briefing: `docs/vibe-queue.md` in the toolkit.

## Hard boundaries — never do these

- **Never merge, close, comment, push or archive without approval of that repo's rows.**
- **Never merge a PR whose checks fail**, or one the user has not seen the TL;DR of.
- **Never merge a PR whose diff still holds `SPEC.md` or `HANDOFF.md`.**
- **Never change code.** You edit only a job's `HANDOFF.md`, with the user's words.
- **Never archive a row you did not carry out.** A skipped row stays for the next review.

## Phase 1 — Read

1. Run `vibe queue report` outside the sandbox. Read the briefing it printed.
2. For each row under "Yours", "Needs you" and "PR ready", read what the row links:
   the job's `report.md`, the `## <job>` block (next action, blockers),
   and for a PR `gh pr view <url> --json title,body,isDraft,statusCheckRollup`.
   If `gh` fails, run it again outside the sandbox.

## Phase 2 — Propose

One action per row:

| Action | When | Does |
| --- | --- | --- |
| `merge` | PR ready, checks pass or none, Verify line is a quick look | `gh pr ready`, then `gh pr merge` with the method of the repo's last merges |
| `requeue` | blocked on a decision the user can give now | writes the answer into the job's `HANDOFF.md`, commits, pushes, queues a follow-up job |
| `hold` | needs the user: a big diff, hardware, judgment | `vibe queue hold <id> <note>`; the row leads every briefing under "Yours" |
| `close` | wrong direction or superseded | `gh pr close` with a one-line reason |
| `ack` | a report to read, or nothing left to do | nothing; the row is archived |
| `log` | `failed`, `timeout` | read the log tail; propose one of the actions above with the cause |

Show the whole action table first, grouped by repo like the briefing: one
`### <repo>` heading per repo, "Yours" rows first, then its rows as
`# · job · status · context · TL;DR · action · why`. Do not ask for approval yet.

## Phase 3 — Walk each repo

Take the repos one at a time, in table order. For each repo:

1. Show its rows again with the full context of each: the `Context` line,
   the TL;DR, the Verify line of a PR, and the blocker of a blocked job.
2. For a `requeue` row, ask the question the job is blocked on.
3. **Stop and wait for approval of this repo's rows.** Apply every change the
   user asks for, then show the rows again.
4. Carry out the approved rows top to bottom. Report each one as one line. A
   failed command stops that row only: report the error and go on.
5. `vibe queue archive <id>...` for every row carried out, except `hold`.

Then go to the next repo.

For `requeue`: under `## Next action` and `## Blockers` of the job's
`HANDOFF.md`, put the user's answer in place of the block. Commit
`docs(handoff): <job> unblocked` and push the job's branch. Then copy the
job's `job` and `prompt.md` into a fresh dir (`mktemp -d`) and run
`vibe queue add <dir>` outside the sandbox.

Merged and closed branches keep their worktrees: `/worktree-cleanup` removes them.

## Done

Done when every repo is walked and its approved rows are carried out and
archived. Report in at most 6 lines: merged, requeued, held, closed,
archived, and `Decisions/risks:`.
