# Handoff — agentic-dev-toolkit / research-kit-v1

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-kit-v1` (draft PR #82 against `main`)
- **Worktree:** /home/lukas-mueller/git/worktrees/agentic-dev-toolkit/research-kit-v1
- **Last updated:** 2026-10-24 13:55 CEST · local (turing)

## State

Kit v1 draft is committed; 1-day budget started 2026-10-24.

- `research-experiment-setup`: SKILL + `references/cards.md` (10 cards) +
  `seed.sh` → `docs/EXPERIMENT_SETUP.md`. Model-invocable.
- `research-hardware-trial`: SKILL (5-step gate procedure) + `seed.sh` →
  `docs/hardware/<platform>.md` (slot + gate table). User-only.
- `skills/_lib/doc-lib.sh` (`seed_doc`) shared with `codebase-map/map.sh`.
- Gate: shellcheck, shfmt, `skill-lint --strict` (12 skills), `bats tests/`
  313/313 — all green.

Settled design (grilling 2026-10-24; promote to the PR body):

- Goal: new robot-learning project start 4 weeks → 4 days. Sim end state =
  smoke + counted run, pinned, recorded, grouped by key in wandb, read back by
  a report. Robot second, own clock.
- The agent maps the host's parts to the cards, adds only gaps, asks the
  author each decision. Kit ships no run scripts; the agent writes them in
  the host's style.
- Upkeep: retro ≤ 3 lines per kit run → one commit to `cards.md`. NCBF
  records kit start date + sim end-state date in its `PROJECT_STATUS.md`.
- Go2 robot path and commander scope: deferred to NCBF's hardware stage,
  asked by `research-hardware-trial`.
- `humanoid-locoman-vla` stays unchanged (frozen reference); no links to its
  lab skills.

## Next action

1. Get the author's review of the card text in `references/cards.md` and the
   two SKILL.md files (Q14: text review in the PR, no design round).
2. Run step 2 of `research-experiment-setup` on NCBF (`rl-x-NCBF`, author's
   branch off `pncbf-v2`): the card table only, no code; the author approves
   it. That is kit v1's done-when.

## Blockers

None.

## Gotchas (unpromoted)

- NCBF facts for step 2: one in-process JAX/MJX job through the RL-X runner,
  SLURM arrays on the IAS cluster, conda env `rlx-ncbf`. `pncbf-v2` already
  has a read-only tree per commit, a HEAD == COMMIT + clean check, wandb tags,
  `eval/protocol_default.json` with `_evidence`, empty `RESULTS.md`, a GPU
  memory trace, `SMOKE=1`. Missing: a code hash narrower than the commit, a
  comparison key, a preflight.
- Go2 estimates for the hardware stage: repair the rl-x deploy script 3–5 d;
  port the bridge rules to Python 4–6 d; minimal Go2 bridge target 6–9 d
  (recommended); plus neutral commander and Go2 sim 12–20 d. The rl-x Go2
  script crashes at startup, cannot load `ncbf_ppo` checkpoints, has no e-stop.
- `rl-x-NCBF` is Siwei's repo: work only on the author's own branch.
