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

Milestones 1 to 5 are done. `bin/vibe`, `bin/vibe-web` and the page name no research or workspace term. `extensions/research/research` owns `vibe ws`, tool jobs, place runs, the research lifecycle and the research card, status and report; `docs/vibe-extensions.md` is the contract as built. Its tests sit in `tests/research-queue.bats`, `research-tool.bats`, `research-web.bats`, `vibe-ws.bats` and `research.bash`; they run the extension from a copy outside the checkout (`research_ext`).

## Next action

Milestone 6 of `SPEC.md`, the end action: update `CLAUDE.md` (layout), `docs/vibe-queue.md`, `docs/workspaces.md` and the CI template check; add the roadmap item for the move to the research repo; rewrite `SPEC.md` into `docs/vibe-extensions.md`, move each decision to the PR body. Done when `test ! -e SPEC.md` and the "Before committing" gate of `CLAUDE.md` passes.

## Blockers

None.

## Gotchas (unpromoted)

- Two research jobs are live until 2026-11-22 20:00: the branch must not merge while a research run is live.
- Three shortcuts carry jobs from before this branch: `ev_pass` writes `publish=push` into a `hid=` job and `card=research` into a `research=` job, and `run_alive` takes a ` queue run --` fork. Drop them once no such job is left.
- A hand-written research job in a test needs `card=research`, else it sits in its repo group: `research_fixture` (`tests/research.bash`) writes it.
- The `tab` lines of every extension go into one tab, named by the first `title` line.
- `vibe-web` reads extension routes once at its start (`vibe ext lines route`): `research_ext` must run before `web_start`.
- A place run is a fork of the extension's `pass` event: `run_alive` matches `*/research event pass`. `$WS_STATES/run.<job id>` holds a copy of the run pid until `run/exit` exists.
- The extension reads `skills/fill-queue/references/`, `templates/job-pr.md`, `templates/job-report.md`, `workspaces/` and `docs/workspaces/` from its own `../..`: `research_ext` copies them; the move to the research repo must carry or find them.
- The core suites still load the checkout's `extensions/research/`: `ext_list` always scans it. A copy with no `extensions/` passes the research suites (105 tests).
- The stub `claude` sources `$STUBS/claude.more` after its mode pick: `research_modes` writes the research modes there.
- The extension executable must not read stdin at `describe` or `event`: `ext_call` gives it `/dev/null`.
- `tests/vibe-queue.bats` runs about 3 times slower in this worktree than in a `git clone` under `$TMPDIR`: run the suites in a clone. The full `bats tests/` takes about 12 min there.
- `vibe-web.bats` fails `routes skip and skip-undo` and `route server-remove` on the base commit too: not this branch.
- `shellcheck` fails SC2016 on `tests/install.bats` line 14 on the base commit too (local shellcheck version).
