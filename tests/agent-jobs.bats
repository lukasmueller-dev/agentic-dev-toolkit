#!/usr/bin/env bats
#
# vibe job — recurring jobs: the catalogue, a repo's opt-in files, the due
# rule, the dispatcher that writes them onto a night, and the runner's state
# updates. Stubs as in night-shift.bats; `tmux has-session` says a night runs
# while $STUBS/night-runs exists.

load helper

VIBE="$REPO_ROOT/bin/vibe"

setup() {
  git_env
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"
  cat >"$STUBS/claude" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$STUBS/claude.log"
prompt="\$(cat)"
mode="\$(printf '%s\n' "\$prompt" | sed -n 's/^MODE=//p' | head -n 1)"
case "\$mode" in
  ok)
    echo work >work.txt && git add work.txt && git commit -q -m "feat: work"
    printf 'job(health): tidy\n\n**Changed:** work.txt added.\n' >"\$NIGHT_SHIFT_JOB_DIR/pr.md"
    echo "done: work.txt added" >"\$NIGHT_SHIFT_JOB_DIR/result"
    ;;
  crash) exit 3 ;;
  sleep) sleep 30 ;;
esac
EOF
  cat >"$STUBS/gh" <<EOF
#!/bin/sh
echo "\$*" >>"$STUBS/gh.log"
case "\$1 \$2 \$3" in
  "pr create "*) echo "https://example.com/pull/1" ;;
  "pr list --label") [ ! -f "$STUBS/cap" ] || cat "$STUBS/cap" ;;
esac
EOF
  # shellcheck disable=SC2016  # the stub's own $@ and $3
  printf '#!/bin/sh\necho "$@" >>"%s/tmux.log"\nif [ "$3" = has-session ]; then [ -f "%s/night-runs" ]; fi\n' "$STUBS" "$STUBS" >"$STUBS/tmux"
  chmod +x "$STUBS/claude" "$STUBS/gh" "$STUBS/tmux"
  PATH="$STUBS:$PATH"
  export VIBE_TOOLKIT="$BATS_TEST_TMPDIR/no-toolkit" VIBE_NIGHT_POLL=0.2
  export GPU_QUEUE_DIR="$BATS_TEST_TMPDIR/gpu-queue" GPUQ_POLL=0.1
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  export AGENT_JOBS_CATALOGUE="$BATS_TEST_TMPDIR/catalogue"
  mkdir -p "$AGENT_JOBS_CATALOGUE" "$XDG_CONFIG_HOME/night-shift"
  printf -- '---\nschedule: weekly\noutput: pr\ntimeout: 2h\n---\n\nCheck the code.\nMODE=ok\n' >"$AGENT_JOBS_CATALOGUE/health.md"
  printf -- '---\nschedule: daily\n---\n\nMODE=crash\n' >"$AGENT_JOBS_CATALOGUE/crashy.md"
  printf -- '---\nschedule: daily\ntimeout: 2s\n---\n\nMODE=sleep\n' >"$AGENT_JOBS_CATALOGUE/slow.md"
  TODAY="$(LC_ALL=C date +%a | tr '[:upper:]' '[:lower:]')"
  NIGHTS="$XDG_STATE_HOME/night-shift"
}

# optin REPO JOB [FRONTMATTER] [BODY] — the repo's .agent-jobs file.
optin() {
  mkdir -p "$1/.agent-jobs"
  printf -- '---\n%b---\n\n%s\n' "${3:-}" "${4:-}" >"$1/.agent-jobs/$2.md"
}
# state REPO JOB FILE VALUE — a job's state file.
state() {
  mkdir -p "$XDG_STATE_HOME/agent-jobs/$(basename "$1")/$2"
  echo "$4" >"$XDG_STATE_HOME/agent-jobs/$(basename "$1")/$2/$3"
}
soon() { date -d '+3 hours' +%H:%M 2>/dev/null || date -v+3H +%H:%M; }
# jobdir ID — the job dir ID under the dispatcher's night.
jobdir() { echo "$NIGHTS"/*-jobs/jobs/"$1"; }

@test "job list: catalogue + repo file, repo-only jobs, invalid files; repos from the config" {
  local r
  r="$(make_repo proj)"
  optin "$r" health "day: $TODAY\n"
  optin "$r" custom "schedule: monthly\n" "Do the custom thing."
  optin "$r" nosched "" "Body without a schedule."
  optin "$r" nobody "schedule: daily\n"
  echo "$r" >"$XDG_CONFIG_HOME/night-shift/repos"
  state "$r" custom last-run "$(date +%s)"
  run "$VIBE" job list
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"REPO"*"JOB"*"SCHEDULE"* ]] || false
  [[ "$output" == *"proj"*"health"*"weekly"*"$TODAY"*"never"*"due"* ]] || false
  [[ "$output" == *"custom"*"monthly"*"-"*"$(date +%F)"*"not due"* ]] || false
  [[ "$output" == *"nosched"*"invalid: no schedule"* ]] || false
  [[ "$output" == *"nobody"*"invalid: not in the catalogue, and the repo file has no instructions"* ]] || false
  run "$VIBE" job list "$BATS_TEST_TMPDIR/nowhere"
  [[ "$output" == *"no directory"* ]] || false
}

@test "job due --dry: the due rule — period, day, two failures stop a job" {
  local r
  r="$(make_repo proj)"
  optin "$r" health
  optin "$r" crashy
  run "$VIBE" job due --claude --dry "$r"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would queue: $r health"* ]] || false
  [[ "$output" == *"would queue: $r crashy"* ]] || false
  state "$r" health last-run "$(($(date +%s) - 5 * 86400))"
  state "$r" crashy fails 2
  run "$VIBE" job due --claude --dry "$r"
  [[ "$output" == *"nothing to queue"*"stopped: $r crashy (2 failures)"* ]] || false
  [[ "$output" != *"would queue"* ]] || false
  state "$r" health last-run "$(($(date +%s) - 7 * 86400))"
  optin "$r" health "day: $TODAY\n"
  run "$VIBE" job due --claude --dry "$r"
  [[ "$output" == *"would queue: $r health"* ]] || false
  optin "$r" health "day: nosuchday\n"
  run "$VIBE" job due --claude --dry "$r"
  [[ "$output" == *"nothing to queue"* ]] || false
  [ ! -d "$NIGHTS" ]
}

@test "job due: writes a <date>-jobs night and starts it; oldest first, at most --max" {
  local r
  r="$(make_repo proj)"
  optin "$r" health "" "Skip legacy/."
  optin "$r" crashy
  state "$r" health last-run 100
  state "$r" crashy last-run 50
  echo "$r" >"$XDG_CONFIG_HOME/night-shift/repos"
  run "$VIBE" job due --claude --max 1
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"queued 90-proj-crashy"*"night started"* ]] || false
  [ ! -e "$(jobdir 91-proj-health)" ]
  grep -q -- "-L night-shift new-session -d -s night" "$STUBS/tmux.log"
  run "$VIBE" job due --claude
  [[ "$output" == *"queued 90-proj-crashy"*"queued 91-proj-health"* ]] || false
  [ -e "$(jobdir 90-proj-crashy-2)" ]
  run cat "$(jobdir 91-proj-health)/job"
  [[ "$output" == *"repo=$r"*"branch=jobs/health"*"model=sonnet"*"timeout=2h"*"recurring=health"*"output=pr"* ]] || false
  run cat "$(jobdir 91-proj-health)/prompt.md"
  [[ "$output" == *"# Recurring job: health"*"Check the code."*"MODE=ok"*"## In this repo"*"Skip legacy/."* ]] || false
  [[ "$output" == *"**Changed:** <changed>"*"**Needs you:** <needs-you>"* ]] || false
  [[ "$output" != *"<catalogue-instructions>"* ]] || false
}

@test "job due: a running night gets the dirs; a stopped job lands as skipped under Needs you" {
  local r
  r="$(make_repo proj)"
  optin "$r" health
  optin "$r" crashy
  state "$r" crashy fails 2
  mkdir -p "$NIGHTS/2026-10-26/jobs"
  touch "$STUBS/night-runs"
  run "$VIBE" job due --claude "$r"
  echo "$output"
  [ "$status" -eq 0 ]
  [ -f "$NIGHTS/2026-10-26/jobs/90-proj-health/prompt.md" ]
  [ "$(cat "$NIGHTS/2026-10-26/jobs/99-proj-crashy/status")" = skipped ]
  [[ "$(cat "$NIGHTS/2026-10-26/jobs/99-proj-crashy/note")" == "stopped after 2 failures — rm "*"/agent-jobs/proj/crashy/fails" ]] || false
  run grep -c new-session "$STUBS/tmux.log"
  [ "$output" = 0 ]
  run "$VIBE" night report "$NIGHTS/2026-10-26"
  run cat "$NIGHTS/briefings/$(date +%F).md"
  [[ "$output" == *"## Needs you"*"| 2026-10-26/99-proj-crashy | skipped | stopped after 2 failures"* ]] || false
}

@test "job run + night run: branch jobs/<job>, label, last-run on done; failures count and stop the job" {
  local r
  r="$(make_repo proj)"
  optin "$r" health
  optin "$r" crashy
  run "$VIBE" job run --claude "$r" health
  [ "$status" -eq 0 ]
  run "$VIBE" night run --claude "$NIGHTS"/*-jobs --until "$(soon)"
  [ "$status" -eq 0 ]
  [ "$(cat "$(jobdir 90-proj-health)/status")" = "done" ]
  git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/jobs/health
  [ -d "$r/.claude/worktrees/jobs/health" ]
  grep -q -- '--head jobs/health --title job(health): tidy' "$STUBS/gh.log"
  grep -qF -- 'api --method POST repos/{owner}/{repo}/issues/1/labels -f labels[]=agent' "$STUBS/gh.log"
  grep -q -- '--name proj-jobs-health' "$STUBS/claude.log"
  [ -f "$XDG_STATE_HOME/agent-jobs/proj/health/last-run" ]
  run "$VIBE" job list "$r"
  [[ "$output" == *"health"*"$(date +%F)"*"not due"* ]] || false
  rm -rf "$NIGHTS"
  run "$VIBE" job run --claude "$r" crashy
  "$VIBE" night run --claude "$NIGHTS"/*-jobs --until "$(soon)" >/dev/null 2>&1
  [ "$(cat "$XDG_STATE_HOME/agent-jobs/proj/crashy/fails")" = 1 ]
  rm -rf "$NIGHTS"
  run "$VIBE" job run --claude "$r" crashy
  "$VIBE" night run --claude "$NIGHTS"/*-jobs --until "$(soon)" >/dev/null 2>&1
  [ "$(cat "$XDG_STATE_HOME/agent-jobs/proj/crashy/fails")" = 2 ]
  run "$VIBE" job list "$r"
  [[ "$output" == *"crashy"*"stopped: 2 failures — rm "* ]] || false
  run "$VIBE" job run --claude "$r" nosuch
  [ "$status" -ne 0 ]
  [[ "$output" == *"no schedule"* ]] || false
}

@test "job run: a job's timeout replaces the night's" {
  local r
  r="$(make_repo proj)"
  optin "$r" slow
  "$VIBE" job run --claude "$r" slow >/dev/null
  run "$VIBE" night run --claude "$NIGHTS"/*-jobs --until "$(soon)" --timeout 1h
  [ "$status" -eq 0 ]
  [ "$(cat "$(jobdir 90-proj-slow)/status")" = timeout ]
  [ "$(cat "$(jobdir 90-proj-slow)/note")" = "stopped after 2s" ]
  [ "$(cat "$XDG_STATE_HOME/agent-jobs/proj/slow/fails")" = 1 ]
}

@test "job due: output drops to report at 2 open job PRs, unless this job's branch is one" {
  local r
  r="$(make_repo proj)"
  optin "$r" health
  printf 'jobs/a\njobs/b\nfeat/x\n' >"$STUBS/cap"
  "$VIBE" job run --claude "$r" health >/dev/null
  grep -q '^output=report$' "$(jobdir 90-proj-health)/job"
  grep -q -- '- \*\*Output:\*\* report' "$(jobdir 90-proj-health)/prompt.md"
  printf 'jobs/a\njobs/health\n' >"$STUBS/cap"
  "$VIBE" job run --claude "$r" health >/dev/null
  grep -q '^output=pr$' "$(jobdir 90-proj-health-2)/job"
}

@test "job add: renders the opt-in file once; refuses a bad name" {
  local r
  r="$(make_repo proj)"
  run "$VIBE" job add "$r" health
  [ "$status" -eq 0 ]
  run cat "$r/.agent-jobs/health.md"
  [[ "$output" == "---"*"# health in proj."*"_One line per instruction"* ]] || false
  [[ "$output" != *"<job>"* ]] || false
  run "$VIBE" job add "$r" health
  [ "$status" -ne 0 ]
  [[ "$output" == *"exists"* ]] || false
  run "$VIBE" job add "$r" "Bad Name"
  [ "$status" -ne 0 ]
  run "$VIBE" job add "$r" custom
  [[ "$output" == *"not in the catalogue"* ]] || false
}

@test "unit: the dispatcher runs only with role 'server', at 01:00, not persistent" {
  grep -q '^ExecCondition=.*grep -qx server %h/.config/vibe/role' "$REPO_ROOT/claude/systemd/agent-jobs.service"
  grep -q '^ExecStart=.*vibe job due --claude$' "$REPO_ROOT/claude/systemd/agent-jobs.service"
  grep -q '^OnCalendar=\*-\*-\* 01:00:00$' "$REPO_ROOT/claude/systemd/agent-jobs.timer"
  run grep -c Persistent "$REPO_ROOT/claude/systemd/agent-jobs.timer"
  [ "$output" = 0 ]
}

@test "unit: every catalogue entry has a schedule, a day when weekly, and a task body" {
  local f sched body
  for f in "$REPO_ROOT"/skills/recurring-jobs/references/jobs/*.md; do
    case "${f##*/}" in _*) continue ;; esac
    sched="$(awk 'NR > 1 && $0 == "---" { exit } index($0, "schedule:") == 1 { print $2 }' "$f")"
    [[ "$sched" == daily || "$sched" == weekly || "$sched" == monthly ]] || false
    body="$(awk 'NR > 1 && on { print } NR > 1 && $0 == "---" { on = 1 }' "$f" | grep -c . || true)"
    [ "$body" -gt 2 ]
  done
}
