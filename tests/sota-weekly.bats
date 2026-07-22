#!/usr/bin/env bats
#
# The cron wrapper for the weekly SOTA digest. Every test runs a *copy* of the
# script inside a throwaway repo, because the script derives the repo root from
# its own location — running the real one would launch a real loop against the
# real checkout.

load helper

setup() {
  git_env
  REPO="$(make_repo sota)"
  SKILL="$REPO/.claude/skills/sota-digest"
  mkdir -p "$SKILL"
  cp "$REPO_ROOT/.claude/skills/sota-digest/sota-weekly.sh" "$SKILL/"
  cp "$REPO_ROOT/.claude/skills/sota-digest/loop-brief.md" "$SKILL/"
  chmod +x "$SKILL/sota-weekly.sh"
  SCRIPT="$SKILL/sota-weekly.sh"

  # A stub vibe that records its arguments instead of creating anything.
  STUB="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB"
  VIBE_LOG="$BATS_TEST_TMPDIR/vibe-calls"
  cat >"$STUB/vibe" <<STUBEOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$VIBE_LOG"
exit 0
STUBEOF
  chmod +x "$STUB/vibe"

  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
}

run_script() {
  PATH="$STUB:$PATH" run "$SCRIPT" "$@"
}

@test "sota-weekly: rejects a week that is not YYYY-Www" {
  run_script 2026-30
  [ "$status" -eq 1 ]
  [[ "$output" == *"bad week"* ]]
  [ ! -e "$XDG_STATE_HOME/sota-digest" ]
}

@test "sota-weekly: defaults to the current ISO week" {
  local week
  week="$(date -u +%G-W%V)"
  run_script
  [ "$status" -eq 0 ]
  [ -f "$XDG_STATE_HOME/sota-digest/$week.log" ]
  grep -q "sota $week" "$VIBE_LOG"
}

@test "sota-weekly: launches one bounded loop that ends in a PR" {
  run_script 2026-W29
  [ "$status" -eq 0 ]
  # The digest file is the stop check, --pr is what makes the run reviewable,
  # and the brief is what points the agent at the skill. Losing any one of the
  # three turns the run into something that finishes without producing a digest.
  grep -q -- "--until test -f docs/sota/2026-W29.md" "$VIBE_LOG"
  grep -q -- "--pr" "$VIBE_LOG"
  grep -q -- "--no-attach" "$VIBE_LOG"
  # Matched by suffix, not against $SKILL: the script resolves its own location
  # with `cd -P`, and on macOS that turns the test's /var/folders/… path into
  # its /private/var/folders/… real path, so the two strings never compare equal.
  grep -qE -- "--prompt /.*/sota-digest/loop-brief\.md" "$VIBE_LOG"
}

@test "sota-weekly: writes its own log instead of mailing cron output" {
  run_script 2026-W29
  [ "$status" -eq 0 ]
  # Nothing on the terminal: cron mails whatever a job prints, and a weekly
  # mail saying "starting" is noise that trains you to ignore the real one.
  [ -z "$output" ]
  grep -q "starting SOTA digest run for 2026-W29" \
    "$XDG_STATE_HOME/sota-digest/2026-W29.log"
}

@test "sota-weekly: reports a missing vibe to the log rather than dying mute" {
  # A deliberately minimal PATH: the developer's own ~/bin holds a real vibe,
  # and inheriting it here would launch a real loop against a real checkout.
  PATH="/usr/bin:/bin" run "$SCRIPT" 2026-W29
  [ "$status" -eq 1 ]
  grep -q "vibe is not on PATH" "$XDG_STATE_HOME/sota-digest/2026-W29.log"
}

@test "sota-weekly: refuses to launch without the loop brief" {
  rm "$SKILL/loop-brief.md"
  run_script 2026-W29
  [ "$status" -eq 1 ]
  grep -q "no loop brief" "$XDG_STATE_HOME/sota-digest/2026-W29.log"
  [ ! -f "$VIBE_LOG" ]
}

@test "sota-weekly: refuses to run outside a git checkout" {
  mkdir -p "$BATS_TEST_TMPDIR/loose"
  cp "$SCRIPT" "$BATS_TEST_TMPDIR/loose/"
  PATH="$STUB:$PATH" run "$BATS_TEST_TMPDIR/loose/sota-weekly.sh" 2026-W29
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a git checkout"* ]]
}
