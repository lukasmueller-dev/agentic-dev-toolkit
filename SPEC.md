# Spec — agentic-dev-toolkit / queue-page-v2

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** /home/lukas-mueller/github/agentic-dev-toolkit
- **Branch:** `queue-page-v2`
- **Written:** 2026-11-17

## Goal

The queue page is a calm monitor with one-click decisions: centered, plain labels,
only the actions a human uses from a phone or a desk.

## Non-goals

- No change to CLI commands, job files or state names; only page labels change.
- No new page action that needs more than one line of text.
- No change to the runner pass (30 s) or to workspace start scripts.

## Decisions

- Role: monitor and quick decisions; specs, tasks, briefs and roadmap work happen in a session.
- Layout: direction B (`spec-design/Main.dc.html`): top bar with glider, "vibe queue", tabs, status, Pause.
- Frame: centered, max 1440 px; job list ≤600 px beside the job panel; one column under 1200 px.
- Tabs: Jobs · Recurring · Workspaces · Settings · Help ↗.
- Colors: B3 tokens, light and dark; one indigo accent for brand, selection and primary button.
- Red: only for failure states and the glider's red cell; no red selection or nav mark.
- Glider: stays as it is, with its run animation.
- Refresh: no "updated N s ago" counter; "Runner stopped" shows when the render is older than 2 min.
- Triage: hourly, own systemd timer; drop it from `vibe-jobs.service`.
- Triage also archives each ended job whose PR is merged or closed (`gh pr view`).
- Removed from the page (CLI keeps them): Fix, Triage PRs, the New Job screen (free task, Roadmap, Opt in).
- Also removed from the page: Worktrees, Remove worktree, Sync worktrees, Update toolkit, Merge order, Page actions table.
- Job actions kept: Start next, Skip review, Cancel, Stop, Message to tool, Cancel GPU run, Archive, Test passed, Archive feature.
- Failed or blocked job: one note field; Run again (note optional, needed when blocked), Put on hold (note needed), Archive.
- Recurring page: per repo: job, schedule, last run, state, Run; Reset only when stopped.
- Settings page: Slots, Clear usage limit, other key=value, Restart queue runner, Restart per `claude-rc@` server (from unit files).
- Workspaces: one card per tool; 2 services (Start/Stop/Open UI) and 3 run tools (state, job, last result, recipe; no Start).
- Workspaces tab: a dot only while a tool runs.
- Job panel order: state, title, repo · branch · time; steps; one result line; actions; task (3 lines + more); files; activity.
- Steps: Work · Review n · Verify · Checks · PR (Report for report jobs); each a one-sentence tooltip.
- Activity: last 5 agent texts and last 5 tool calls from the stream-json, by a vibe-web GET route that page.js fetches when the panel opens; the render stays files-only.
- Help ↗: `docs/vibe-queue.md#page-words` on GitHub, URL from the origin remote.
- Research card (#208): same tokens and row shape; content unchanged.
- Labels: the table below; each state and step has a tooltip; "Page words" in the docs uses the same words.
- Mockups: `spec-design/*.dc.html` (dark theme only; Activity rows there are partly example data).

| Today | Page label |
| --- | --- |
| blocked · timeout · skipped | Has a question · Ran out of time · Skipped: (reason) |
| parked · your test · merge | Waits for the GPU · Test it yourself · Ready to merge |
| exit N (GPU) · gate exit N | Failed, exit N / Finished · Checks failed (exit N) |
| Triage · Held · Config · Run tools | PR problems · On hold · Settings · Tools that run as a job |
| 9/9 · 1/2 (job) | 9 of 9 items · Milestone 1 of 2 |
| `<date-id>-t1-surv1-s42` | GPU run · t1-surv1-s42 |
| 5 of 8 slots · limit 5h · GPU: x | 5 of 8 jobs run · Claude usage N%, resets HH:MM · GPU busy: x |
| places | Runs on |
| No review · Hold · Clear limit · Steer X · Restart runner | Skip review · Put on hold · Clear usage limit · Message to X · Restart queue runner |
| report.md · pr.md · note · result | Report · PR text · Note · Result |
| gate.log · tool.log · log · out/report.md · out/files/ | Checks log · Tool log · Full log · Tool report · Output files |

## Milestones

- [x] Backend: hourly triage timer with auto-archive; route cuts; Run again with optional note; Hold on the same note; activity GET route; recurring and server data for the page — code — done when `bats tests/` passes, and new tests cover auto-archive of a merged-PR job (gh stub), Run again with no note on a failed job, the activity route on a stream-json fixture, and no removed route left in `ROUTES`.
- [x] Page: direction B per `spec-design/` and the Decisions, every label from the table — code — done when `bats tests/vibe-web.bats` passes with `VIBE_TEST_BROWSER` set, `tests/page_check.py` checks the five tabs and that no raw state word (`blocked`, `gate.log`) shows, and screenshots at 2560×1440, 1440×900 and 390×844 are in `$VIBE_JOB_DIR/shots/`.
- [ ] Docs and end action: "Page words" table, page actions table and triage timer setup in `docs/vibe-queue.md` and `docs/vibe-jobs.md`; delete `SPEC.md` and `spec-design/` — code — done when the "Before committing" commands of `CLAUDE.md` pass and `test ! -e SPEC.md && test ! -e spec-design`.

## End action

delete — each decision moves to the PR body.
