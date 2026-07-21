---
name: sync-with-main
description: Rebase the current topic branch onto the latest default branch after a parallel PR's merge moved it. Use when the user says "sync with main", "main moved", "catch up with main", "rebase onto main", or reports that a just-merged PR touches files this branch also edits. Fetches and confirms the branch is behind, scopes the overlap before touching anything, rebases, resolves textual and semantic conflicts, re-runs the repo's checks, and pushes with --force-with-lease. Do NOT use for reconciling a branch with its own upstream after a rejected push, for merging PRs, or on the default branch itself.
---

# Sync With Main

Bring an in-flight topic branch up to date after the default branch moved
underneath it — typically because a parallel PR merged and touched files this
branch also edits. Rebase-based: the branch's commits are replayed onto the
new tip, then pushed with `--force-with-lease`. Run end-to-end without asking
unless a **Stop condition** below is hit.

## Boundaries

- Operate **only on the current topic branch**. If HEAD is the default branch
  (`main`/`master`), stop — there is nothing to sync, and nothing in this
  skill may ever rewrite or force-push a shared branch.
- `--force-with-lease` only, never `--force`. The lease is what turns
  "overwrite the remote" into "overwrite only history already seen locally";
  plain `--force` silently discards anything pushed in the meantime.
- Never start over uncommitted changes. Rebasing with a dirty tree mixes the
  user's in-progress work into conflict resolution and makes `--abort`
  lossy. Stop and ask instead.
- Never resolve a conflict by taking one side wholesale (`--ours` /
  `--theirs`). Both changes were merged or committed on purpose; a resolution
  must preserve the intent of both.

## Flow

### 1. Establish the facts

```bash
git status --porcelain                 # must be empty — see Boundaries
git branch --show-current              # must not be the default branch
git fetch origin
default="origin/$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's|^origin/||' || echo main)"
git rev-list --count "HEAD..$default"  # commits the branch is behind
```

If the branch is 0 commits behind, report "already up to date with
`<default>`" and stop — done, nothing to sync.

### 2. Scope the collision before touching anything

```bash
base="$(git merge-base HEAD "$default")"
git log --oneline "$base..$default"        # what landed on the default branch
git diff --name-only "$base..$default"     # files it changed
git diff --name-only "$base..HEAD"         # files this branch changed
```

Intersect the two file lists — that is where textual conflicts will land.
Then read the landed commits themselves (`git show`) for changes that will
*not* conflict textually but still break this branch: renamed helpers,
changed function signatures, moved files, altered templates or contracts this
branch's code relies on. Note each one; phase 4 checks them.

### 3. Rebase

```bash
git rebase "$default"
```

Resolve each conflict hunk with the phase-2 context: what landed is now the
baseline, and this branch's change adapts *to* it — not the other way
around. If the correct resolution of any hunk is genuinely ambiguous — both
sides rewrote the same logic and the intents cannot be combined without
guessing — run `git rebase --abort` to restore the branch untouched, then
stop and ask, quoting the conflicting hunks.

### 4. Check for semantic breakage

A clean rebase can still be a broken branch. Revisit every item noted in
phase 2: if something this branch calls, reads, or emits was renamed or
changed on the default branch, update this branch's usage now.

Then run the repo's own gate — whatever its contributing docs or CI define
(lint, formatter, test suite). Failures *introduced by the rebase* are this
skill's job: fix them and re-run. Failures that already exist on the default
branch are not — leave them and flag them in the report.

### 5. Push

```bash
git push --force-with-lease origin HEAD
```

If the lease is rejected, the remote branch moved during the sync: fetch and
restart from phase 1, once. A second lease rejection means the branch is
being actively pushed to from somewhere else — stop and report rather than
fight over it.

### 6. Report

Done means: the branch replays cleanly on the current default-branch tip, the
repo's checks pass, and the remote branch is updated. Report, tersely:

- what had landed on the default branch (the phase-2 log),
- which files conflicted and how each conflict was resolved,
- any semantic fixes from phase 4, and which checks were run.

## Stop conditions (pause and ask the user)

- Working tree is dirty at the start.
- HEAD is the default branch, or has no upstream on `origin`.
- A conflict hunk whose correct resolution would be a guess (after
  `git rebase --abort`).
- The lease is rejected twice.
- This branch's own PR is already merged or closed — a finished PR is not
  brought up to date, and follow-up work is a new branch's job.
