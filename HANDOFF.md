# Handoff — agentic-dev-toolkit / implement-first-track-c-items

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `implement-first-track-c-items`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/implement-first-track-c-items
- **Last updated:** 2026-07-27 03:31 UTC · server (srv1841294)

## State

Not started. The family's contracts are settled in `docs/research-skills.md`,
already on the default branch — **read it first**. Its seven decisions are not
to be re-litigated here; a change to one edits that file, in the same PR, with
the reason.

Scope: Track C wave 1 — `research-cartographer`, then `research-first-run`.
One PR per skill. Both roadmap items stay in `PROJECT_ROADMAP.md` until the
PR that finishes each one merges.

What the contracts already fix, so none of it gets rediscovered: both ship as
skills under `skills/`, not as agents; each emitted document gets a
`templates/research/` entry in the PR of the skill that emits it; artifacts
land in the *target* repo's `docs/`, never its root; the two shared detections
live in `skills/_lib/research-lib.sh`; nothing multi-GPU, multi-hour or
scheduler-bound may be executed (§6, the smoke-scale rule);
`research-first-run` sets `disable-model-invocation: true` and the cartographer
does not.

The lib is shared and neither skill owns it. The cartographer needs
`detect_repo_kind` / `repo_kind_evidence`; first-run needs
`detect_exec_context` / `exec_context_evidence`. Whichever lands first creates
the file; the second extends it.

Test material on this machine, no network needed: `~/git/github/mini-vla` is a
genuinely mixed repo — `train.py` and `pyproject.toml` alongside
`package.json` and three playwright configs — so it is the adversarial case
for §4's verdict rule. It must not come out `application`; `research` and
`ambiguous` are both defensible, but the evidence lines have to show both
sides. This repo itself must not come out `research`. The roadmap's dogfood
target, `openpi`, is not checked out; a shallow clone is enough, since the
cartographer only reads.

Gates before either PR: `shfmt -f . | xargs shellcheck`,
`shfmt -d -i 2 -ci .`, `bats tests/`, `./bin/skill-lint --strict skills`.
Adding a template also means a row in `templates/README.md` and
`templates/research` added as a *directory* to the hardcoded lists in both
`.github/workflows/ci.yml` and `tests/install.bats`.

## Next action

Write `detect_repo_kind` / `repo_kind_evidence` in
`skills/_lib/research-lib.sh` per §4 and run them against
`~/git/github/mini-vla`, this repo, and one plain application repo **before**
writing any of the skill. The verdict rule is the piece most likely to be
wrong and the cheapest to test. Then `skills/research-cartographer/SKILL.md`
plus the `templates/research/CODEBASE_MAP.md` schema, dogfooded on a shallow
`openpi` clone. Done when every schema section carries a `file:line` pointer
and a re-run reports a diff rather than a fresh map.

## Blockers

`research-first-run`'s done-bar is a committed `scripts/smoke.sh` that runs in
under about two minutes on a real research codebase. This machine has no GPU
and no scheduler (`nvidia-smi` absent, no `sbatch`/`srun`), so that proof needs
a GPU box. The skill and its execution-context detection can still be written
and tested here — the correct verdict here is `workstation`, CPU-only — but
the item is not done on the strength of the skill alone.

## Gotchas (unpromoted)

Three from the repo `CLAUDE.md` the lib will hit directly: bash 3.2 with BSD
*and* GNU userland; `grep -q` at the end of a pipeline kills its producer with
SIGPIPE under `pipefail`; `skill-lint` needs `skills` passed explicitly or it
lints this repo's own `.claude/skills` and reports green having checked
nothing. Also stage new files under `skills/` before running `bats`, or the
suite's stray-file guard fails on them. CI is opt-in — each PR needs the
`run-ci` label.
