#!/usr/bin/env bats
#
# claude/hooks/* — these run inside a live editing session, so the contract
# they must never break is: exit 0 and stay quiet when they cannot do their job.

load helper

setup() {
  git_env
  HOOKS="$REPO_ROOT/claude/hooks"
}

# ---------------------------------------------------------------------------
# session-end-handoff.sh
# ---------------------------------------------------------------------------
@test "handoff: silent when there is no HANDOFF.md" {
  local r
  r="$(make_repo proj)"
  run bash -c "echo '{\"cwd\":\"$r\"}' | '$HOOKS/session-end-handoff.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "handoff: silent when the handoff is newer than the work" {
  local r
  r="$(make_repo proj)"
  echo "code" >"$r/app.txt"
  sleep 1
  echo "handoff" >"$r/HANDOFF.md"
  run bash -c "echo '{\"cwd\":\"$r\"}' | '$HOOKS/session-end-handoff.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "handoff: warns when tracked work is newer than the handoff" {
  local r
  r="$(make_repo proj)"
  echo "code" >"$r/app.txt"
  git -C "$r" add -A
  git -C "$r" commit -q -m "add app"
  echo "handoff" >"$r/HANDOFF.md"
  sleep 1
  echo "more code" >>"$r/app.txt"

  run bash -c "echo '{\"cwd\":\"$r\"}' | '$HOOKS/session-end-handoff.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"HANDOFF.md"* ]]
  [[ "$output" == *"stale"* ]]
}

@test "handoff: editing only the handoff does not make it stale" {
  local r
  r="$(make_repo proj)"
  echo "code" >"$r/app.txt"
  git -C "$r" add -A
  git -C "$r" commit -q -m "add app"
  sleep 1
  echo "handoff" >"$r/HANDOFF.md"
  sleep 1
  echo "more handoff" >>"$r/HANDOFF.md"

  run bash -c "echo '{\"cwd\":\"$r\"}' | '$HOOKS/session-end-handoff.sh' 2>&1"
  [ "$status" -eq 0 ]
}

@test "handoff: silent outside a git repository" {
  run bash -c "echo '{\"cwd\":\"$BATS_TEST_TMPDIR\"}' | '$HOOKS/session-end-handoff.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "handoff: survives malformed stdin without complaining" {
  run bash -c "echo 'not json at all' | '$HOOKS/session-end-handoff.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "handoff: no-ops when jq is unavailable" {
  run env PATH= /bin/bash "$HOOKS/session-end-handoff.sh" </dev/null
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# notify-ntfy.sh
# ---------------------------------------------------------------------------
@test "ntfy: does nothing when no topic is configured" {
  run env -u VIBE_NTFY_TOPIC VIBE_CONFIG_FILE=/nonexistent \
    bash -c "echo '{\"cwd\":\"$PWD\"}' | '$HOOKS/notify-ntfy.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ntfy: reads the topic from the config file" {
  local cfg="$BATS_TEST_TMPDIR/config"
  printf 'VIBE_NTFY_TOPIC=from-config-topic\n' >"$cfg"
  # No network in CI: a stub curl proves the topic reached the request.
  local stub="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$stub"
  cat >"$stub/curl" <<'EOF'
#!/bin/sh
echo "CURL_ARGS: $*" >>"$STUB_LOG"
EOF
  chmod +x "$stub/curl"
  local log="$BATS_TEST_TMPDIR/curl.log"

  run env -u VIBE_NTFY_TOPIC VIBE_CONFIG_FILE="$cfg" PATH="$stub:$PATH" STUB_LOG="$log" \
    bash -c "echo '{\"cwd\":\"$PWD\",\"notification_type\":\"idle_prompt\"}' | '$HOOKS/notify-ntfy.sh'"
  [ "$status" -eq 0 ]
  grep -q 'ntfy.sh/from-config-topic' "$log"
}

@test "ntfy: the environment variable beats the config file" {
  local cfg="$BATS_TEST_TMPDIR/config"
  printf 'VIBE_NTFY_TOPIC=from-config-topic\n' >"$cfg"
  local stub="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$stub"
  cat >"$stub/curl" <<'EOF'
#!/bin/sh
echo "CURL_ARGS: $*" >>"$STUB_LOG"
EOF
  chmod +x "$stub/curl"
  local log="$BATS_TEST_TMPDIR/curl.log"

  run env VIBE_NTFY_TOPIC=from-env-topic VIBE_CONFIG_FILE="$cfg" PATH="$stub:$PATH" STUB_LOG="$log" \
    bash -c "echo '{\"cwd\":\"$PWD\"}' | '$HOOKS/notify-ntfy.sh'"
  [ "$status" -eq 0 ]
  grep -q 'ntfy.sh/from-env-topic' "$log"
  run grep -q 'from-config-topic' "$log"
  [ "$status" -ne 0 ]
}

@test "ntfy: a failing push never fails the hook" {
  local stub="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$stub"
  printf '#!/bin/sh\nexit 7\n' >"$stub/curl"
  chmod +x "$stub/curl"
  run env VIBE_NTFY_TOPIC=t PATH="$stub:$PATH" \
    bash -c "echo '{}' | '$HOOKS/notify-ntfy.sh'"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# statusline.sh
# ---------------------------------------------------------------------------
@test "statusline: prints repo and branch in a plain checkout" {
  local r
  r="$(make_repo proj)"
  run bash -c "echo '{\"workspace\":{\"current_dir\":\"$r\"}}' | '$HOOKS/statusline.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"proj"* ]]
  [[ "$output" == *"main"* ]]
}

@test "statusline: reports the main repo name from inside a worktree" {
  local r
  r="$(make_repo proj)"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/feat-x"
  mkdir -p "$(dirname "$wt")"
  git -C "$r" worktree add -q -b feat-x "$wt"

  run env VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    bash -c "echo '{\"workspace\":{\"current_dir\":\"$wt\"}}' | '$HOOKS/statusline.sh'"
  [ "$status" -eq 0 ]
  # the repo, not the task directory
  [[ "$output" == *"proj"* ]]
  [[ "$output" == *"feat-x"* ]]
}

@test "statusline: shows the task only when it differs from the branch" {
  local r
  r="$(make_repo proj)"
  local wt="$BATS_TEST_TMPDIR/worktrees/proj/feat-x"
  mkdir -p "$(dirname "$wt")"
  git -C "$r" worktree add -q -b feat-x "$wt"
  git -C "$wt" checkout -q -b hotfix

  run env VIBE_WORKTREE_ROOT="$BATS_TEST_TMPDIR/worktrees" \
    bash -c "echo '{\"workspace\":{\"current_dir\":\"$wt\"}}' | '$HOOKS/statusline.sh'"
  [[ "$output" == *"hotfix"* ]]
  [[ "$output" == *"feat-x"* ]]
}

@test "statusline: never errors on empty stdin" {
  run bash -c "echo '' | '$HOOKS/statusline.sh'"
  [ "$status" -eq 0 ]
}
