#!/usr/bin/env bats
#
# vibe night — the night-shift runner in throwaway repos with a bare origin.
# A stub `claude` acts on the MODE line of its prompt; stub `gh` and `tmux`
# record their calls under $STUBS.

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
mode="\$(printf '%s\n' "\$prompt" | sed -n 's/^MODE=//p')"
case "\$prompt" in *"## GPU run finished"*) mode=ok ;; esac
case "\$mode" in
  gpu)
    echo code >code.txt && git add code.txt && git commit -q -m "feat: train script"
    "$VIBE" night gpu -- sh -c 'echo trained >out.txt'
    echo "queued: training" >"\$NIGHT_SHIFT_JOB_DIR/result"
    ;;
  ok)
    echo work >work.txt && git add work.txt && git commit -q -m "feat: work"
    printf 'feat: night work\n\n**Changed:** work.txt added.\n**Verify:** cat work.txt\n' >"\$NIGHT_SHIFT_JOB_DIR/pr.md"
    echo "done: work.txt added" >"\$NIGHT_SHIFT_JOB_DIR/result"
    ;;
  nopr)
    echo work >work.txt && git add work.txt && git commit -q -m "feat: work"
    echo "done: work.txt added, no pr.md" >"\$NIGHT_SHIFT_JOB_DIR/result"
    ;;
  blocked) echo "blocked: needs a decision" >"\$NIGHT_SHIFT_JOB_DIR/result" ;;
  crash) exit 3 ;;
  silent) ;;
  sleep) sleep 30 ;;
esac
EOF
  cat >"$STUBS/gh" <<EOF
#!/bin/sh
echo "\$*" >>"$STUBS/gh.log"
case "\$1 \$2" in
  "pr create") echo "https://example.com/pull/1" ;;
  "pr list") [ ! -f "$STUBS/pr-exists" ] || echo "https://example.com/pull/9" ;;
esac
EOF
  # shellcheck disable=SC2016  # the stub's own $@ and $3
  printf '#!/bin/sh\necho "$@" >>"%s/tmux.log"\n[ "$3" != has-session ]\n' "$STUBS" >"$STUBS/tmux"
  chmod +x "$STUBS/claude" "$STUBS/gh" "$STUBS/tmux"
  PATH="$STUBS:$PATH"
  export VIBE_TOOLKIT="$BATS_TEST_TMPDIR/no-toolkit" VIBE_NIGHT_POLL=0.2
  export GPU_QUEUE_DIR="$BATS_TEST_TMPDIR/gpu-queue" GPUQ_POLL=0.1
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  NIGHT="$XDG_STATE_HOME/night-shift/2026-10-26"
  mkdir -p "$NIGHT/jobs"
}

# mkjob ID REPO BRANCH MODE — one job dir as the skill writes it.
mkjob() {
  mkdir -p "$NIGHT/jobs/$1"
  printf 'repo=%s\nbranch=%s\nmodel=sonnet\n' "$2" "$3" >"$NIGHT/jobs/$1/job"
  printf 'Do the task.\nMODE=%s\n' "$4" >"$NIGHT/jobs/$1/prompt.md"
}

# soon — an --until a few hours from now, so no job is skipped.
soon() { date -d '+3 hours' +%H:%M 2>/dev/null || date -v+3H +%H:%M; }

@test "night run: jobs one at a time, commits pushed, draft PR from pr.md" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  mkjob 02-b "$r" task-b ok
  run "$VIBE" night run --claude "$NIGHT" --jobs 1 --until "$(soon)"
  [ "$status" -eq 0 ]
  [ "$(cat "$NIGHT/jobs/01-a/status")" = "done" ]
  [ "$(cat "$NIGHT/jobs/02-b/status")" = "done" ]
  git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/task-a
  git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/task-b
  [ "$(cat "$NIGHT/jobs/01-a/pr")" = "https://example.com/pull/1" ]
  grep -q -- 'pr create --draft --base main --head task-a --title feat: night work' "$STUBS/gh.log"
  grep -q '^\*\*Changed:\*\* work.txt added.' "$NIGHT/jobs/01-a/pr-body.md"
  grep -q -- 'pr edit https://example.com/pull/1 --add-label agent' "$STUBS/gh.log"
  [ "$(cat "$NIGHT/jobs/01-a/note")" = "done: work.txt added" ]
  [[ "$output" == *"01-a"*"done"* ]] || false
}

@test "night run: the agent is headless, sandboxed by the night settings, named <repo>-<branch>" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  run "$VIBE" night run --claude "$NIGHT" --until "$(soon)"
  [ "$status" -eq 0 ]
  grep -q -- '-p --model sonnet --name proj-task-a' "$STUBS/claude.log"
  grep -q -- '--permission-prompts none' "$STUBS/claude.log"
  grep -q -- "--settings $REPO_ROOT/claude/night-shift-settings.json" "$STUBS/claude.log"
}

@test "night run: no pr.md titles the PR from the result; an open PR gets its body replaced" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a nopr
  run "$VIBE" night run --claude "$NIGHT" --until "$(soon)"
  [ "$status" -eq 0 ]
  grep -q -- '--title night(01-a): work.txt added, no pr.md --body-file' "$STUBS/gh.log"
  touch "$STUBS/pr-exists"
  mkjob 02-b "$r" task-b ok
  run "$VIBE" night run --claude "$NIGHT" --until "$(soon)"
  [ "$status" -eq 0 ]
  [ "$(cat "$NIGHT/jobs/02-b/pr")" = "https://example.com/pull/9" ]
  grep -q -- 'pr edit https://example.com/pull/9 --body-file' "$STUBS/gh.log"
  run grep -c -- 'pr create --draft --base main --head task-b' "$STUBS/gh.log"
  [ "$output" = 0 ]
}

@test "night run: blocked without commits pushes nothing; crash and silence fail" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a blocked
  mkjob 02-b "$r" task-b crash
  mkjob 03-c "$r" task-c silent
  run "$VIBE" night run --claude "$NIGHT" --jobs 3 --until "$(soon)"
  [ "$status" -eq 0 ]
  [ "$(cat "$NIGHT/jobs/01-a/status")" = blocked ]
  [ "$(cat "$NIGHT/jobs/01-a/note")" = "blocked: needs a decision" ]
  [ ! -e "$NIGHT/jobs/01-a/pr" ]
  run git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/task-a
  [ "$status" -ne 0 ]
  [ "$(cat "$NIGHT/jobs/02-b/status")" = failed ]
  [[ "$(cat "$NIGHT/jobs/02-b/note")" == "agent exit 3: "* ]] || false
  [ "$(cat "$NIGHT/jobs/03-c/status")" = failed ]
  [ "$(cat "$NIGHT/jobs/03-c/note")" = "no result line" ]
}

@test "night run: a job over its time limit is stopped" {
  command -v timeout >/dev/null 2>&1 || skip "no timeout(1)"
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a sleep
  run "$VIBE" night run --claude "$NIGHT" --timeout 1s --until "$(soon)"
  [ "$status" -eq 0 ]
  [ "$(cat "$NIGHT/jobs/01-a/status")" = timeout ]
}

@test "night run: nothing starts after the deadline" {
  local r before
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  before="$(date +%H:%M)"
  run "$VIBE" night run --claude "$NIGHT" --until "$before"
  [ "$(date +%H:%M)" = "$before" ] || skip "the minute changed during the run"
  [ "$status" -eq 0 ]
  [ "$(cat "$NIGHT/jobs/01-a/status")" = skipped ]
  [ ! -e "$STUBS/claude.log" ]
}

@test "night run: skips a dirty worktree, fails a bad branch, a missing repo and a dead job" {
  local r
  r="$(make_repo proj)"
  "$VIBE" start -C "$r" busy >/dev/null 2>&1
  echo wip >"$r/.claude/worktrees/busy/wip.txt"
  mkjob 01-a "$r" busy ok
  mkjob 02-b "$r" main ok
  mkjob 03-c "$BATS_TEST_TMPDIR/nowhere" task-c ok
  mkjob 04-d "$r" task-d ok
  echo running >"$NIGHT/jobs/04-d/status"
  echo 999999 >"$NIGHT/jobs/04-d/pid"
  run "$VIBE" night run --claude "$NIGHT" --until "$(soon)"
  [ "$status" -eq 0 ]
  [ "$(cat "$NIGHT/jobs/01-a/status")" = skipped ]
  [[ "$(cat "$NIGHT/jobs/01-a/note")" == *"uncommitted changes"* ]] || false
  [ "$(cat "$NIGHT/jobs/02-b/status")" = failed ]
  [ "$(cat "$NIGHT/jobs/03-c/status")" = failed ]
  [ "$(cat "$NIGHT/jobs/04-d/status")" = failed ]
  [ "$(cat "$NIGHT/jobs/04-d/note")" = "job process died" ]
  [ ! -e "$STUBS/claude.log" ]
}

@test "night start: runs the night in tmux with absolute paths; refuses bad input" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  cd "$XDG_STATE_HOME/night-shift"
  run "$VIBE" night start --claude 2026-10-26 --jobs 2
  [ "$status" -eq 0 ]
  grep -q -- "-L night-shift new-session -d -s night -c $NIGHT" "$STUBS/tmux.log"
  grep -q -- "night run --claude $NIGHT --jobs 2 --until 06:30 --timeout 3h" "$STUBS/tmux.log"
  run "$VIBE" night start --nope "$NIGHT"
  [ "$status" -ne 0 ]
  run "$VIBE" night start --claude "$BATS_TEST_TMPDIR/empty"
  [ "$status" -ne 0 ]
  run "$VIBE" night start --claude "$NIGHT" --until 25:00
  [ "$status" -ne 0 ]
}

@test "night status: defaults to the latest night" {
  local r
  r="$(make_repo proj)"
  mkdir -p "$XDG_STATE_HOME/night-shift/2026-10-25/jobs"
  mkjob 01-a "$r" task-a ok
  echo blocked >"$NIGHT/jobs/01-a/status"
  run "$VIBE" night status
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-10-26"* ]] || false
  [[ "$output" == *"01-a"*"blocked"* ]] || false
}

SWEEP="$REPO_ROOT/skills/night-shift/sweep.sh"

@test "sweep: repos from the config in rank order, items joined, handoff next action" {
  local a b
  a="$(make_repo alpha)" b="$(make_repo beta)"
  printf '# Roadmap\n\n## Items\n\n- [ ] First item\n      done when x.\n- [x] Finished\n- [ ] Second item\n' >"$b/PROJECT_ROADMAP.md"
  "$VIBE" start -C "$a" task >/dev/null 2>&1
  printf '## Next action\n\n_placeholder_\n\nRun the eval.\n\n## Blockers\n\nNone.\n' >"$a/.claude/worktrees/task/HANDOFF.md"
  mkdir -p "$BATS_TEST_TMPDIR/config/night-shift"
  printf 'beta   # first\n\n%s\n' "$a" >"$BATS_TEST_TMPDIR/config/night-shift/repos"
  XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config" NIGHT_SHIFT_ROOT="$BATS_TEST_TMPDIR" run "$SWEEP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# 1. beta"*"# 2. alpha"* ]] || false
  [[ "$output" == *"L5: - [ ] First item done when x."* ]] || false
  [[ "$output" == *"L8: - [ ] Second item"* ]] || false
  [[ "$output" != *"Finished"* ]] || false
  [[ "$output" == *"[task] DIRTY"*"Run the eval."*"None."* ]] || false
  [[ "$output" != *"placeholder"* ]] || false
}

@test "sweep: arguments override the config; no repos at all fails" {
  local a
  a="$(make_repo alpha)"
  XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config" run "$SWEEP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no repos"* ]] || false
  run "$SWEEP" "$a" "$BATS_TEST_TMPDIR/nowhere"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# 1. alpha"*"no PROJECT_ROADMAP.md"*"# 2. nowhere"*"not a git repo"* ]] || false
}

@test "night report: counts, one row per job, next action of unfinished jobs" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  mkjob 02-b "$r" task-b blocked
  mkjob 03-c "$r" task-c crash
  "$VIBE" night run --claude "$NIGHT" --jobs 3 --until "$(soon)" >/dev/null 2>&1
  printf '## Next action\n\nAsk the supervisor.\n\n## Blockers\n\nNeeds a | decision.\n' \
    >"$r/.claude/worktrees/task-b/HANDOFF.md"
  run "$VIBE" night report "$NIGHT"
  [ "$status" -eq 0 ]
  run cat "$NIGHT/report.md"
  [[ "$output" == *"1 done · 1 blocked · 1 failed"* ]] || false
  [[ "$output" == *"## Needs you"*"| 02-b | blocked | blocked: needs a decision |  |"*"| 03-c | failed |"*"## PR ready"*"## Done, nothing to read"* ]] || false
  [[ "$output" == *"## PR ready"*"| 01-a | done | work.txt added. | https://example.com/pull/1 |"*"## Done, nothing to read"*"none"* ]] || false
  [[ "$output" == *"## 02-b — blocked"*"Ask the supervisor."*"Needs a | decision."* ]] || false
  [[ "$output" == *"## 03-c — failed"*"- Log: $NIGHT/jobs/03-c/log"* ]] || false
  [[ "$output" != *"## 01-a"* ]] || false
}

@test "night report: --new keeps an existing report; --claude opens a session in tmux" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  echo old >"$NIGHT/report.md"
  run "$VIBE" night report --claude --new "$NIGHT"
  [ "$status" -eq 0 ]
  [ "$(cat "$NIGHT/report.md")" = old ]
  [ ! -e "$STUBS/tmux.log" ]
  run "$VIBE" night report --claude "$NIGHT"
  [ "$status" -eq 0 ]
  [ "$(cat "$NIGHT/report.md")" != old ]
  grep -q -- "-L night-shift new-session -d -s report -c $REPO_ROOT" "$STUBS/tmux.log"
  grep -q -- "--add-dir $NIGHT --model sonnet --remote-control night-shift\\\\ 2026-10-26 Read" "$STUBS/tmux.log"
  run "$VIBE" night report --nope "$NIGHT"
  [ "$status" -ne 0 ]
}

@test "unit: the morning report runs only with role 'server', at 07:00" {
  grep -q '^ExecCondition=.*grep -qx server %h/.config/vibe/role' "$REPO_ROOT/claude/systemd/night-shift-report.service"
  grep -q '^ExecStart=.*vibe night report --claude --new$' "$REPO_ROOT/claude/systemd/night-shift-report.service"
  grep -q '^OnCalendar=\*-\*-\* 07:00:00$' "$REPO_ROOT/claude/systemd/night-shift-report.timer"
}

@test "night gpu: the job queues its run, the queue runs it, a follow-up job finishes the task" {
  local r pid
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a gpu
  "$VIBE" night run --claude "$NIGHT" --until "$(soon)" >"$BATS_TEST_TMPDIR/run.out" 2>&1 &
  pid=$!
  for _ in $(seq 1 100); do
    [ "$(cat "$NIGHT/jobs/01-a/status" 2>/dev/null)" != gpu ] || break
    sleep 0.1
  done
  [ "$(cat "$NIGHT/jobs/01-a/status")" = gpu ]
  [ "$(cat "$NIGHT/jobs/01-a/pr")" = "https://example.com/pull/1" ]
  "$REPO_ROOT/bin/gpu-queue" run --once
  wait "$pid"
  [ "$(cat "$NIGHT/jobs/01-a/status")" = "done" ]
  [ "$(cat "$NIGHT/jobs/01-a/note")" = "GPU run exit 0 → 01-a-gpu" ]
  [ "$(cat "$r/.claude/worktrees/task-a/out.txt")" = trained ]
  grep -q '^follow=1$' "$NIGHT/jobs/01-a-gpu/job"
  grep -q -- '- Exit: 0' "$NIGHT/jobs/01-a-gpu/prompt.md"
  [ "$(cat "$NIGHT/jobs/01-a-gpu/status")" = "done" ]
}

@test "night gpu: only inside a night job" {
  run "$VIBE" night gpu -- true
  [ "$status" -ne 0 ]
  [[ "$output" == *"inside a night job"* ]] || false
}
