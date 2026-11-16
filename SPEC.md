# Spec — agentic-dev-toolkit / queue-redesign

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `queue-redesign`
- **Written:** 2026-11-16

## Goal

The queue page is a calm, desk-first surface: one inbox of what needs you, a job panel
that is always open, and the workspaces, per the boards in `design/queue-a/`.

## Non-goals

- No JSON API or client-side render: the bash render in `vibe queue page` stays.
- No tool-job creation on the page: tool jobs stay `/enqueue`-only.
- No new place or tool under `workspaces/`.
- No change to runner rules, job states or the report text.

## Decisions

- Boards: `design/queue-a/` (Main, Detail, Workspace, Phone); the canvas is the source; B is rejected.
- Desk first: MacBook at 1440 px; the phone is the same page in one column.
- Look: B3 tokens (robots_web_commander `style.css`), light and dark from the system; red #e12d1a only on the glider cell, the active nav item and the selected row.
- Type: Geist, Geist Mono for numbers, repos and ids; sizes 12, 13, 14, 16, 24 px; fonts in `templates/fonts/` (CSP blocks Google Fonts).
- No 1.15 desk zoom.
- Layout: rail 216 px | list ≤960 px | panel 400–560 px, always open from 1200 px; under it a click opens it over the list; phone: bottom sheet.
- Rail: glider + `vibe`, Queue with the Needs-you count, Workspaces (services only), Config. No Sessions link.
- Header: lamp, `3 of 4 slots`, usage limit, GPU holder, `updated N s ago` (red `stale` after 2 min); Pause/Resume; Clear limit only while limited; New job.
- Sections: Needs you (open), Running (open), Queued, Held, Triage, Done (each folded to one line); Done = all unarchived.
- Needs you = blocked, failed, timeout, skipped, done with a failed gate or verify, push failed, PR not created, PR to review, feature in your test or merge.
- No repo groups: the repo is a mono label per row. A lane, a feature, a tool job (`kapso · turing`) or an outside GPU run is one row; members and details in the panel.
- One primary button per row: Answer, Retry, Fix, Open PR, Test passed, Archive, else none; all others in the panel.
- Phase bar: one segment per step of the phase line, the running step's name after it.
- Destructive buttons keep tap-again within 4 s.
- Panel content: one hidden block per item in the page; file links load on tap; the open item is `#job-<id>` in the URL.
- Text: input fields in the panel replace every `prompt()`; `⌘↵` sends, `Esc` clears.
- Keys: `j`/`k` move the selection; no single key writes.
- Poll: the 10 s swap skips the panel while a panel field has focus or text.
- Tab title: `(N) vibe`, N = the Needs-you count. The glider animates while a job runs (off with reduced motion).
- New job opens the panel: the new-job form, Roadmap, Opt in, recurring jobs.
- Config: settings with Set config; Actions (Restart runner, Triage PRs, Sync worktrees, Servers, Restart server, Update toolkit, Worktrees); recurring jobs with Run and Reset; last 20 `actions.log` lines.
- Tool jobs: `vibe-web` serves `tool.log`; the panel shows its last 10 lines while it runs; after the run it links `out/report.md` (and `out/files/` for a folder tool).
- Steer: a field in a tool job's panel, only when the tool's `steer` is supported; route `steer` runs `vibe queue steer <id> <text>`.
- Workspaces page: one row per service: lamp, place, time left (amber under 30 min), Open UI ↗, Stop; Start opens a place + hours form when the tool has 2+ places, else a plain button.
- `vibe ws start <name> [--place P] [--hours N]`; routes `ws-start`, `ws-stop`.
- GPU holder, first match: running `gpu` job, running outside gpu-queue run, workspace with a live `holder`, running tool job on turing with `gpu=yes`; else `GPU: busy` while the lock is held.
- The separate GPU group goes: outside runs are rows in Running or Queued; the last 3 finished in Done.

## Milestones

- [x] Shell: tokens, fonts, rail, header, the six sections, rows with label, lamp, phase bar and primary button; tab title; no zoom — code — done when `bats tests/vibe-queue.bats tests/vibe-web.bats` passes with new tests for the sections, the Needs-you rules and the copied fonts
- [x] Panel and Config: hidden blocks, always-open panel and bottom sheet, `#job-<id>`, input fields, keys, swap guard, New job panel, Config page — code — done when `node --check templates/queue-page.js` passes, no `prompt(` is left in it, and the bats suites pass with tests for the panel blocks and the Config parts
- [x] Workspaces and tools: `vibe ws start --place --hours`, routes `ws-start`, `ws-stop`, `steer`, `tool.log` served, tool panel, Workspaces page and rail, GPU holder, outside GPU rows — code — done when `bats tests/vibe-ws.bats tests/vibe-web.bats tests/vibe-queue.bats` passes with tests for each new route, flag and holder case
- [x] Docs: `docs/vibe-queue.md` (Phone page → Page, Page actions table) and `docs/workspaces.md` match the code — code — done when `grep -c "Sessions ↗\|chips" docs/vibe-queue.md` prints 0 and the full lint, format and bats gate of `CLAUDE.md` passes
- [ ] End action — code — done when SPEC.md, HANDOFF.md and design/queue-a/ are gone from the branch

## End action

`delete`: SPEC.md, HANDOFF.md and design/queue-a/; each decision moves to the PR body.
