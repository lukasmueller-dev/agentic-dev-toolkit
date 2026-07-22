# Handoff — agentic-dev-toolkit / fresh-review-2

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fresh-review-2`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/fresh-review-2
- **Last updated:** 2026-07-22 03:58 UTC · server (srv1841294)

## State

Not started. Mission: a second independent, in-depth review of this repo —
repo health, loose ends, and a code review, with fresh eyes. Unlike the
first round, **you may fix what you find as you go**, not just report it.

**This is round two, and its value depends on not re-finding round one.**
That round landed as PR #36 (11 commits, merged) and opened a `Track C —
verification debt` in `PROJECT_STATUS.md`. Do your own discovery pass
*first*, then read those two and de-duplicate against them. Rediscovering
something already fixed or already tracked is a sign the pass is working —
it is not a finding, and must not be reported as one.

What round one already covered, so you can weight your effort elsewhere:
adversarial static reading of `bin/vibe`, `install.sh`, `bin/skill-lint`,
`claude/hooks/`, the skill scripts and `.githooks/`; docs-vs-code drift
across README, `docs/`, every `SKILL.md`, help text and completions;
test-suite blind spots plus a harness leak audit; and CI workflow
correctness with branch and remote hygiene.

Where it was thin, and where this round should push hardest:

- **Nothing was executed end-to-end.** No `vibe start`, `vibe loop`,
  `vibe done` or `install.sh --uninstall` was ever run through a full
  lifecycle in a throwaway repo. The server/tmux paths were reviewed by
  reading only. This is the single biggest gap.
- **Skill *quality*, not just lint.** The judgment criteria in
  `docs/skill-quality.md` — does a description say what *and when*, does
  the body open with its boundaries and define "done", do side-effecting
  skills disable model invocation — were never graded. Only the mechanical
  rules `bin/skill-lint` enforces were.
- **`claude/agents/*.md`, `memory/GLOBAL.md`, and `templates/` rendering**
  got only a light pass.
- **Permission-rule safety** in `claude/settings.json`. `CLAUDE.md` warns
  that `*` spans spaces (so `Bash(git *)` would allow `git push --force`)
  and that a leading `/` in a path rule anchors to the settings file's own
  directory. Nobody audited the actual rules against either trap.
- **Cross-file consistency**, e.g. the three literal copies of the
  handoff-scaffold regex (`bin/vibe`, `claude/hooks/session-start-handoff.sh`,
  `skills/_lib/vibe-lib.sh`) kept in lockstep by comment alone.

Hold everything to the repo's documented conventions: bash 3.2, BSD *and*
GNU userland, the `set -e` tail-statement trap, the `pipefail`/SIGPIPE rule
(added to `CLAUDE.md` by round one, after that shape turned up three
times), the installer's safety rules, and the template contract.

## Next action

**Rebase onto the current default branch first — `git rebase origin/main`,
never `vibe resume`.** `resume` fast-forwards a branch to *its own*
upstream, so it reports "already up to date" while leaving you arbitrarily
far behind `main`. That exact mistake made round one review nine-commit-old
sources and spend effort on eight findings that were already fixed
upstream.

Then run the repo's own verification and treat only what it does *not*
catch as the review's real target:

```
shfmt -f . | xargs shellcheck
shfmt -d -i 2 -ci .
bats tests/
./install.sh doctor
./bin/skill-lint skills/ --strict
```

Baseline at the time of writing: all clean, `bats` 260/260.

Then start with the biggest gap — drive `vibe` through a **full lifecycle
in a throwaway repo**: `start` → work → `sync` → `loop` (bounded, with
`--max 2`) → `done`, plus `install.sh` install → doctor → `--uninstall`
against a throwaway `HOME`. Never against the real `$HOME`, `~/.claude`,
`~/bin`, or the real worktree root. Then work the rest of the emphasis
list above.

Verify every finding against the actual code before acting on it, and
re-check it against `origin/main` — something fixed upstream is not a
finding. Anything reasoned but unproven must be labelled as such.

## Blockers

**CI cannot verify anything: GitHub Actions is billing-blocked**
(`PROJECT_STATUS.md`, Track C item 1). The macOS leg is the only place
bash 3.2 and BSD userland are exercised, and it has not run since
2026-07-21 — so round one's 11 merged commits are themselves unverified on
that platform. Until billing is cleared, the five commands above are the
only gate, and a portability regression can merge green. Clearing it is the
highest-value action available and unblocks judging this round's own work.

Note also that CI is **opt-in per PR**: a PR runs nothing unless it carries
the `run-ci` label, and GitHub's merge box reads a skipped job as passing.

## Gotchas (unpromoted)

- **Fixing is in scope this round**, but keep review and repair separable:
  one commit per concern with the failure it prevents in the body, so any
  single fix can be reverted alone. Anything with a blast radius beyond the
  obvious — installer safety rules, destructive git paths, the settings
  merge — gets the owner's go-ahead before it lands, not after.
- The deliverable is still a **ranked findings list**, each with
  `file:line` and a concrete failure scenario, saying which items were
  fixed and which were deliberately left. Do not let the fixes replace the
  report.
- Round one's own process lesson, worth repeating: parallel reviewers over
  independent tracks worked well, but every one of them reviewed a stale
  tree. Rebase *before* dispatching them, not after.
