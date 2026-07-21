#!/usr/bin/env bats
#
# .githooks/pre-push — blocks direct pushes to main/master. GitHub Free has no
# branch protection for private repos, so this is the local substitute: opt in
# per clone with `git config core.hooksPath .githooks`.

load helper

setup() {
  git_env
  HOOK="$REPO_ROOT/.githooks/pre-push"
}

# install_hook DIR — point DIR's git config at this repo's real hook.
install_hook() {
  git -C "$1" config core.hooksPath "$(dirname "$HOOK")"
}

@test "pre-push: blocks a direct push to main" {
  local r
  r="$(make_repo proj)"
  install_hook "$r"
  echo more >>"$r/file.txt"
  git -C "$r" add file.txt
  git -C "$r" commit -q -m "direct commit"

  run git -C "$r" push origin main
  [ "$status" -ne 0 ]
  [[ "$output" == *"blocked"* ]]
}

@test "pre-push: allows pushing a topic branch" {
  local r
  r="$(make_repo proj)"
  install_hook "$r"
  git -C "$r" checkout -q -b topic
  echo more >>"$r/file.txt"
  git -C "$r" add file.txt
  git -C "$r" commit -q -m "topic work"

  run git -C "$r" push origin topic
  [ "$status" -eq 0 ]
}

@test "pre-push: a clone without core.hooksPath set can still push main" {
  local r
  r="$(make_repo proj)"
  # deliberately not installed — the escape hatch this hook can't close
  echo more >>"$r/file.txt"
  git -C "$r" add file.txt
  git -C "$r" commit -q -m "direct commit"

  run git -C "$r" push origin main
  [ "$status" -eq 0 ]
}
