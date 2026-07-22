# Handoff — agentic-dev-toolkit / review-brief-skill

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `review-brief-skill`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/review-brief-skill
- **Last updated:** 2026-07-22 14:24 UTC · server (srv1841294)

## State

Not started. Mission: build a new skill, `skills/review-brief`, that
stages the brief for an independent repo-review round — automating what
has now been done by hand twice (the staged handoffs on
`origin/fresh-review-2`, in that branch's git history, and
`origin/fresh-review-3`; both are ground truth for what the skill must be
able to render).

What the skill must do, as concluded in discussion:

1. **Stage, never run** — same hard boundary as its siblings
   `handoff-brief` and `loop-brief`: the deliverable is a pushed
   `HANDOFF.md` on a fresh `fresh-review-N` branch plus a printed start
   command. The human merge gate between rounds is deliberate and stays:
   one round staged per invocation, never a self-perpetuating chain — a
   round's value depends on the owner merging the previous review PR and
   deciding its open items first.
2. **Carry the review content, not just the mechanics.** The skill owns a
   review-dimensions catalog as a reference file in its own directory,
   split into a generic core (adversarial static read against the repo's
   documented pitfalls · docs-vs-code drift · test blind spots and
   harness isolation · config/permission safety · CI correctness and
   guard coverage · cross-file consistency of duplicated constants) and
   toolkit-specific dimensions (skill quality judged per
   `docs/skill-quality.md` beyond what lint enforces · end-to-end
   execution of the task lifecycle and installer in throwaway
   environments). A staged round is: catalog, minus dimensions
   well-covered by recent rounds, plus code changed since the last round.
   New dimensions a round discovers are added to the catalog file — that
   is where review knowledge accumulates instead of evaporating into PR
   history.
3. **Round computation with a correct degenerate case.** Next round
   number comes from existing `fresh-review-*` branches; coverage comes
   from merged review PR bodies plus `PROJECT_STATUS.md`'s
   verification-debt track. With no prior rounds the coverage set is
   empty, so round 1 stages the full catalog — no separate seeding mode.
   The round-1 brief must carry two extras: dispatch parallel
   sub-reviewers over independent dimensions (after rebasing — round
   one's stale-tree lesson), and degrade the dedupe rule to "check
   findings against pre-existing TODO tracks", since there are no prior
   review PRs to dedupe against.
4. **Bake in the standing rules** every round has needed: rebase onto
   the default branch first, never the resume verb (it fast-forwards to
   the branch's own upstream and lies "already up to date"); discover
   blind, then de-duplicate — a re-found fixed item is replication, not a
   finding; ranked findings with file:line and a concrete failure
   scenario, fixes never replacing the report; one commit per concern;
   owner go-ahead for high-blast-radius fixes; the `run-ci` label on the
   PR.
5. **Portability boundary**: in a repo that is not this toolkit, stage
   the generic core only and tell the session to extend the catalog from
   that repo's own docs — do not hardcode this repo's anatomy into the
   staged brief.
6. **Reuse, don't duplicate**: staging goes through the same
   worktree/branch/publish plumbing as `handoff-brief`
   (`skills/_lib/vibe-lib.sh`); nothing hand-rendered from memory. The
   catalog lives in the skill directory, not `templates/` — it names
   tools, which the template-neutrality rule forbids there.

Design questions left for this session:

- Whether to also support an unattended variant (staging a `LOOP.md` via
  the `loop-brief` machinery for a single bounded loop round). Supervised
  handoff mode is the required core; loop mode is optional scope.
- SQ13: the skill commits and pushes, so it should set
  `disable-model-invocation: true` — SQ13 enforcement is itself an open
  item in the verification-debt track; this skill must land on the right
  side of it.

Conventions: start from `skills/_template/SKILL.md`; portable top-level
skill, so no agent CLI named anywhere in it; `bin/skill-lint skills/
--strict` clean; the judgment bar in `docs/skill-quality.md` (description
says what and when, body opens with boundaries, "done" defined);
shellcheck + shfmt -i 2 -ci, bash 3.2, BSD+GNU for any script.

## Next action

Rebase onto the default branch (`git rebase origin/main`), run the repo
gate as baseline, then read in this order: `skills/_template/SKILL.md`,
`docs/skill-quality.md`, `skills/handoff-brief/` and `skills/loop-brief/`
(the siblings this composes with), `skills/_lib/vibe-lib.sh`, and the two
hand-staged review handoffs named above. Then draft the SKILL.md flow and
the catalog reference file before writing any script.

## Blockers

None.

## Gotchas (unpromoted)

- The handoff publish validation rejects any angle-bracket token in the
  rendered file — staged mission text that discusses template
  placeholders must paraphrase them, never quote them literally.
- Every new guard or script path gets a test (`bats tests/`), and CI is
  opt-in per PR: `gh pr edit N --add-label run-ci`.
