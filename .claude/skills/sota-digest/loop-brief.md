# Loop — <repo> / <branch>

> The brief for the weekly SOTA digest run. It is handed to a fresh agent
> every round with no other context, so everything the round needs is here or
> in the skill it points at.

- **Repo:** <repo>
- **Branch:** `<branch>`
- **Worktree:** `<worktree>`
- **Started:** <date> · <machine>
- **Stop check:** `<until>`
- **Max rounds:** <max>

## Goal

<goal>

Follow the repo-local `sota-digest` skill at
`.claude/skills/sota-digest/SKILL.md`. Read it in full before doing anything
else — it holds the source list, the digest format, and the bar a
recommendation has to clear. The week identifier is in the goal line above;
use exactly that string.

Throughout this brief, **the digest file** means `docs/sota/` followed by the
week identifier from the goal line above and `.md` — e.g. for week `2026-W30`
it is `docs/sota/2026-W30.md`. `<week>` is not a literal filename; substitute
the week before you write anything. The stop check tests for that exact path.

## Done when

The digest file exists, holds between zero and three recommendations, and
every claim in it carries a URL that was actually fetched. The stop check
above tests for the file; the rest is on you.

## How to work a round

- **The task is one complete digest, not a partial one.** Aim to finish the
  file in a single round.
- **Leave the tree in a working state every time you stop.** A round may be
  the last one before the loop hits `--max`, so a half-written digest must
  still be coherent Markdown, never a truncated sentence mid-fetch.
- **Record where you got to in the iteration log below.** A later round (or a
  resume after a crash) starts fresh with only this brief and the file on
  disk — if a round surveyed three sources but did not finish, the log is the
  only place that says so.

## Constraints

- **Only ever create or edit the digest file.** Nothing else in the worktree
  may change — not the roadmap, not the status file, not code.
- **Do not commit, push, or open a pull request.** The loop does all three
  when it stops.
- **Do not promote recommendations into `PROJECT_ROADMAP.md`.** They are
  proposals; a human promotes them after reviewing the PR.
- If web search is unavailable, write that fact into the digest's run notes
  and stop rather than producing an unsourced file.

## Iteration log

_One line per round that changed something, newest last._
