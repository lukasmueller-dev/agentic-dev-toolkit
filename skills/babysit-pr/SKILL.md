---
name: babysit-pr
description: "Stages an unattended-loop brief that drives an open pull request to mergeable, on the PR's own branch. Use when the user says 'babysit PR 42', 'keep pushing this PR until it merges', 'watch this PR', or wants CI failures and review comments on a pull request worked through without them sitting there. Renders a LOOP.md whose goal is 'PR #N is mergeable' and whose stop check is green checks plus zero unresolved review threads, commits and pushes it, and prints the exact command to start the loop — without ever starting it, and without merging, closing, reviewing or commenting on the PR."
disable-model-invocation: true
argument-hint: "<pr-number>"
---

# Babysit a PR

Turn an open pull request into the brief an unattended loop agent is handed
every round. The brief is `LOOP.md` at the root of a worktree for **the PR's
own head branch**, so every round the loop commits and pushes lands on the PR
itself. The stop check is the bundled `pr-ready.sh <N>`: green checks and zero
unresolved review threads.

This skill *stages* a brief. It never watches or polls a PR — that is the
loop's job, once the user starts it.

## Hard boundaries — never do these

- **Never start the loop.** No loop runner, no headless agent invocation. The
  deliverable is the pushed brief and the printed command.
- **Never merge, close, review or comment on the PR.** No `gh pr merge`, `gh
  pr close`, `gh pr review`, `gh pr comment`. Reading (`gh pr view`, `gh pr
  checks`, `gh pr diff`) is the only PR interaction allowed.
- **Never write LOOP.md from memory or a heredoc.** `brief.sh create` renders
  it from `templates/LOOP.md`; you only edit the rendered file.
- **Never touch a task whose loop is live.** `brief.sh` refuses on its own —
  do not work around it by editing files directly.
- **Never force-push.** If `brief.sh publish` fails to push, report the error
  and stop.

## Phase 1 — Read the PR

The PR number arrives as `$ARGUMENTS`; if it is empty, ask for it. Confirm
`gh` and `jq` are installed and `gh auth status` succeeds — both are required,
by this skill and by the stop check the loop will run.

Read the PR's current state:

```
gh pr view <N> --json headRefName,title,url,isDraft,mergeStateStatus
gh pr checks <N>
```

Summarize for the user what actually stands between the PR and merge: which
checks fail, how many review threads are unresolved, whether the base branch
has moved underneath it. A brief written without this produces a loop that
flails.

## Phase 2 — Refine, then confirm

Pin down three things with the user. The agent running the loop gets *only*
this brief, with no one watching.

1. **Goal** — one concrete paragraph: "PR #N is mergeable" plus what that
   means for *this* PR — the failing suite to fix, the review threads to
   address, the rebase to perform. Name the files involved.
2. **Constraints** — what the unattended agent must NOT do. Always include:
   never merge, close, approve or comment on the PR; never force-push; never
   change the PR's base branch; stay inside the PR's own scope rather than
   opening new work. Add anything repo-specific.
3. **Budget** — max rounds (default 10), and whether each round should push
   (`--push`, recommended so progress is visible from the other machine).

Show the three answers together as the draft brief and **wait for explicit
approval before Phase 3**.

## Phase 3 — Stage

Run the bundled script (resolve the path from this skill's directory):

```
bash brief.sh create <N>
```

It resolves the PR's head branch through `gh`, creates the worktree for it
(adopting the branch from origin), renders `LOOP.md` from the shared template
with `pr-ready.sh <N>` as the stop check, and seeds `HANDOFF.md`. Read the
`KEY=VALUE` output:

- `STATE=created` — fresh brief; continue to Phase 4.
- `STATE=existing-brief` — a brief already exists (perhaps from a maxed or
  stalled earlier run). Read it, show the user what is there, and refine
  *that* file in Phase 4 instead of starting over.

`UNTIL=` is the stop-check command to use verbatim in Phase 5.

## Phase 4 — Fill in the refined brief

Edit the `LOOP.md` the script printed as `LOOP_MD=`:

- Expand `## Goal` to the refined paragraph from Phase 2.
- Replace the italic placeholder under `## Done when` with: the PR's checks
  all pass and it has no unresolved review threads — which is exactly what the
  stop check verifies. Note that a broken environment (`gh` missing,
  unauthenticated, API erroring) fails the check rather than passing it, so
  the loop never ends early on a green-looking accident.
- Replace the italic placeholder under `## Constraints` with the refined list
  from Phase 2.
- Leave the header metadata and the `## Iteration log` placeholder untouched
  — the loop maintains the log.

## Phase 5 — Publish and hand off

Run:

```
bash brief.sh publish <N>
```

It validates the brief (no unrendered tokens, no placeholder left in the two
refined sections), commits, and pushes. If validation fails it names the
unfinished section — fix it and retry.

Then print the exact start command and stop:

```
vibe loop <branch> --until '<UNTIL from Phase 3>' --max <n> [--push] --no-attach
```

with three notes: run it on the server for a session that survives
disconnect; `--no-attach` is what makes the command return instead of
attaching, which is required when starting it from inside another agent
session; and a loop that ends on max rounds rather than on the stop check
leaves the PR unmerged — read `LOOP.md`'s iteration log before deciding what
to do next.

If the user wants to be told when the run needs them, point them at the
repo's existing phone-notification hook (`docs/notifications.md`) rather than
adding any notification of your own.

**Done means:** the brief is pushed and the command is printed. Do not start
the loop, do not touch the PR, and do not keep refining after approval.
