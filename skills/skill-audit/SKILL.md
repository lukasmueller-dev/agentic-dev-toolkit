---
name: skill-audit
description: Audits a repo's local skills against the toolkit's quality criteria and proposes fixes. Use when the user asks to review, audit, lint, or improve the SKILL.md files under .claude/skills — grading whether each description says what and when, whether the body opens with its boundaries and defines "done", and whether side-effecting skills disable model invocation. Read-only until fixes are approved.
---

# skill-audit

Grade the local skills in this repo against the quality bar in
`docs/skill-quality.md`, focusing on the **judgment** criteria a linter cannot
check. Report findings, then fix only what the user approves.

## Boundaries — read these first

- **Read-only until approval.** Phases 1–5 read and report. Never edit a
  `SKILL.md` or any other file before the user has approved specific fixes in
  phase 6.
- **Local skills only.** Audit the skills this repo owns. Skip any skill
  directory that is a symlink resolving *outside* the repo — those are
  installed toolkit skills, not this repo's, and are not yours to grade here.
- **Do not re-implement the mechanical checks.** `bin/skill-lint` owns SQ1–SQ8
  and SQ14. Run it; do not re-derive its rules by hand. Your job is the
  judgment rows.
- **Cite an ID for every finding.** A finding that maps to no criterion in
  `docs/skill-quality.md` is out of scope — say so or drop it.

## Phase 1 — locate the local skills

Find the skills directory the same way `skill-lint` does: use `./.claude/skills`
if it exists, else `./skills`. If neither exists, say so and stop.

List its immediate subdirectories, skipping any whose name starts with `_`. For
each remaining one, if the directory is a symlink, resolve it; drop it from the
audit when the target is outside the repo root (an installed toolkit skill).
The survivors are the skills to grade.

## Phase 2 — mechanical pass

Run `skill-lint <skills-dir>` if `skill-lint` is on `PATH`. Fold its findings
into the report unchanged — they already cite IDs. If it is not on `PATH`, note
"mechanical checks skipped (skill-lint not installed)" and continue; do not try
to reproduce them.

## Phase 3 — load the criteria

Run `bash scripts/criteria-path.sh` (resolve the path from this skill's
directory — the shell's cwd is the audited repo) to get the absolute path to
`docs/skill-quality.md`, then read that file. Grade against the **judgment**
rows only — the reader's half of SQ8, and SQ9–SQ13 and SQ15–SQ18. Do not
restate the criteria from memory; read the current file.

## Phase 4 — judgment pass

Read each surviving `SKILL.md` in full and grade it against every judgment row.
Concretely, for each skill ask:

- **SQ9** — does the description name both *what* it does and *when* to reach
  for it, with the strongest trigger first (it survives truncation)?
- **SQ8** — beyond the first-person openings the linter catches, does the
  description otherwise read as a third-person catalog entry?
- **SQ10–SQ12** — does the body open with the skill's boundaries, number its
  phases, mark any approval gate, and say what "done" means?
- **SQ13** — if the skill has side effects (deploys, commits, sends), does it
  set `disable-model-invocation: true`?
- **SQ15** — do bundled scripts resolve their own path rather than trust `$PWD`?
- **SQ16** — are emitted documents rendered from `templates/`, not embedded?
- **SQ17** — is the shared workflow in `SKILL.md` with ecosystem-specific parts
  in `references/`, and do sibling references keep parity?
- **SQ18** — does it avoid naming a specific machine, hostname, or personal
  workflow?

## Phase 5 — report

Present findings ranked most-severe first. One finding per line:
`<skill>/SKILL.md — [SQxx] <what is wrong and the fix in a clause>`. Group the
`skill-lint` output above it. If a skill is clean, say so; do not invent
findings to fill the report.

## Phase 6 — offer fixes (approval gate)

**Stop and ask before editing anything.** Offer to apply the fixes, and let the
user pick which. Apply only the approved ones, one skill at a time, re-running
`skill-lint` on any skill whose frontmatter you touched.

## Done when

Every local skill has been graded, the ranked report is delivered, and either
the user declined fixes or the approved fixes are applied and re-linted clean.
