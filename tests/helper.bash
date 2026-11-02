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
