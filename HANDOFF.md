# Handoff — agentic-dev-toolkit / skill-quality

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and clear this file back to its headings: a finished task hands
> nothing off.

- **Repo:** agentic-dev-toolkit
- **Branch:** `skill-quality`
- **Worktree:** this checkout
- **Last updated:** 2026-07-21 · server session

## State

All five phases of the cross-repo skill-quality plan are **implemented,
pushed, green, and mergeable**: PR #6
(`feat: cross-repo skill-quality tooling`), branch `skill-quality` → `main`.
All 4 CI jobs pass (`gh pr checks 6`), `mergeable_state: clean`.

What shipped, one commit each:
- `bin/skill-lint` + CI dogfood + `tests/skill-lint.bats` + `docs/skill-lint.md`
- `docs/skill-quality.md` (SQ1–SQ18, one home) + `_template`/`CLAUDE.md` trimmed
- `skills/skill-audit` (judgment pass) + `criteria-path.sh` + tests
- `claude/hooks/skill-lint-on-edit.sh` wired into settings baseline + tests
- `.skill-lint.conf` per-repo rules + `templates/skill-lint.conf.example` + tests

Two follow-up fixes landed once CI actually ran (it hadn't before — see
below): the `bats` CI job never installed `shellcheck`/`shfmt`, so
`skill-lint.bats`'s real-tool tests failed on `ubuntu-latest`
(`fix(ci): install shellcheck and shfmt in the bats job`); and
`tests/skill-audit.bats` compared against an unresolved `$TK` path, which
diverged from `criteria-path.sh`'s physically-resolved output only on
macOS, since `/var` is a symlink to `/private/var` there
(`fix(tests): resolve $TK physically in skill-audit.bats`).

The auth blocker (token missing `workflow` scope, needed to push a commit
touching `.github/workflows/ci.yml`) is resolved: `gh auth refresh -h
github.com -s workflow` ran, then the branch pushed clean. `main` had since
moved (PR #4, `loop-prompt-file-setup`, merged its own `HANDOFF.md`), so this
branch also merged `origin/main` in (commit `fbac44d`), keeping this branch's
`HANDOFF.md` on the "ours" side of that conflict — that merge is also *why*
CI hadn't run yet: GitHub won't build the `pull_request` test-merge ref (and
so never triggers the workflow) while a PR conflicts with its base.

## Next action

1. Review and merge PR #6.
2. PR #5 (`docs: hand off the cross-repo skill-quality plan`) is superseded —
   it's this branch's own first commit (`7916e53`); consider closing it once
   #6 merges so it doesn't dangle.

Then promote nothing further (durable state already lives in `docs/` and
`CLAUDE.md`; this repo keeps no `PROJECT_STATUS.md`) and clear this file back to
its headings.

## Blockers

None.

## Gotchas (unpromoted)

None — the bash-3.2 / BSD-userland and settings-merge-idempotency gotchas the
plan flagged were observed throughout and are already enforced by CI and the
bats suite.
