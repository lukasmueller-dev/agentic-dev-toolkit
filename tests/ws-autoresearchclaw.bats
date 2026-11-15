#!/usr/bin/env bats
#
# workspaces/autoresearchclaw — conf, config and the run/steer/stop scripts
# against a stub `researchclaw` and a stub `timeout` (macOS has none).

load helper

WSDIR="$REPO_ROOT/workspaces/autoresearchclaw"
PINNED=be4ba4755bf1b52220f25e13b2293b5956590070

setup() {
  export WS_ROOT="$BATS_TEST_TMPDIR/ws" WS_INSTANCE=autoresearchclaw-job1 WS_HOURS=2
  export TMPDIR="$BATS_TEST_TMPDIR" STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
  RUN_DIR="$WS_ROOT/data/artifacts/$WS_INSTANCE"
  mkdir -p "$WS_ROOT/in" "$WS_ROOT/data" "$BATS_TEST_TMPDIR/bin"
  echo "Sparse attention for small vision models" >"$WS_ROOT/in/brief.md"
  cat >"$BATS_TEST_TMPDIR/bin/timeout" <<'STUB'
#!/usr/bin/env bash
echo "timeout $1" >>"$STUB_LOG"
shift
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
mkdir -p "$out/deliverables"
[ -z "${STUB_SUMMARY:-}" ] || echo "$STUB_SUMMARY" >"$out/pipeline_summary.json"
[ -n "${STUB_NO_PAPER:-}" ] || echo "# Paper" >"$out/deliverables/paper_final.md"
exit "${STUB_RC:-0}"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/"*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  DONE='{"stages_done":22,"stages_failed":1,"degraded":false,"final_stage":23,"final_status":"done","content_metrics":{"verified_citations":9,"total_citations":10}}'
  FAILED='{"stages_done":11,"stages_failed":1,"degraded":false,"final_stage":12,"final_status":"failed","content_metrics":{}}'
}

result() { cat "$WS_ROOT/out/result"; }

@test "conf: a run tool with a GPU and a folder result, pinned to one commit in conf and Dockerfile" {
  grep -qx 'kind=run' "$WSDIR/workspace.conf"
  grep -qx 'gpu=yes' "$WSDIR/workspace.conf"
  grep -qx 'result=folder' "$WSDIR/workspace.conf"
  grep -qx "commit=$PINNED" "$WSDIR/workspace.conf"
  grep -qx "ARG COMMIT=$PINNED" "$WSDIR/Dockerfile"
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
  grep -qx 'timeout 2h' "$STUB_LOG"
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
  for _ in $(seq 50); do
    [ -s "$TMPDIR/ws-run.pid" ] && break
    sleep 0.1
  done
  run "$WSDIR/stop"
  [ "$status" -eq 0 ]
  wait "$runpid" || true
  [[ "$(result)" == "failed: stopped after stage 0"* ]] || false
  [ -d "$WS_ROOT/data" ]
  [ ! -e "$TMPDIR/ws-run.pid" ]
}

@test "stop: nothing running is not an error" {
  run "$WSDIR/stop"
  [ "$status" -eq 0 ]
}
