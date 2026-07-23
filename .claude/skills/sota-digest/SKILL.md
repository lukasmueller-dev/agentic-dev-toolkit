---
name: sota-digest
description: "Writes the weekly state-of-the-art digest for this repo — surveys agentic-development sources by web search, diffs what it finds against PROJECT_ROADMAP.md and PROJECT_STATUS.md, and emits docs/sota/<YYYY-Www>.md with 1-3 recommendations formatted as ready-to-add roadmap items. Use when the unattended weekly run invokes it, or when the user asks for a SOTA digest, a state-of-the-art sweep, or 'what changed in agentic dev this week'. Repo-local: it only ever runs against this toolkit."
disable-model-invocation: true
---

# Weekly SOTA digest

Produce one file — `docs/sota/<YYYY-Www>.md` — that a human reads in five
minutes and either acts on or ignores. Its value is entirely in what it
*leaves out*: a digest that lists everything that happened is a feed, not a
recommendation.

This skill normally runs unattended, in a worktree, driven by `vibe loop`
(see `docs/sota-watch.md`). The loop does the git work. You write the file.

## Hard boundaries — never do these

- **Never commit, push, or open a PR.** The surrounding loop does all three.
  Writing the digest file is the entire deliverable.
- **Never edit `PROJECT_ROADMAP.md` or `PROJECT_STATUS.md`.** Recommendations
  are *proposals*; they are promoted by a human running `add-roadmap-item`
  after the PR is reviewed. Writing them straight into the roadmap removes
  the review gate this whole mechanism exists to provide.
- **Never touch anything else in the repo.** No refactors, no fixes, no
  "while I was in here". A digest run that changes code is unreviewable.
- **Never invent a source.** Every claim carries a URL you actually fetched.
  If web search is unavailable this round, say so in the digest and stop —
  an unsourced digest is worse than a missing one.
- **Never re-propose what is already decided.** Phase 3 exists for this.

## Phase 1 — Fix the week

Use the week identifier named in the goal of `LOOP.md` if there is one;
otherwise `date -u +%G-W%V` (ISO year and week, e.g. `2026-W30`). Everything
below writes that exact string. The digest path is
`docs/sota/<YYYY-Www>.md` — create `docs/sota/` if it does not exist.

If that file already exists and has content, this run is a resume: read it,
keep what is there, and only fill gaps. Do not start over.

## Phase 2 — Sweep

Read `references/sources.md` for the source list and the search angles. Work
the categories in it; do not stop at the first interesting thing. Aim for
breadth first (what moved at all), depth second (what matters here).

A finding is worth carrying forward only if it could plausibly change this
toolkit — a workflow it should adopt, an assumption it now gets wrong, or a
capability that makes an existing workaround obsolete. "Interesting but
inapplicable" is noise; drop it.

## Phase 3 — Diff against what is already decided

Before writing a single recommendation, read:

- `PROJECT_ROADMAP.md` — every open item, including tracks
- `PROJECT_STATUS.md` — the decisions section, which records what was
  *rejected* and why
- `CLAUDE.md` — the conventions a proposal would have to live within
- the two or three most recent `docs/sota/*.md` digests — a recommendation
  already made and not acted on is not new information

Anything already planned, already done, or explicitly rejected does not
become a recommendation. If a rejected decision now looks wrong *because of
something you found this week*, that is legitimate — but say plainly which
decision you are reopening and what changed.

## Phase 4 — Write the digest

Structure, in order:

1. **Title and date line** — `# SOTA digest — <YYYY-Www>` and the UTC date.
2. **Bottom line** — three sentences at most: what actually changed this
   week for someone building agentic dev tooling. If nothing did, say that;
   a quiet week is a legitimate result and the rest of the file gets short.
3. **What moved** — grouped by the categories in `references/sources.md`.
   One bullet per item: what it is, why it matters *here*, and a link. Skip
   any category with nothing in it rather than writing "nothing to report".
4. **Recommendations** — **one to three**, never more. Zero is allowed and
   is the right answer on a quiet week. Each one formatted as a ready-to-add
   roadmap item, so promoting it is a copy-paste:
   - a name and a one-line goal — what exists when it is done
   - design bullets: approach, constraints, touchpoints in this repo
   - **Done when:** an observable condition
   - **Source:** the link(s) that motivated it
   - **Not already covered because:** the one line that proves Phase 3 ran —
     which existing item or decision it is adjacent to, and how it differs
5. **Sources consulted** — flat list of URLs fetched, so the next run can
   see what was already covered and a reader can audit the sweep.

The bar for a recommendation is high: it must be something you would defend
in review, sized as one task, and grounded in something that changed *this
week*. Three weak items are worse than one strong one, and far worse than
none.

## Phase 5 — Note the run's own health

End the file with a short `## Run notes` section: whether web search worked,
any source that failed to fetch, and anything about the run a human should
know. This is where "search was unavailable" or "GitHub rate-limited the
release feed" goes — silence there is read as a clean run.

## Done

Done when `docs/sota/<YYYY-Www>.md` exists, every claim in it carries a URL,
it holds between zero and three recommendations, and nothing else in the
worktree has changed. Stop there — the loop commits, pushes, and opens the
PR.
