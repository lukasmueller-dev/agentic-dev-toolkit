#!/usr/bin/env bats
#
# bin/gpu-queue — submit, run, lock and status in a temp queue dir.

load helper

GQ="$REPO_ROOT/bin/gpu-queue"

setup() {
  export GPU_QUEUE_DIR="$BATS_TEST_TMPDIR/q" GPUQ_POLL=0.1
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
}

@test "run --once: jobs in submit order, in their dir, then --then with the exit code" {
  "$GQ" submit --name first --dir "$WORK" -- sh -c 'echo one >>order.txt'
  "$GQ" submit --name "second job" --dir "$WORK" \
    --then "echo \"\$GPUQ_EXIT \$GPUQ_JOB\" >$WORK/then.txt" -- sh -c 'echo two >>order.txt; exit 3'
  run "$GQ" run --once
  [ "$status" -eq 0 ]
  [ "$(tr '\n' ' ' <"$WORK/order.txt")" = "one two " ]
  [[ "$(cat "$WORK/then.txt")" == "3 "*"-second-job" ]] || false
  [ "$(find "$GPU_QUEUE_DIR/queued" -mindepth 1 | wc -l | tr -d ' ')" -eq 0 ]
  run "$GQ" status
  [[ "$output" == *"finished"*"-first"*"0"* ]] || false
  [[ "$output" == *"finished"*"-second-job"*"3"* ]] || false
}

@test "run --until: no job starts after the deadline" {
  local now
  "$GQ" submit --dir "$WORK" -- touch ran.txt
  now="$(date +%H:%M)"
  run "$GQ" run --until "$now"
  [ "$(date +%H:%M)" = "$now" ] || skip "the minute changed during the run"
  [ "$status" -eq 0 ]
  [ ! -e "$WORK/ran.txt" ]
  run "$GQ" status
  [[ "$output" == queued* ]] || false
}

@test "lock: runs the command, returns its exit code; the mkdir lock without flock" {
  run "$GQ" lock -- sh -c 'exit 4'
  [ "$status" -eq 4 ]
  PATH="$(path_without flock)" run "$GQ" lock -- sh -c 'echo held'
  [ "$status" -eq 0 ]
  [ "$output" = held ]
  [ ! -e "$GPU_QUEUE_DIR/gpu.lock.d" ]
}

@test "submit: refuses a missing command or directory" {
  run "$GQ" submit --name x
  [ "$status" -ne 0 ]
  run "$GQ" submit --dir "$BATS_TEST_TMPDIR/nowhere" -- true
  [ "$status" -ne 0 ]
}

@test "cancel: a queued job ends at once, a running one with its whole tree; --then gets GPUQ_EXIT=cancelled" {
  local a b pid
  a="$("$GQ" submit --name a --dir "$WORK" --then "echo \"\$GPUQ_EXIT\" >$WORK/then-a.txt" -- touch ran-a.txt)"
  run "$GQ" cancel "$a"
  [ "$status" -eq 0 ]
  [ "$(cat "$GPU_QUEUE_DIR/finished/$a/exit")" = cancelled ]
  [ "$(cat "$WORK/then-a.txt")" = cancelled ]
  b="$("$GQ" submit --name b --dir "$WORK" --then "echo \"\$GPUQ_EXIT\" >$WORK/then-b.txt" -- sh -c 'sleep 1; echo late >late.txt')"
  "$GQ" run --once 2>/dev/null &
  pid=$!
  for _ in $(seq 1 50); do
    [ ! -s "$GPU_QUEUE_DIR/running/$b/pid" ] || break
    sleep 0.1
  done
  run "$GQ" cancel "$b"
  [ "$status" -eq 0 ]
  wait "$pid"
  [ "$(cat "$GPU_QUEUE_DIR/finished/$b/exit")" = cancelled ]
  [ "$(cat "$WORK/then-b.txt")" = cancelled ]
  sleep 1.5
  [ ! -e "$WORK/late.txt" ]
  [ ! -e "$WORK/ran-a.txt" ]
  run "$GQ" cancel "$b"
  [ "$status" -ne 0 ]
  run "$GQ" cancel ../x
  [ "$status" -ne 0 ]
}
