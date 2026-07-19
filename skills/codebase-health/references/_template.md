# <Language> rules

Copy this file to `references/<language>.md` and fill in every section.
The pipeline reads it during preflight for repos containing this language.
Keep the same section names — SKILL.md refers to them.

## Candidate-finding tools

List the deterministic tools that surface candidates for each category,
with exact invocations. Always include the reminder that a missing tool is
skipped with a note, not treated as an error.

- `<linter>` — lint, unused code.
- `<complexity tool>` — which threshold counts as a candidate.
- `<clone detector>` — exact/near-exact duplication.

## Semantic duplication pre-filter

State the cheap similarity signals used to shortlist pairs before judgment
(length within ~30%, signature shape, shared identifiers — adapt to the
language's units: functions, methods, components, modules).

## Test discovery

Where the real test command lives for this ecosystem (manifest scripts,
Makefile, CI config), and the common frameworks to expect.

## Doc surfaces

The documentation artifacts this ecosystem typically has, each paired with
the code it must be checked against (doc comments vs. signatures, README
vs. manifest, CLAUDE.md vs. repo, example configs vs. real keys).

## Behavior-risk traps — report, never auto-fix

The language-specific ways a "safe cleanup" silently changes behavior.
This is the most valuable section: it is what keeps the skill's
no-behavioral-change promise honest in this language.
