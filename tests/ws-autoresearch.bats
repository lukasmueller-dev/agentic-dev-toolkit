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
  # Stub render_env.py (at $AR_RUNTIME/..): writes the settings file from the env it gets.
  mkdir -p "$BATS_TEST_TMPDIR/scripts"
  cat >"$BATS_TEST_TMPDIR/scripts/render_env.py" <<'EOF2'
import os
import pathlib
import sys
import time

time.sleep(float(os.environ.get("RENDER_SLEEP", "0")))
if os.environ.get("RENDER_FAIL"):
    sys.exit(2)
d = pathlib.Path(os.environ["AR_RUNTIME"]) / ".claude"
d.mkdir(parents=True, exist_ok=True)
(d / "settings.local.json").write_text(os.environ["FAKE_KEY"])
EOF2
  # Stub supervisor: logs argv, cwd and env, writes the result paths, then acts on STUB_MODE.
  cat >"$AR_RUNTIME/scripts/ar-supervisor.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" "$PWD" "$FAKE_KEY" >"$TMPDIR/stub.log"
printf '%s\n' "${URL-}" "${KEY2-}" "${KEY3-}" "$(cat "$AR_RUNTIME/.claude/settings.local.json" 2>/dev/null || echo missing)" "${IS_SANDBOX-}" "$PATH" >"$TMPDIR/stub.env"
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
  deaf)
    trap '' TERM
    sleep 5 >/dev/null 2>&1 &
    wait $!
    ;;
  term0)
    trap 'kill $s 2>/dev/null; exit 0' TERM
    sleep 30 >/dev/null 2>&1 &
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
  [ "$(sed -n 4p "$TMPDIR/stub.env")" = "from-secrets" ]
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

@test "run ends the supervisor at WS_HOURS minus the margin" {
  STUB_MODE=hang AR_LIMIT_MARGIN=3599 run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_ROOT/out/result")" = "failed: stopped at the limit, supervisor exit 143" ]
}

@test "a run cut at the limit is never done:, also when the supervisor exits 0 on TERM" {
  STUB_MODE=term0 AR_LIMIT_MARGIN=3599 run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_ROOT/out/result")" = "failed: stopped at the limit, supervisor exit 0" ]
  [ -f "$WS_ROOT/out/files/state.md" ]
}

@test "run kills a supervisor that ignores TERM after the grace" {
  STUB_MODE=deaf AR_LIMIT_MARGIN=3599 AR_KILL_GRACE=1 run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_ROOT/out/result")" = "failed: stopped at the limit, supervisor exit 137" ]
  [ -f "$WS_ROOT/out/report.md" ]
}

@test "stop ends a running supervisor and waits for run to write the result" {
  STUB_MODE=hang "$WSDIR/run" >/dev/null 2>&1 3>&- &
  local rp=$!
  for _ in $(seq 1 50); do
    if [ -s "$TMPDIR/stub.log" ]; then break; fi
    sleep 0.2
  done
  [ -s "$TMPDIR/stub.log" ]
  run "$WSDIR/stop"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_ROOT/out/result")" = "failed: stopped, supervisor exit 143" ]
  wait "$rp"
}

@test "stop waits for the result when the supervisor ended on its own and run still copies" {
  local real
  real="$(command -v cp)"
  mkdir -p "$TMPDIR/bin"
  cat >"$TMPDIR/bin/cp" <<EOF2
#!/bin/sh
touch "\$TMPDIR/cp-started"
sleep 1
exec $real "\$@"
EOF2
  chmod +x "$TMPDIR/bin/cp"
  PATH="$TMPDIR/bin:$PATH" "$WSDIR/run" >/dev/null 2>&1 3>&- &
  local rp=$!
  for _ in $(seq 1 50); do
    if [ -e "$TMPDIR/cp-started" ]; then break; fi
    sleep 0.2
  done
  [ -e "$TMPDIR/cp-started" ]
  [ ! -s "$WS_ROOT/out/result" ]
  run "$WSDIR/stop"
  [ "$status" -eq 0 ]
  [ "$(cut -c1-5 "$WS_ROOT/out/result")" = "done:" ]
  wait "$rp"
}

@test "a stop during the setup ends run before the supervisor starts" {
  RENDER_SLEEP=2 "$WSDIR/run" >/dev/null 2>&1 3>&- &
  local rp=$!
  for _ in $(seq 1 50); do
    if [ -s "$TMPDIR/ar-supervisor.pid" ]; then break; fi
    sleep 0.2
  done
  [ -s "$TMPDIR/ar-supervisor.pid" ]
  run "$WSDIR/stop"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_ROOT/out/result")" = "failed: stopped before the supervisor started" ]
  [ ! -e "$TMPDIR/stub.log" ]
  wait "$rp"
}

# shellcheck disable=SC2016
@test "secrets are data: &, spaces, \$ and = in a value arrive as they are" {
  {
    echo '# a comment'
    echo 'URL=https://x.example/v1?a=1&b=2'
    echo 'KEY2=has space here'
    echo 'KEY3=sk-ab$cd=='
    echo 'not a pair'
    echo 'FAKE_KEY=from-secrets'
  } >"$WS_ROOT/secrets.env"
  run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$TMPDIR/stub.env")" = 'https://x.example/v1?a=1&b=2' ]
  [ "$(sed -n 2p "$TMPDIR/stub.env")" = 'has space here' ]
  [ "$(sed -n 3p "$TMPDIR/stub.env")" = 'sk-ab$cd==' ]
  [ "$(cut -c1-5 "$WS_ROOT/out/result")" = "done:" ]
}

@test "a WS_HOURS that is no whole number writes failed: and starts nothing" {
  WS_HOURS=1.5 run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_ROOT/out/result")" = "failed: WS_HOURS is not a whole number: 1.5" ]
  [ ! -e "$TMPDIR/stub.log" ]
}

@test "an abort in run itself still leaves a failed: result" {
  touch "$WS_ROOT/out/files"
  run "$WSDIR/run"
  [ "$status" -ne 0 ]
  [ "$(cut -c1-20 "$WS_ROOT/out/result")" = "failed: run aborted," ]
}

@test "run sets IS_SANDBOX and the venv PATH itself: a place may start it with a bare environment" {
  run env -i PATH="$PATH" TMPDIR="$TMPDIR" WS_ROOT="$WS_ROOT" AR_RUNTIME="$AR_RUNTIME" WS_HOURS=1 "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ "$(sed -n 5p "$TMPDIR/stub.env")" = "1" ]
  [ "$(sed -n 6p "$TMPDIR/stub.env" | cut -c1-14)" = "/opt/venv/bin:" ]
  [ "$(cut -c1-5 "$WS_ROOT/out/result")" = "done:" ]
}

@test "run writes the Claude Code settings before the supervisor starts, and stops if that fails" {
  RENDER_FAIL=1 run "$WSDIR/run"
  [ "$status" -eq 0 ]
  [ "$(cut -c1-7 "$WS_ROOT/out/result")" = "failed:" ]
  [ ! -e "$TMPDIR/stub.log" ]
}

@test "stop exits 1 when run has not written the result in time" {
  sleep 30 >/dev/null 2>&1 3>&- &
  local sp=$!
  echo "$sp" >"$TMPDIR/ar-supervisor.pid"
  AR_STOP_WAIT=1 run "$WSDIR/stop"
  kill "$sp"
  [ "$status" -eq 1 ]
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

# shellcheck disable=SC2016
@test "the Dockerfile pins the base image, uv, claude, bun and the Python packages" {
  grep -Eq '^FROM [^ ]+@sha256:[0-9a-f]{64}$' "$WSDIR/Dockerfile"
  grep -Eq '^COPY --from=[^ ]+@sha256:[0-9a-f]{64} ' "$WSDIR/Dockerfile"
  grep -Eq '^ARG CLAUDE_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' "$WSDIR/Dockerfile"
  grep -Eq '^ARG BUN_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' "$WSDIR/Dockerfile"
  grep -q 'claude-code@${CLAUDE_VERSION}' "$WSDIR/Dockerfile"
  grep -Eq '^ARG PIP_CUTOFF=[0-9]{4}-[0-9]{2}-[0-9]{2}$' "$WSDIR/Dockerfile"
  grep -q -- '--exclude-newer "$PIP_CUTOFF"' "$WSDIR/Dockerfile"
}

@test "nothing in the workspace names run_pending_forge" {
  run grep -rq run_pending_forge "$WSDIR"
  [ "$status" -eq 1 ]
}
