# Feature — the shared steps

A feature is big work on 2 or more branches that merge together, most often in
several repos: one member per branch, one PR each, one merge batch.
`/fill-queue` Phase 1 and `/enqueue` both do these steps. Runner side:
`docs/vibe-queue.md` § Features in the toolkit.

Work that can merge in parts is separate items, not a feature.

## 1. Grill

Run the `grilling` skill until each section of `templates/FEATURE.md` (toolkit) has an answer:

- Context, the human test, the members: `<absolute repo path> <branch>`, a new or an existing branch.
- Goal, non-goals, decisions.
- Contract: one row per interface that crosses repos — name, owner repo, each copy as `repo:path`.
- Per member: its milestones, as in `templates/SPEC.md`. The gate (`fill-queue` Phase 3) holds per member.

## 2. Stage each member

Outside the sandbox, per member with milestones:

1. New branch: `git -C <repo> worktree add -b <branch> <repo>/.claude/worktrees/<branch>`.
   Existing branch: its worktree, else `git -C <repo> worktree add <repo>/.claude/worktrees/<branch> <branch>`.
2. `SPEC.md` from `templates/SPEC.md`, with this member's milestones only.
   Goal: one line, then `Feature: ~/.local/state/vibe/features/<feature>.md`. Non-goals and decisions: `see the feature file`.
3. `HANDOFF.md` from `templates/HANDOFF.md`; next action: the first milestone with its done-when.
4. Commit `docs(spec): <branch> (feature <feature>)`, push.

A member without milestones (a PR that only waits for the batch) gets no `SPEC.md` and no job.

## 3. Register

Write the feature file from `templates/FEATURE.md` to `$TMPDIR/<feature>.md`; the file name is the slug.
Outside the sandbox: `vibe feature add $TMPDIR/<feature>.md`. It stops on a missing branch, a member
of another feature or a slug in use: repair the file and run it again.

## 4. Queue

One job per member with a `SPEC.md`; its task is "the first open milestone of `SPEC.md`".
The runner adds the feature block to each prompt: do not write it.
