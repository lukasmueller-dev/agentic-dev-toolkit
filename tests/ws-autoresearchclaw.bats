#!/usr/bin/env bats
#
# workspaces/autoresearchclaw — conf, config and the run/steer/stop scripts
# against a stub `researchclaw` and a stub `timeout` (macOS has none).

load helper

WSDIR="$REPO_ROOT/workspaces/autoresearchclaw"
PINNED=be4ba4755bf1b52220f25e13b2293b5956590070

setup() {
  export WS_ROOT="$BATS_TEST_TMPDIR/ws" WS_INSTANCE=autoresearchclaw-job1 WS_HOURS=2
  export TMPDIR="$BATS_TEST_TMPDIR" STUB_LOG="$BATS_TEST_TMPDIR/stub.log" STUB_READY="$BATS_TEST_TMPDIR/ready"
  RUN_DIR="$WS_ROOT/data/artifacts/$WS_INSTANCE"
  mkdir -p "$WS_ROOT/in" "$WS_ROOT/data" "$BATS_TEST_TMPDIR/bin"
  echo "Sparse attention for small vision models" >"$WS_ROOT/in/brief.md"
  cat >"$BATS_TEST_TMPDIR/bin/timeout" <<'STUB'
#!/usr/bin/env bash
echo "timeout $1 $2 $3" >>"$STUB_LOG"
shift 3
exec "$@"
STUB
  # run: write STUB_SUMMARY and a paper into -o, exit STUB_RC. guide: log the args.
  cat >"$BATS_TEST_TMPDIR/bin/researchclaw" <<'STUB'
#!/usr/bin/env bash
echo "researchclaw $*" >>"$STUB_LOG"
echo "token=${CLAUDE_CODE_OAUTH_TOKEN:-}" >>"$STUB_LOG"
[ "$1" = run ] || exit 0
[ -z "${STUB_SLEEP:-}" ] || exec sleep "$STUB_SLEEP"
while [ $# -gt 0 ]; do
  if [ "$1" = -o ]; then out="$2"; fi
  shift
done
if [ -n "${STUB_TERM_WRITES:-}" ]; then # on TERM: write the paper, exit 143
  trap 'kill "$sp" 2>/dev/null; mkdir -p "$out/deliverables"; echo "# Paper" >"$out/deliverables/paper_final.md"; exit 143' TERM
  sleep 30 &
  sp=$!
  touch "$STUB_READY"
  wait "$sp"
fi
mkdir -p "$out/deliverables"
[ -z "${STUB_SUMMARY:-}" ] || echo "$STUB_SUMMARY" >"$out/pipeline_summary.json"
[ -n "${STUB_NO_PAPER:-}" ] || echo "# Paper" >"$out/deliverables/paper_final.md"
exit "${STUB_RC:-0}"
STUB
  # cp: STUB_CP_SLEEP delays it, STUB_CP_FAIL fails it.
  cat >"$BATS_TEST_TMPDIR/bin/cp" <<'STUB'
#!/usr/bin/env bash
[ -z "${STUB_CP_FAIL:-}" ] || exit 1
[ -z "${STUB_CP_SLEEP:-}" ] || sleep "$STUB_CP_SLEEP"
exec /bin/cp "$@"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/"*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  DONE='{"stages_done":22,"stages_failed":1,"degraded":false,"final_stage":23,"final_status":"done","content_metrics":{"verified_citations":9,"total_citations":10}}'
  FAILED='{"stages_done":11,"stages_failed":1,"degraded":false,"final_stage":12,"final_status":"failed","content_metrics":{}}'
}

result() { cat "$WS_ROOT/out/result"; }

# wait_for FILE: poll up to 5 s for a file to exist.
wait_for() {
  local _
  for _ in $(seq 50); do
    [ -e "$1" ] && return 0
    sleep 0.1
  done
  return 1
}

@test "conf: a run tool with a GPU and a folder result, pinned to one commit in conf and Dockerfile" {
  grep -qx 'kind=run' "$WSDIR/workspace.conf"
  grep -qx 'gpu=yes' "$WSDIR/workspace.conf"
  grep -qx 'result=folder' "$WSDIR/workspace.conf"
  grep -qx "commit=$PINNED" "$WSDIR/workspace.conf"
  grep -qx "ARG COMMIT=$PINNED" "$WSDIR/Dockerfile"
}

@test "Dockerfile: base image by digest, npm and pip packages by version" {
  local pkg npm pip
  grep -Eq '^FROM [^ ]+@sha256:[0-9a-f]{64}$' "$WSDIR/Dockerfile"
  read -ra npm <<<"$(sed -n 's/^RUN npm install -g //p' "$WSDIR/Dockerfile")"
  read -ra pip <<<"$(sed -n 's/.*pip install -e "[^"]*" //p' "$WSDIR/Dockerfile")"
  [ "${#npm[@]}" -eq 3 ]
  [ "${#pip[@]}" -eq 5 ]
  for pkg in "${npm[@]}"; do
    [[ "$pkg" =~ .@[0-9]+\.[0-9]+\.[0-9]+$ ]] || false
  done
  for pkg in "${pip[@]}"; do
    [[ "$pkg" =~ ==[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || false
  done
}

@test "config: real experiments through ACP, never simulated or docker" {
  [ "$(grep -c 'mode: sandbox' "$WSDIR"/*.yaml)" -eq 1 ]
  run grep -Eq 'mode: (simulated|docker)' "$WSDIR"/*.yaml
  [ "$status" -eq 1 ]
  grep -q 'provider: acp' "$WSDIR/config.yaml"
}

@test "run: hands over config, topic, output folder and the hour limit" {
  STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [ "$status" -eq 0 ]
  grep -qx 'timeout -k 60 2h' "$STUB_LOG"
  grep -qxF "researchclaw run -c $WSDIR/config.yaml -t Sparse attention for small vision models -o $RUN_DIR --auto-approve --skip-noncritical-stage" "$STUB_LOG"
}

@test "run: a finished pipeline gives done: and copies deliverables to files/" {
  STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [[ "$(result)" == "done: paper in files/, 22 stages done, 1 failed"* ]] || false
  [ -s "$WS_ROOT/out/files/paper_final.md" ]
  grep -q 'citations verified: 9 of 10' "$WS_ROOT/out/report.md"
}

@test "run: a summary with a failed stage gives failed: at exit 0" {
  STUB_SUMMARY="$FAILED" run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [[ "$(result)" == "failed: ended at stage 12 (failed), 1 stage(s) failed" ]] || false
}

@test "run: exit 0 without a summary gives failed:" {
  run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [[ "$(result)" == "failed: no valid pipeline_summary.json"* ]] || false
}

@test "run: all stages done but no paper gives failed:" {
  STUB_SUMMARY="$DONE" STUB_NO_PAPER=1 run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [[ "$(result)" == "failed: all 23 stages done, but"* ]] || false
}

@test "run: a non-zero exit of the tool gives failed: and the same exit code" {
  STUB_RC=7 STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [ "$status" -eq 7 ]
  [[ "$(result)" == "failed: researchclaw exit 7 after stage 0"* ]] || false
}

@test "run: the hour limit (timeout exit 124) gives failed: hour limit, also next to a done summary" {
  STUB_RC=124 STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [ "$status" -eq 124 ]
  [[ "$(result)" == "failed: hour limit of 2 h reached after stage 0"* ]] || false
}

@test "run: a tool killed after it ignored TERM (timeout exit 137) gives failed: killed" {
  STUB_RC=137 STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [ "$status" -eq 137 ]
  [[ "$(result)" == "failed: killed after stage 0"* ]] || false
}

@test "run: no brief gives failed: and no tool call" {
  rm "$WS_ROOT/in/brief.md"
  run "$WSDIR/run"
  [ "$status" -eq 1 ]
  [[ "$(result)" == "failed: no brief"* ]] || false
  [ ! -e "$STUB_LOG" ]
}

@test "run: --resume only when a checkpoint exists" {
  STUB_SUMMARY="$DONE" run "$WSDIR/run"
  run grep -q -- '--resume' "$STUB_LOG"
  [ "$status" -eq 1 ]
  echo '{"last_completed_stage": 5}' >"$RUN_DIR/checkpoint.json"
  STUB_SUMMARY="$DONE" run "$WSDIR/run"
  grep -q -- '--resume' "$STUB_LOG"
}

@test "run: exit 1 of the tool with a complete summary (a skipped stage 21 failed) is done: at exit 0" {
  STUB_RC=1 STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [[ "$(result)" == "done: paper in files/"* ]] || false
  [ -s "$WS_ROOT/out/files/paper_final.md" ]
}

@test "run: exit 1 of the tool with an unfinished summary, or none, stays failed: at exit 1" {
  STUB_RC=1 STUB_SUMMARY="$FAILED" run "$WSDIR/run"
  [ "$status" -eq 1 ]
  [[ "$(result)" == "failed: ended at stage 12 (failed)"* ]] || false
  STUB_RC=1 run "$WSDIR/run"
  [ "$status" -eq 1 ]
  [[ "$(result)" == "failed: no valid pipeline_summary.json"* ]] || false
}

@test "run: a checkpoint at stage 23 does not start the tool again, the verdict and copy still happen" {
  mkdir -p "$RUN_DIR/deliverables"
  echo '{"last_completed_stage": 23}' >"$RUN_DIR/checkpoint.json"
  echo "$DONE" >"$RUN_DIR/pipeline_summary.json"
  echo "# Paper" >"$RUN_DIR/deliverables/paper_final.md"
  run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ ! -e "$STUB_LOG" ]
  [[ "$(result)" == "done: paper in files/"* ]] || false
  [ -s "$WS_ROOT/out/files/paper_final.md" ]
}

@test "run: a summary left by an earlier part never gives a verdict to a tool that wrote none" {
  mkdir -p "$RUN_DIR"
  echo '{"last_completed_stage": 5}' >"$RUN_DIR/checkpoint.json"
  echo "$DONE" >"$RUN_DIR/pipeline_summary.json"
  STUB_RC=1 run "$WSDIR/run"
  [ "$status" -eq 1 ]
  [[ "$(result)" == "failed: no valid pipeline_summary.json"* ]] || false
}

@test "run: after a resume, result and report say the counts cover the last part only, also in a later run" {
  STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [[ "$(result)" == "done:"* ]] || false
  [[ "$(result)" != *resumed* ]] || false
  rm -rf "$RUN_DIR"
  mkdir -p "$RUN_DIR"
  echo '{"last_completed_stage": 5}' >"$RUN_DIR/checkpoint.json"
  STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [[ "$(result)" == "done:"*"(resumed run: counts cover the last part only)" ]] || false
  grep -q 'resumed run: counts cover the last part only' "$WS_ROOT/out/report.md"
  echo '{"last_completed_stage": 23}' >"$RUN_DIR/checkpoint.json"
  run "$WSDIR/run"
  [[ "$(result)" == "done:"*"(resumed run: counts cover the last part only)" ]] || false
}

@test "run: secrets.env reaches the tool, value kept literally" {
  # shellcheck disable=SC2016
  printf '# token\nCLAUDE_CODE_OAUTH_TOKEN=sk-a=b$c d\n' >"$WS_ROOT/secrets.env"
  STUB_SUMMARY="$DONE" run "$WSDIR/run"
  # shellcheck disable=SC2016
  grep -qxF 'token=sk-a=b$c d' "$STUB_LOG"
}

@test "run: a secrets.env line that is no KEY=VALUE is skipped with a warning, never exported" {
  printf 'CLAUDE_CODE_OAUTH_TOKEN\n  # indented comment\n1BAD=x\nCLAUDE_CODE_OAUTH_TOKEN=good\n' >"$WS_ROOT/secrets.env"
  STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"line 1 skipped"* ]] || false
  [[ "$output" == *"line 2 skipped"* ]] || false
  [[ "$output" == *"line 3 skipped"* ]] || false
  grep -qx 'token=good' "$STUB_LOG"
  [[ "$(result)" == "done:"* ]] || false
}

@test "steer: names the next stage from checkpoint.json" {
  mkdir -p "$RUN_DIR"
  echo '{"last_completed_stage": 8}' >"$RUN_DIR/checkpoint.json"
  run "$WSDIR/steer" "use fewer datasets"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stage 9"* ]] || false
  grep -qxF "researchclaw guide $RUN_DIR --stage 9 --message use fewer datasets" "$STUB_LOG"
}

@test "steer: before any checkpoint the next stage is 1, and a stage that reads no guidance is warned about" {
  mkdir -p "$RUN_DIR"
  run "$WSDIR/steer" "x"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: only stages 8 and 9"* ]] || false
  grep -q -- '--stage 1 ' "$STUB_LOG"
}

@test "steer: refuses when all stages are done, without text, and without a run folder" {
  run "$WSDIR/steer" "x"
  [ "$status" -eq 1 ]
  mkdir -p "$RUN_DIR"
  echo '{"last_completed_stage": 23}' >"$RUN_DIR/checkpoint.json"
  run "$WSDIR/steer" "x"
  [ "$status" -eq 1 ]
  run "$WSDIR/steer"
  [ "$status" -eq 2 ]
  [ ! -e "$STUB_LOG" ]
}

@test "stop: TERM ends a running pipeline, keeps /ws/data, and run says stopped" {
  STUB_SLEEP=30 "$WSDIR/run" &
  local runpid=$!
  wait_for "$TMPDIR/ws-run.pid"
  run "$WSDIR/stop"
  [ "$status" -eq 0 ]
  wait "$runpid" || true
  [[ "$(result)" == "failed: stopped after stage 0"* ]] || false
  [ -d "$WS_ROOT/data" ]
  [ ! -e "$TMPDIR/ws-run.pid" ]
}

@test "stop: returns only after run has written result, report and files" {
  STUB_TERM_WRITES=1 STUB_CP_SLEEP=2 "$WSDIR/run" &
  local runpid=$!
  wait_for "$STUB_READY"
  run "$WSDIR/stop"
  [ "$status" -eq 0 ]
  [[ "$(result)" == "failed: stopped after stage 0"* ]] || false
  [ -s "$WS_ROOT/out/report.md" ]
  [ -s "$WS_ROOT/out/files/paper_final.md" ]
  [ ! -e "$TMPDIR/ws-run.pid" ]
  wait "$runpid" || true
}

@test "run: TERM sent to run itself ends the tool, writes the verdict and exits 143" {
  STUB_SLEEP=30 "$WSDIR/run" &
  local runpid=$! rc=0
  wait_for "$TMPDIR/ws-run.pid"
  kill -TERM "$runpid"
  wait "$runpid" || rc=$?
  [ "$rc" -eq 143 ]
  [[ "$(result)" == "failed: stopped after stage 0"* ]] || false
  [ ! -e "$TMPDIR/ws-run.pid" ]
}

@test "run: an unreadable checkpoint.json does not stop the verdict" {
  mkdir -p "$RUN_DIR"
  echo 'not json' >"$RUN_DIR/checkpoint.json"
  STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [[ "$(result)" == "done:"* ]] || false
}

@test "run: a failed copy of the deliverables gives failed: with the run verdict" {
  STUB_CP_FAIL=1 STUB_SUMMARY="$DONE" run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [[ "$(result)" == "failed: copy of deliverables"*"the run verdict was: done:"* ]] || false
}

@test "run: an abort before any verdict still leaves a result and removes the pid file" {
  rm -rf "$WS_ROOT/data"
  run "$WSDIR/run"
  [ "$status" -eq 1 ]
  [ "$(result)" = "failed: run script aborted (exit 1)" ]
  [ ! -e "$TMPDIR/ws-run.pid" ]
}

@test "stop: nothing running is not an error" {
  run "$WSDIR/stop"
  [ "$status" -eq 0 ]
}
