# Babysitting a pull request

A PR is rarely done when you open it. CI goes red, a reviewer leaves four
threads, the base branch moves and it needs a rebase. Each of those is a small,
well-defined task with an unambiguous "fixed" signal — exactly the shape an
unattended loop handles well.

`skills/babysit-pr` is how you hand a PR to one. It **stages a brief**; it does
not watch anything. The watching is the loop's job, and the loop only starts
when you start it.

```
skills/babysit-pr/
├── SKILL.md      the procedure the agent follows
├── brief.sh      create → render the brief; publish → validate, commit, push
└── pr-ready.sh   the stop check: is PR #N actually ready?
```

## What it produces

Given a PR number, `brief.sh create <N>`:

1. resolves the PR's **head branch** through `gh pr view`,
2. creates a worktree for that branch — adopting it from `origin`, so the loop
   commits onto the PR rather than beside it,
3. renders `LOOP.md` from `templates/LOOP.md` with the goal `PR #N is
   mergeable` and `pr-ready.sh <N>` as the stop check,
4. seeds `HANDOFF.md`.

The agent then expands the Goal, Done-when and Constraints sections in that
file — the refined prose never passes through the script — and
`brief.sh publish <N>` validates that no placeholder survived, commits, and
pushes. The last thing printed is the start command:

```bash
vibe loop <pr-branch> \
  --until 'bash ~/git/agentic-dev-toolkit/skills/babysit-pr/pr-ready.sh 42' \
  --max 10 --push --no-attach
```

You run that. The skill never does — see [unattended loops](vibe-loop.md) for
what happens next.

## The stop check

`pr-ready.sh <N>` exits 0 only when **both** hold:

| Signal        | Read via                                        | Ready when |
| ------------- | ----------------------------------------------- | ---------- |
| Checks        | `gh pr checks <N> --json bucket`                 | every bucket is `pass` or `skipping` — nothing failing, nothing pending |
| Review threads| `gh api graphql` → `pullRequest { reviewThreads }` | zero threads with `isResolved: false` |

Review threads need GraphQL because `gh pr view` cannot report *resolution*
state — it returns the comments, not whether the conversation was resolved. A
PR whose CI is green while a reviewer still has an open thread is not done, and
the check says so.

**Everything ambiguous fails.** `gh` not installed, `gh` unauthenticated, the
API returning a 502, output that does not parse as JSON — each exits non-zero.
That direction is deliberate: a stop check that reads a broken environment as
"done" ends the loop with the PR unmerged and nobody watching. The cost of the
opposite error is a loop that keeps working, which you will notice.

`gh` and `jq` are the only dependencies, and nothing here is tied to a
particular agent — the skill lives in top-level `skills/`.

## What it will never do

The skill reads the PR (`gh pr view`, `gh pr checks`, `gh pr diff`) and nothing
else. It does not merge, close, approve, review or comment, and it does not
start the loop. Those boundaries are stated at the top of `SKILL.md`, and the
constraints it writes into the brief carry the same rules to the loop agent,
which *does* run unattended.

`brief.sh` also refuses to touch a brief while that task's loop is live, the
same guard `skills/loop-brief` uses — editing a brief out from under a running
loop changes the instructions mid-round.

## Being told when it needs you

Escalation to the phone is the existing ntfy hook — see
[phone notifications](notifications.md). The skill deliberately adds no
notification of its own; there is one path for "the agent wants you", and it is
that hook.

## Tests

`tests/babysit-pr.bats` drives `pr-ready.sh` against a stub `gh` placed early
on `PATH`: clean PR, failing check, pending check, unresolved thread, `gh`
missing, `gh` erroring. The stub exits 3 on any subcommand outside the
read-only set, so a future change that reaches for `gh pr merge` fails the
suite rather than the PR.
