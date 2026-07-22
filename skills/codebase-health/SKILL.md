---
name: codebase-health
description: Non-behavioral codebase health check with optional guided fixes. Scans for duplicated code (exact and semantic), needless complexity and readability problems, and documentation that has drifted out of sync with the code (docstrings, README, CLAUDE.md, config docs). Reports findings grouped by file, then fixes only user-approved categories on separate branches with test-verified, behavior-preserving changes delivered as PRs. Use whenever the user asks for a health check, cleanup pass, refactoring sweep, tech-debt review, code-quality audit, duplication check, dead-code removal, or asks whether docs or comments are stale — even if they phrase it as "make this codebase cleaner/healthier/simpler" or "is my README still accurate".
---

# Codebase Health Check + Fix

Improve maintainability without changing behavior. This skill is a hygiene
pass, not a bug hunt: functionality is the test suite's job, and the test
suite is also the referee that proves your fixes changed nothing.

Two commitments define everything below. First, **no behavioral changes** —
if a cleanup would alter what the code does (even an exception message a
caller might match on), it gets reported, never auto-fixed. Second, **no
fixes without approval** — the scan and report are always safe to run; code
is only touched after the user approves a category.

## Pipeline

Run the nine steps in order. Do not skip the preflight test run — without a
recorded baseline you cannot prove the fixes were behavior-preserving.

### 1. Resolve scope

- Accept an optional path argument from the user; default is the whole repo.
- Read `.codebase-health/state.json` if it exists:

```json
{ "last_scanned_commit": "<sha>", "last_run": "<ISO date>" }
```

- If present: incremental run. Primary targets are files changed since that
  SHA (`git diff --name-only <sha>..HEAD`). Duplication comparison still runs
  against the whole repo — a changed file can duplicate an unchanged one.
- If absent: full scan.
- Keep the state directory out of version control via `.git/info/exclude`
  (not `.gitignore`) so the health tool never creates diff noise of its own.

### 2. Preflight

- Detect languages from file extensions in scope. For each detected
  language, read `references/<language>.md` from this skill's directory —
  it lists the candidate-finding tools, test discovery hints, doc surfaces,
  and behavior-risk traps for that language. For a language with no
  reference file, proceed with general judgment and say so in the report;
  `references/_template.md` shows how to add one.
- Find the real test command: check CLAUDE.md, Makefile, CI config, and
  package manifests before guessing. Run the suite and record the result.
  - **Green baseline**: full safety net available.
  - **Failing baseline**: record the exact failure set. Fixes must not add
    new failures. Tell the user the net is partial.
  - **No or weak tests** (no framework, or scanned files obviously
    uncovered): warn the user plainly that the behavioral guarantee is
    reduced to static checks, and ask for explicit confirmation before the
    fix phase. Scanning and reporting proceed regardless. Where linters or
    type checkers exist, record their clean/failing state as a fallback gate.

### 3. Scan

Three categories. Let deterministic tools find *candidates* and reserve
judgment for *is this actually worth fixing* — tools make runs fast and
findings reproducible; judgment keeps the report from being lint noise.

- **dedup** — Run the language's clone detector for exact and near-exact
  duplicates. For semantic duplicates, do NOT compare all pairs (that is
  quadratic and slow): pre-filter candidates cheaply — similar length,
  same signature shape, overlapping identifier sets — and apply judgment
  only to the shortlist.
- **complexity** — Run the language's complexity and dead-code tools, then
  judge the flagged sites: long functions, deep nesting, dead code,
  misleading names, convoluted control flow. A high metric alone is not a
  finding; a high metric plus a clearly simpler equivalent is.
- **docs** — Pure judgment; no tool can do this. Check every documentation
  surface against the code it describes: docstrings vs. actual signatures
  and return types, README setup/usage vs. what actually works, CLAUDE.md
  claims vs. repo structure and commands, config file comments and example
  configs vs. real keys.

### 4. Report

Present findings in chat, grouped by file, no ranking. Use exactly this
shape so approval is easy to give per category:

```
## path/to/file.py
- [dedup] lines 40-80: near-duplicate of utils/parse.py:12-50 — extract shared helper. Risk: low.
- [complexity] load_config() lines 90-160: 5 nesting levels — flatten with early returns. Risk: low.
- [docs] docstring of train() says it returns dict; it returns TrainResult — update docstring. Risk: none.
```

Every finding names its category, location, the problem, a one-line
proposed fix, and a risk note. End the report by asking which categories
to fix: **dedup**, **complexity**, **docs**, any combination, or none.

### 5. Approve

**Stop here and wait for the user's category-by-category approval — do not
proceed to step 6 without it.** Fix only approved categories. Record
unapproved findings — they reappear in the delivery step so nothing silently
disappears.

### 6. Fix

- One branch per approved category, from the current HEAD:
  `health/dedup-<YYYY-MM-DD>`, `health/complexity-<...>`, `health/docs-<...>`.
  One category per branch keeps each PR reviewable in one sitting.
- One commit per fix. Atomic commits make step 7's reverts surgical.
- Behavior-preserving transformations only. When unsure whether a change
  alters behavior, don't make it — downgrade the finding to report-only.
  The per-language reference lists known traps; read its behavior-risk
  section before fixing anything in that language.
- Doc fixes update the documentation to match the code, never the code to
  match the documentation — the latter is a behavioral change wearing a
  docs costume. If the documented behavior seems like the *intended*
  behavior, flag the mismatch as a possible bug for the user instead.
- Renames or signature changes are only safe when every call site is inside
  the scanned scope; otherwise report-only.

### 7. Verify

- Per branch, re-run the **full** test suite, not just tests near changed
  files — refactors have blast radius.
- Any failure not in the preflight baseline: `git revert` the offending
  commit and mark that finding "attempted, failed verification" with the
  failure output. Do not rationalize a new failure as unrelated.
- Re-run linters and type checkers recorded in preflight; hold fixes to the
  same clean/failing state as the baseline.

### 8. Deliver

- Push each branch and open a PR (e.g. `gh pr create`). The PR description
  **is** the report for that category: the findings fixed (grouped by file,
  same format as step 4), plus any reverted attempts with their failure
  output.
- Append to the first PR a short "Known, not addressed" section listing
  unapproved and report-only findings, so the full scan result survives in
  reviewable history.

### 9. Update state

Write the new `last_scanned_commit` (the SHA that was scanned) to
`.codebase-health/state.json` only after the PRs are open. If a run
crashes, the stale marker makes the next run re-scan instead of skip —
re-scanning is cheap, silently skipped findings are not.

## If the user only wants part of this

The pipeline degrades gracefully: "just scan" means stop after step 4;
"just check the docs" means run only the docs category; "scan this
directory" sets the scope in step 1. Never skip steps 2 (baseline) or 7
(verify) when any fixing happens.
