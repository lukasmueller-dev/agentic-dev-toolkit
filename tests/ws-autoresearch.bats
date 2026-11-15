#!/usr/bin/env bats
#
# workspaces/autoresearch — run, stop and steer against a stub supervisor.

load helper

WSDIR="$REPO_ROOT/workspaces/autoresearch"

setup() {
  export WS_ROOT="$BATS_TEST_TMPDIR/ws" AR_RUNTIME="$BATS_TEST_TMPDIR/rt" WS_HOURS=1
  export TMPDIR="$BATS_TEST_TMPDIR"
  mkdir -p "$WS_ROOT/in" "$WS_ROOT/data" "$WS_ROOT/out" "$AR_RUNTIME/scripts"
  echo "an idea" >"$WS_ROOT/in/brief.md"
  echo "FAKE_KEY=from-secrets" >"$WS_ROOT/secrets.env"
  # Stub supervisor: logs argv, cwd and env, writes the result paths, then acts on STUB_MODE.
  cat >"$AR_RUNTIME/scripts/ar-supervisor.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" "$PWD" "$FAKE_KEY" >"$TMPDIR/stub.log"
mkdir -p "$2/results"
for f in results/summary.md review.md critic.md blind_review.md state.md decisions.log plan.md; do
  echo "$f" >"$2/$f"
done
case "${STUB_MODE:-}" in
  fail) exit 7 ;;
  hang)
    trap 'kill $s 2>/dev/null; exit 143' TERM
    sleep 30 &
    s=$!
    wait $s
    ;;
esac
EOF
  chmod +x "$AR_RUNTIME/scripts/ar-supervisor.sh"
}

@test "run hands over the idea and the project root, copies the six result paths, writes done:" {
  run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$TMPDIR/stub.log")" = "$WS_ROOT/in/brief.md" ]
  [ "$(sed -n 2p "$TMPDIR/stub.log")" = "$WS_ROOT/data/project" ]
  [ "$(sed -n 3,4p "$TMPDIR/stub.log" | tr '\n' ' ')" = "8 1h " ]
  [ "$(sed -n 5p "$TMPDIR/stub.log")" = "$AR_RUNTIME" ]
  [ "$(sed -n 6p "$TMPDIR/stub.log")" = "from-secrets" ]
  for f in results/summary.md review.md critic.md blind_review.md state.md decisions.log; do
    [ -f "$WS_ROOT/out/files/$f" ]
  done
  [ ! -e "$WS_ROOT/out/files/plan.md" ]
  [ "$(cut -c1-5 "$WS_ROOT/out/result")" = "done:" ]
  grep -q '^results/summary.md$' "$WS_ROOT/out/report.md"
  [ ! -e "$TMPDIR/ar-supervisor.pid" ]
}

@test "run writes failed: with the exit code and keeps what the tool wrote when the supervisor fails" {
  STUB_MODE=fail run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_ROOT/out/result")" = "failed: supervisor exit 7" ]
  [ -f "$WS_ROOT/out/files/state.md" ]
  [ -f "$WS_ROOT/out/report.md" ]
}

@test "run ends the supervisor at the limit" {
  STUB_MODE=hang AR_LIMIT_SECONDS=1 run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_ROOT/out/result")" = "failed: supervisor exit 143" ]
}

@test "stop ends a running supervisor and waits for run to write the result" {
  STUB_MODE=hang "$WSDIR/run" >/dev/null 2>&1 3>&- &
  local rp=$!
  for _ in $(seq 1 50); do
    if [ -s "$TMPDIR/ar-supervisor.pid" ]; then break; fi
    sleep 0.2
  done
  [ -s "$TMPDIR/ar-supervisor.pid" ]
  run "$WSDIR/stop"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_ROOT/out/result")" = "failed: supervisor exit 143" ]
  wait "$rp"
}

@test "stop with no run exits 0" {
  run "$WSDIR/stop"
  [ "$status" -eq 0 ]
}

@test "steer exits 3" {
  run "$WSDIR/steer" "use a smaller model"
  [ "$status" -eq 3 ]
}

@test "conf holds the contract keys and the commit matches the Dockerfile" {
  grep -q '^kind=run$' "$WSDIR/workspace.conf"
  grep -q '^gpu=yes$' "$WSDIR/workspace.conf"
  grep -q '^result=folder$' "$WSDIR/workspace.conf"
  grep -Eq '^commit=[0-9a-f]{40}$' "$WSDIR/workspace.conf"
  grep -q "^ARG COMMIT=$(sed -n 's/^commit=//p' "$WSDIR/workspace.conf")$" "$WSDIR/Dockerfile"
}

@test "nothing in the workspace names run_pending_forge" {
  run grep -rq run_pending_forge "$WSDIR"
  [ "$status" -eq 1 ]
}
