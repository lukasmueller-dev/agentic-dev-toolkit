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

Verdict walk in progress (started 2026-10-24). Nothing applied yet. A
read-only usage audit ran on 2026-10-24 from a humanoid-locoman-vla
session; its numbers are below.

Verdicts so far:

| Feature | Verdict | Note |
|---|---|---|
| vibe loop | cut | cmd_loop, cmd_loop_run, templates/LOOP*.md, docs/vibe-loop.md, tests/vibe-loop.bats |
| loop-brief | cut | skill + tests/loop-brief.bats |
| babysit-pr | cut | skill + docs/babysit-pr.md + tests/babysit-pr.bats |
| sota-digest | keep, on demand | drop cron + vibe-loop wrapper (sota-weekly.sh); rewrite to run in-session |
| vibe rc | cut | built-in /remote-control replaces it |
| vibe park | cut | |
| vibe status --json | cut | flag + tests/vibe-status-json.bats + PROJECT_ROADMAP.md:19 |
| vibe sync | cut | update GLOBAL.md:96, project-status-scaffold SKILL.md:96, attach/resume hint messages |
| vibe list / where / resume | merge | list → status, where → doctor, resume → attach |
| vibe doctor | rare-but-critical, trim | drop checks for removed verbs, aim for half size |
| notify-ntfy | cut | hook + docs/notifications.md + tests + both hook wirings |
| session-end-handoff | cut | hook + tests + both hook wirings (settings.json, .claude-plugin/hooks.json) |
| local/server detection | reduce | tmux only when $SSH_CONNECTION/$SSH_TTY; remove VIBE_SERVER_HOSTNAME + hostname fallback |
| handoff-start | keep | separate from handoff-brief |
| add-roadmap-item | keep, enable model invocation | remove `disable-model-invocation`; agents never saw it on "add this to the roadmap" |
| implement-test-suite | keep | |
| skill-audit | merge into docs/skill-lint.md | judgment checklist moves; skill goes |
| research-first-run | merge into codebase-map | "how to run it" part + RUNBOOK template; skill goes |
| codebase-review, codebase-health, codebase-map, commit-push-pr, sync-with-main | keep | |
| weekly-report | cut | skill + templates/report + tests |
| repo-scaffold | cut | + templates ci/, gitignore/, repo/pre-push; drop pre-push from the CI template check + CLAUDE.md list |
| team-up | cut | |
| grilling, grill-me | keep | |
| vendored writing skills (4) | keep | |
| subagents: diff-reviewer, docs-drift, test-hardener, security-sweep | cut all | + readonly-bash.sh, readonly-bash-for-reviewers.sh, tests/readonly-bash.bats, claude/agents/, `agents` list in .claude-plugin/plugin.json; refs in README, docs/{academic-writing,mcp-servers,plugin,vendoring-external-skills}.md, tests/{install,plugin}.bats, PROJECT_STATUS.md |
| .claude-plugin install path | keep | |
| skill-lint-on-edit | cut | hook + both wirings + tests |
| statusline, vscode/, completions/ | keep | completions lose cut verbs |
| GLOBAL.md "My setup" | rewrite | one workstation (turing), reached over SSH + tmux; drop machine-to-machine git travel |
| vibe status | keep, core | the author's most-used value; absorbs list |
| HANDOFF / PROJECT_STATUS / PROJECT_ROADMAP + templates | keep, core | they carry context session to session, not machine to machine |
| session-start-handoff, handoff-brief, project-status-scaffold, tmux/ | keep | |

Workflow (decided): turing is the workstation and the only machine with
work; the laptop only SSHes in. So the usage numbers above cover the real
machine — the "check the server" gotcha no longer applies.

Archive: tag `pre-audit-2026-10-24` on main (3c3d895), pushed.

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

The author wants a full audit: every part of the repo, not only the table.
Settle the workflow question first, then walk the groups below. Record each
verdict above, then apply cuts and merges as one PR per cluster.

1. Workflow + handoff: GLOBAL.md "My setup", detect_env / `where`, tmux/,
   templates/HANDOFF.md, handoff-brief, handoff-start, session-start-handoff,
   session-end-handoff, notify-ntfy, project-status-scaffold +
   PROJECT_STATUS/ROADMAP templates, add-roadmap-item,
   docs/artifact-architecture.md.
2. Own skills: codebase-health, codebase-map, codebase-review,
   commit-push-pr, implement-test-suite, repo-scaffold (+ templates ci,
   gitignore, repo), research-first-run (+ templates/research), skill-audit,
   sync-with-main, team-up, weekly-report (+ templates/report).
3. Vendored: grilling, grill-me, literature-review, proofread,
   writing-assistance, writing-simple-style.
4. Subagents: diff-reviewer, docs-drift, test-hardener, security-sweep.
5. Hooks + config: readonly-bash (+ for-reviewers), skill-lint-on-edit,
   inject-global-memory (plugin only), statusline, settings.json,
   claude/CLAUDE.md (response style).
6. Infra: .claude-plugin, install.sh, bin/plug, bin/skill-lint,
   completions/, vscode/, docs/ (14 files + docs/sota/).

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
