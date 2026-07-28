#!/usr/bin/env bats
#
# skills/_lib/research-lib.sh's execution-context detection, and the env.sh
# steps built on it. Everything runs in throwaway repos under
# $BATS_TEST_TMPDIR, with a stub `nvidia-smi` and stub schedulers on PATH —
# the suite must be able to assert every row of docs/research-skills.md §5's
# table on a machine that has none of them.

load helper

setup() {
  git_env
  # A private PATH prefix per test, so a stub never outlives the test that
  # wanted it and never reaches the real machine's tools.
  STUB="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB"
  PATH="$STUB:$PATH"
  export PATH
  # The runner's own allocation must not reach the suite: running the tests
  # from inside a real job would otherwise make every verdict `cluster`.
  unset SLURM_JOB_ID SLURM_JOB_NODELIST
}

ENV_SH="$REPO_ROOT/skills/research-first-run/env.sh"

# stub_gpu N   — nvidia-smi listing N devices
# stub_gpu 0   — nvidia-smi present but failing (no driver / no passthrough)
stub_gpu() {
  local n="$1" i=0
  if [ "$n" -eq 0 ]; then
    printf '#!/usr/bin/env bash\nexit 1\n' >"$STUB/nvidia-smi"
  else
    cat >"$STUB/nvidia-smi" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in -L) ;; *) exit 0 ;; esac
STUB
    while [ "$i" -lt "$n" ]; do
      echo "echo 'GPU $i: Stub (UUID: GPU-$i)'" >>"$STUB/nvidia-smi"
      i=$((i + 1))
    done
  fi
  chmod +x "$STUB/nvidia-smi"
}

# nvidia-smi that succeeds but lists nothing — a container that has the driver
# but was given no devices. Distinct from stub_gpu 0, which fails outright.
stub_gpu_empty() {
  printf '#!/usr/bin/env bash\nexit 0\n' >"$STUB/nvidia-smi"
  chmod +x "$STUB/nvidia-smi"
}

stub_scheduler() {
  printf '#!/usr/bin/env bash\nexit 0\n' >"$STUB/${1:-sbatch}"
  chmod +x "$STUB/${1:-sbatch}"
}

context_of() {
  bash -c '
    set -euo pipefail
    . "$1/skills/_lib/research-lib.sh"
    detect_exec_context
  ' _ "$REPO_ROOT"
}

evidence_of() {
  bash -c '
    set -euo pipefail
    . "$1/skills/_lib/research-lib.sh"
    exec_context_evidence
  ' _ "$REPO_ROOT"
}

@test "exec context: inside an allocation is cluster" {
  # shellcheck disable=SC2030  # each @test is its own subshell; that is the isolation
  export SLURM_JOB_ID=12345
  [ "$(context_of)" = cluster ]
}

@test "exec context: SLURM_JOB_NODELIST alone is also inside an allocation" {
  export SLURM_JOB_NODELIST="node[001-004]"
  [ "$(context_of)" = cluster ]
}

@test "exec context: an allocation outranks every other probe" {
  # The environment variable is checked first on purpose: inside a job the
  # answer is settled, whatever else is on PATH or visible.
  # shellcheck disable=SC2031  # ditto — setup() unsets it, this test sets its own
  export SLURM_JOB_ID=12345
  stub_scheduler sbatch
  stub_gpu 8
  [ "$(context_of)" = cluster ]
}

@test "exec context: a scheduler with no GPU is a login node" {
  stub_scheduler sbatch
  [ "$(context_of)" = cluster ]
}

@test "exec context: a scheduler AND a GPU is ambiguous" {
  # The row that matters: an interactive allocation and a workstation with
  # cluster access look identical here, and they want opposite things. A
  # verdict either way would be a guess, and a wrong guess burns an
  # allocation.
  stub_scheduler srun
  stub_gpu 2
  [ "$(context_of)" = ambiguous ]
}

@test "exec context: no scheduler and a GPU is a workstation" {
  stub_gpu 1
  [ "$(context_of)" = workstation ]
}

@test "exec context: no scheduler and no GPU is a CPU-only workstation" {
  [ "$(context_of)" = workstation ]
  run evidence_of
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'nvidia-smi not installed'
}

@test "exec context: a present-but-failing nvidia-smi counts as no GPU" {
  # A container without device passthrough looks like a GPU box and is not.
  # With a scheduler present this is the difference between `cluster` and
  # `ambiguous`, so it decides a verdict rather than only a message.
  stub_gpu 0
  stub_scheduler sbatch
  [ "$(context_of)" = cluster ]
  run evidence_of
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'listed no device'
}

@test "exec context: an nvidia-smi that succeeds but lists nothing is no GPU" {
  # The other half of "GPU visible": exiting 0 is not enough, a device has to
  # be listed. A container with the driver but no devices assigned lands here,
  # and reading it as a GPU box would flip a login node to `ambiguous`.
  stub_gpu_empty
  stub_scheduler sbatch
  [ "$(context_of)" = cluster ]
  run evidence_of
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'listed no device'
}

@test "exec context: evidence reports every probe, including the negatives" {
  # "no scheduler on PATH" is itself the evidence for `workstation`; a reader
  # resolving an ambiguous verdict needs the negatives as much as the hits.
  run evidence_of
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -c .)" -eq 3 ]
  echo "$output" | grep -q '^scheduler environment: '
  echo "$output" | grep -q '^scheduler on PATH: '
  echo "$output" | grep -q '^GPU: '
}

@test "exec context: never errors, so a caller under set -e reaches the ask" {
  run context_of
  [ "$status" -eq 0 ]
  run evidence_of
  [ "$status" -eq 0 ]
}

@test "env.sh detect: prints the verdict and its evidence, and runs nothing" {
  stub_gpu 1
  run bash "$ENV_SH" detect
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^context: workstation$'
  echo "$output" | grep -q '^GPU: nvidia-smi lists 1 device'
}

@test "env.sh seed: renders the runbook into docs/, not the repo root" {
  local d
  d="$(make_repo booked)"
  run bash "$ENV_SH" seed "$d"
  [ "$status" -eq 0 ]
  [ -f "$d/docs/RUNBOOK.md" ]
  [ ! -f "$d/RUNBOOK.md" ]
  grep -q '^# Runbook — booked$' "$d/docs/RUNBOOK.md"
  run grep -nE '<(repo|date)>' "$d/docs/RUNBOOK.md"
  [ "$status" -ne 0 ] || {
    echo "unrendered placeholder: $output" >&2
    return 1
  }
}

@test "env.sh seed: never overwrites — the runbook is appended to for life" {
  # Regenerating would destroy exactly the knowledge the document exists to
  # keep, which is why this guard matters more here than for a map.
  local d before
  d="$(make_repo kept)"
  bash "$ENV_SH" seed "$d"
  echo "### a workaround someone found the hard way" >>"$d/docs/RUNBOOK.md"
  before="$(cat "$d/docs/RUNBOOK.md")"
  run bash "$ENV_SH" seed "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^exists: '
  [ "$(cat "$d/docs/RUNBOOK.md")" = "$before" ]
}

@test "env.sh seed: uses an existing docs directory under another name" {
  local d
  d="$(make_repo doc-named-rb)"
  mkdir -p "$d/doc"
  run bash "$ENV_SH" seed "$d"
  [ "$status" -eq 0 ]
  [ -f "$d/doc/RUNBOOK.md" ]
  [ ! -d "$d/docs" ]
}

@test "env.sh seed: refuses to write outside a git repository" {
  local d="$BATS_TEST_TMPDIR/not-a-repo-rb"
  mkdir -p "$d"
  run bash "$ENV_SH" seed "$d"
  [ "$status" -ne 0 ]
  [ ! -e "$d/docs/RUNBOOK.md" ]
}

@test "research-first-run is user-invoked only" {
  # SQ13 and docs/research-skills.md §1: this skill installs packages, builds
  # wheels and executes commands, so it must never be model-triggered by a
  # description match. The one frontmatter line that keeps that true.
  grep -q '^disable-model-invocation: true$' \
    "$REPO_ROOT/skills/research-first-run/SKILL.md"
}
