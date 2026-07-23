---
name: repo-scaffold
description: Audits a repo against the full baseline scaffold and applies what is missing after approval — project-type .gitignore, a pre-push hook protecting the default branch, an opt-in CI workflow, and status/handoff files. Use when creating or initializing a new repo or project, when the user says "scaffold this repo", "set up repo basics", "add a gitignore", "protect main", "add CI", or "bring this repo up to standard", and when starting work in an existing repo that is visibly missing these pieces. Audit-first on existing repos — it reports gaps and never overwrites what is already there.
---

# Repo Scaffold

Brings a repo — brand new or existing — up to the baseline this toolkit
expects: version control with a protected default branch, an ignore file that
fits the project type, CI that verifies every merge, and the status/handoff
files that let work move between sessions.

## Boundaries

- **Every write sits behind the approval gate in phase 3.** Phases 1–2 are
  read-only; this is why the skill may run proactively. Nothing is created,
  edited, or configured before the user approves it item by item or as a
  batch.
- **Never overwrite an existing file.** An existing `.gitignore`, workflow,
  hook, or instruction file is extended or left alone — additions only, no
  deletions, no reordering of what is there.
- **Never commit or push.** The scaffold lands as uncommitted changes for the
  user to review; committing belongs to the task workflow.
- **Never change the remote without its own explicit approval.** Enabling
  server-side branch protection modifies the hosted repo; it is offered
  separately and never bundled into a blanket "apply everything".
- Out of scope: README, LICENSE, formatter/linter configs, and application
  code. Point the user at other tools for those rather than improvising.

## Phase 1 — Detect (read-only)

Determine the project type(s) from marker files — a repo can be several at
once. The markers, and everything ecosystem-specific, live in
`references/<type>.md` (python, node, rust, go, shell); read the matching
reference for each detected type before proposing anything.

Then take stock of the baseline, item by item:

| Item | How to check |
| ---- | ------------ |
| Git repo | `git rev-parse --git-dir` — if missing, `git init -b main` is the first gap |
| `.gitignore` | exists, and covers the detected type(s) |
| Pre-push protection | `.githooks/pre-push` exists **and** `git config core.hooksPath` returns `.githooks` — either alone protects nothing |
| Server-side protection | only if a GitHub remote exists: `gh api "repos/<owner>/<repo>/branches/<default>/protection"` — a 403 mentioning an upgrade means the plan has none (private repo on a free plan); 404 means available but not enabled |
| CI | a workflow under `.github/workflows/` that runs lint and tests |
| Repo visibility | only if a GitHub remote exists: `gh repo view --json isPrivate --jq .isPrivate` — `true` (private) keeps the opt-in `run-ci` label gate on CI; `false` (public) strips it, since public repos get free Actions minutes |
| Status files | `PROJECT_STATUS.md` and `PROJECT_ROADMAP.md` at the repo root, `HANDOFF.md` in the worktree |
| Instruction file | `CLAUDE.md` / `AGENTS.md` — exists, and records the conventions the scaffold establishes |

Degrade gracefully: no `gh`, no remote, or no network means the remote checks
are reported as "unknown", not guessed.

## Phase 2 — Report

Present one gap table: each item, its current state, and what would be
applied. Recommend, don't insist — an intentionally minimal repo (a scratch
repo, a fork) may not want all of it.

## Phase 3 — Approval gate

**Ask which items to apply and wait for the answer. Nothing below runs
without it.** Server-side branch protection is always its own line item in
that question, never folded into "everything".

## Phase 4 — Apply

Only approved items, only where missing. Every emitted file is copied from
the toolkit's `templates/` directory — never write one from memory. Resolve
the directory from this skill's own location: the installed skill directory
is a symlink into the toolkit checkout, so resolve it physically (`cd -P`)
and go two levels up; templates are at `<toolkit>/templates/`.

- **Git repo** — `git init -b main`, then continue with the rest.
- **`.gitignore`** — concatenate `templates/gitignore/common.gitignore` with
  each detected type's file. If a `.gitignore` exists, append only the
  entries that are missing and clearly apply, under a comment marking the
  addition.
- **Pre-push hook** — copy `templates/repo/pre-push` to
  `.githooks/pre-push`, make it executable, run
  `git config core.hooksPath .githooks`. The config is per-clone, so record
  the one-time step in the instruction file (below).
- **Server-side protection** (separately approved) — where the plan allows
  it, enable a ruleset or branch protection via `gh api` requiring a PR
  before merging into the default branch. The local hook stays regardless:
  it works offline and on every clone.
- **CI** — copy `templates/ci/<type>.yml` to `.github/workflows/ci.yml`,
  then adapt it to the repo's actual tooling per the reference file.
  - **Default branch** — the template hardcodes `main` in the push trigger
    and the concurrency line. If the repo's default branch (resolved in
    phase 1) is not `main`, replace it in both places; GitHub expands no
    variable there, and an unreplaced `main` means CI never runs on merge.
  - **The `run-ci` label** — if the repo is private and you keep the label
    gate, create the label too (`gh label create run-ci -c '#0e8a16'
    -d 'Run CI on this PR'`), or the gate is unusable: `run-ci` is not one
    of GitHub's default labels, so `gh pr edit --add-label run-ci` fails
    until it exists. If the repo is public, strip the gate as the template's
    header comment describes.
  - Several types → one workflow, one job per type — and give each job a
    distinct id (`check-python`, `check-shell`), not the template's shared
    `check`, or the merged workflow has a duplicate mapping key and one job
    silently vanishes. An existing workflow is left alone; report what it
    lacks instead of replacing it.
- **Status files** — run the sibling skill's script:
  `bash <toolkit>/skills/project-status-scaffold/scaffold.sh`. It is
  idempotent and owns those two files; do not reimplement it.
- **Instruction file** — if none exists, suggest generating one (e.g. an
  init command) rather than writing a thin stub. Whether it existed or not,
  append the conventions this scaffold just established so agents and
  humans keep them: the per-clone `git config core.hooksPath .githooks`
  step, and the `run-ci` label if the gate was kept.

## Phase 5 — Verify and report

Re-run the phase 1 checks for the approved items. Done when every approved
item now passes and the report says what was applied, what was skipped and
why, and the one follow-up the user must do themselves on other clones
(`git config core.hooksPath .githooks`). Stop there — committing the
scaffold, pushing, and opening a PR belong to the task workflow, not to this
skill.
