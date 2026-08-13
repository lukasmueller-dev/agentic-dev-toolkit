# Handoff — agentic-dev-toolkit / fix-status-json-macos

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fix-status-json-macos`
- **Worktree:** /home/mueller/git/worktrees/agentic-dev-toolkit/fix-status-json-macos
- **Last updated:** 2026-08-13 16:28 CEST · local (gosling)

## State

Not started. `tests/vibe-status-json.bats` fails 11 cases on macOS and passes
on Linux, and has done since `vibe status --json` landed in PR #70 (`6a8f74d`,
2026-07-31). The default branch's macOS CI leg has been red ever since — runs
`30641073941` and `30761942049` on the default branch, and again on PR #72's
run `31709617414` (job `94478872256`), where these are the *only* failures.

Failing: tests 324, 326–332, 334, 336, 337. Passing: 325, 333, 335, 338. So
it is not the whole file, and not the whole document.

What is already ruled out, from reading the macOS logs:

- **Not a path-matching failure in the file's `task_block` helper.** Test 324
  asserts `"loop": null` and then `"kind": "task"` against the same extracted
  block; the first passes and the second fails. The block is therefore found
  and non-empty, so the helper is locating the right task object.
- **Not a single wrong field.** The failing assertions span `"kind"`,
  `"dirty"`, `"state"`, `"tmux_session"`, `"detached"`, `"updated"` and
  `"iter"` — several unrelated derived values are wrong at once.

The closest suspect is `worktree_records` in `bin/vibe` (around lines
2116–2126), which derives these values and already carries a comment about
resolving paths the macOS way. That is a starting point, not a diagnosis.

## Next action

Make the failure legible before theorising about it. Add a temporary
diagnostic to the failing cases that prints the extracted block *and* the full
`status --json` document when an assertion fails, push it on a branch carrying
the CI label, and read the macOS job log. One run buys the actual output,
which nothing available on Linux does. Batch every diagnostic into that single
push — see Blockers.

## Blockers

Reproduces only on macOS. CI is opt-in per pull request and its macOS leg
bills at ten times the Linux rate, so each diagnostic iteration costs real
money. That is the reason to instrument everything at once rather than
bisecting across several runs.

## Gotchas (unpromoted)

A red macOS leg on the default branch means every pull request's macOS job is
red too, so a genuinely new macOS failure is currently invisible — which is
how this one survived two merges. That argues for fixing it ahead of its
actual severity.

A second, independent portability bug was found and fixed in the same period
(date arithmetic that only the macOS leg could catch, PR #72). If this task
also ends up adding a way to exercise a macOS-only path from Linux, the two
belong in the repo's instructions together, as one note about which traps this
suite can and cannot see.
