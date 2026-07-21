# Loop — agentic-dev-toolkit / ralphify-vibe-loop

> A task run unattended: each round an agent works toward the goal below, then
> a stop check decides whether it is done. This document is the brief the agent
> is handed every round, so keep the goal and done-criteria precise — they are
> the only instructions it gets.

- **Repo:** agentic-dev-toolkit
- **Branch:** `ralphify-vibe-loop`
- **Worktree:** `/root/git/worktrees/agentic-dev-toolkit/ralphify-vibe-loop`
- **Started:** 2026-07-21 16:25 UTC · server (srv1841294)
- **Stop check:** `grep -q VIBE_LOOP_SANDBOX_ARGS bin/vibe && grep -q VIBE_LOOP_SANDBOX_ARGS docs/vibe-loop.md && grep -q VIBE_LOOP_SANDBOX_ARGS tests/vibe-loop.bats && grep -q -- --for= bin/vibe && grep -q -- --for= tests/vibe-loop.bats && grep -q smallest templates/LOOP.md && bats tests/ && shfmt -d -i 2 -ci . && shfmt -f . | xargs shellcheck`
- **Max rounds:** 12

## Goal

Ralphify `vibe loop` — the Track A roadmap item in `PROJECT_STATUS.md`. Three
independent additions to `bin/vibe`, all shipping on this one branch:

1. **`--sandbox`.** A third source of agent arguments alongside
   `VIBE_AGENT_HEADLESS_ARGS` and `VIBE_LOOP_PERMISSIVE_ARGS`, appended to the
   headless `argv` built in `run_loop` only when the flag is passed. It is
   driven by a new `VIBE_LOOP_SANDBOX_ARGS`, which follows its siblings
   exactly: captured into `_env_loop_sandbox_args` before the config file is
   sourced, resolved `env > config > default`, and **empty by default**. It
   must name no specific agent — the value is the user's to configure, the
   same reason `VIBE_LOOP_PERMISSIVE_ARGS` has no default. Like `PERMISSIVE`,
   it is persisted in `.vibe-loop.state` (a `SANDBOX` key) and carried through
   `loop_effective_settings` so a resumed loop keeps running sandboxed.
   Passing `--sandbox` with the variable unset should die with a pointer to
   the docs, mirroring the `--dangerously-allow-all` guard in
   `loop_parse_args`. Document it in `docs/vibe-loop.md` — a row in the
   configuration table and a paragraph under "Permissions and blast radius" —
   and recommend it over `--dangerously-allow-all` in the startup warning
   `cmd_loop` prints for a fresh non-permissive loop.

2. **`--for <duration>`** (accept `--for=<duration>` too, as `--max` does). A
   wall-clock stop alongside `--max`, because an overnight run is bounded by
   time, not by rounds. Parse a short duration (e.g. `90m`, `6h`), reject
   anything else with a clear message like `--max` does, resolve it to a
   deadline, and store it in `.vibe-loop.state` so a resumed loop honours the
   original deadline rather than restarting the clock. Check it in `run_loop`
   beside the max and stall checks, after the round's push, so the last
   iteration is never left unpushed; report a distinct stop reason and send
   the matching `ntfy_push`. Add it as a fourth row to the stop table in
   `docs/vibe-loop.md` ("The three ways it stops" becomes four).

3. **One-task-per-round discipline in `templates/LOOP.md`.** Write into the
   template that each round does the *smallest complete task* that moves the
   goal and then stops, rather than trying to finish everything in one round —
   per-round context stays fresh, and each round's work lands as its own
   commit. This is a change to the shared template only; the word "smallest"
   must appear in it.

Each part carries tests in `tests/vibe-loop.bats`, in the style already there:
throwaway git repos under `$BATS_TEST_TMPDIR`, the stub `tmux` from
`tests/helper.bash`, and assertions against `$VIBE_TEST_TMUX_LOG` rather than
a live tmux server.

## Done when

The stop check in the header passes. It proves both halves of the job: the
greps prove all three features actually exist and are documented and tested
(`VIBE_LOOP_SANDBOX_ARGS` present in `bin/vibe`, `docs/vibe-loop.md` and
`tests/vibe-loop.bats`; `--for=` handled in `bin/vibe` and exercised in
`tests/vibe-loop.bats`; "smallest" written into `templates/LOOP.md`), and the
tail — `bats tests/`, `shfmt -d -i 2 -ci .`, `shfmt -f . | xargs shellcheck` —
proves nothing else broke and the repo's own pre-commit gates still pass. The
greps run first so a round that has not landed a feature yet fails in
milliseconds. The whole check ran clean on `main` except the greps, so it
cannot pass until real work exists.

## Constraints

- **Never open a PR, merge, or force-push.** The loop's job ends at a pushed
  branch; review is a human step.
- **bash 3.2 and BSD + GNU userland.** macOS still ships bash 3.2: no
  `mapfile`, no associative arrays, no `${var,,}`, and expand possibly-empty
  arrays as `"${arr[@]+"${arr[@]}"}"`. Use `sed -E`, never `\|` in a BRE; no
  `readlink -f`; `stat` needs both `-c %Y` and `-f %m`. Computing a deadline
  is exactly where this bites — `date -d` is GNU-only and `date -v` is
  BSD-only, so do the arithmetic in shell on a plain `date +%s`.
- **`[[ cond ]] && cmd` must not be a function's last statement** — the
  function's exit status becomes that command's and trips `set -e`. Use
  `if cond; then cmd; fi` there.
- **`VIBE_LOOP_SANDBOX_ARGS` stays empty by default and agent-agnostic.** A
  Claude-specific default was already considered and deliberately rejected;
  do not add one, and do not name any agent CLI in `bin/vibe` or in
  `templates/LOOP.md`.
- **Do not rename or change the behaviour of existing flags, state keys, or
  functions.** `--max`, `--until`, `--push`, `--no-attach`,
  `--dangerously-allow-all` and the existing `.vibe-loop.state` keys keep
  working exactly as they do; a loop written by the old code must still
  resume under the new code.
- **Leave these files alone:** `claude/settings.json` (the sandbox baseline is
  in flight on another branch, PR #19), `install.sh`, `tests/helper.bash`, and
  every test suite other than `tests/vibe-loop.bats`.
- **No new dependencies.** Nothing beyond git, bash, coreutils, tmux, and the
  tools already required.
- **Do not edit `PROJECT_STATUS.md`.** Ticking the roadmap box happens after
  this merges, not inside the loop.
- **Never run `vibe loop`, `vibe done`, or `vibe start` from inside the
  round** — the agent is already running inside a loop worktree.

## Iteration log

_One line per round that changed something, newest last._
