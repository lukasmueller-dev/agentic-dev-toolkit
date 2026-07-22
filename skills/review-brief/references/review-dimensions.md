# Review-dimensions catalog

The accumulated knowledge of what an independent review round looks at.
`review-brief` assembles each round's mission from this file: the generic
core applies to any repo; a conditional dimension applies only when its
anchor files exist in the target repo. A staged round is this catalog,
minus dimensions well-covered by recent rounds, plus the code changed
since the last round.

This file is where review knowledge accumulates instead of evaporating
into PR history. When a round surfaces a new class of defect worth
checking every time: a generic class is added here (a toolkit change); a
class specific to some other repo belongs in that repo's own instruction
file or docs, and the staged brief tells the session so.

## Generic core — any repo

- **Adversarial static read.** Read the executable surface against the
  repo's own documented pitfalls (instruction file, docs): assume each
  documented trap has at least one instance the guards missed, and hunt
  for it. Silent-failure paths first — the bug that prints success.
- **Docs-vs-code drift.** README, docs, help text, comments that describe
  a sibling file, config examples, completions: does each still match the
  code as it is today?
- **Test blind spots and harness isolation.** Guards without tests; paths
  only one platform exercises; assertions that pass vacuously; whether
  the suite can ever touch the developer's real environment.
- **Config and permission safety.** Audit permission/settings rules
  against their documented traps (wildcards spanning more than intended,
  path rules anchoring somewhere unexpected); secrets reachable through a
  side door the deny rules miss; deny rules that miss an equivalent
  spelling of the same action.
- **CI correctness and guard coverage.** Do workflows run what they claim,
  on the platforms that matter; are repo-invariant guards (greps, lint
  rules) actually matching the drift they exist to catch; are opt-in
  triggers understood by the merge process.
- **Cross-file consistency.** Constants, regexes, or contracts duplicated
  across files and kept in lockstep only by comment — verify every copy,
  and every pointer comment that names the siblings.

## Conditional — only when the anchor files exist in the target repo

- **Skill quality beyond lint** *(anchors: `docs/skill-quality.md`,
  `bin/skill-lint`)*. Grade every `SKILL.md` against the judgment
  criteria the linter cannot check: description says what *and* when,
  body opens with boundaries, "done" defined, side-effecting skills not
  model-invocable.
- **End-to-end lifecycle execution** *(anchors: `bin/vibe`,
  `install.sh`)*. Execute, never just read: the full task lifecycle
  (start → edit → sync → bounded loop with a stub agent → done, every
  guard exercised) and the installer (install → doctor → idempotent
  second run → uninstall) — all in throwaway environments, never the
  real HOME, `~/.claude`, `~/bin`, or the real worktree root. A repo
  reviewed only statically for two rounds has earned an execution pass.

## Standing rules — baked into every staged round

- Rebase onto the default branch first (`git rebase origin/main`, or
  whatever the default is) — never the resume verb, which fast-forwards
  to the branch's own upstream and reports "already up to date" while
  arbitrarily far behind the default branch.
- Run the repo's own verification first as the baseline; a failure there
  is yours. Treat what that gate does *not* catch as the review's real
  target.
- Discover blind, then de-duplicate: complete the discovery pass before
  reading prior rounds' findings or the project's debt tracks. A re-found
  fixed-or-tracked item is replication — evidence the pass works — and is
  reported separately, never as a finding.
- The deliverable is a ranked findings list: each with `file:line` and a
  concrete failure scenario, reasoned-but-unproven claims labelled as
  such. Fixes never replace the report.
- One commit per concern, the failure it prevents in the body, so any
  single fix can be reverted alone.
- Owner go-ahead before any high-blast-radius fix — installer/uninstall
  safety, destructive git paths, permission or settings changes.
- Where CI is opt-in per PR, the review PR must opt in (here: the
  `run-ci` label) — a skipped run reads as passing in the merge box.
- End the round by naming any new review dimension its findings imply, so
  this catalog can grow instead of the lesson evaporating.

## Round-1 extras — when no prior round exists

- Dispatch parallel sub-reviewers over independent dimensions — after the
  rebase, never before: a stale tree wastes the entire fan-out.
- De-duplicate against the repo's pre-existing TODO/debt tracks instead
  of prior review PRs, since there are none.
