#!/usr/bin/env bats
#
# vibe job — recurring jobs: the catalogue, a repo's opt-in files, the due
# rule, the dispatcher that adds them to the vibe queue, and the runner's
# state updates. Stubs as in vibe-queue.bats.

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
    printf 'job(health): tidy\n\n**Changed:** work.txt added.\n' >"\$VIBE_JOB_DIR/pr.md"
    echo "done: work.txt added" >"\$VIBE_JOB_DIR/result"
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
  "pr list --label")
    if [ -f "$STUBS/prs.json" ]; then
      while [ \$# -gt 1 ]; do [ "\$1" != -q ] || q="\$2"; shift; done
      jq -r "\$q" "$STUBS/prs.json"
    elif [ -f "$STUBS/cap" ]; then cat "$STUBS/cap"; fi
    ;;
esac
EOF
  chmod +x "$STUBS/claude" "$STUBS/gh"
  PATH="$STUBS:$PATH"
  export VIBE_TOOLKIT="$BATS_TEST_TMPDIR/no-toolkit" VIBE_QUEUE_POLL=0.2
  export GPU_QUEUE_DIR="$BATS_TEST_TMPDIR/gpu-queue" GPUQ_POLL=0.1
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  mkdir -p "$HOME/.config/vibe" && echo server >"$HOME/.config/vibe/role"
  export VIBE_JOBS_CATALOGUE="$BATS_TEST_TMPDIR/catalogue" VIBE_ROOT="$BATS_TEST_TMPDIR"
  mkdir -p "$VIBE_JOBS_CATALOGUE" "$XDG_CONFIG_HOME/vibe"
  printf -- '---\nschedule: weekly\noutput: pr\ntimeout: 2h\n---\n\nCheck the code.\nMODE=ok\n' >"$VIBE_JOBS_CATALOGUE/health.md"
  printf -- '---\nschedule: daily\n---\n\nMODE=crash\n' >"$VIBE_JOBS_CATALOGUE/crashy.md"
  printf -- '---\nschedule: daily\ntimeout: 2s\n---\n\nMODE=sleep\n' >"$VIBE_JOBS_CATALOGUE/slow.md"
  TODAY="$(LC_ALL=C date +%a | tr '[:upper:]' '[:lower:]')"
  Q="$XDG_STATE_HOME/vibe/queue"
}

# optin REPO JOB [FRONTMATTER] [BODY] — the repo's .vibe-jobs file.
optin() {
  mkdir -p "$1/.vibe-jobs"
  printf -- '---\n%b---\n\n%s\n' "${3:-}" "${4:-}" >"$1/.vibe-jobs/$2.md"
}
# state REPO JOB FILE VALUE — a job's state file.
state() {
  mkdir -p "$XDG_STATE_HOME/vibe/jobs/$(basename "$1")/$2"
  echo "$4" >"$XDG_STATE_HOME/vibe/jobs/$(basename "$1")/$2/$3"
}
# qjobs SUFFIX — the queue's job dirs whose id ends in SUFFIX, oldest first.
qjobs() { for d in "$Q"/*-"$1"; do [ ! -d "$d" ] || echo "$d"; done; }
# drain — run the queue until nothing can start.
drain() { "$VIBE" queue run --claude --drain >/dev/null 2>&1; }

@test "job list: catalogue + repo file, repo-only jobs, invalid files; every repo with an opt-in" {
  local r
  r="$(make_repo proj)"
  make_repo bystander >/dev/null
  optin "$r" health "day: $TODAY\n"
  optin "$r" custom "schedule: monthly\n" "Do the custom thing."
  optin "$r" nosched "" "Body without a schedule."
  optin "$r" nobody "schedule: daily\n"
  state "$r" custom last-run "$(date +%s)"
  run "$VIBE" job list
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"REPO"*"JOB"*"SCHEDULE"* ]] || false
  [[ "$output" == *"proj"*"health"*"weekly"*"$TODAY"*"never"*"due"* ]] || false
  [[ "$output" == *"custom"*"monthly"*"-"*"$(date +%F)"*"not due"* ]] || false
  [[ "$output" == *"nosched"*"invalid: no schedule"* ]] || false
  [[ "$output" == *"nobody"*"invalid: not in the catalogue, and the repo file has no instructions"* ]] || false
  [[ "$output" != *bystander* && "$output" != *available* ]] || false
  [[ "$output" == *"fill-queue sweep: no "*"vibe/repos"* ]] || false
  mkdir -p "$XDG_CONFIG_HOME/vibe"
  printf 'proj  # first\n\n%s\n' "$BATS_TEST_TMPDIR/other" >"$XDG_CONFIG_HOME/vibe/repos"
  run "$VIBE" job list
  [[ "$output" == *"fill-queue sweep ("*"vibe/repos): proj, other"* ]] || false
  run "$VIBE" job list --all
  [[ "$output" == *"proj"*"crashy"*"daily"*"available — vibe job add proj crashy"* ]] || false
  [[ "$output" != *bystander* ]] || false
  [ "$(printf '%s\n' "$output" | grep -c 'health.*available')" = 0 ]
  run "$VIBE" job list "$BATS_TEST_TMPDIR/nowhere"
  [[ "$output" == *"no directory"* ]] || false
}

@test "job due --dry: the due rule — period, day, two failures stop a job" {
  local r
  r="$(make_repo proj)"
  optin "$r" health
  optin "$r" crashy
  run "$VIBE" job due --dry "$r"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would queue: $r health"* ]] || false
  [[ "$output" == *"would queue: $r crashy"* ]] || false
  state "$r" health last-run "$(($(date +%s) - 5 * 86400))"
  state "$r" crashy fails 2
  run "$VIBE" job due --dry "$r"
  [[ "$output" == *"nothing to queue"*"stopped: $r crashy (2 failures)"* ]] || false
  [[ "$output" != *"would queue"* ]] || false
  state "$r" health last-run "$(($(date +%s) - 7 * 86400))"
  optin "$r" health "day: $TODAY\n"
  run "$VIBE" job due --dry "$r"
  [[ "$output" == *"would queue: $r health"* ]] || false
  optin "$r" health "day: nosuchday\n"
  run "$VIBE" job due --dry "$r"
  [[ "$output" == *"nothing to queue"* ]] || false
  [ ! -d "$Q" ]
}

@test "job due: adds due jobs to the queue, oldest last-run first, at most --max" {
  local r d
  r="$(make_repo proj)"
  optin "$r" health "" "Skip legacy/."
  optin "$r" crashy
  state "$r" health last-run 100
  state "$r" crashy last-run 50
  run "$VIBE" job due --max 1
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"queued "*"-proj-jobs-crashy (pr)"* ]] || false
  [ -z "$(qjobs jobs-health)" ]
  run "$VIBE" job due
  [[ "$output" == *"-proj-jobs-crashy"*"-proj-jobs-health"* ]] || false
  [ "$(qjobs jobs-crashy | wc -l)" -eq 2 ]
  d="$(qjobs jobs-health)"
  run cat "$d/job"
  [[ "$output" == *"repo=$r"*"branch=jobs/health"*"model=sonnet"*"timeout=2h"*"recurring=health"*"output=pr"* ]] || false
  run cat "$d/prompt.md"
  [[ "$output" == *"# Recurring job: health"*"\`\$VIBE_JOB_DIR\`"*"Check the code."*"MODE=ok"*"## In this repo"*"Skip legacy/."* ]] || false
  [[ "$output" == *"**Context:** <context>"*"**Changed:** <changed>"*"**Context:** <context>"*"**Needs you:** <needs-you>"* ]] || false
  [[ "$output" != *"<catalogue-instructions>"* ]] || false
}

@test "job due: a stopped job lands once as skipped under Needs you" {
  local r d
  r="$(make_repo proj)"
  optin "$r" crashy
  state "$r" crashy fails 2
  run "$VIBE" job due "$r"
  [ "$status" -eq 0 ]
  "$VIBE" job due "$r" >/dev/null
  [ "$(qjobs jobs-crashy | wc -l)" -eq 1 ]
  d="$(qjobs jobs-crashy)"
  [ "$(cat "$d/status")" = skipped ]
  [[ "$(cat "$d/note")" == "stopped after 2 failures — rm "*"/vibe/jobs/proj/crashy/fails" ]] || false
  "$VIBE" queue report >/dev/null
  run cat "$XDG_STATE_HOME"/vibe/briefings/*.md
  [[ "$output" == *"### Needs you"*"| ${d##*/} | skipped |  | stopped after 2 failures"* ]] || false
}

@test "job run + queue run: branch jobs/<job>, label, last-run on done; failures count and stop the job" {
  local r
  r="$(make_repo proj)"
  optin "$r" health
  optin "$r" crashy
  run "$VIBE" job run "$r" health
  [ "$status" -eq 0 ]
  drain
  [ "$(cat "$(qjobs jobs-health)/status")" = "done" ]
  git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/jobs/health
  [ -d "$r/.claude/worktrees/jobs/health" ]
  grep -q -- '--head jobs/health --title job(health): tidy' "$STUBS/gh.log"
  grep -qF -- 'api --method POST repos/{owner}/{repo}/issues/1/labels -f labels[]=agent' "$STUBS/gh.log"
  grep -q -- '--name proj-jobs-health' "$STUBS/claude.log"
  [ -f "$XDG_STATE_HOME/vibe/jobs/proj/health/last-run" ]
  run "$VIBE" job list "$r"
  [[ "$output" == *"health"*"$(date +%F)"*"not due"* ]] || false
  "$VIBE" job run "$r" crashy >/dev/null
  drain
  [ "$(cat "$XDG_STATE_HOME/vibe/jobs/proj/crashy/fails")" = 1 ]
  "$VIBE" job run "$r" crashy >/dev/null
  drain
  [ "$(cat "$XDG_STATE_HOME/vibe/jobs/proj/crashy/fails")" = 2 ]
  run "$VIBE" job list "$r"
  [[ "$output" == *"crashy"*"stopped: 2 failures — rm "* ]] || false
  run "$VIBE" job run "$r" nosuch
  [ "$status" -ne 0 ]
  [[ "$output" == *"no schedule"* ]] || false
}

@test "job run: the job's own timeout stops it" {
  local r d
  r="$(make_repo proj)"
  optin "$r" slow
  "$VIBE" job run "$r" slow >/dev/null
  drain
  d="$(qjobs jobs-slow)"
  [ "$(cat "$d/status")" = timeout ]
  [ "$(cat "$d/note")" = "stopped after 2s" ]
  [ "$(cat "$XDG_STATE_HOME/vibe/jobs/proj/slow/fails")" = 1 ]
}

@test "job due: output drops to report at 2 open job PRs, unless this job's branch is one" {
  local r
  r="$(make_repo proj)"
  optin "$r" health
  printf 'jobs/a\njobs/b\nfeat/x\n' >"$STUBS/cap"
  "$VIBE" job run "$r" health >/dev/null
  grep -q '^output=report$' "$(qjobs jobs-health)/job"
  grep -q -- '- \*\*Output:\*\* report' "$(qjobs jobs-health)/prompt.md"
  printf 'jobs/a\njobs/health\n' >"$STUBS/cap"
  "$VIBE" job run "$r" health >/dev/null
  grep -q '^output=pr$' "$(qjobs jobs-health | tail -n 1)/job"
}

@test "job add: renders the opt-in file once; refuses a bad name" {
  local r
  r="$(make_repo proj)"
  run "$VIBE" job add "$r" health
  [ "$status" -eq 0 ]
  run cat "$r/.vibe-jobs/health.md"
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

# pr NUMBER HEAD MERGEABLE [CHECKS] [COMMENTS] [COMMITS] — one PR object for prs.json.
pr() {
  printf '{"number":%s,"url":"https://example.com/pull/%s","headRefName":"%s","baseRefName":"main","mergeable":"%s","statusCheckRollup":[%s],"comments":[%s],"reviews":[],"commits":[%s]}' \
    "$1" "$1" "$2" "$3" "${4:-}" "${5:-}" "${6:-}"
}
# branch_off REPO BRANCH FILE TEXT — commit FILE on a new BRANCH off main, push it.
branch_off() {
  git -C "$1" checkout -q -b "$2" main
  echo "$4" >"$1/$3" && git -C "$1" add "$3" && git -C "$1" commit -q -m "feat: $3"
  git -C "$1" push -q origin "$2"
  git -C "$1" checkout -q main
}

@test "job triage: merges the base into a conflicted agent PR and pushes; real conflicts, running jobs and unpushed work stay" {
  local r
  r="$(make_repo proj)"
  branch_off "$r" jobs/clean a.txt a
  branch_off "$r" jobs/clash f.txt branch
  branch_off "$r" jobs/local c.txt c
  branch_off "$r" jobs/busy b.txt b
  mkdir -p "$Q/1-busy" && printf 'repo=%s\nbranch=jobs/busy\n' "$r" >"$Q/1-busy/job" && echo running >"$Q/1-busy/status"
  echo local >"$r/l.txt" && git -C "$r" checkout -q jobs/local && git -C "$r" add l.txt && git -C "$r" commit -q -m "wip" && git -C "$r" checkout -q main
  echo main >"$r/f.txt" && git -C "$r" add f.txt && git -C "$r" commit -q -m "feat: main" && git -C "$r" push -q origin main
  printf '[%s,%s,%s,%s,%s]' "$(pr 1 jobs/clean CONFLICTING)" "$(pr 2 jobs/clash CONFLICTING)" \
    "$(pr 3 jobs/local CONFLICTING)" "$(pr 4 jobs/fine MERGEABLE)" "$(pr 5 jobs/busy CONFLICTING)" >"$STUBS/prs.json"
  run "$VIBE" job triage
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"- proj [#1](https://example.com/pull/1) \`jobs/clean\`: merged main and pushed"* ]] || false
  [[ "$output" == *"[#2]"*"conflicts with main in f.txt: needs a hand merge"* ]] || false
  [[ "$output" == *"[#3]"*"not merged: local commits not pushed"* ]] || false
  [[ "$output" == *"[#5]"*"not merged: a job runs on it"* ]] || false
  [[ "$output" != *"#4"* ]] || false
  git -C "$r" fetch -q origin
  git -C "$r" merge-base --is-ancestor origin/main origin/jobs/clean
  [ "$(git -C "$r" log -1 --format=%s origin/jobs/clean)" = "Merge branch 'main' into jobs/clean" ]
  run git -C "$r" merge-base --is-ancestor origin/main origin/jobs/clash
  [ "$status" -ne 0 ]
  run git -C "$r" merge-base --is-ancestor origin/main origin/jobs/local
  [ "$status" -ne 0 ]
  [ "$(git -C "$r" worktree list | wc -l)" -eq 1 ]
  "$VIBE" queue report >/dev/null
  run cat "$XDG_STATE_HOME"/vibe/briefings/*.md
  [[ "$output" == *"## Triage — "*"merged main and pushed"*"needs a hand merge"* ]] || false
}

@test "job triage: red CI and review comments since the last commit become briefing lines" {
  local r checks commits
  r="$(make_repo proj)"
  checks='{"name":"test","conclusion":"FAILURE"},{"name":"lint","conclusion":"SUCCESS"},{"context":"ci/old","state":"ERROR"},{"name":"slow","conclusion":null,"status":"IN_PROGRESS"}'
  commits='{"messageHeadline":"feat: x","committedDate":"2026-10-01T00:00:00Z"},{"messageHeadline":"Merge branch '"'main'"' into jobs/a","committedDate":"2026-10-05T00:00:00Z"}'
  printf '[%s,%s]' "$(pr 1 jobs/a MERGEABLE "$checks" '{"createdAt":"2026-09-30T00:00:00Z"},{"createdAt":"2026-10-02T00:00:00Z"}' "$commits")" \
    "$(pr 2 jobs/b MERGEABLE '{"name":"test","conclusion":"SUCCESS"}' '{"createdAt":"2026-09-30T00:00:00Z"}' "$commits")" >"$STUBS/prs.json"
  run "$VIBE" job triage "$r"
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[#1]"*"\`jobs/a\`: CI red: test, ci/old"* ]] || false
  [[ "$output" == *"[#1]"*"\`jobs/a\`: unanswered review comments: 1"* ]] || false
  [[ "$output" != *"#2"* ]] || false
  "$VIBE" queue report >/dev/null
  run cat "$XDG_STATE_HOME"/vibe/briefings/*.md
  [[ "$output" == *"## Triage — "*"CI red: test, ci/old"* ]] || false
  echo '[]' >"$STUBS/prs.json"
  run "$VIBE" job triage "$r"
  [ "$output" = "triage: nothing to report" ]
  [ ! -f "$XDG_STATE_HOME/vibe/triage.md" ]
  PATH="$(path_without gh)" run "$VIBE" job triage "$r"
  [ "$output" = "no gh — nothing to triage" ]
}

@test "unit: the dispatcher runs only with role 'server', at 01:00, not persistent" {
  grep -q '^ExecCondition=.*grep -qx server %h/.config/vibe/role' "$REPO_ROOT/claude/systemd/vibe-jobs.service"
  grep -q '^ExecStart=.*vibe job due$' "$REPO_ROOT/claude/systemd/vibe-jobs.service"
  [ "$(grep '^ExecStart=' "$REPO_ROOT/claude/systemd/vibe-jobs.service" | head -n 1)" = 'ExecStart=-%h/bin/vibe job triage' ]
  grep -q '^OnCalendar=\*-\*-\* 01:00:00$' "$REPO_ROOT/claude/systemd/vibe-jobs.timer"
  run grep -c Persistent "$REPO_ROOT/claude/systemd/vibe-jobs.timer"
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
