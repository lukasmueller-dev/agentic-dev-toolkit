#!/usr/bin/env bats
#
# skills/worktree-cleanup/cleanup.sh — rating linked worktrees and removing
# only the ones whose work has landed. Everything runs in throwaway repos
# under $BATS_TEST_TMPDIR.

load helper

# A gh on PATH that logs its arguments to $GH_LOG and answers `pr list` with
# $GH_OIDS (one head sha per line) and, when the query asks for commits, $GH_COMMITS;
# $GH_FAIL makes it exit 1. No test reaches the real gh.
setup() {
  git_env
  mkdir -p "$BATS_TEST_TMPDIR/stubs"
  cat >"$BATS_TEST_TMPDIR/stubs/gh" <<'EOF2'
#!/bin/sh
echo "$*" >>"$GH_LOG"
[ -z "${GH_FAIL:-}" ] || exit 1
[ -z "${GH_OIDS:-}" ] || printf '%s\n' "$GH_OIDS"
[ -z "${GH_COMMITS:-}" ] || case "$*" in *commits*) printf '%s\n' "$GH_COMMITS" ;; esac
EOF2
  chmod +x "$BATS_TEST_TMPDIR/stubs/gh"
  export GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  unset GH_OIDS GH_COMMITS GH_FAIL
}

CLEANUP="$REPO_ROOT/skills/worktree-cleanup/cleanup.sh"

# add_wt REPO NAME — a worktree at REPO/.claude/worktrees/NAME on branch NAME.
add_wt() {
  git -C "$1" worktree add -q -b "$2" "$1/.claude/worktrees/$2"
  printf '%s' "$1/.claude/worktrees/$2"
}

# state_of PATH — the state the scan reports for PATH. git prints physical
# paths (/private/var/… on macOS), so resolve the parent; PATH may be gone.
state_of() {
  local p
  p="$(cd -P "$(dirname "$1")" && pwd)/$(basename "$1")"
  bash "$CLEANUP" scan | awk -F'\t' -v p="$p" '$2 == p { print $1 }'
}

@test "scan: skips the main checkout and rates a clean branch on main as merged" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" done-task)"
  cd "$r"
  run bash "$CLEANUP" scan
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c "^merged	")" -eq 1 ]
  run grep -q "	$r	" <<<"$output"
  [ "$status" -ne 0 ]
  [ "$(state_of "$w")" = merged ]
}

@test "scan: commits not on main are unpushed, changes are dirty" {
  local r a b
  r="$(make_repo proj)"
  a="$(add_wt "$r" ahead)"
  git -C "$a" commit -q --allow-empty -m "work"
  b="$(add_wt "$r" edited)"
  echo x >"$b/new.txt"
  cd "$r"
  [ "$(state_of "$a")" = unpushed ]
  [ "$(state_of "$b")" = dirty ]
}

# squash_merge REPO WT BRANCH — commit a file on BRANCH in WT, push it, squash
# it into main, then delete the remote branch, as a merged PR does.
squash_merge() {
  echo work >"$2/work.txt"
  git -C "$2" add work.txt
  git -C "$2" commit -q -m "work"
  git -C "$2" push -q -u origin "$3"
  git -C "$1" merge -q --squash "$3"
  git -C "$1" commit -q -m "squash $3"
  git -C "$1" push -q origin main
  git -C "$1" push -q origin --delete "$3"
}

@test "scan: a squash-merged branch with a deleted upstream and a merged PR is merged" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" squashed)"
  squash_merge "$r" "$w" squashed
  GH_OIDS="$(git -C "$w" rev-parse HEAD)"
  export GH_OIDS
  cd "$r"
  [ "$(state_of "$w")" = merged ]
  grep -qF -- 'pr list --head squashed --state merged --json headRefOid' "$GH_LOG"
}

@test "scan: a deleted upstream without a merged PR is unpushed, also when gh fails" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" abandoned)"
  git -C "$w" commit -q --allow-empty -m "work"
  git -C "$w" push -q -u origin abandoned
  git -C "$r" push -q origin --delete abandoned
  cd "$r"
  [ "$(state_of "$w")" = unpushed ]
  GH_FAIL=1
  export GH_FAIL
  [ "$(state_of "$w")" = unpushed ]
}

@test "scan: a deleted upstream is unpushed when the merged PR lacks the local HEAD" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" extra)"
  git -C "$w" commit -q --allow-empty -m "pushed"
  git -C "$w" push -q -u origin extra
  GH_OIDS="$(git -C "$w" rev-parse HEAD)"
  export GH_OIDS
  git -C "$w" commit -q --allow-empty -m "after the PR"
  git -C "$r" push -q origin --delete extra
  cd "$r"
  [ "$(state_of "$w")" = unpushed ]
}

@test "scan: a deleted upstream is merged when the PR head moved on to a commit this clone lacks" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" moved)"
  git -C "$w" commit -q --allow-empty -m "pushed"
  git -C "$w" push -q -u origin moved
  GH_COMMITS="$(git -C "$w" rev-parse HEAD)"
  GH_OIDS="$(printf '%040d' 7)"
  export GH_COMMITS GH_OIDS
  git -C "$r" push -q origin --delete moved
  cd "$r"
  [ "$(state_of "$w")" = merged ]
  grep -qF -- '--limit 100' "$GH_LOG"
}

# ignore_dirs REPO — commit a .gitignore before any worktree exists.
ignore_dirs() {
  printf '%s\n' 'runs/' '*.ckpt' '.venv/' 'node_modules/' '__pycache__/' '.claude/settings.local.json' \
    '.DS_Store' '*.swp' '.vscode/' '.tox/' '*.egg-info/' 'target/' 'dist/' 'build/' >"$1/.gitignore"
  git -C "$1" add .gitignore
  git -C "$1" commit -q -m "ignore"
  git -C "$1" push -q origin main
}

@test "scan: a clean worktree with an ignored runs/x.ckpt is ignored, and remove keeps it" {
  local r w
  r="$(make_repo proj)"
  ignore_dirs "$r"
  w="$(add_wt "$r" trained)"
  mkdir "$w/runs"
  echo weights >"$w/runs/x.ckpt"
  cd "$r"
  [ "$(state_of "$w")" = ignored ]
  run bash "$CLEANUP" scan
  [[ "$output" == *"runs/"* ]] || false
  run bash "$CLEANUP" remove "$w"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ignored"* ]] || false
  [ -f "$w/runs/x.ckpt" ]
  git -C "$r" show-ref --verify --quiet refs/heads/trained
}

@test "scan: regenerable ignored paths do not keep a worktree; the reason names 3 other paths" {
  local r w i
  r="$(make_repo proj)"
  ignore_dirs "$r"
  w="$(add_wt "$r" caches)"
  mkdir -p "$w/.venv/bin" "$w/node_modules/x" "$w/src/__pycache__"
  touch "$w/.venv/bin/python" "$w/node_modules/x/i.js" "$w/src/__pycache__/a.pyc"
  mkdir -p "$w/.claude"
  echo '{}' >"$w/.claude/settings.local.json"
  mkdir -p "$w/.vscode" "$w/target/debug" "$w/dist" "$w/build" "$w/.tox" "$w/pkg.egg-info" "$w/docs"
  touch "$w/.DS_Store" "$w/docs/.DS_Store" "$w/a.swp" "$w/.vscode/settings.json" "$w/target/debug/a" \
    "$w/dist/b.js" "$w/build/c" "$w/.tox/d" "$w/pkg.egg-info/PKG-INFO"
  cd "$r"
  [ "$(state_of "$w")" = merged ]
  for i in 1 2 3 4 5; do echo w >"$w/m$i.ckpt"; done
  [ "$(state_of "$w")" = ignored ]
  run bash "$CLEANUP" scan
  [[ "$output" == *"m1.ckpt, m2.ckpt, m3.ckpt (+2 more)"* ]] || false
  [[ "$output" != *"m4.ckpt"* ]] || false
  [[ "$output" != *"venv"* ]] || false
}

@test "scan: dist/ below the top level is not a cache" {
  local r w
  r="$(make_repo proj)"
  ignore_dirs "$r"
  w="$(add_wt "$r" nested)"
  mkdir -p "$w/exp/dist"
  echo weights >"$w/exp/dist/w.pt"
  cd "$r"
  [ "$(state_of "$w")" = ignored ]
  run bash "$CLEANUP" scan
  [[ "$output" == *"exp/dist/w.pt"* ]] || false
}

@test "scan: locked and current worktrees are never removable" {
  local r l c
  r="$(make_repo proj)"
  l="$(add_wt "$r" held)"
  git -C "$r" worktree lock "$l"
  c="$(add_wt "$r" here)"
  cd "$c"
  [ "$(state_of "$l")" = locked ]
  [ "$(state_of "$c")" = current ]
}

@test "remove: deletes a merged worktree and its branch" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" done-task)"
  cd "$r"
  run bash "$CLEANUP" remove "$w"
  [ "$status" -eq 0 ]
  [ ! -d "$w" ]
  run git -C "$r" show-ref --verify --quiet refs/heads/done-task
  [ "$status" -ne 0 ]
}

@test "remove: rates each worktree once, so N paths cost N gh calls" {
  local r w n oids="" paths=()
  r="$(make_repo proj)"
  for n in a b c; do
    w="$(add_wt "$r" "t-$n")"
    echo "$n" >"$w/$n.txt"
    git -C "$w" add "$n.txt" && git -C "$w" commit -q -m "work $n"
    git -C "$w" push -q -u origin "t-$n"
    git -C "$r" merge -q --squash "t-$n" && git -C "$r" commit -q -m "squash $n"
    git -C "$r" push -q origin main
    git -C "$r" push -q origin --delete "t-$n"
    oids+="$(git -C "$w" rev-parse HEAD)"$'\n'
    paths+=("$w")
  done
  GH_OIDS="$oids"
  export GH_OIDS
  cd "$r"
  run bash "$CLEANUP" remove "${paths[@]}"
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$GH_LOG" | tr -d ' ')" -eq 3 ]
  for w in "${paths[@]}"; do [ ! -d "$w" ]; done
}

@test "remove: a relative path is resolved against the caller's directory, not the repo's" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" done-task)"
  cd "$BATS_TEST_TMPDIR"
  run bash "$CLEANUP" remove proj/.claude/worktrees/done-task
  [ "$status" -eq 0 ]
  [ ! -d "$w" ]
}

@test "remove: refuses unpushed work and leaves it intact" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" ahead)"
  git -C "$w" commit -q --allow-empty -m "work"
  cd "$r"
  run bash "$CLEANUP" remove "$w"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unpushed"* ]] || false
  [ -d "$w" ]
  git -C "$r" show-ref --verify --quiet refs/heads/ahead
}

@test "remove: prunes the record of a worktree whose directory is gone" {
  local r w
  r="$(make_repo proj)"
  w="$(add_wt "$r" vanished)"
  rm -rf "$w"
  cd "$r"
  [ "$(state_of "$w")" = prunable ]
  run bash "$CLEANUP" remove "$w"
  [ "$status" -eq 0 ]
  run git -C "$r" worktree list
  [[ "$output" != *"vanished"* ]] || false
}
