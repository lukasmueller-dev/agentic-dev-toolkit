# Contracts for the `research-*` skill family

A family of skills for working in **research codebases** — the kind where a
`train.py`, a config tree and a cluster stand between you and a result. The
motivating case is vision-language-action (VLA) research, but nothing in the
family may be VLA-specific: the shapes it deals with (an unfamiliar repo, an
environment that fights back, a run that is not learning, a fork that drifts
from upstream) are common to any research code.

This file is **design only**. No skill ships from it. It fixes the seven
things every later item in the family consumes, so that a later item can be
picked up cold without re-deciding any of them. A later item that wants to
change one of these edits *this file*, in the same PR, with the reason — it
does not decide locally and leave the family inconsistent.

| The decision                                   | Section |
| ---------------------------------------------- | ------- |
| 1. Skill vs agent                              | [Skills, not agents](#1-skills-not-agents) |
| 2. A `templates/` entry per emitted document   | [One template per document](#2-one-template-per-emitted-document) |
| 3. Artifacts land in the target repo's `docs/` | [Where artifacts land](#3-where-emitted-artifacts-land) |
| 4. Shared research-repo detection              | [Repo-kind detection](#4-repo-kind-detection) |
| 5. Shared execution-context detection          | [Execution-context detection](#5-execution-context-detection) |
| 6. Never launch the expensive thing            | [The smoke-scale rule](#6-the-smoke-scale-rule) |
| 7. The `research-` name prefix                 | [Naming and scope](#7-naming-and-scope) |

## 1. Skills, not agents

**All nine items ship as skills under `skills/`, including `codebase-map`**
(named `research-cartographer` when this file was written — see §7).

The exception was worth considering: mapping an unfamiliar repo is a broad,
read-heavy sweep, which is exactly the shape the reviewer agents in
`claude/agents/` exist for — read-only fan-out with isolated context, so the
sweep's file dumps never land in the main session. Three things decided
against it:

- **Portability is the family's premise.** `claude/agents/` is Claude-Code-only
  by the layout contract, and a codebase map is precisely the artifact a
  second agent should be able to produce. A skill is the portable half of the
  repo; an agent is not.
- **The reviewer agents are read-only by tool allowlist**, and that allowlist
  is what makes them trustworthy — an agent that can edit can make its own
  findings disappear. `codebase-map`'s product is a *written file*, so it
  does not fit the pattern that keeps those agents safe.
- **Isolated context is available to a skill anyway.** A skill body may say
  "delegate the per-subsystem reads to subagents if the host offers them,
  otherwise read sequentially" — the context win without the coupling. No
  skill in the family may *require* a subagent to exist.

If dogfooding shows context bloat is the real bottleneck, the escape hatch is
a thin `claude/agents/codebase-map.md` that **invokes the skill**
(plus its line in `.claude-plugin/plugin.json`, since `agents` there is a list
of files) — never a second copy of the workflow. That needs evidence from a
real run and a note in this section, not a preference.

### Model invocation (beyond the seven, decided here to keep it consistent)

Per SQ13 in `docs/skill-quality.md`, a skill with side effects sets
`disable-model-invocation: true` unless its writes are gated or are
never-destructive scaffolding of files it owns. The line for this family:

| Skill | `disable-model-invocation` | Why |
| ----- | -------------------------- | --- |
| `codebase-map`, `research-train-doctor`, `research-run-archaeology`, `research-ablation-planner`, `research-paper-to-code` | absent (model-invocable) | They read, and write only their own artifact under `docs/`. A re-run diffs against the existing artifact rather than overwriting it, which is what keeps this inside SQ13(b). |
| `research-lab-notebook` | absent (model-invocable) | Append-only into its own file; it must fire proactively at the end of an experiment or the entry is never written. |
| `research-first-run` | **`true`** | It mutates the environment — installs packages, builds wheels, executes commands. |
| `research-fork-delta` | **`true`** | It rewrites git history (rebase onto upstream). |

The line is: *a skill that mutates the environment or git history is
user-invoked only.* Everything else earns model invocation by owning its
output file and never clobbering it.

## 2. One template per emitted document

Every document these skills emit has exactly one copy under `templates/`, in
**`templates/research/`** — or, for a document emitted by a skill that is not
part of the family, the directory matching that skill (`templates/codebase/`
for `CODEBASE_MAP.md`). Either way it is rendered through the placeholder
contract in
`templates/README.md`. Never a heredoc, never pasted into a `SKILL.md` as an
example — that is how three divergent copies of `HANDOFF.md` came about
(SQ16).

| Document            | Template                             | Emitted by |
| ------------------- | ------------------------------------ | ---------- |
| `CODEBASE_MAP.md`   | `templates/codebase/CODEBASE_MAP.md` | `codebase-map` (outside the family — §7) |
| `RUNBOOK.md`        | `templates/research/RUNBOOK.md`      | `research-first-run` (appended to by any skill that discovers a workaround) |
| `FORK_DELTA.md`     | `templates/research/FORK_DELTA.md`   | `research-fork-delta` |
| `LAB_NOTEBOOK.md`   | `templates/research/LAB_NOTEBOOK.md` | `research-lab-notebook` |

**A template lands in the same PR as the skill that emits it, not up front.**
The `CODEBASE_MAP.md` schema will change on first contact with a real repo —
that is why wave 1 is dogfooded before wave 2 starts — so freezing four
templates before any of them has produced a document would guarantee a
rewrite. What is fixed *now* is the contract, not the content.

Three obligations come with adding one, all in that same PR:

- **A row in `templates/README.md`** — the file/lives-at/lifespan table, plus
  a row per new placeholder token. The token table is the contract the
  renderers implement; prefer the existing `<repo>`, `<date>`, `<machine>`
  tokens over inventing one.
- **Extend the hardcoded lists.** The tool-neutrality guard in
  `.github/workflows/ci.yml` and its mirror in `tests/install.bats` both read
  a hardcoded file list. Add **`templates/research` as a directory** to the
  two directory loops there (beside `templates/ci` and `templates/gitignore`)
  rather than naming files, so the *fifth* document is covered without
  another CI edit. Both loops assert the directory is non-empty first, for the
  reason the existing comment gives: a rename would otherwise make a glob
  match nothing and pass silently.
- **Stay tool-neutral and machine-neutral.** No template may name a CLI, an
  agent, a hostname or a cluster — so a `RUNBOOK.md` template may not say
  "ask the agent to re-run this". The *rendered* runbook in a target repo will
  name real hosts and real paths; the template may not.

`LAB_NOTEBOOK.md` is the one artifact in this repo that is legitimately a
**log**: experiment history is data, and an entry stays true after the
experiment ends. Its template carries the file header plus one entry skeleton
(hypothesis, config delta, result, verdict) that gets copied per entry. This
does not weaken the append-never rule for `HANDOFF.md` — that file is a baton
whose content expires, and the distinction is the point.

## 3. Where emitted artifacts land

**In the target repo's `docs/`, never its root.** So `docs/CODEBASE_MAP.md`,
`docs/RUNBOOK.md`, `docs/FORK_DELTA.md`, `docs/LAB_NOTEBOOK.md`.

The root belongs to the status trio — `PROJECT_STATUS.md`,
`PROJECT_ROADMAP.md`, `HANDOFF.md` — which every repo has and which agents are
told to look for there. These four are layer-3 living documents in the sense of
`docs/artifact-architecture.md`: repo-scoped, read by whoever picks the repo up,
pointed *to* rather than skimmed. `docs/` is where that layer already lives.

Rules that follow:

- If the repo already has a docs directory under another name (`doc/`,
  `documentation/`), use it; otherwise create `docs/`. Never write outside the
  repo, and never above its root.
- `PROJECT_STATUS.md` gets a one-line pointer when one of these is created —
  the same treatment `docs/` files already get. That is how a cold session
  finds a map it did not know existed.
- In a fork, these files are local additions that will show in every diff
  against upstream. That is expected: `research-fork-delta` records them as
  intentional divergences so a rebase does not treat them as noise.

## 4. Repo-kind detection

Shared, in **`skills/_lib/research-lib.sh`** — sourced the way
`skills/_lib/README.md` documents (through the script's own resolved location,
never `$PWD`, since a skill runs symlinked out of `~/.claude/skills`).
Underscore-prefixed, so the installer and `skill-lint` skip it.

```
detect_repo_kind   [DIR]  → research | application | ambiguous
repo_kind_evidence [DIR]  → one "signal: detail" line per matched signal
```

Modelled on `detect_env`/`env_reason` in `bin/vibe`: a verdict function and a
reason function, both cheap, both always exiting 0 — "cannot tell" is a
verdict (`ambiguous`), not an error.

**Research signals** (each counts once): a training entry point (`train.py`,
`scripts/train*`, a `train` console script in `pyproject.toml`); a config tree
plus a config framework (`configs/**/*.{yaml,yml,gin}` with `hydra-core`,
`gin-config`, `draccus`, `omegaconf` or `ml_collections` declared); an
experiment tracker (`wandb`, `mlflow`, `aim`, `tensorboard`); a deep-learning
framework (`torch`, `jax`, `flax`, `tensorflow`); checkpoint/eval conventions
(`checkpoints/`, `eval*.py`).

**Application signals**: a `package.json` with a web framework; route
definitions (`@app.route`, `router.get`, `urls.py`, an OpenAPI document); a
serving entry point (`uvicorn`, `gunicorn`, `fastapi`, `flask`, `django`,
`express`, or a Dockerfile whose `CMD` starts a server); deploy config
(`k8s/`, `helm/`, `fly.toml`, `vercel.json`, `Procfile`).

**Verdict:** `research` when research ≥ 2 and application ≤ 1;
`application` when application ≥ 2 and research ≤ 1; otherwise `ambiguous`,
which means **ask** — with the evidence on screen. A research repo with a
serving path is normal, which is why one application signal must not flip the
verdict, and 1-vs-1 (or 0-vs-0) is genuinely unknown rather than a coin toss.

Implementation constraints, all of them already-bitten shapes from the repo
`CLAUDE.md`: no network, works on a shallow checkout, bash 3.2, BSD *and* GNU
userland. Bound the walk (`-maxdepth 3`, prune `.git`, `node_modules`,
`.venv`) so it stays fast on a large repo. And watch `pipefail`: `grep -q`
exits as soon as it matches, killing its producer with SIGPIPE, so grep files
directly rather than ending a pipeline with it — and remember `grep -v` exits
1 when it filters everything out.

## 5. Execution-context detection

Same lib, same shape:

```
detect_exec_context      → cluster | workstation | ambiguous
exec_context_evidence    → one "signal: detail" line per probe
```

| Evidence | Verdict |
| -------- | ------- |
| `SLURM_JOB_ID` / `SLURM_JOB_NODELIST` in the environment | `cluster` — inside an allocation |
| `sbatch`/`srun` on `PATH`, no GPU visible | `cluster` — a login/submit node; nothing GPU-shaped runs *here* |
| `sbatch`/`srun` on `PATH` **and** GPUs visible | **`ambiguous`** — an interactive allocation, or a workstation with cluster access |
| No scheduler, GPUs visible | `workstation` |
| No scheduler, no GPU | `workstation` (CPU-only) |

"GPU visible" means `nvidia-smi -L` exits 0 and lists at least one device;
`nvidia-smi` present but failing (no driver, no permission) counts as *no GPU
visible* and says so in the evidence, because that is the state a container
without device passthrough is in.

Three rules, all copied deliberately from how `vibe` treats local-vs-server:

- **Detected per session, never a fixed label.** The same machine is a
  workstation when you sit at it and a cluster login node when you SSH in.
  Nothing writes a role into config.
- **It prints its verdict and the reason before acting** — `vibe where`'s
  contract. A silent guess here burns an allocation.
- **Ambiguous means ask**, once, with the evidence and the two candidate
  verdicts. Ambiguity is the *common* case (a login node with a stray GPU, a
  workstation with cluster access), so the ask is a normal path, not an error
  path.

The answer to that question is recorded under an `## Environment` heading in
the target repo's `docs/RUNBOOK.md`, together with the evidence that was
ambiguous, so the next session does not re-ask. It is a **cached answer, not
configuration**: detection still runs every session, and a fresh verdict that
contradicts the record is reported and re-asked rather than trusted. That is
the one judgment call in this section — recording anything at all sits close
to the never-a-fixed-label rule, and re-detecting is what keeps it honest.

## 6. The smoke-scale rule

**Never launch the expensive thing.** Stated once, here; every skill in the
family references this section rather than restating it.

A skill may execute a command only when *all five* hold:

1. **One process, one device.** No `torchrun`, `accelerate launch`,
   `deepspeed`, `mpirun`; no `--nproc-per-node` above 1; no
   `CUDA_VISIBLE_DEVICES` naming more than one device.
2. **No scheduler submission.** Never `sbatch`, `srun`, `salloc`, `qsub`,
   `bsub`, and never a `kubectl apply` of a job.
3. **Bounded wall clock** — expected under about two minutes, *and* run under
   a hard `timeout` so a wrong expectation stops itself instead of running
   until someone notices.
4. **Bounded download** — nothing expected to exceed roughly 1 GB. Dataset and
   checkpoint pulls are the cost that is not compute, and the one most easily
   started by accident.
5. **No side effects outside the repo and the environment that already
   exists** — no writes to shared scratch or a shared dataset path, and no run
   registered in a shared tracker project (`WANDB_MODE=offline` for a smoke
   run that would otherwise appear in someone's dashboard).

Anything failing one of the five: **stop and hand the command over** — printed
verbatim, copy-pasteable, with the reason it was not run and what it needs
(GPUs, hours, an allocation). Handing over is the successful outcome of that
step, not a failure to complete it; a skill that apologises for stopping
teaches the wrong thing.

The human may authorise a specific command in the moment. That authorisation
covers **that command, in that session** — it is never recorded, never
generalised to "runs are fine now", exactly as approval in one context does
not extend to the next.

Why the rule is this blunt: a guessed multi-GPU launch costs GPU-hours and
queue priority that belong to other people, and a wrong multi-hour run is
discovered hours later, when the day is gone. The asymmetry is total — the
cost of stopping is one paste.

`research-first-run`'s deliverable, a committed `scripts/smoke.sh` that runs
in under ~2 minutes, is the sanctioned shape of the *allowed* side of this
rule: the thing that may run gets a name, a budget and a home in the repo.

## 7. Naming and scope

**Every skill *whose workflow is research-specific* is named
`research-<thing>`.** `skills/` is a flat global namespace shared with every
other repo's skills and with vendored third-party ones, so a prefix is the only
grouping mechanism there is — and `ls ~/.claude/skills | grep '^research-'` is
the family roster. It also keeps them from colliding with a future skill called
`first-run` or `notebook`.

### The one carve-out: `codebase-map`

Written as `research-cartographer`, renamed on landing. Two reasons, and the
first is the one that matters:

- **Its workflow is not research-specific.** It has an explicit `application`
  mode, ships both middle sections of its schema, and was verified producing
  an `application` verdict on a plain web repo. A `research-` prefix on a skill
  that maps any codebase advertises a narrower thing than it is, and the next
  person mapping a web service has no reason to look for it under `research-`.
- **`-er` names an actor, which is what agents are.** The skills here are named
  for the task or the artifact (`codebase-health`, `codebase-review`,
  `add-roadmap-item`); a cartographer is a *someone*. `codebase-map` names the
  document it writes and sorts beside the two `codebase-*` skills already in
  `skills/`, which is the grouping it actually belongs to.

So the prefix rule is about the *workflow*, not about who consumes the output:
`research-train-doctor` reads `CODEBASE_MAP.md` (§3) and stays in the family,
because triaging a run that is not learning is research-shaped and mapping a
repo is not. The other eight items keep the prefix. A future item that turns
out to be general-purpose in the same way takes the same exit, and records it
here.

The cost is accepted knowingly: the family roster is now
`grep '^research-'` **plus** `codebase-map`, and this section is where that is
written down.

The prefix is `research-`, not `vla-` or `ml-`, because **nothing in the family
may be domain-specific**:

- A `description` triggers on research-codebase work in general ("an
  unfamiliar research codebase", "a training run that is not learning"), never
  on robotics or VLA vocabulary. The description is the only text the model
  sees when choosing (SQ9), and a robotics-flavoured trigger makes the skill
  invisible on the next repo.
- Domain specifics belong in `references/`, as examples — `research-train-doctor`
  may name action normalization and action-token masking in a
  `references/vla.md`, the way `codebase-health` keeps its shell knowledge in
  `references/shell.md` (SQ17). The workflow in `SKILL.md` stays general.
- No skill names a machine, a cluster, or a personal workflow (SQ18). That
  context lives in `memory/GLOBAL.md` and in the target repo's own runbook.

`skill-lint`'s mechanical rules apply as everywhere else: directory name equals
frontmatter `name`, lowercase and hyphens only, and no "claude"/"anthropic" in
a name (SQ3, SQ4).

## What this file deliberately does not decide

- **The `CODEBASE_MAP.md` schema.** Owned by `codebase-map` and
  expected to change on first contact with `openpi`; that is why wave 1 is
  dogfooded before wave 2 begins.
- **Whether the family gets its own `references/` shared between skills.** No
  evidence yet that two skills need the same reference file; the first time
  they do, that is a decision for that PR, recorded here.
- **The dogfood repo's own contents.** `openpi` is the target throughout, but
  nothing in the family may depend on its layout.

## Consumers

| Item | Consumes |
| ---- | -------- |
| `codebase-map` | §1 (skill, model-invocable), §2, §3, §4, §7 — the one item outside the `research-` prefix |
| `research-first-run` | §2 (`RUNBOOK.md`), §3, §5, §6, §7 |
| `research-train-doctor` | §3 (reads the map), §5, §6, §7 |
| `research-run-archaeology` | §3, §7 |
| `research-lab-notebook` | §2, §3, §7 — plus a row in `docs/artifact-architecture.md` and a line in `memory/GLOBAL.md`, since it adds a lifetime tier |
| `research-ablation-planner` | §6 (emits roadmap items, launches nothing), §7 |
| `research-fork-delta` | §2, §3, §7, and `disable-model-invocation` per §1 |
| `research-paper-to-code` | §3, §7 |
