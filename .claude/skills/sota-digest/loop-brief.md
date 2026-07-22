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

## Done when

`docs/sota/<week>.md` exists, holds between zero and three recommendations,
and every claim in it carries a URL that was actually fetched. The stop check
above tests for the file; the rest is on you.

## Constraints

- **Only ever create or edit `docs/sota/<week>.md`.** Nothing else in the
  worktree may change — not the roadmap, not the status file, not code.
- **Do not commit, push, or open a pull request.** The loop does all three
  when it stops.
- **Do not promote recommendations into `PROJECT_ROADMAP.md`.** They are
  proposals; a human promotes them after reviewing the PR.
- If web search is unavailable, write that fact into the digest's run notes
  and stop rather than producing an unsourced file.

## Iteration log

_One line per round that changed something, newest last._
