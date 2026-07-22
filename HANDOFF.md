# Handoff — agentic-dev-toolkit / fresh-review-4

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fresh-review-4`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/fresh-review-4
- **Last updated:** 2026-07-22 21:25 UTC · server (srv1841294)

## State

Not started. This branch carries only this brief.

This is **round four** of the independent review of this repo. Rounds one
through three are merged (PRs #36, #38, #41): round one was a broad static
pass over the whole surface, rounds two and three executed the full `vibe`
lifecycle and the installer end to end, twice, the second time as a blind
replication. Both execution rounds came back mostly confirming the first —
that vein is worked out, so **do not re-run the whole lifecycle sweep**.

**Mission: the surface that has landed since round three, which no review
has ever seen.** Four merged PRs added a large amount of new code and
several new documents, and none of it has been through a review round:

- `skills/repo-scaffold` and everything it emits — `templates/ci/*.yml`,
  `templates/gitignore/*`, `templates/repo/pre-push`, and the
  per-ecosystem `references/`. A skill that writes CI workflows and a
  push-blocking git hook into *other people's* repos is the highest
  blast radius addition in this set.
- `PROJECT_ROADMAP.md` as an artifact class: the template, the
  `add-roadmap-item` skill, and the `project-status-scaffold` changes
  that now render and maintain three files instead of two.
- The weekly SOTA watch: the repo-local `.claude/skills/sota-digest`,
  `docs/sota-watch.md`, and the cron entry that drives it through
  `vibe loop --pr` unattended. An unattended run that opens its own PR
  is worth reading adversarially — what happens when the digest step
  fails, when the week's file already exists, when the loop stalls?
- Three `bin/vibe` changes: `vibe start --no-attach`, foreground
  `vibe loop` exiting with its outcome code, and the `vibe done` fix
  that removes the worktree before killing the task's tmux session.

Scoped dimensions for this round, in priority order:

1. **Adversarial static read of the changed surface above.** Read it
   against the pitfalls this repo documents about itself in `CLAUDE.md` —
   assume each documented trap has at least one instance the new code
   missed, and hunt for it. Silent-failure paths first: the path that
   prints success. The `set -e`-in-a-subshell trap, the `pipefail` +
   early-closing-consumer trap, and the `patsub_replacement` trap have
   each already produced a real bug here.
2. **Skill quality beyond lint.** `repo-scaffold`, `add-roadmap-item`,
   and `sota-digest` have never been graded against
   `docs/skill-quality.md`'s judgment criteria — the ones `bin/skill-lint`
   cannot check. Description says what *and* when; body opens with its
   boundaries; "done" defined; a side-effecting skill not left
   model-invocable without a recorded exemption.
3. **CI correctness and guard coverage.** The repo-invariant guards
   (template-neutrality greps, the memory-neutrality grep, and their bats
   mirrors) must actually cover the files added since round three —
   a guard that silently stops matching is the failure mode. Also: do the
   emitted `templates/ci/*.yml` workflows do what the skill claims they
   do, on the platforms they claim?
4. **Docs-vs-code drift and cross-file consistency.** New docs, help
   text, both shell completions, and the constants or regexes duplicated
   across `bin/vibe` and `skills/_lib/vibe-lib.sh` — verify every copy
   and every pointer comment that names its siblings.
5. **Targeted execution, not a full sweep.** Execute only the new paths:
   `repo-scaffold` against throwaway repos of more than one ecosystem,
   the scaffold script's roadmap rendering, `vibe start --no-attach`, and
   the foreground loop's exit codes. Throwaway git repos and a throwaway
   HOME only — nothing may touch the real HOME, `~/.claude`, `~/bin`, or
   the real worktree root.
6. **Config and permission safety**, lighter than round two's pass:
   confirm the reviewer-subagent Bash scoping that `claude/hooks/readonly-bash.sh`
   now implements actually holds, since it landed as a fix to a review
   finding and has not itself been reviewed.

**Discover blind, then de-duplicate.** Complete the discovery pass before
reading PRs #36, #38 and #41 or the tracks in `PROJECT_STATUS.md` and
`PROJECT_ROADMAP.md`. A re-found item that turns out fixed or already
tracked is *replication* — evidence the pass works — and is reported in
its own section, never as a finding.

## Next action

1. `git rebase origin/main` — rebase, never the resume verb, which
   fast-forwards to this branch's own upstream and reports "already up to
   date" while arbitrarily far behind the default branch. Round one wasted
   a whole parallel fan-out on a stale tree this way.
2. Run this repo's own verification gate as the baseline, before touching
   anything: `shfmt -f . | xargs shellcheck`, `shfmt -d -i 2 -ci .`,
   `bats tests/`, `./bin/skill-lint skills/ --strict`, and
   `./install.sh doctor`. A failure there is yours, not a finding. What
   that gate does *not* catch is this round's real target. (`doctor` run
   from a worktree reports every link "not ours" — that is the ownership
   check working, not breakage.)
3. Then start with scope item 1 on `skills/repo-scaffold` and the
   `templates/` assets it emits — highest blast radius, entirely
   unreviewed.

## Blockers

None known. CI is opt-in per PR on this repo, so **the review PR must
carry the `run-ci` label** — an unlabelled PR shows no checks at all and
GitHub's merge box reads a skipped job as passing. The macOS leg is the
only place bash 3.2 and BSD userland are exercised.

## Gotchas (unpromoted)

Standing rules for the round's deliverable:

- The deliverable is a **ranked findings list**: each finding with a
  `file:line` and a concrete failure scenario. Label a
  reasoned-but-unproven claim as such. Fixes never replace the report.
- One commit per concern, with the failure it prevents in the body, so
  any single fix can be reverted alone.
- Get the owner's go-ahead before any high-blast-radius fix — installer
  or uninstall safety, destructive git paths, permission or settings
  changes.
- End the round by naming any new *review dimension* the findings imply,
  so the catalog in the `review-brief` skill's
  `references/review-dimensions.md` grows instead of the lesson
  evaporating. A class specific to some other repo belongs in that
  repo's own docs instead.
- The PR merges through the owner — do not self-merge.
