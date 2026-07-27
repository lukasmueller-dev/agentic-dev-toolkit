# Handoff — agentic-dev-toolkit / skill-handoff-start

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `skill-handoff-start`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/skill-handoff-start
- **Last updated:** 2026-07-27 03:42 UTC · server (srv1841294)

## State

Not started. The goal is two entry points for staging a task brief, differing
only in who launches the session:

- `handoff-brief` (exists) — stages the brief, prints the start command,
  launches nothing. Stays as it is apart from one pointer line to its sibling.
- `handoff-start` (new) — stages the same brief and then launches the session
  itself, so the person staging it never has to run `vibe start`.

**Decided: `handoff-start` is a thin wrapper, not a copy.** Its `SKILL.md`
delegates phases 1–5 to `handoff-brief` and adds only the launch step.
Duplicating five phases is the drift this repo has already been bitten by —
three copies of `HANDOFF.md`. The launch block is modelled on
`skills/codebase-review/SKILL.md:138-163`: on a server
`vibe start <task> --no-attach`, then print `vibe attach <task>`; locally
print the command and stop, since `--no-attach` is rejected off a server.

**Decided: the kickoff turn narrows to `--no-attach` only.** Today
`open_session` appends `Begin per HANDOFF.md.` on any fresh launch that finds
real handoff content — `bin/vibe:1728` (server), `:1772` (local exec), and the
dead-pane relaunch at `:1743`, which reuses `launch_fresh`. The wanted
behavior: a session someone is attaching to opens with the handoff injected as
context by the SessionStart hook and *waits* for them to say go; only a
session nobody is attaching to begins by itself.

Rejected: gating on a tty (`[[ ! -t 0 ]]`) instead of on the flag. bats runs
without a tty, so every existing kickoff test would silently take the
non-interactive branch, and the interactive case would need
`tests/pty-run.py`. `--no-attach` is both the semantically right signal —
nobody is attaching — and testable as things stand.

Tests in `tests/vibe.bats` that move: the two template-only cases and
"start: `--no-attach` sends the kickoff (server)" stay green;
"start: local exec appends the kickoff prompt…" (~:813) and the dead-pane
attach case (~:1225) invert to asserting the prompt is *absent*. Add one for
an attaching server start (no `--no-attach`) sending no kickoff.

`PROJECT_STATUS.md` carries the 2026-07-23 decision that introduced the
kickoff; this narrows it, so that entry needs a superseding line rather than a
silent contradiction. A README skills-table row is also needed.
`install.sh` auto-discovers a new directory under `skills/`, and
`.claude-plugin/plugin.json` needs no edit — it lists agents as files, while
skills come from the directory.

## Next action

Narrow the kickoff in `bin/vibe` first: build `launch_fresh` with the prompt
only when `no_attach == 1`, which touches all three sites above — the
dead-pane relaunch in the attach path is the easy one to miss. Flip the two
tests, add the attaching-start test, and get `bats tests/` green **before**
writing the skill. The behavior change is the part that can break a live
session; the skill is purely additive.

## Blockers

None.

## Gotchas (unpromoted)

`vibe start` and `vibe attach` share `open_session`, so the change lands in
both paths whether or not that was intended. `handoff-brief`'s Phase 5 gets
one pointer line to the sibling, never a second copy of the launch
instructions. Repo gates before the PR: `shfmt -f . | xargs shellcheck`,
`shfmt -d -i 2 -ci .`, `bats tests/`, `./bin/skill-lint --strict skills` —
with `skills` passed explicitly, and the new skill `git add`ed before `bats`
runs, or the suite's stray-file guard fails on it. CI is opt-in per PR
(`run-ci` label).
