# Handoff — agentic-dev-toolkit / harness-agent-features

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `harness-agent-features`
- **Worktree:** /home/lukas-mueller/git/worktrees/agentic-dev-toolkit/harness-agent-features
- **Last updated:** 2026-10-24 12:44 CEST · local (turing)

## State

Not started; design in progress. Three grilling rounds with the author ran
on 2026-10-24 in a humanoid-locoman-vla session (nothing changed there).

**Goal:** cut a new robot-learning project's start from ~4 weeks to ~4
days, with the experience of `humanoid-locoman-vla` (lab/),
`g1_web_commander` and `humanoid_bridge`. First user: the NCBF paper,
Siwei Ju's `rl-x-NCBF`, branch `pncbf-v2`.

**Settled**

- Decisions transfer more than code: most rework came from decisions made
  after the first runs.
- Two targets, separate clocks: sim in 4 days (a smoke and a counted run,
  pinned, recorded, grouped by key in wandb, read back by a report); robot
  second (an observe-only run, recorded the same way).
- Adapt to the host: map its parts to the cards, add only gaps, keep its
  conventions.
- An agent runs the kit and asks the author each decision.
- v1 gets at most 1 day, is tested on NCBF at once, then corrected. Order:
  toolkit audit -> kit v1 -> NCBF.
- `humanoid-locoman-vla` stays completely unchanged until the thesis ends:
  it is the reference implementation. Link or copy, never move code out.
- Robot part is robot-neutral: a procedure plus one slot per robot. Go2
  robot layer: not decided.
- NCBF work goes on the author's own branch off `pncbf-v2`.
- Script rule: script when one correct result + runs more than once +
  silent error; agent when it needs per-project judgment; hybrid = agent
  decides, script writes or checks.
- v1 covers every area: envelope, logging, wandb, model/sim bring-up,
  robot procedure.
- Also in scope: port the generic findings of `humanoid-locoman-vla` to
  the toolkit (see Q8). The source keeps its lines: copy, never remove.

**Open (round 3; recommendation in brackets)**

- Q1 Form: two agent-only skills, `research-run-envelope` (cards 1-10) and
  `research-robot-bringup` (procedure + slot template); no scripts in the
  toolkit. [yes]
- Q2 Scripts: the kit ships none; the agent writes host-native scripts
  from the cards, which link to the lab code. Frequency refinement:
  toolkit scripts only for per-session or per-repo steps; once-per-project
  steps stay prose; per-run steps become host scripts. [yes; audit:
  hybrids ~0.4 uses per commit]
- Q3 Card defaults: table below. [ok, all rows]
- Q4 Robot procedure and slot fields: below. [accept]
- Q5 Doctor pattern becomes card 10. [yes]
- Q6 Upkeep: each kit run ends with a retro of at most 3 lines -> a card
  change commit. On NCBF, record the kit start date and the sim end-state
  date in `PROJECT_STATUS.md`. [yes]
- Q7 Trigger: model-invocable, writes gated by approval; a session-start
  hook line only if NCBF shows misses. Ask the author why
  `research-first-run` was never used. [model-invocable]
- Q8 Port from `humanoid-locoman-vla/CLAUDE.md`: the generic sandbox and
  tool traps, one line each (symptom + fix). Each Bash call has its own
  network namespace; `ps`/`pgrep` are blind in the sandbox; a second
  `uv sync` blocks silently on the cache lock; `git fetch`/`gh`/`rebase`/
  `merge`/`stash`/`worktree prune` fail in the sandbox; a command whose
  text names `.env` is refused; `cd` into a subfolder leaves `.claude/`
  placeholders; `kill $(pgrep -f ...)` kills the caller; `tmux
  has-session -t` prefix-matches (use `-t '=name'`); wandb needs its dirs
  under `$TMPDIR`; `git push` signing fails intermittently. Research
  lessons go into the cards instead. [sandbox-specific traps ->
  `claude/CLAUDE.md`; agent-neutral ones -> `memory/GLOBAL.md`]
- Later rounds: Go2 robot path and Go2 sim, commander scope, card wording
  and skill names, edits to `docs/research-skills.md` contracts.

| # | Card | Default |
|---|---|---|
| 1 | Record + key | One JSON record per run in git, schema version from day 1. Record more than the key needs: commit, dirty flag, code hash of declared globs, resolved config, seeds, env lock hash, host, checkpoint hashes, outcome. Derive the key at read time. |
| 2 | Counted vs uncounted | Uncounted by default; counted only from a frozen tag on a clean, pinned tree. Decide once, before the first counted run. |
| 3 | Execution route | One route per project, chosen on day 1, its pin in the record. |
| 4 | Raw data | Before the first counted run, decide what is kept raw, with a format version. Large files off git, sha256 in the record. |
| 5 | Viewer | wandb only, no custom UI. group = key, `job_type` = run kind, tags = state; one sync script rebuilds wandb from the records. Log media only from finished runs (rewind is off). |
| 6 | Repo boundaries | Decide which repo owns what before code; no code moves between repos in the first weeks. |
| 7 | Report | Group by key, refuse to mix keys, always show an interval (Wilson for rates, stderr over seeds). |
| 8 | Host effects | Record host, load, GPU; refuse a run only if outcomes depend on wall-clock time. |
| 9 | Protocol | One versioned file for eval settings, evidence per value; add a suite, never edit one. |
| 10 | Doctor | Each trap becomes a check that runs in seconds; else a one-line trap in the instruction file. |

**Robot procedure:** (1) sim rehearsal with the real robot layer in the
loop; (2) observe-only on the robot, nothing writes `/lowcmd`, N minutes
recorded; (3) latency check, one JSON line within budget; (4) gantry
gates: G0 (commands stop), e-stop, damp on exit, joint limits; (5)
commanded run, gantry then ground. Slot fields: robot layer, e-stop path,
gate values, sim, release tool, recording.

**Facts**

- NCBF: one in-process JAX/MJX job through the RL-X runner, SLURM arrays
  on the IAS cluster, conda env `rlx-ncbf`. `pncbf-v2` already has a
  read-only tree per commit, a HEAD == COMMIT + clean check, wandb tags,
  `eval/protocol_default.json` with `_evidence`, `RESULTS.md` (empty), a
  GPU memory trace, `SMOKE=1`. It has no code hash narrower than the
  commit, no comparability key, no preflight.
- Where the time went (git history of lab + commander + bridge, regex
  classifier, about +-10%):

  | Area | Commits | Active days |
  |---|---|---|
  | Research-specific | 342 | 38 |
  | Model / sim bench | 331 | 35 |
  | Robot | 246 | 26 |
  | Envelope (most rework: 118 commits on 10-12/13) | 206 | 27 |
  | Logging | 122 | 22 |
  | Custom UI, later removed | 62 | 15 |
  | wandb | 34 | 13 |

- Six late decisions: key changed 5 times in 12 days (schema 1 -> 6);
  freeze, unfreeze, freeze; execution route changed twice; raw log format
  3 -> 6; custom UI replaced by wandb; console moved to a new repo within
  24 h, then 2 renames.
- Go2: the rl-x Go2 deploy script uses raw DDS at 50 Hz with one safety
  check, no e-stop; it crashes at startup, cannot load `ncbf_ppo`
  checkpoints and does not apply the filter on the robot. Siwei's T1
  deploy uses `humanoid_bridge`'s `RobotClient` (upstream DFKI).
  `humanoid_bridge` vendors `unitree_go` and its CRC: a Go2 target takes
  H1's I/O and G1's safety. The commander hard-codes 29 joints and
  `unitree_hg`. Estimates: repair the rl-x script 3-5 d; port the bridge
  rules to Python 4-6 d; minimal Go2 bridge target 6-9 d (recommended);
  plus neutral commander and Go2 sim 12-20 d.

## Next action

After `toolkit-audit` merges: resume the grilling with the author at round
3 (Q1-Q8 above), then the later rounds. Then write `research-run-envelope`
v1 (at most 1 day) under the `docs/research-skills.md` contracts, and run
it on NCBF.

## Blockers

Waits for `toolkit-audit` to merge: the kit lands on the audited toolkit.

## Gotchas (unpromoted)

- `docs/research-skills.md` fixes the family contracts: a member that
  changes one edits that file in the same PR.
- Never edit `humanoid-locoman-vla`: its counted cells run from frozen
  tags, and a change outside `runs/` needs a new tag.
- `rl-x-NCBF` is Siwei's repo; the Go2 deploy code is the same on `master`
  and `pncbf-v2`.
