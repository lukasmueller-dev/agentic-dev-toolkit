# shellcheck shell=bash
#
# research-lib.sh — detections shared by the research-* skill family.
#
# Sourced, never executed. The caller is expected to run under
# `set -euo pipefail` and to have resolved its own real location first
# (script_dir cannot live here — a script needs it to *find* this file).
#
# The contracts these implement are in docs/research-skills.md; §4 fixes the
# signals and the verdict rule below, so a change here changes that file too,
# in the same PR, with the reason.
#
# Shape copied from detect_env/env_reason in bin/vibe: a verdict function and
# a reason function, both cheap, both always exiting 0 — "cannot tell" is a
# verdict (`ambiguous`), not an error, because ambiguity is the common case
# and the skill's answer to it is to ask with the evidence on screen.
#
# No network, works on a shallow checkout, bash 3.2, BSD *and* GNU userland.
#
# The `_lib` name matters: install.sh skips `skills/_*`, which is the only
# thing keeping this directory out of ~/.claude/skills.

# ---------------------------------------------------------------------------
# §4 Repo-kind detection
#
#   detect_repo_kind   [DIR]  -> research | application | ambiguous
#   repo_kind_evidence [DIR]  -> one "[kind] signal: detail" line per match
#
# Both derive from the same scan, so a verdict and its evidence can never
# disagree. The scan is cached per directory: a skill calls both.
# ---------------------------------------------------------------------------

_RK_DIR=""     # directory the cached scan describes ("" = nothing cached)
_RK_PATHS=""   # newline-separated paths, relative, "./"-prefixed
_RK_SIGNALS="" # newline-separated "kind|signal|detail"

# _rk_scan DIR — populate _RK_PATHS for DIR, unless it is already cached.
#
# One bounded walk feeds every signal. -maxdepth 3 and the prune list are what
# keep this fast on a large checkout; a research repo's giveaways all sit near
# the root. Directories are printed too, so `checkpoints/` and `k8s/` are
# matchable as paths.
#
# The list is sorted shallowest-first, then lexically, for two reasons. It
# makes evidence cite the most central file — a repo's root pyproject.toml
# rather than whichever example's requirements.txt the walk happened to reach
# first — and it makes every line reproducible, since raw find order is
# filesystem order and would differ between two machines mapping the same
# repo. A map that must diff cleanly against its own re-run cannot be built on
# an unstable scan.
#
# find's own exit status is discarded: it reports 1 for an unreadable
# subdirectory, and losing an otherwise good walk to one permission error
# would turn a full verdict into `ambiguous`.
_rk_scan() {
  local dir="$1" resolved
  resolved="$(cd -P "$dir" 2>/dev/null && pwd)" || resolved=""
  if [ -n "$resolved" ] && [ "$resolved" = "$_RK_DIR" ]; then
    return 0
  fi
  _RK_DIR="$resolved"
  _RK_PATHS=""
  _RK_SIGNALS=""
  [ -n "$resolved" ] || return 0
  _RK_PATHS="$(cd "$resolved" && {
    find . -maxdepth 3 \
      \( -name .git -o -name node_modules -o -name .venv -o -name venv \
      -o -name __pycache__ -o -name .mypy_cache -o -name .pytest_cache \
      -o -name .tox -o -name site-packages -o -name .next \) -prune \
      -o -print 2>/dev/null || true
  } | awk -F/ '{ print NF " " $0 }' | sort -k1,1n -k2 | cut -d' ' -f2-)" ||
    _RK_PATHS=""
  return 0
}

# _rk_path REGEX — the first scanned path matching REGEX (ERE), or "".
#
# grep reads the whole list rather than exiting at the first hit: a consumer
# that closes the pipe early (grep -m1, head) kills the producer with SIGPIPE,
# and under `set -o pipefail` that 141 becomes the assignment's status.
_rk_path() {
  local hits
  hits="$(printf '%s\n' "$_RK_PATHS" | grep -E "$1")" || hits=""
  printf '%s' "${hits%%$'\n'*}"
}

# _rk_content PATHRE CONTENTRE — the first scanned file whose path matches
# PATHRE and whose contents match CONTENTRE (case-insensitive), or "".
#
# Each candidate is grepped as a plain file argument, never as the tail of a
# pipeline, for the SIGPIPE reason above.
_rk_content() {
  local hits f
  hits="$(printf '%s\n' "$_RK_PATHS" | grep -E "$1")" || hits=""
  [ -n "$hits" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -f "$_RK_DIR/$f" ] || continue
    if grep -qiE "$2" "$_RK_DIR/$f" 2>/dev/null; then
      printf '%s' "$f"
      return 0
    fi
  done <<EOF
$hits
EOF
  return 0
}

# Python dependency declarations. A framework name is looked for here rather
# than in package.json on purpose: "@tensorflow/tfjs" in a web app's
# dependencies is not a deep-learning research stack, and a bare grep for
# "tensorflow" over every manifest would read it as one.
_RK_DEPFILES='(^|/)(pyproject\.toml|requirements[^/]*\.txt|setup\.py|setup\.cfg|environment\.ya?ml|Pipfile)$'
_RK_PYFILES='\.py$'

_rk_add() { _RK_SIGNALS="$_RK_SIGNALS$1|$2|$3
"; }

# _rk_signals DIR — emit one "kind|signal|detail" line per matched signal.
# Each signal counts once, per §4.
_rk_signals() {
  local hit hit2
  _rk_scan "$1"
  if [ -n "$_RK_SIGNALS" ] || [ -z "$_RK_PATHS" ]; then
    printf '%s' "$_RK_SIGNALS"
    return 0
  fi

  # -- research -------------------------------------------------------------

  # A training entry point. Anchored to a whole filename so `trainer.py`, a
  # library module, does not read as one.
  hit="$(_rk_path '(^|/)train\.(py|sh)$|(^|/)scripts/train[^/]*$')"
  if [ -n "$hit" ]; then
    _rk_add research "training entry point" "${hit#./}"
  else
    hit="$(_rk_content '(^|/)pyproject\.toml$' '^[a-z0-9_.-]*train[a-z0-9_.-]* *=')"
    if [ -n "$hit" ]; then
      _rk_add research "training entry point" "a train console script in ${hit#./}"
    fi
  fi

  # A config tree *and* a config framework. Either alone is too common: any
  # repo has yaml, and omegaconf turns up as a transitive pin.
  hit="$(_rk_path '(^|/)configs?/.*\.(ya?ml|gin|json)$')"
  if [ -n "$hit" ]; then
    hit2="$(_rk_content "$_RK_DEPFILES" 'hydra-core|gin-config|draccus|omegaconf|ml[_-]collections')"
    if [ -n "$hit2" ]; then
      _rk_add research "config tree with a config framework" \
        "${hit#./} with a framework declared in ${hit2#./}"
    fi
  fi

  # An experiment tracker.
  hit="$(_rk_content "$_RK_DEPFILES" '(^|[^a-z0-9_-])(wandb|mlflow|aim|tensorboard)([^a-z0-9_-]|$)')"
  if [ -n "$hit" ]; then
    _rk_add research "experiment tracker" "declared in ${hit#./}"
  else
    hit="$(_rk_content "$_RK_PYFILES" '^(import|from) *(wandb|mlflow|aim|tensorboard)([^a-z0-9_]|$)')"
    if [ -n "$hit" ]; then
      _rk_add research "experiment tracker" "imported in ${hit#./}"
    fi
  fi

  # A deep-learning framework.
  hit="$(_rk_content "$_RK_DEPFILES" '(^|[^a-z0-9_/-])(torch|jax|flax|tensorflow)([^a-z0-9_/-]|$)')"
  if [ -n "$hit" ]; then
    _rk_add research "deep-learning framework" "declared in ${hit#./}"
  else
    hit="$(_rk_content "$_RK_PYFILES" '^(import|from) *(torch|jax|flax|tensorflow)([^a-z0-9_]|$)')"
    if [ -n "$hit" ]; then
      _rk_add research "deep-learning framework" "imported in ${hit#./}"
    fi
  fi

  # Checkpoint / eval conventions.
  hit="$(_rk_path '(^|/)(checkpoints|ckpts)$|(^|/)eval[^/]*\.py$')"
  if [ -n "$hit" ]; then
    _rk_add research "checkpoint or eval convention" "${hit#./}"
  fi

  # -- application ----------------------------------------------------------

  # A web/UI framework in package.json. A frontend build tool counts: a repo
  # that ships a browser bundle has an application side even when its research
  # side is the bigger half — which is exactly the case the verdict rule below
  # is built to survive.
  hit="$(_rk_content '(^|/)package\.json$' \
    '"(next|nuxt|react|vue|svelte|@angular/core|astro|@remix-run/[a-z]+|solid-js|gatsby|express|fastify|koa|@nestjs/core|vite)" *:')"
  if [ -n "$hit" ]; then
    _rk_add application "web/UI framework" "declared in ${hit#./}"
  fi

  # Route definitions.
  hit="$(_rk_path '(^|/)urls\.py$|(^|/)(openapi|swagger)\.(ya?ml|json)$|(^|/)app/.*/(route|page)\.[jt]sx?$')"
  if [ -n "$hit" ]; then
    _rk_add application "route definitions" "${hit#./}"
  else
    hit="$(_rk_content '\.(py|[cm]?js|tsx?)$' \
      '@(app|blueprint|router)\.(route|get|post)|\b(app|router)\.(get|post|use)\(')"
    if [ -n "$hit" ]; then
      _rk_add application "route definitions" "${hit#./}"
    fi
  fi

  # A serving entry point.
  hit="$(_rk_content "$_RK_DEPFILES" '(^|[^a-z0-9_-])(uvicorn|gunicorn|fastapi|flask|django)([^a-z0-9_-]|$)')"
  if [ -n "$hit" ]; then
    _rk_add application "serving entry point" "declared in ${hit#./}"
  else
    hit="$(_rk_content '(^|/)Dockerfile[^/]*$' '^ *(CMD|ENTRYPOINT).*(uvicorn|gunicorn|serve|start|node |npm |flask|django)')"
    if [ -n "$hit" ]; then
      _rk_add application "serving entry point" "${hit#./} starts a server"
    fi
  fi

  # Deploy config.
  hit="$(_rk_path '(^|/)(k8s|kubernetes|helm|charts)$|(^|/)(fly\.toml|vercel\.json|Procfile|netlify\.toml|render\.yaml|wrangler\.(toml|jsonc?))$')"
  if [ -n "$hit" ]; then
    _rk_add application "deploy config" "${hit#./}"
  fi

  printf '%s' "$_RK_SIGNALS"
  return 0
}

# detect_repo_kind [DIR] -> research | application | ambiguous
#
# §4's rule: research when research >= 2 and application <= 1; application when
# application >= 2 and research <= 1; otherwise ambiguous, which means *ask*.
# A research repo with a serving path is normal, so one application signal must
# not flip the verdict — and 1-vs-1 (or 0-vs-0) is genuinely unknown rather
# than a coin toss.
detect_repo_kind() {
  local sig r a
  sig="$(_rk_signals "${1:-.}")"
  r="$(printf '%s\n' "$sig" | grep -c '^research|')" || r=0
  a="$(printf '%s\n' "$sig" | grep -c '^application|')" || a=0
  if [ "$r" -ge 2 ] && [ "$a" -le 1 ]; then
    echo research
  elif [ "$a" -ge 2 ] && [ "$r" -le 1 ]; then
    echo application
  else
    echo ambiguous
  fi
  return 0
}

# repo_kind_evidence [DIR] — one line per matched signal, both sides shown.
#
# The kind is prefixed rather than left implicit: an ambiguous verdict is
# resolved by a human reading these lines, and "which side is this?" is the
# first thing they need.
repo_kind_evidence() {
  local sig kind name detail
  sig="$(_rk_signals "${1:-.}")"
  if [ -z "$sig" ]; then
    echo "no research or application signal matched"
    return 0
  fi
  while IFS='|' read -r kind name detail; do
    [ -n "$kind" ] || continue
    printf '[%s] %s: %s\n' "$kind" "$name" "$detail"
  done <<EOF
$sig
EOF
  return 0
}

# ---------------------------------------------------------------------------
# §5 Execution-context detection
#
#   detect_exec_context    -> cluster | workstation | ambiguous
#   exec_context_evidence  -> one "signal: detail" line per probe
#
# Detected per session, never a fixed label: the same machine is a workstation
# when you sit at it and a cluster login node when you reach it over SSH.
# Nothing here reads or writes a configured role — the caller prints the
# verdict and its reason before acting, because a silent guess here burns an
# allocation.
#
# Takes no argument: this describes the machine, not a directory.
# ---------------------------------------------------------------------------

# _ec_gpu — echo the GPU state and return 0 only when a device is actually
# usable:
#   none     nvidia-smi is not installed
#   broken   installed but failing — no driver, no permission, or a container
#            without device passthrough. Counts as *no GPU visible* per §5,
#            and says so, because that state looks like a GPU box and is not.
#   <n>      that many devices listed
_ec_gpu() {
  command -v nvidia-smi >/dev/null 2>&1 || {
    echo none
    return 1
  }
  local out n
  out="$(nvidia-smi -L 2>/dev/null)" || {
    echo broken
    return 1
  }
  # grep -c reads all of its input, so nothing upstream dies of SIGPIPE; a
  # zero count exits 1, which the fallback absorbs.
  n="$(printf '%s\n' "$out" | grep -c '^GPU [0-9]')" || n=0
  [ "$n" -gt 0 ] || {
    echo broken
    return 1
  }
  echo "$n"
  return 0
}

# _ec_scheduler — echo the first scheduler submitter on PATH, or "" .
_ec_scheduler() {
  local c
  for c in sbatch srun salloc qsub bsub; do
    if command -v "$c" >/dev/null 2>&1; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

# detect_exec_context -> cluster | workstation | ambiguous
#
# The §5 table, in order. The ambiguous row is the one that matters: a
# scheduler *and* a visible GPU is either an interactive allocation or a
# workstation with cluster access, and those want opposite things. Ambiguity
# is the common case here, so the ask is a normal path, not an error path.
detect_exec_context() {
  if [ -n "${SLURM_JOB_ID:-}" ] || [ -n "${SLURM_JOB_NODELIST:-}" ]; then
    echo cluster
    return 0
  fi
  local sched="" gpus=""
  sched="$(_ec_scheduler)" || sched=""
  gpus="$(_ec_gpu)" || gpus=""
  if [ -n "$sched" ]; then
    # A GPU count only lands in $gpus when _ec_gpu succeeded; "none" and
    # "broken" both leave it empty, which is the "nothing GPU-shaped runs
    # here" half of the table.
    if [ -n "$gpus" ]; then
      echo ambiguous
    else
      echo cluster
    fi
  else
    echo workstation
  fi
  return 0
}

# exec_context_evidence — one line per probe, whether or not it matched.
#
# Unlike repo_kind_evidence, every probe reports: "no scheduler on PATH" is
# itself the evidence for `workstation`, and a reader resolving an ambiguous
# verdict needs the negatives as much as the positives.
exec_context_evidence() {
  local sched gpus
  if [ -n "${SLURM_JOB_ID:-}" ]; then
    echo "scheduler environment: SLURM_JOB_ID=${SLURM_JOB_ID} — inside an allocation"
  elif [ -n "${SLURM_JOB_NODELIST:-}" ]; then
    echo "scheduler environment: SLURM_JOB_NODELIST=${SLURM_JOB_NODELIST} — inside an allocation"
  else
    echo "scheduler environment: no SLURM_JOB_ID or SLURM_JOB_NODELIST set"
  fi

  sched="$(_ec_scheduler)" || sched=""
  if [ -n "$sched" ]; then
    echo "scheduler on PATH: $sched"
  else
    echo "scheduler on PATH: none of sbatch, srun, salloc, qsub, bsub"
  fi

  gpus="$(_ec_gpu)" || true
  case "$gpus" in
    none) echo "GPU: nvidia-smi not installed — no GPU visible" ;;
    broken) echo "GPU: nvidia-smi present but listed no device — no driver, no permission, or no device passthrough; counts as no GPU visible" ;;
    *) echo "GPU: nvidia-smi lists $gpus device(s)" ;;
  esac
  return 0
}
