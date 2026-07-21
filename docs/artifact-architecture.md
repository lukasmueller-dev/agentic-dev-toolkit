# Artifact architecture — where information goes

This is the canonical, long-form description of how information produced
during agentic work is routed between chat, handoff files, git, and docs.
The short version agents act on lives in `memory/GLOBAL.md`; this file is
what that section points to.

## The problem this solves

Agent output tries to be two things at once: the thing you skim *now* and the
record you consult *later*. Serving both in one place fails at both — chat
messages and PR descriptions grow too long to skim, while the detail in them
evaporates (chat) or goes stale (handoffs used as logs). Meanwhile the places
that are actually durable and searchable — commit bodies, PR history, status
files — stay thin.

The fix is a routing rule, not a compression rule:

> **Every piece of information has exactly one home, chosen by its lifetime.
> Write it once at the lowest layer whose lifetime fits. Higher layers link
> down; they never restate.**

Two consequences, deliberately asymmetric:

- **Read-now surfaces are short.** Chat summaries, the top of a PR
  description, the "Key decisions" list — anything a human reads in the
  moment carries only what changes their next action, plus pointers.
- **Pointed-to surfaces are verbose.** Commit bodies, `<details>` blocks,
  `docs/` files — anything reached by following a pointer should be as
  detailed as it needs to be. Verbosity is only a cost when it sits between
  the reader and their answer.

Nothing critical may exist *only* in a short surface's omitted detail, and
nothing may exist *only* in chat. Skimming is safe precisely because the
short layer is contractually complete for decisions and risks, and everything
else is retrievable.

## The layers

| Layer | Artifact             | Lifetime                          | Reader                        |
| ----- | -------------------- | --------------------------------- | ----------------------------- |
| 0     | Chat                 | dies with the session             | you, right now                |
| 1     | `HANDOFF.md`         | dies when the task ends           | the next session on this task |
| 1     | `LOOP.md`            | dies when the loop's task ends    | the loop agent, every round   |
| 1     | PR description       | read until merge, then history    | the reviewer                  |
| 2     | Diff                 | permanent                         | anyone, forever               |
| 2     | Commit body          | permanent (`git log` / `blame`)   | future maintainer             |
| 3     | `PROJECT_STATUS.md`  | living, repo-scoped               | anyone joining the repo cold  |
| 3     | Repo `CLAUDE.md`     | living, repo-scoped               | agents                        |
| 3     | `docs/`              | living, repo-scoped               | humans                        |

## Per-artifact contracts

### Chat (layer 0)

Progress notes while working, and an end-of-task summary of **at most six
lines**: what changed, what to verify, and a mandatory `Decisions/risks:`
line — anything surprising, any judgment call made on the user's behalf,
anything expensive to reverse. If there are none, it says "none"; the line is
never omitted, because its guaranteed presence is what makes skimming safe.
Each summary line points to where the detail lives ("why: commit body",
"state: HANDOFF.md") instead of restating it.

Hard rule: nothing exists only in chat. Chat is where things are *mentioned*;
an artifact is where they *live*. Chat evaporating is then a feature.

### `HANDOFF.md` (layer 1) — the baton

Lives at the worktree root, one per task. Strictly present tense: current
state, the next concrete action, active blockers, gotchas discovered but not
yet resolved. It is **overwritten each session, never appended** — an
appended handoff is a log wearing a handoff's name. Budget: one screen.

It does *not* contain history ("first I did X…"), rationale, completed-step
logs, or anything about other tasks. History is git's job; rationale is the
commit body's job.

When the task ends the baton dies: `vibe done` refuses to remove a worktree
whose `HANDOFF.md` still carries content beyond its own headings — and, once
cleared, refuses again while the file itself is still on the branch, where a
merge would land it in the PR diff and stray it onto the default branch.
Promote what is durable (see below), delete the file (`git rm HANDOFF.md`,
then sync), then finish. `--discard-handoff` is the explicit override
meaning "I looked; nothing in it is worth keeping — and if the file stays on
the branch, that is deliberate."

### `LOOP.md` (layer 1)

The brief handed to an unattended loop's agent every round (`vibe loop`),
plus its iteration log. Task-scoped like the handoff, with the same
end-of-task discipline. Nothing in it can be silently
orphaned — brief and log are committed each round — and its content (goal,
constraints, one-line round notes) is not the kind that gets promoted. But
the file itself is start-of-task input, not deliverable: left on the branch,
it lands verbatim in the PR diff. So a finished task deletes it. `vibe done`
refuses while `LOOP.md` is still on the branch; deletion is a commit
(`git rm LOOP.md`, then sync), and `--keep-brief` is the explicit override
meaning "I want the brief in the history." When a loop's agent learns
something durable, the promotion paths below apply exactly as in an attended
session.

### PR description (layer 1)

Says only what the diff cannot: intent, tradeoffs, what to verify, known
risks. Top section is skimmable — a short summary plus a `Decisions/risks`
note. An exhaustive file-by-file account, if produced at all, goes inside a
collapsed `<details>` block. Never narrate the diff; the diff is right there.

After merge the PR becomes the searchable task-level narrative, which is why
task-scoped rationale belongs here or in commit bodies rather than in chat.

### Diff and commit body (layer 2)

The diff answers *what changed* and is never restated elsewhere. The commit
body is the canonical home of *why*: the reasoning, alternatives considered
and rejected, the bug class a guard prevents. This is where the paragraphs
that used to live in chat belong — `git blame` finds them in two years, and
they cost nothing to skim past today. Verbose is correct here.

### `PROJECT_STATUS.md` (layer 3)

The durable *current* picture: goal, architecture, key decisions, open TODOs
and questions. A snapshot, not a log — git history is the log, so there is no
"Done" section and finished TODOs are simply removed.

"Key decisions" entries are one line each, dated, with a pointer (commit SHA
or PR number) to the full rationale at layer 2. The file stays skimmable
because it never absorbs the reasoning, only the conclusion and the pointer.

### Repo `CLAUDE.md` and `docs/` (layer 3)

`CLAUDE.md` gets only what should change agent *behavior*: conventions,
commands, pitfalls that recur. `docs/` gets a file when a topic outgrows a
paragraph in `PROJECT_STATUS.md` — move the content, leave a link. Both are
pointed-to surfaces: depth is welcome.

## Promotion — how information moves up

Information starts at the lowest layer and is promoted when it proves
durable:

- Chat finding worth keeping → `HANDOFF.md` (if task state) or commit body
  (if rationale).
- `HANDOFF.md` gotcha that would bite again after this task → repo
  `CLAUDE.md`.
- Decision made mid-task → commit/PR body, plus a one-line pointer entry in
  `PROJECT_STATUS.md` when it shapes future work.
- `PROJECT_STATUS.md` section outgrowing a paragraph → `docs/` file plus a
  link.

The end of a task is the enforcement point: a finished task hands nothing
off, so everything still in the handoff is either promoted or consciously
discarded. `vibe done` checks exactly this, deterministically and with no
agent involvement — agents are instructed (via `memory/GLOBAL.md` and the
`project-status-scaffold` skill) to promote and clear before wrapping up, and
the guard catches the cases where that discipline was skipped.

## Who enforces what

| Rule                                        | Enforced by                              |
| ------------------------------------------- | ---------------------------------------- |
| Summary contract, routing table             | `memory/GLOBAL.md` (agent instructions)  |
| Handoff baton semantics                     | `templates/HANDOFF.md` + scaffold skill  |
| Handoff empty at task end                   | `vibe done` guard (`bin/vibe`)           |
| Commit body carries rationale, PR is skim+`<details>` | `skills/commit-push-pr`       |
| Templates stay tool-neutral                 | CI (`.github/workflows/ci.yml`)          |
