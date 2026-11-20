# Handoff — agentic-dev-toolkit / extension-seam

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `extension-seam`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/extension-seam
- **Last updated:** 2026-11-20 · turing

## State

Milestones 1 to 4 are done. `bin/vibe`, `bin/vibe-web` and the page name no research or workspace term. `extensions/research/research` owns `vibe ws`, tool jobs, place runs, the research lifecycle and the research card, status and report; `docs/vibe-extensions.md` is the contract as built. The tests still hold research and `ws` cases in `tests/vibe-queue.bats`, `tests/vibe-web.bats` and `tests/helper.bash`.

## Next action

Milestone 5 of `SPEC.md`: move the research and `ws` tests, helpers (`research_fixture`, `wsfold`, the research stub modes) and stub modes into their own files; they pass with `extensions/research/` copied outside the checkout. Done when `grep -ci research tests/vibe-queue.bats tests/vibe-web.bats tests/helper.bash` prints 0 for each file and `bats tests/` passes.

## Blockers

None.

## Gotchas (unpromoted)

- Two research jobs are live until 2026-11-22 20:00: the branch must not merge while a research run is live.
- Three shortcuts carry jobs from before this branch: `ev_pass` writes `publish=push` into a `hid=` job and `card=research` into a `research=` job, and `run_alive` takes a ` queue run --` fork. Drop them once no such job is left.
- A hand-written research job in a test needs `card=research`, else it sits in its repo group: `research_fixture` writes it.
- The `tab` lines of every extension go into one tab, named by the first `title` line.
- `vibe-web` reads extension routes once at its start (`vibe ext lines route`): the module's `ROUTES` holds the built-in ones only.
- A place run is a fork of the extension's `pass` event: `run_alive` matches `*/research event pass`. `$WS_STATES/run.<job id>` holds a copy of the run pid until `run/exit` exists.
- Research tests in `tests/vibe-queue.bats` pick the stub `claude` mode from prompt lines (`CLAUDE.md`, "Before committing").
- A suite run inside a queue job inherits `VIBE_JOB_DIR`: `vibe queue gpu` in a test then writes `gpu-cmd` into the live job dir. `unset VIBE_JOB_DIR` in setup.
- The extension executable must not read stdin at `describe` or `event`: `ext_call` gives it `/dev/null`.
- `tests/vibe-queue.bats` runs about 3 times slower in this worktree than in a `git clone` under `$TMPDIR` (7 min there): run the full file in a clone.
- `vibe-web.bats` fails `routes skip and skip-undo` and `route server-remove` on the base commit too: not this branch.
- `shellcheck` fails SC2016 on `tests/install.bats` line 14 on the base commit too (local shellcheck version).
