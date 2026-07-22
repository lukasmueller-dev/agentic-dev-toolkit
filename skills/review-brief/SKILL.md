---
name: review-brief
description: "Stages the next independent repo-review round: a HANDOFF.md brief on a fresh fresh-review-N branch, assembled from the skill's review-dimensions catalog, pushed, and the start command printed — never running the review itself. Use when the user says 'stage a review round', 'set up the next review', 'prepare a fresh-eyes review', or a review PR has merged and the next round should be staged. Computes the round number from existing review branches (refusing while an older round is unmerged), weights the catalog by what recent rounds covered and what changed since, and bakes in the standing review rules: rebase first, discover blind then de-duplicate, ranked findings with failure scenarios, fixes never replacing the report."
disable-model-invocation: true
argument-hint: "[<extra focus for this round>]"
---

# Review brief

Stage the brief for one independent review round of the current repo. The
artifact is `HANDOFF.md` on the round's own `fresh-review-<n>` branch,
committed and pushed, plus the printed command to start the reviewing
session — the review-specialised sibling of `handoff-brief`, sharing its
staging plumbing. One round per invocation: the human merge gate between
rounds is deliberate, because a round's value depends on the owner merging
the previous review PR and deciding its open items first. There is no
unattended-loop variant: a review has no executable stop check, which is
exactly what `loop-brief` requires.

## Hard boundaries — never do these

- **Never run the review.** No dispatching reviewers, no findings, no
  fixes. The deliverable is the pushed brief and the printed command.
- **Never start the session.** No `vibe start`, no agent launch — starting
  is the user's move.
- **Never stage past an unmerged round.** `review.sh` refuses on its own —
  do not work around it by creating branches by hand.
- **Never write HANDOFF.md from memory or a heredoc.** `review.sh create`
  renders it from `templates/HANDOFF.md`; you only edit the rendered file.
- **Never quote template placeholder tokens literally** in the mission
  text — angle brackets around repo, branch, worktree, date, or machine
  are rejected by publish validation. Paraphrase them.
- **Never overwrite a handoff that carries content.** `STATE=existing-handoff`
  means show the user what is there and refine it in place.
- **Never force-push.** If `review.sh publish` fails to push, report the
  error and stop.

## Phase 1 — Stage the round

Confirm you are inside a git repository, then run the bundled script
(resolve the path from this skill's directory):

```
bash review.sh create
```

If it refuses because a prior round is unmerged, relay that: the previous
review PR must be merged (or its branch deleted) before the next round has
value. Otherwise read the `KEY=VALUE` output — `ROUND`, `BRANCH`,
`DEFAULT_BRANCH`, `LAST_ROUND_BRANCH` (empty on round 1), `HANDOFF_MD` —
and branch on `ROUND_STATE`:

- `ROUND_STATE=new` — a fresh round was staged; continue.
- `ROUND_STATE=existing` — the latest round is already staged or in
  flight and was adopted. Inspect it: if the branch carries review work
  beyond the brief, or an open PR, the round is running — tell the user
  and stop. If it is only a staged (or half-staged) brief, show what is
  there and continue as a refinement of *that* round.

## Phase 2 — Compute coverage

The mission depends on what earlier rounds already covered and what has
changed since. Skip this phase on round 1 — the coverage set is empty by
definition.

1. **Prior coverage:** read the merged review PR bodies (`gh pr list
   --state merged --search "head:fresh-review"`, then `gh pr view <n>`;
   without `gh`, the merge commits of prior round branches) and the
   project status file's verification-debt / TODO tracks. Note which
   catalog dimensions each round genuinely exercised — a dimension named
   but skimmed does not count as covered.
2. **Changed since:** `git log --stat origin/<last round branch>..origin/<default branch>`
   — code changed since the last round is always in scope, whatever the
   catalog says.

## Phase 3 — Assemble the mission

Read `references/review-dimensions.md` and compose the round's scope:

- The **generic core** always applies. A **conditional** dimension applies
  only when its anchor files exist in the target repo.
- Drop or deprioritise dimensions recent rounds covered well; add the
  changed-code focus from Phase 2; fold in any extra focus passed as
  `$ARGUMENTS`.
- The **standing rules** go into every round, with the default-branch name
  resolved to the real one. On **round 1**, stage the full catalog plus
  the round-1 extras.
- **In a repo that is not this toolkit**, stage the generic core only and
  have the brief tell the session to extend its scope from that repo's own
  instruction file and docs — never import this toolkit's anatomy.

Then edit the rendered `HANDOFF.md` (path in `HANDOFF_MD=`), written for a
session with none of this context:

- `## State` — "Not started", the round number, its mission, the scoped
  dimension list, the blind-then-deduplicate rule with what to
  de-duplicate against.
- `## Next action` — rebase onto the default branch first (never the
  resume verb), run the repo's verification gate as baseline, then the
  first scope item.
- `## Blockers` / `## Gotchas (unpromoted)` — known obstacles and the
  standing deliverable rules that fit neither section above. Leave a
  placeholder alone if there is genuinely nothing.

The two hand-staged rounds in this repo's history (`fresh-review-2`,
`fresh-review-3`) are the shape to match.

## Phase 4 — Confirm

Show the drafted brief as one piece and **wait for explicit approval
before Phase 5**.

## Phase 5 — Publish and hand off

```
bash review.sh publish <branch>
```

It validates the brief, commits, and pushes. If validation fails it names
the unfinished section — fix it and retry. Then print the start commands
and stop:

```
vibe start <branch>     # here — on the server this survives disconnect
vibe attach <branch>    # from another machine
```

with one note: the reviewing session must merge its PR through the owner,
and any new review dimension it discovers belongs in this skill's
`references/review-dimensions.md` (or, for repo-specific classes, in that
repo's own docs) — that is where review knowledge accumulates.

**Done means:** the brief is pushed and the command is printed. Do not
start the session, and do not keep refining after approval.
