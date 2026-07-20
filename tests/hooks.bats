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
# skill-lint-on-edit.sh
#
# It shells out to `skill-lint`, so the tests put this repo's bin/ on PATH.
# ---------------------------------------------------------------------------
sl_env() {
  PATH="$REPO_ROOT/bin:$PATH"
  export PATH
}

# a skill under <root>/skills/<name> with the given name field.
mk_edit_skill() {
  local root="$1" name="$2" namefield="$3"
  mkdir -p "$root/skills/$name"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n# body\n' "$namefield" \
    "Analyzes the thing and reports findings; use it when the user asks to check the thing." \
    >"$root/skills/$name/SKILL.md"
}

@test "on-edit: no-ops when jq is unavailable" {
  run env PATH= /bin/bash "$HOOKS/skill-lint-on-edit.sh" </dev/null
  [ "$status" -eq 0 ]
}

@test "on-edit: no-ops when skill-lint is not on PATH" {
  # jq present, skill-lint absent: a minimal PATH with jq but not bin/.
  local jqdir="$BATS_TEST_TMPDIR/jqonly"
  mkdir -p "$jqdir"
  ln -sf "$(command -v jq)" "$jqdir/jq"
  ln -sf "$(command -v bash)" "$jqdir/bash"
  run env PATH="$jqdir" bash -c "echo '{\"tool_input\":{\"file_path\":\"/x/skills/a/SKILL.md\"}}' | '$HOOKS/skill-lint-on-edit.sh'"
  [ "$status" -eq 0 ]
}

@test "on-edit: silent on a path that is not inside a skill" {
  sl_env
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"$BATS_TEST_TMPDIR/README.md\"}}' | '$HOOKS/skill-lint-on-edit.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "on-edit: silent when the touched skill is clean" {
  sl_env
  mk_edit_skill "$BATS_TEST_TMPDIR" good good
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"$BATS_TEST_TMPDIR/skills/good/SKILL.md\"}}' | '$HOOKS/skill-lint-on-edit.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "on-edit: surfaces findings on a bad skill and exits 2" {
  sl_env
  mk_edit_skill "$BATS_TEST_TMPDIR" bad Wrong
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"$BATS_TEST_TMPDIR/skills/bad/SKILL.md\"}}' | '$HOOKS/skill-lint-on-edit.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[SQ3]"* ]]
}

@test "on-edit: triggers when a sibling file in the skill is edited" {
  sl_env
  mk_edit_skill "$BATS_TEST_TMPDIR" bad Wrong
  mkdir -p "$BATS_TEST_TMPDIR/skills/bad/scripts"
  printf '#!/usr/bin/env bash\n' >"$BATS_TEST_TMPDIR/skills/bad/scripts/run.sh"
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"$BATS_TEST_TMPDIR/skills/bad/scripts/run.sh\"}}' | '$HOOKS/skill-lint-on-edit.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[SQ3]"* ]]
}

@test "on-edit: resolves a relative file_path against cwd" {
  sl_env
  mk_edit_skill "$BATS_TEST_TMPDIR" bad Wrong
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"skills/bad/SKILL.md\"},\"cwd\":\"$BATS_TEST_TMPDIR\"}' | '$HOOKS/skill-lint-on-edit.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[SQ3]"* ]]
}

@test "on-edit: never exits with a code other than 0 or 2" {
  sl_env
  # Malformed stdin must not crash it.
  run bash -c "echo 'not json' | '$HOOKS/skill-lint-on-edit.sh' 2>&1"
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
