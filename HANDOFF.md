# Handoff — agentic-dev-toolkit / claude/cross-repo-skill-quality-f4v5me

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and clear this file back to its headings: a finished task hands
> nothing off.

- **Repo:** agentic-dev-toolkit
- **Branch:** `claude/cross-repo-skill-quality-f4v5me`
- **Worktree:** (wherever this branch is checked out)
- **Last updated:** 2026-07-20 · claude.ai session

## State

Design is agreed; nothing is implemented. The goal: this repo already
enforces a quality bar for its *own* skills (the CI `validate` job in
`.github/workflows/ci.yml` plus the checklist in
`skills/_template/SKILL.md`), but those rules are trapped here — inlined in
CI YAML and prose. The work is to extract that bar into forms that travel,
so the *local* skills in any repo I work in (`.claude/skills/`) can be
checked against the same criteria.

A skill-creation helper was considered and dropped: Claude Code ships a
built-in `skill-creator` skill. Do not build one.

## Next action

Implement the five phases below, in order, one commit (or a few) per phase.
Each phase is shippable on its own; do not start a phase before the previous
one passes the full pre-commit check in `CLAUDE.md` (shellcheck, shfmt,
`bats tests/`, `./install.sh doctor`).

### Phase 1 — `bin/skill-lint`: the mechanical criteria as a portable CLI

Extract every machine-checkable rule into one script, `bin/skill-lint`. It
lands in `~/bin` via the installer's auto-discovery, so it becomes runnable
in every repo with no installer changes. It goes in `bin/`, not `claude/`,
because SKILL.md is an open standard — checking one is not Claude-specific.

Interface:

- `skill-lint [<skills-dir>...]`. With no argument: use `./.claude/skills`
  if it exists, else `./skills`, else exit non-zero with usage.
- Skips `_*`-prefixed skill directories (same rule as the installer).
- Output one finding per line, `<path>: error|warn: <message>`, then a
  summary line. Exit 1 if any error, 0 otherwise. `--strict` promotes
  warnings to errors.

Errors (all currently inlined in the CI `validate` job, plus the checkable
parts of the template checklist): frontmatter block present and delimited;
`name:` and `description:` present; `name` matches the directory name;
name charset `[a-z0-9]+(-[a-z0-9]+)*`, ≤64 chars, and does not contain
"claude" or "anthropic"; `description` ≤1024 chars; bundled `scripts/*`
pass shellcheck and `shfmt -d -i 2 -ci`.

Warnings: description reads first-person (starts with `I `/`You `/`We `);
description too short to trigger well (< ~50 chars).

Degrade, never break: if shellcheck/shfmt are not installed, skip those
checks with a note rather than failing — the linter must be useful on a
machine with nothing but bash.

Then dogfood it: replace the inline skill-checking steps of the CI
`validate` job with `./bin/skill-lint skills/ --strict` (keep the JSON and
template-neutrality steps — they are not skill checks). After this phase
the linter is the single source of truth for the mechanical rules; CI
duplicates nothing.

Tests: `tests/skill-lint.bats`, fixture skills built in `$BATS_TEST_TMPDIR`
— one clean skill, one fixture per violation, the `_template` skip, the
no-argument directory discovery, and the degrade path with shellcheck
stripped from `PATH`. Short narrative doc at `docs/skill-lint.md`.

### Phase 2 — `docs/skill-quality.md`: the criteria get one home

The bar is currently smeared across three places: `_template/SKILL.md`,
`ci.yml` (now `skill-lint`), and the "Authoring a skill" section of
`CLAUDE.md`. Consolidate into `docs/skill-quality.md`:

- Every criterion gets a stable ID (`SQ1`, `SQ2`, …), one sentence of
  rationale, and a tag: **lint** (enforced by `bin/skill-lint`) or
  **judgment** (needs a reader).
- `skill-lint` messages cite the IDs.
- Then de-duplicate the other copies: trim `skills/_template/SKILL.md` to
  the authoring workflow with a checklist of one-liners that reference IDs,
  and trim the `CLAUDE.md` section to a pointer. After this phase, changing
  a criterion means editing exactly one file (plus the linter when the
  criterion is lint-tagged).

### Phase 3 — `skills/skill-audit`: the judgment criteria as a cross-repo skill

A linter can verify a description exists; it cannot tell whether it states
*what and when* with trigger words first, whether the body opens with
boundaries and defines "done", or whether a side-effecting skill is missing
`disable-model-invocation`. That is model work. Build `skills/skill-audit`
from `_template`:

- **Boundaries first:** read-only by default; it proposes fixes and applies
  them only after explicit approval. No side effects otherwise, so leave it
  model-invocable.
- Phases: (1) locate the repo's local skills — `.claude/skills/` (or
  `skills/` when run inside this toolkit), **skipping any entry that is a
  symlink resolving outside the repo**, since those are installed toolkit
  skills, not local ones; (2) mechanical pass via `skill-lint` if on
  `PATH`, noting "mechanical checks skipped" if absent; (3) judgment pass:
  read each SKILL.md and grade it against the judgment-tagged criteria in
  `docs/skill-quality.md`; (4) report findings ranked, each citing a
  criterion ID; (5) offer fixes.
- The criteria doc lives in this repo, but the skill runs in *other* repos
  through a symlink in `~/.claude/skills`. Do not bundle a second copy —
  ship a small `scripts/criteria-path.sh` that resolves the skill's own
  location through the symlink chain back into this checkout (the
  `script_dir()` pattern from `bin/vibe` /
  `skills/project-status-scaffold/scaffold.sh`) and prints the path to
  `docs/skill-quality.md`; the SKILL.md body says to run it, then read that
  file. Bats-test the script's symlink resolution in a temp `HOME`.

### Phase 4 — passive enforcement hook

`claude/hooks/skill-lint-on-edit.sh`, a `PostToolUse` hook matched on
`Write|Edit`: when the touched file lives under a skill directory (a
`*/skills/<name>/` path with a `SKILL.md`), run `skill-lint` on that one
skill and surface findings; otherwise say nothing.

Follow `claude/hooks/README.md` to the letter: bail early on path mismatch
(fast); exit 0 silently when `skill-lint` or `jq` is missing (test with
`PATH= /bin/bash`); surface findings by writing to stderr and exiting 2 —
the documented way to feed text back from a hook. Wire it into the `hooks`
block of `claude/settings.json` (the baseline — the installer merges it)
with a timeout, and add the script to the hooks README table. Tests go in
`tests/hooks.bats`: degrade path, silence on non-skill paths, findings on a
bad fixture skill, and never any exit code other than 0 or 2.

### Phase 5 — per-repo extension: `.skill-lint.conf`

Smallest and last. A repo may *add* rules, never weaken the baseline:

- `skill-lint` looks for `.skill-lint.conf` at the repo root (walk up from
  the skills dir to the git root). Line-based directives parseable in bash
  3.2 — no YAML, no jq dependency:
  - `forbid-pattern <ERE> <message>` — extra grep over SKILL.md bodies
  - `require-field <frontmatter-key>` — extra required frontmatter
  - `ignore-warn <skill-name> <check-id>` — silence a **warning** for one
    skill; errors can never be disabled. The baseline bar is non-negotiable.
- Example config at `templates/skill-lint.conf.example` (the
  `vibe.config.example` precedent), a section in `docs/skill-lint.md`, and
  tests for each directive plus the errors-are-undisablable guard.

### Done when

All five phases are committed (Conventional Commits, bodies say *why*), the
full pre-commit check passes, CI is green on the branch, and
`./bin/skill-lint skills/ --strict` is clean on this repo itself. Then
promote anything durable and clear this file back to its headings.

## Blockers

None.

## Gotchas (unpromoted)

- bash 3.2 and BSD userland apply to `skill-lint`, the hook, and every
  skill script — the macOS leg of CI exists because this has bitten twice.
- The settings merge must stay idempotent in both directions when adding
  the hook to `claude/settings.json`; re-running `install.sh` twice must
  still report `already applied`.
- `Bash(git *)`-style permission-rule pitfalls in `CLAUDE.md` don't apply
  here, but the hook runs on *every* Write/Edit in *every* repo — a slow or
  chatty version degrades every session, which is why "bail early, say
  nothing" is a hard requirement, not a style preference.
