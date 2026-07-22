# Handoff — agentic-dev-toolkit / fresh-review

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fresh-review`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/fresh-review
- **Last updated:** 2026-07-22 · server (srv1841294)

## State

Review done, and the code fixes that came out of it are committed — eight
commits on top of `origin/main` (`d633013`), rebased. Each commit body carries
the *why*; this section is only the map.

Verification after the changes: shellcheck 0, `shfmt -d -i 2 -ci` 0,
`bats tests/` **260/260** (257 on main + 3 added), `skill-lint --strict` 0,
`./install.sh doctor` all-ok.

**Fixed here** (one commit per concern, in `git log` order):

| Commit | What it stops |
| --- | --- |
| `fix(vibe)` | a `--pr` loop exiting 141 after pushing and never opening the PR (SIGPIPE under `pipefail`); a blank tmux pane killing `wait_for_pane_idle`; a failed *first* push reported to your phone as "remote diverged" |
| `fix(claude)` | the session-end hook warning "stale handoff" on every correctly-finished session; `curl -d` reading a leading `@` in a notification as a filename and posting a local file to a public ntfy topic |
| `fix(install)` | the settings merge silently deleting user-added hooks on every run, while still letting a renamed baseline hook retire cleanly |
| `ci` | post-merge runs on `main` cancelling each other (the only verification an opt-in-CI repo gets); two neutrality guards that would pass forever if their file were renamed; `.vibe-loop.state*` reaching a commit |
| `fix(skill-lint)` | unterminated frontmatter passing SQ1 whenever the body held a `---` rule; valid single-quoted YAML failing SQ3/SQ4 under `--strict` |
| `fix(config)` | `export KEY=value` — which `vibe` sources and `doctor` blesses — being invisible to the skill lib and both completions, so they resolved a different worktree root |
| `docs` | `commit-push-pr` instructing agents to clear `HANDOFF.md` instead of deleting it, producing a branch `vibe done` blocks and CI fails |
| `test` | `script_dir`'s symlink walk and `settings.json`'s hook paths — two breakages the suite could not see at all |

**Deliberately not fixed** — these are yours, not code:

1. **GitHub Actions is billing-blocked.** No run since 2026-07-21 23:22; PRs
   #33, #34 and #35 merged with zero CI. Nothing is broken (`d633013` passes
   locally, and so does this branch), but nothing is *verified* either, and
   none of the eight commits above can be checked on macOS/bash 3.2 until
   this is cleared. Highest-value action in the repo.
2. **`origin/claude/open-source-alternatives-2yiha7`** — 2 commits, 228 lines
   of `docs/plugins.md`, no PR ever opened, not on main. It is the design doc
   for the *open* `PROJECT_STATUS.md:82-86` TODO. Recover before pruning
   anything.
3. **Branch pruning** — 20 fully-merged remote branches, 4 locals with `gone`
   upstreams, 4 abandoned brief-only branches. Safe, but do it after (2).

**Left alone on purpose**, recorded so the next session need not re-derive it:

- `install.sh:704-705` chmods `+x` inside the developer's checkout, and
  `tests/install.bats` runs the real installer ~25× per suite run. A no-op
  today because every such file is already executable; it would bite the day
  someone adds a deliberately non-executable `*.sh` under a skill. The
  standing guard at `tests/install.bats:101` filters mode-only changes by
  design.
- `tests/helper.bash` never redirects `HOME` (only `install.bats` does),
  contra CLAUDE.md. Nothing exploits it today — verified by marker-file diff
  that no test writes outside `$BATS_TEST_TMPDIR` — but the defaults are one
  forgotten wrapper away from the real worktree root.
- Remaining uncovered paths: the whole server side of
  `cmd_loop`/`cmd_loop_run`/`cmd_rc`, `--uninstall --dry`, both jq-absent
  degrades, `vibe list`, a *conflicting* `resume --rebase`. Plus four
  weak/vacuous assertions (`install.bats:172`, `vibe-loop.bats:100`,
  `hooks.bats:322`, `vibe-ui.bats:50`).
- bash 3.2 is genuinely running on the macOS leg (confirmed in a job log) but
  is never *asserted*; a runner image change would retire the guarantee
  silently.
- Minor doc drift: `docs/vibe.md:170` `--force` "overrides every check" (the
  running-loop guard is unconditional) · `project-status-scaffold/SKILL.md:29`
  points at a template that is not there ·
  `implement-test-suite/SKILL.md:13,103` names `codebase-healthiness`
  (it is `codebase-health`) · `docs/vibe-loop.md:20-29` "four ways it stops"
  omits the diverged-remote fifth.

## Next action

Clear the Actions billing, then run this branch's CI (the PR needs the
`run-ci` label) so all eight commits get verified on macOS and bash 3.2 —
the leg most likely to catch a portability mistake in them. Then recover the
orphaned plugins branch.

## Blockers

GitHub Actions cannot run — billing. Nothing on this branch is verified
beyond a Linux/bash-5 run of the repo's own four checks.

## Gotchas (unpromoted)

- `vibe resume` ≠ "catch up to main": it targets the branch's own upstream,
  so it reports success while leaving you on stale code. This is now written
  into `docs/vibe.md`; **promote the reviewing lesson too** — re-validate
  findings against `origin/main` before reporting, or a review pass reads
  code that was fixed days ago. Belongs in `CLAUDE.md` if review passes
  become routine.
- The `$(… | head -n)` shape under `set -euo pipefail` is a recurring bug
  class here, not a one-off — three instances found, two of them live.
  Worth a lint rule or a line in `CLAUDE.md`'s shell section.
