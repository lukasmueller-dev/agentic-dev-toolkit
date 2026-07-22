# Handoff — agentic-dev-toolkit / fresh-review-3

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fresh-review-3`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/fresh-review-3
- **Last updated:** 2026-07-22 14:10 UTC · server (srv1841294)

## State

Not started. Mission: a third independent review round — this one an
**execution-focused blind replication**. Round two ran the repo's first
end-to-end execution pass; a single session's run is weak verification, so
this round repeats it with fresh eyes and **no knowledge of what that
session observed**. Execute everything yourself, record what you see, and
only afterwards de-duplicate.

Scope, all in throwaway environments:

1. Full `vibe` lifecycle in a throwaway repo with a bare origin: `start` →
   edit → `sync` → `loop` (bounded, `--max 2`, stub agent) → `done`,
   exercising every `done` guard (dirty, unpushed, handoff content,
   handoff-on-branch, LOOP.md), plus multi-task `done` with one passing
   and one refusing task.
2. The server path for real: hostname-match trick to force `detect_env`
   to server, a real tmux server on an isolated socket, `loop
   --no-attach`, `vibe status` against it, `done --stop` on the live
   session. Also probe failure paths: what happens when tmux cannot
   start, when the agent dies mid-round, when a loop is interrupted.
3. `install.sh` against a throwaway `HOME`: install → doctor → second run
   (must be idempotent: all `ok`, no backups) → `--uninstall` (must
   remove only what the repo owns).
4. Anything the execution turns up gets the usual adversarial read of the
   code behind it.

Isolation is non-negotiable: never the real `HOME`, `~/.claude`, `~/bin`,
or the real worktree root. Mirror `tests/helper.bash`'s scrubbing — unset
`SSH_*`, point `VIBE_SERVER_HOSTNAME` at an unmatchable value (except
when deliberately forcing the server path), redirect `VIBE_CONFIG_FILE`,
stub the agent via `VIBE_AGENT_CMD`.

**Blindness rule:** do NOT read `PROJECT_STATUS.md` Track C, PRs #36/#38,
or their commit bodies until the execution pass is complete and your
findings are written down. Then de-duplicate: anything already fixed or
tracked is confirmation the pass works, not a finding — report it as
replication, separately from new findings.

## Next action

`git rebase origin/main` first — never `vibe resume` (it fast-forwards to
the branch's own upstream and reports "already up to date" while behind
main). Then run the gate as baseline:

```
shfmt -f . | xargs shellcheck
shfmt -d -i 2 -ci .
bats tests/
./install.sh doctor
./bin/skill-lint skills/ --strict
```

A failure is yours — main is green. Then build the throwaway environment
and start with scope item 1.

## Blockers

None.

## Gotchas (unpromoted)

- Unix socket paths cap at ~104 bytes: a tmux socket under a deep scratch
  directory fails with "File name too long" — put the socket somewhere
  short.
- Fixing is in scope, but keep review and repair separable: one commit per
  concern, failure scenario in the body; anything with blast radius beyond
  the obvious (installer safety, destructive git paths, the settings
  merge) needs the owner's go-ahead first.
- Deliverable is a ranked findings list (`file:line`, concrete failure
  scenario, fixed vs left), replications listed separately. The fixes must
  not replace the report.
- CI is opt-in per PR: `gh pr edit N --add-label run-ci`, or the merge box
  reads a skipped run as passing.
