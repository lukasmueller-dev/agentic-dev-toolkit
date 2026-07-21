# Handoff — agentic-dev-toolkit / session-start-handoff

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and clear this file back to its headings: a finished task hands
> nothing off.

- **Repo:** agentic-dev-toolkit
- **Branch:** `session-start-handoff`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/session-start-handoff
- **Last updated:** 2026-07-21 · server (srv1841294)

## State

Not started. Context: the toolkit's handoff flow has a gap at the receiving
end. `vibe start` launches the agent inside the task's worktree, but nothing
feeds `HANDOFF.md` to it — the human has to say "read HANDOFF.md" as the
first prompt. The decision: close the gap with a Claude Code **SessionStart**
hook that injects the handoff's content as session context when one is
present and actually carries content.

What exists today, to build against:

- `claude/hooks/session-end-handoff.sh` — the SessionEnd staleness reminder.
  Reuse its shape: read stdin JSON with `jq`, resolve the repo root via
  `git -C "$cwd" rev-parse --show-toplevel`, degrade to a silent `exit 0`
  when `jq`/git/file is missing. SessionEnd cannot inject context;
  SessionStart can — that asymmetry is documented in
  `claude/hooks/README.md`, which also holds the hook conventions (never
  break the session, test the no-op path).
- `handoff_carries_content` in `bin/vibe` (bin/vibe:847) — the
  "scaffolding-only" line filter that distinguishes a seeded-but-empty
  handoff from one with real content. The hook needs the same check so a
  blank scaffold is not injected.
- `claude/settings.json` is the baseline the installer merges into the live
  file; the new hook is wired there under a `SessionStart` matcher. It is
  real JSON, parsed by CI — no comments.

Design decisions made: inject only when the handoff carries content beyond
the template scaffolding; anchor to the git toplevel of the session's cwd
(same as the SessionEnd hook); keep the hook agent-side (`claude/hooks/`),
not in `bin/` — it is Claude Code-specific by nature, which is the correct
side of the repo's top-level split. Decision left open for the session:
which SessionStart `source` values to inject on (`startup` vs also
`resume`/`clear`/`compact`) — injecting on every resume may duplicate
context; check Claude Code's current hook payload docs and pick
deliberately, recording the choice in the commit body.

## Next action

Read `claude/hooks/README.md` and `claude/hooks/session-end-handoff.sh` for
the conventions, then create `claude/hooks/session-start-handoff.sh`: parse
`cwd` (and `source`) from stdin JSON, locate `<root>/HANDOFF.md`, apply the
carries-content filter, and emit the file's content the way SessionStart
hooks add context (verify the current mechanism — plain stdout vs
`hookSpecificOutput.additionalContext` — against Claude Code docs before
writing). Then add the `SessionStart` entry to `claude/settings.json` and a
bats test covering the degrade-to-no-op paths (no jq, no repo, no handoff,
scaffold-only handoff) plus one for the inject path.

## Blockers

_What is stopping progress, and what would unblock it._

## Gotchas (unpromoted)

- The carries-content regex will then exist in three places (`bin/vibe`
  twice, the hook once); the in-flight `vibe-refactor` task (item 5) hoists
  the two in `bin/vibe` into one. The hook cannot source `bin/vibe`, so a
  comment on both sides naming the other copy is the lockstep mechanism —
  same pattern as `ensure_worktree` / `skills/loop-brief/brief.sh`.
- Hooks run inside a live session: every failure path must `exit 0`
  silently (missing jq, no git, unreadable file). Repo rule: add a bats
  test when you add a guard.
- `claude/hooks/` is linked as a directory by the installer — a new script
  there needs no installer change, but the `settings.json` hook entry only
  reaches the live machine after `./install.sh` re-merges; run it and
  `./install.sh doctor` before calling the task done.
- On the VPS, run bats with
  `env -u SSH_CONNECTION -u SSH_TTY -u VIBE_SERVER_HOSTNAME bats tests/`.
- Shell rules apply: shellcheck-clean, `shfmt -i 2 -ci`, bash 3.2, BSD/GNU
  userland.
- Direct push to main is blocked by `.githooks/pre-push`; land via PR.
- A stale `HANDOFF.md` (metadata from `fix-skill-lint-sigpipe-race`) is
  committed on main at the repo root — it leaked via a PR. Remove it from
  main in a separate PR; until then every new branch starts with it.
