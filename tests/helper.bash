#!/usr/bin/env bash
# Shared setup for the bats suites.
#
# Everything happens under $BATS_TEST_TMPDIR, which bats creates per test and
# removes afterwards, so no test can touch the real HOME or the real ~/.claude.

REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# Redirect HOME so a test that forgets its own sandbox still lands in one.
# install.bats narrows this further to a per-test directory in its setup().
HOME="${BATS_TEST_TMPDIR:-${BATS_FILE_TMPDIR:-${BATS_RUN_TMPDIR:-$BATS_TMPDIR}}}/home"
export HOME
mkdir -p "$HOME"

# path_without CMD — echo a PATH that holds everything the current PATH holds
# except CMD, by symlinking each executable into a fresh directory. For testing
# what a tool does on a machine that simply does not have one binary — dropping
# a stub in cannot express that, since the question is what `command -v` says.
path_without() {
  local drop="$1"
  local dir="${BATS_TEST_TMPDIR:-$BATS_FILE_TMPDIR}/path-without-$drop"
  local d f b
  mkdir -p "$dir"
  for d in ${PATH//:/ }; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      [ -x "$f" ] || continue
      b="${f##*/}"
      if [ "$b" = "$drop" ]; then continue; fi
      [ -e "$dir/$b" ] || ln -s "$f" "$dir/$b"
    done
  done
  printf '%s' "$dir"
}

# git refuses to commit without an identity, and the CI runner has none.
git_env() {
  export GIT_AUTHOR_NAME="test"
  export GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="test"
  export GIT_COMMITTER_EMAIL="test@example.com"
  # Keep the test independent of the runner's own git config.
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
  export GIT_CONFIG_SYSTEM=/dev/null
  : >"$GIT_CONFIG_GLOBAL"
}

# make_repo NAME — a repo with one commit and a bare "remote" it tracks.
# Echoes the working copy path.
make_repo() {
  local name="${1:-proj}"
  local remote="$BATS_TEST_TMPDIR/$name.git"
  local work="$BATS_TEST_TMPDIR/$name"
  git init -q --bare "$remote"
  # Pin the bare remote's HEAD to main. The suite disables system/global git
  # config, so without this the built-in default (master) leaves HEAD pointing
  # at a ref we never create — and `clone_repo` then checks out nothing.
  git -C "$remote" symbolic-ref HEAD refs/heads/main
  git init -q -b main "$work"
  git -C "$work" commit -q --allow-empty -m "init"
  git -C "$work" remote add origin "$remote"
  git -C "$work" push -q -u origin main
  printf '%s' "$work"
}

# hook_files REPO MARKER HOOK... — commit and push .githooks/HOOK in REPO's main; each hook appends
# its name to MARKER. The test sets `core.hooksPath .githooks` (relative) itself, after its own git calls.
hook_files() {
  local repo="$1" marker="$2" h
  shift 2
  mkdir -p "$repo/.githooks"
  for h in "$@"; do
    printf '#!/bin/sh\necho %s >>"%s"\n' "$h" "$marker" >"$repo/.githooks/$h"
    chmod +x "$repo/.githooks/$h"
  done
  git -C "$repo" add .githooks && git -C "$repo" commit -q -m "chore: hooks" && git -C "$repo" push -q origin main
}

# A second clone of the same remote, to create divergence between two copies.
clone_repo() {
  local name="$1" as="$2"
  git clone -q "$BATS_TEST_TMPDIR/$name.git" "$BATS_TEST_TMPDIR/$as"
  printf '%s' "$BATS_TEST_TMPDIR/$as"
}

# stub_systemd_run DIR — a systemd-run in DIR that logs its arguments to
# DIR/systemd-run.log and runs the command in no scope at all, so no test makes
# a real unit. With DIR/no-systemd it fails, as without a user manager.
stub_systemd_run() {
  cat >"$1/systemd-run" <<EOF2
#!/bin/sh
[ ! -f "$1/no-systemd" ] || { echo "Failed to connect to bus" >&2; exit 1; }
echo "\$*" >>"$1/systemd-run.log"
while [ \$# -gt 0 ]; do
  case "\$1" in
    -p) shift 2 ;;
    -*) shift ;;
    *) break ;;
  esac
done
exec "\$@"
EOF2
  chmod +x "$1/systemd-run"
}

# rjob QDIR ID STATUS REPO BRANCH [KEY=VALUE...] — a job dir with a status, in the queue QDIR.
rjob() {
  local q="$1" id="$2" st="$3" repo="$4" branch="$5" l
  shift 5
  mkdir -p "$q/$id"
  {
    printf 'repo=%s\nbranch=%s\n' "$repo" "$branch"
    for l in "$@"; do echo "$l"; done
  } >"$q/$id/job"
  echo task >"$q/$id/prompt.md"
  echo "$st" >"$q/$id/status"
}

# research_fixture QDIR REPO — the question `lr` as job dirs, written by hand from the contract: a coordinator
# (done) and 4 workers. h1 turing, done, 0.81; h2 runpod, run in flight, $1.20; h3 slurm, blocked on a paste;
# h4 turing, done, 0.84, builds on h1. Spent $1.20 of $50; best 0.84 (h4); state line `needs you · paste h3 · h2 on runpod`.
research_fixture() {
  local q="$1" r="$2" w="research-lr"
  rjob "$q" 20261117-100000-proj-$w "done" "$r" research/lr "research=lr" "question=Does a wider net help & by how much?" \
    "usd=50" "workers=3" "better=higher" "deadline=2026-11-18 09:00"
  echo "done: baseline row" >"$q/20261117-100000-proj-$w/note"
  rjob "$q" 20261117-100100-proj-$w-h1 "done" "$r" research/lr/h1 "research=lr" "hid=h1" "place=turing" "idea=baseline" "builds=root"
  echo '{"metric": 0.81}' >"$q/20261117-100100-proj-$w-h1/run-result"
  echo 0 >"$q/20261117-100100-proj-$w-h1/cost"
  echo "done: row written" >"$q/20261117-100100-proj-$w-h1/note"
  rjob "$q" 20261117-100200-proj-$w-h2 gpu "$r" research/lr/h2 "research=lr" "hid=h2" "place=runpod" "idea=wider net" "builds=root"
  echo 1.20 >"$q/20261117-100200-proj-$w-h2/cost"
  echo "queued: run on runpod" >"$q/20261117-100200-proj-$w-h2/note"
  rjob "$q" 20261117-100300-proj-$w-h3 blocked "$r" research/lr/h3 "research=lr" "hid=h3" "place=slurm" "idea=lr 3e-4" "builds=root"
  printf '1. git fetch the commit\n2. sbatch runs/h3/job.sbatch\n3. print the RESULT line\n' >"$q/20261117-100300-proj-$w-h3/paste.md"
  echo "blocked: paste 3 steps on the cluster" >"$q/20261117-100300-proj-$w-h3/note"
  rjob "$q" 20261117-100400-proj-$w-h4 "done" "$r" research/lr/h4 "research=lr" "hid=h4" "place=turing" "idea=baseline + warmup" "builds=h1"
  echo '{"metric": 0.84, "n": 3}' >"$q/20261117-100400-proj-$w-h4/run-result"
  echo 0 >"$q/20261117-100400-proj-$w-h4/cost"
  echo "done: row written" >"$q/20261117-100400-proj-$w-h4/note"
}
