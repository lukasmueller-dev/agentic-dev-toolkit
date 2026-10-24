# Handoff — agentic-dev-toolkit / toolkit-audit

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `toolkit-audit`
- **Worktree:** /home/lukas-mueller/git/worktrees/agentic-dev-toolkit/toolkit-audit
- **Last updated:** 2026-10-24 12:44 CEST · local (turing)

## State

Not started. A read-only usage audit ran on 2026-10-24 from a
humanoid-locoman-vla session; its numbers are below. No verdict is made.

- Verdicts: decided with the author, feature by feature, no default
  (keep / cut / merge / rare-but-critical).
- Task `harness-agent-features` (a new research kit) starts after this
  audit merges.
- Evidence limits: transcripts reach back to 2026-09-28 only;
  `~/.claude/history.jsonl` covers 08-17..10-24; `~/.bash_history` is
  undated (2000 lines); use on the server machine leaves no trace here;
  293 of 307 commits are from July, so ratios show build cost more than
  upkeep.
- Uses per commit by kind: agent-only skills + subagents ~3.7;
  deterministic vibe ~2.5 (~3.4 without `loop`); hybrid ~0.4.

| Feature | Kind | Uses 30 d | Uses older | Commits | Audit suggestion |
|---|---|---|---|---|---|
| vibe start / done / status / attach | det | 11 + 45 worktrees / 5 / 2 / 0 | 42 / 61 / 41 / 24 | 6 / 10 / 7 / 5 | keep |
| vibe status --json | det | 0 | 0 | 3, tests fail (PROJECT_ROADMAP.md:19) | cut |
| vibe sync | det | 6 | 4 | 3 | keep |
| vibe help | det | 46 (agents, sent by memory/GLOBAL.md:74) | 0 | 14 | keep |
| vibe list / where / resume | det | 3 / 3 / 0 | 0 | 4 / 1 / 1 | merge into status / doctor / attach |
| vibe park | det | 0 | 0 | 2 | merge into sync, or cut |
| vibe doctor | det | 0 | 0 | 10 (200 LOC) | rare-but-critical, trim |
| vibe rc | det | 0 (built-in /remote-control: 16) | 0 | 5 | cut |
| vibe loop + loop-brief + babysit-pr + sota-digest | det / hybrid | 0 (built-in /loop: 18) | 0 | 46 (loop ~915 LOC, 26% of bin/vibe) | cut, or split out |
| grilling / grill-me | agent | 22 / 0 | n/a | 1 / 1 | keep / merge into grilling |
| sync-with-main, codebase-health, commit-push-pr, writing-assistance | agent | 16, 10, 6, 5 | 7, 2, 13, n/a | 3, 3, 8, 1 | keep |
| add-roadmap-item / implement-test-suite / team-up | agent | 0 | 0 | 3 / 4 / 1 | merge into project-status-scaffold / merge into test-hardener / cut |
| handoff-brief / handoff-start | hybrid | 9 / 8 (handoff.sh: 65 runs) | 0 / 2 | 9 / 2 | keep / merge with handoff-brief |
| codebase-review, weekly-report, project-status-scaffold, codebase-map | hybrid | 2, 1, 1, 1 | 0, 2, 0, 0 | 5, 2, 13, 2 | keep |
| repo-scaffold | hybrid | 1 | 0 | 4 | rare-but-critical |
| skill-audit | hybrid | 0 | 0 | 5 | merge into skill-lint docs |
| research-first-run | hybrid | 0 | 0 | 2 | cut, or merge into codebase-map |
| literature-review, proofread, writing-simple-style | vendored | 1, 0, 0 | n/a | 1 each | keep / watch (18 days old) |
| diff-reviewer, docs-drift, test-hardener, security-sweep | subagent | 17, 4, 2, 2 | n/a | 2, 2, 1, 2 | keep (security-sweep rare-but-critical) |
| hook session-start-handoff | det | 232 runs (97 injected a handoff) | n/a | 3 | keep |
| hook notify-ntfy | det | no-op here: no VIBE_NTFY_TOPIC | n/a | 6 | cut unless the server sets a topic |
| plugin-only hooks + .claude-plugin manifest | det | 0 | 0 | 5 | cut with the plugin, or rare-but-critical |
| bin/plug, bin/skill-lint | det | 9, 2 (+ CI, hook) | 0 | 5, 12 | keep |
| completions/ | det | leaves no trace | n/a | 16 | keep, freeze |
| statusline, vscode, tmux, install.sh, settings, GLOBAL.md, other hooks | det / config | no trace, or always on | n/a | | keep |

## Next action

Walk the table with the author, most expensive first (the loop cluster: 46
commits, 0 uses). Record each verdict, then apply cuts and merges as one PR
per cluster.

## Blockers

_What is stopping progress, and what would unblock it._

## Gotchas (unpromoted)

- The audit saw the local machine only. Before cutting `park`, `rc`,
  `loop`, `tmux` or `ntfy`, check `~/.bash_history` and
  `~/.claude/projects` on the server.
- The 46 `vibe help` uses come from agents sent there by
  `memory/GLOBAL.md:74`: a verb rename or cut also updates `GLOBAL.md` and
  `docs/vibe.md`.
- `research-first-run` touches `harness-agent-features`: that design does
  not build on it, so decide its fate here.
- Combined Skill + slash counts can be 1-2 high for the most-used skills.
- Re-measure: counts only, never print history or transcript content.
