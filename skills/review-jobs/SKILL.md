---
name: review-jobs
description: "Reviews the finished agent jobs in the queue: writes a fresh briefing, proposes one action per job that needs a human or has a PR ready — mark ready, answer and requeue, hold for the user, close, archive — one decision for a lane of jobs on one branch, shows the table grouped by repo, then walks the repos one at a time, carries out only the actions the user approves and gives the merge order; the user merges. Use when the user says 'review the jobs', 'what did the agents do', 'go through the briefing', 'merge the agent PRs', or wants the queue's results triaged."
disable-model-invocation: true
---

# Review jobs

Turn the finished jobs into decisions and carry them out. Queue layout and
briefing: `docs/vibe-queue.md` in the toolkit.

## Hard boundaries — never do these

- **Never merge a PR.** You mark it ready and give the merge order; the user merges.
- **Never mark ready, close, comment, push or archive without approval of that repo's rows.**
- **Never mark ready a PR whose checks fail**, or one the user has not seen the TL;DR of.
- **Never mark ready a PR whose diff still holds `SPEC.md` or `HANDOFF.md`.**
- **Never change code.** You edit only a job's `HANDOFF.md`, with the user's words.
- **Never archive a row you did not carry out.** A skipped row stays for the next review.

## Phase 1 — Read

1. Run `vibe queue report` outside the sandbox. Read the briefing it printed.
2. For each row under "Yours", "Needs you" and "PR ready", read what the row links:
   the job's `report.md`, the `## <job>` block (next action, blockers),
   and for a PR `gh pr view <url> --json title,body,isDraft,statusCheckRollup`.
   If `gh` fails, run it again outside the sandbox.
   A lane row (`<branch> · 3/5`) links the lane PR. A job out of the lane has `side` (its side branch) in its job dir.

## Phase 2 — Propose

One action per row:

| Action | When | Does |
| --- | --- | --- |
| `ready` | PR ready, checks pass or none, Verify line is a quick look | `gh pr ready`; the PR goes into the repo's merge order |
| `requeue` | blocked on a decision the user can give now | writes the answer into the job's `HANDOFF.md`, commits, pushes, queues a follow-up job |
| `hold` | needs the user: a big diff, hardware, judgment | `vibe queue hold <id> <note>`; the row leads every briefing under "Yours" |
| `close` | wrong direction or superseded | `gh pr close` with a one-line reason |
| `ack` | a report to read, or nothing left to do | nothing; the row is archived |
| `log` | `failed`, `timeout` | read the log tail; propose one of the actions above with the cause |

Show the whole action table first, grouped by repo like the briefing: one
`### <repo>` heading per repo, "Yours" rows first, then its rows as
`# · job · status · context · TL;DR · action · why`. Do not ask for approval yet.

### Lanes

A row `<branch> · <done>/<total>` is a lane: one PR, one decision.

- A job of the lane is queued or running → no action. The row shows its progress (`3/5`) for the next review.
- Every job is `done` or out of the lane → one decision: `ready`, `requeue`, `hold` or `close`.
- `ready`, `close`: act on the lane PR. A job out of the lane stays for the next review.
- `hold`: `vibe queue hold <id> <note>` for each done job of the lane.
- `requeue`: each job out of the lane, with the user's answer. The lane PR stays a draft.

## Phase 3 — Walk each repo

Take the repos one at a time, in table order. For each repo:

1. Show its rows again with the full context of each: the `Context` line,
   the TL;DR, the Verify line of a PR, and the blocker of a blocked job.
2. For a `requeue` row, ask the question the job is blocked on. For a lane, ask once per job out of the lane.
3. **Stop and wait for approval of this repo's rows.** Apply every change the
   user asks for, then show the rows again.
4. Carry out the approved rows top to bottom. Report each one as one line. A
   failed command stops that row only: report the error and go on.
5. `vibe queue archive <id>...` for every row carried out, except `hold`. For a lane `ready` or `close`: each done job. For a lane `requeue`: each job out of the lane.
6. Give the merge order of the repo's `ready` PRs, one line each:
   `<n>. #<pr> — <why here>`. Put a PR before the ones whose files it shares,
   smallest first, and name the PRs that can conflict after it. Give the
   merge method of the repo's last merges.

Then go to the next repo.

For `requeue` of a job without `side`: under `## Next action` and `## Blockers` of the job's
`HANDOFF.md`, put the user's answer in place of the block. Commit
`docs(handoff): <job> unblocked` and push the job's branch. Then copy the
job's `job` and `prompt.md` into a fresh dir (`mktemp -d`) and run
`vibe queue add <dir>` outside the sandbox.

For `requeue` of a job out of the lane: the side branch holds a WIP commit, so edit no `HANDOFF.md`.

1. Copy the job's `job` and `prompt.md` into a fresh dir (`mktemp -d`).
2. Lane PR open (`gh pr view <pr> --json state` prints `OPEN`): keep `branch=`, `lane=` and `item=` — the item joins the lane again.
3. Else: set `branch=<branch>-<item>-retry`, delete `lane=` and `item=` — a new branch from the default branch.
4. End the `## Task` list of `prompt.md` with two lines, `<start>` being the job's `start` file:
   `Earlier try: git diff <start>..<side-branch>. Do not merge it.`
   `Answer: <the user's words>`
5. `vibe queue add <dir>` outside the sandbox.

## Phase 4 — Clean up

Read `../worktree-cleanup/SKILL.md` and do every phase of it, for each repo
walked. It keeps its own approval gate. The user declines → stop.

## Done

Done when every repo is walked, its approved rows are carried out and
archived, and the cleanup is done or declined. Report in at most 6 lines:
marked ready, requeued, held, closed, archived, worktrees removed, and
`Decisions/risks:`.
