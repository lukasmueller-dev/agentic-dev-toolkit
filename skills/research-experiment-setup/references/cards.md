# The 10 cards

One decision each. *Default* is your recommendation to the human, never a
silent choice. *Evidence* is what the late decision cost on a past project.
*Done when* is what step 4 builds toward.

## 1. Record + key

- **Decide:** what one run record holds; which fields form the comparison key.
- **Default:** one JSON record per run, committed to git, `schema_version`
  from day 1. Record more than the key needs: commit, dirty flag, code hash of
  declared globs, resolved config, seeds, env lock hash, host, checkpoint
  hashes, outcome. Derive the key at read time, so a key change rewrites no
  record.
- **Evidence:** the key changed 5 times in 12 days (schema 1 → 6).
- **Done when:** a smoke run writes a record that validates against the schema.

## 2. Counted vs. uncounted

- **Decide:** which runs count as results.
- **Default:** uncounted by default. A run counts only when it starts from a
  frozen tag on a clean, pinned tree. Decide once, before the first counted run.
- **Evidence:** freeze, unfreeze, freeze again.
- **Done when:** the run entry refuses `counted` on a dirty tree or an untagged
  commit.

## 3. Execution route

- **Decide:** how a run reaches compute (local process, scheduler array,
  container).
- **Default:** one route per project, chosen on day 1; its pin (image digest,
  env lock, module list) goes in the record.
- **Evidence:** the route changed twice.
- **Done when:** the smoke run and the counted run go through the same route.

## 4. Raw data

- **Decide:** what is kept raw (episodes, per-step logs) and where.
- **Default:** decide before the first counted run, with a format version.
  Large files off git; their sha256 in the record.
- **Evidence:** the raw log format went 3 → 6.
- **Done when:** a record names its raw files by hash and format version.

## 5. Viewer

- **Decide:** where people look at runs.
- **Default:** the tracker only (wandb), no custom UI. `group` = key,
  `job_type` = run kind, tags = state (counted, tag name). One sync script
  rebuilds the tracker from the records — the records are the source of
  truth. Log media only from finished runs: a re-run cannot overwrite it.
- **Evidence:** a custom UI took 62 commits over 15 days, then was removed.
- **Done when:** the sync script rebuilds a deleted tracker project from records.

## 6. Repo boundaries

- **Decide:** which repo owns what — training, evaluation, deploy, hardware
  I/O, UI.
- **Default:** decide before code. No code moves between repos in the first
  weeks.
- **Evidence:** a console moved to a new repo within 24 h, then was renamed
  twice.
- **Done when:** a one-line owner per part in the setup table.

## 7. Report

- **Decide:** how results are read back.
- **Default:** group by key; refuse to mix keys in one cell; always show an
  interval — Wilson for rates, stderr over seeds for continuous metrics. Reads
  records only.
- **Done when:** the report reads the smoke and counted records back.

## 8. Host effects

- **Decide:** what the host can change about an outcome.
- **Default:** record host, load (`uptime`), GPU model and memory. Refuse a run
  only when outcomes depend on wall-clock time.
- **Evidence:** CPU load from another job tripled timeout wall time and changed
  outcomes.
- **Done when:** the record carries the host fields.

## 9. Protocol

- **Decide:** where evaluation settings live.
- **Default:** one versioned file (episodes, seeds, horizons, thresholds), each
  value with its evidence. Add a suite; never edit one that a counted run used.
- **Done when:** the record names the protocol file and suite version.

## 10. Doctor

- **Decide:** how known traps are caught.
- **Default:** a trap that a check can catch in seconds becomes a doctor check
  (one command, non-zero exit, one line: symptom → fix). Any other trap: one
  line in the repo's instruction file.
- **Done when:** the doctor runs before every counted run.
