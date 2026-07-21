# Loop — agentic-dev-toolkit / vibe-ui

> A task run unattended: each round an agent works toward the goal below, then
> a stop check decides whether it is done. This document is the brief the agent
> is handed every round, so keep the goal and done-criteria precise — they are
> the only instructions it gets.

- **Repo:** agentic-dev-toolkit
- **Branch:** `vibe-ui`
- **Worktree:** `/root/git/worktrees/agentic-dev-toolkit/vibe-ui`
- **Started:** 2026-07-20 22:32 UTC · server (srv1841294)
- **Stop check:** `bats tests/vibe-ui.bats`
- **Max rounds:** 10

## Goal

Make `vibe`'s terminal output color-safe and visually consistent. `vibe` has no
graphical UI — its "UI" is what it prints to the terminal, all in `bin/vibe`.

1. **Color safety.** The `c_*` color variables are defined at `bin/vibe:138-143`
   (`c_red c_grn c_yel c_dim c_bld c_off`) and always hold raw ANSI escapes, so
   color leaks into pipes, files, and pagers. Add a guard where they are defined
   that resolves every `c_*` variable to an empty string when stdout is not a
   terminal (`[ -t 1 ]` is false) OR when `NO_COLOR` is set to any value, and
   keeps colors when `CLICOLOR_FORCE` is set even if stdout is not a TTY. Do this
   once at the definition site so every command inherits it.
2. **Consistent message style.** Unify the `die/info/warn/ok` helpers
   (`bin/vibe:145-151`) and the `d_ok/d_wn/d_no` doctor helpers so every command
   speaks one visual language — a consistent leading symbol and color per
   severity. Pick one symbol scheme (e.g. `✓ ⚠ ✗`) and apply it everywhere.
3. **status / doctor polish.** In `cmd_status` and `cmd_doctor`, align columns
   and apply the unified symbols/spacing so sections read as a coherent report.
4. **Restructured help.** Replace the `grep '^#'` help in `main()`'s
   `-h|--help|help` branch with a structured, aligned command reference that
   lists every command and a one-line summary.

## Done when

`bats tests/vibe-ui.bats` passes. That file does not exist yet — creating it is
part of this task. It must assert these **objective** properties (do not weaken
them to make them pass — implement the code until honest assertions hold):

- `NO_COLOR=1 vibe status` emits **zero** `\033[` / ESC escape sequences.
- `vibe status` with stdout piped to a non-TTY (e.g. `vibe status | cat`) emits
  **zero** escape sequences.
- With color forced on a TTY (`CLICOLOR_FORCE=1`), escapes **are** present — this
  proves colors were gated, not deleted.
- `vibe help` output contains every command in `main()`'s dispatch:
  `start loop attach park rc status list done sync resume where doctor`.
- The full existing suite `bats tests/` still passes (no regressions).

The stop-check test enforces the color-safety core and help completeness. The
status/doctor alignment and message-style polish (items 2–3) are subjective and
are guided by this brief's prose, not all gated by the check — do them anyway.

## Constraints

- **Only edit `bin/vibe` and add `tests/vibe-ui.bats`.** Leave every other file
  alone: no changes to skills, templates, `install.sh`, other tests, or docs.
- **Style only, not behavior.** Do not change what any command *does* or the
  informational content it prints — only its coloring, symbols, alignment, and
  the help layout.
- **Portability is mandatory** (repo `CLAUDE.md`): bash 3.2 (macOS ships it — no
  `mapfile`, no associative arrays, no `${var,,}`), and BSD + GNU userland. Must
  pass `shellcheck` and `shfmt -i 2 -ci` on every changed file. Run
  `shfmt -f . | xargs shellcheck` and `shfmt -d -i 2 -ci .` before considering a
  round done.
- Do not force-push. Do not disable or delete existing tests to get green.

## Iteration log

_One line per round that changed something, newest last._

- Round 1: gated `c_*` colors on `[ -t 1 ]`/`NO_COLOR`/`CLICOLOR_FORCE`; unified
  `die/info/warn/ok` and doctor's `d_ok/d_wn/d_no` on a ✓/⚠/✗ symbol scheme;
  colored dirty/clean in `sync_state_line`; replaced the `grep '^#'` help with
  `cmd_help` (structured, aligned, colored); added `tests/vibe-ui.bats`
  (4 tests, all passing). shellcheck/shfmt clean. Full `bats tests/` shows the
  same ~44 pre-existing failures on this VPS shell (SSH_CONNECTION set →
  detect_env()=="server" → tmux attach fails with "no current client"),
  unrelated to this change — verified by re-running one (`status: shows
  per-worktree sync state`) in isolation and seeing the same root cause. Could
  not confirm with a clean-env run in this session: env-prefixed/`bash -c`
  invocations of `bats` required interactive approval unavailable in this
  autonomous loop.
- iter 3 (2026-07-21 01:19): changed
