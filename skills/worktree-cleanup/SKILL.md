---
name: worktree-cleanup
description: "Finds and removes the git worktrees of a repo whose work has already landed — branch merged into the default branch, or its upstream deleted after a merged PR — together with their local branches. Use when the user says 'clean up worktrees', 'remove merged worktrees', 'prune old worktrees', or 'git worktree list' shows leftovers from finished sessions. Scans first, shows every worktree with its state, and removes only the merged ones the user approves; dirty, unpushed and in-use worktrees are reported and left alone."
disable-model-invocation: true
argument-hint: "[<repo path>...]"
---

# Worktree cleanup

Remove finished worktrees, and only finished ones. The bundled `cleanup.sh`
decides what is finished; this skill shows its verdict and asks first.

## Hard boundaries — never do these

- **Never remove a worktree the scan does not rate `merged` or `prunable`.**
  `cleanup.sh remove` refuses the other states; do not work around it with
  `git worktree remove`, `--force` or `rm -rf`.
- **Never unlock a `locked` worktree.** A running session holds it.
- **Never delete a remote branch.** Only the local branch of a removed
  worktree goes.
- **Never remove anything before the user approves the list.**

## Phase 1 — Scan

Run the bundled script (resolve the path from this skill's directory) once
per repo — the current repo, or each path passed as `$ARGUMENTS`:

```
bash cleanup.sh scan [<repo>]
```

It fetches with `--prune` (best effort; `FETCH=failed` means the states use
the last fetched refs — say so), then prints one tab-separated line per
linked worktree: `state  path  branch  reason`.

| State | Meaning | Action |
| --- | --- | --- |
| `merged` | All commits on the default branch, or upstream deleted | removable |
| `prunable` | Directory gone, only git's record left | removable |
| `dirty` | Uncommitted or untracked changes | keep |
| `unpushed` | Commits not on the default branch | keep |
| `locked` | Held by a running session | keep |
| `current` | This session runs in it | keep |

## Phase 2 — Confirm

Show one table per repo: path, branch, state, reason. Name the removable
ones explicitly, and for each `unpushed` or `dirty` one say what the user
would lose. **Wait for explicit approval** of the removable set; the user may
narrow it.

## Phase 3 — Remove

```
bash cleanup.sh remove <path>...
```

Pass only the approved paths. The script re-checks each state, removes the
worktree, deletes its local branch, and skips (non-zero exit) anything that
changed in between — report those, do not retry them.

If git fails with a permission or read-only error on the repo's `.git`
directory, rerun the same command with write access to it; never fall back
to deleting directories by hand.

**Done means:** every approved worktree is removed or reported as skipped,
and a final `git worktree list` per repo is shown. Stop there — do not touch
the kept worktrees.
