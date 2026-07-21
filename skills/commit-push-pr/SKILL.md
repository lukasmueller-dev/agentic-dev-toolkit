---
name: commit-push-pr
description: Autonomously stage, commit, push, and open a GitHub PR. Use when the user says "commit and push", "open a PR", "ship this", "create a pull request", or similar, after code changes are ready. Handles Conventional Commits messages, pushes the branch, and opens a PR via GitHub CLI with an auto-generated title and body. Do NOT use for merging PRs, force-pushing to shared branches, or committing secrets.
---

# Commit, Push & PR

Autonomous flow: stage → commit (Conventional Commits) → push → open PR via `gh`. Run end-to-end without asking for confirmation unless a **Stop condition** below is hit.

## Prerequisites (check once, fail fast)

```bash
git rev-parse --is-inside-work-tree   # must be a repo
gh auth status                        # gh must be authenticated
```

If `gh` is missing/unauthenticated, tell the user and stop.

## Flow

### 1. Assess

```bash
git status --porcelain
git branch --show-current
git diff --stat HEAD
```

- If there are no changes (staged or unstaged), stop and say so.
- Read the actual diff (`git diff HEAD`) to understand what changed — the commit message must reflect real changes, not a guess.

### 2. Branch

Never commit directly to `main`/`master`. If on a protected/default branch, create a topic branch:

```bash
git checkout -b <type>/<short-slug>
```

Derive `<type>` from the change (feat, fix, chore, docs, refactor…) and `<slug>` from the primary change (e.g. `fix/oauth-token-refresh`). If already on a topic branch, stay on it.

### 3. Handoff

If this repo has a `HANDOFF.md` at its root, check whether it carries
anything beyond the bare template scaffold — the same check `vibe done`
uses:

```bash
grep -vE '^[[:space:]]*$|^#|^>|^- \*\*|^_.*_[[:space:]]*$' HANDOFF.md
```

Any line that prints is real content. A PR is the "task ends" boundary
that convention exists for, so before committing:
- Make sure whatever it says is either already in the commit body you're
  about to write, or fold it in now — don't let it get lost.
- Clear `HANDOFF.md` back to its bare headings (each section holding only
  its placeholder line) and include that in the same commit.

Skipping this is what causes `HANDOFF.md` merge conflicts between parallel
task branches: each one fully rewrites the same file with its own
narrative, and git can't reconcile two different rewrites. A cleared
handoff still differs from another branch's cleared handoff in its
Branch/Worktree/date header lines — that residual is a trivial conflict to
resolve (either side is equally valid), unlike the paragraphs of prose it
replaces.

### 4. Commit

```bash
git add -A
git commit -m "<type>[optional scope]: <description>" -m "<body>"
```

Conventional Commits rules:
- Types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`.
- Subject ≤ 72 chars, imperative mood, no trailing period.
- Add `!` after type/scope for breaking changes and a `BREAKING CHANGE:` footer.
- The body is the **canonical home of the rationale** — why the change was
  made, alternatives considered and rejected, the failure the change
  prevents. Be thorough here (wrapped at ~72 cols): this is what `git blame`
  surfaces in two years, and detail placed here is detail the chat summary
  and PR body only need to point at, not restate.
- If changes are logically distinct, make multiple commits by staging paths selectively (`git add <paths>`).

### 5. Push

```bash
git push -u origin HEAD
```

Only ever push the current topic branch. Never `--force` / `--force-with-lease` to a shared branch.

### 6. Open PR

```bash
gh pr create --fill --base <default-branch>
```

- `--fill` auto-generates title/body from the commits. Resolve `<default-branch>` via `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.
- If commits are messy or a single squashed narrative is clearer, replace `--fill` with explicit `--title`/`--body` synthesized from the diff (title = Conventional Commit summary).
- If a PR already exists for the branch, skip creation and report its URL (`gh pr view --json url -q .url`).

PR body rules — the body says only what the diff *cannot*:

- **Summary**: ≤5 bullets on intent and approach — why, not what. Never
  narrate the diff; the diff is right there.
- **Decisions/risks**: mandatory, even when the content is "none" —
  judgment calls, tradeoffs, anything a reviewer would want flagged.
- **What to verify**: how to exercise the change, what could plausibly break.
- An exhaustive file-by-file account, if worth generating at all, goes in a
  collapsed block at the end so it costs nothing to skim past:

  ```markdown
  <details><summary>Full changes</summary>

  ...

  </details>
  ```

Return the PR URL as the final output.

## Stop conditions (pause and ask the user)

- Diff contains apparent secrets/credentials (API keys, tokens, `.env` values, private keys).
- Working tree has merge-conflict markers or unresolved conflicts.
- Would require force-pushing a shared/protected branch.
- No remote named `origin`, or push is rejected (diverged history).
- Repo default branch is protected in a way that blocks PR creation.

## Notes

- Respect `.gitignore`; if large/binary artifacts are about to be staged, flag before `git add -A`.
- If the opened PR reports merge conflicts with the base branch (a parallel PR merged first), that is the `sync-with-main` skill's job — invoke it rather than resolving ad hoc here.
- Don't amend or rewrite already-pushed commits.
- Keep output terse: report branch, commit subject(s), and the PR URL.