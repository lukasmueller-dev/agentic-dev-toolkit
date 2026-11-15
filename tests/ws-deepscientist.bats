#!/usr/bin/env bats
#
# workspaces/deepscientist — start/stop/status against a stub `ds` and a stub
# health endpoint. WS_ROOT stands in for /ws; DS_PORT and DS_SEED for the
# port and the image's seed folder.

load helper

WSD="$REPO_ROOT/workspaces/deepscientist"
TOKEN="0123456789abcdef"

setup() {
  export WS_ROOT="$BATS_TEST_TMPDIR/ws"
  export DS_SEED="$BATS_TEST_TMPDIR/seed"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$TMPDIR"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$WS_ROOT/data" "$WS_ROOT/out" "$DS_SEED/runtime/python-env" "$DS_SEED/runtime/tools" "$STUBS"
  echo "CLAUDE_CODE_OAUTH_TOKEN=oauth-secret" >"$WS_ROOT/secrets.env"
  # The stub ds logs its argv and the secret it sees, and writes the daemon
  # state a real start writes. A file $STUBS/no-token leaves the token out.
  cat >"$STUBS/ds" <<EOF
#!/usr/bin/env bash
echo "ds \$* | oauth=\${CLAUDE_CODE_OAUTH_TOKEN:-} sandbox=\${IS_SANDBOX:-} path=\$PATH" >>"$STUBS/ds.log"
case "\$*" in *--stop*) exit 0 ;; esac
if [ -f "$STUBS/ds-fail" ]; then
  case "\$*" in
    *--daemon-only*)
      echo "Auth token: $TOKEN" >&2
      echo "    $TOKEN    "
      exit 1
      ;;
  esac
fi
home=""
while [ \$# -gt 0 ]; do
  if [ "\$1" = --home ]; then home="\$2"; fi
  shift
done
mkdir -p "\$home/runtime" "\$home/logs"
echo "DeepScientist auth token: $TOKEN" >>"\$home/logs/daemon.log"
if [ -f "$STUBS/no-token" ]; then
  echo '{}' >"\$home/runtime/daemon.json"
else
  echo '{"auth_token": "$TOKEN"}' >"\$home/runtime/daemon.json"
fi
echo "launch card: Auth token $TOKEN"
EOF
  chmod +x "$STUBS/ds"
  PATH="$STUBS:$PATH"
  export PATH
  # A free port nothing listens on, for the `down` case.
  DS_PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
  export DS_PORT
  SERVER_PID=""
}

teardown() {
  if [ -n "$SERVER_PID" ]; then kill "$SERVER_PID" 2>/dev/null || true; fi
}

# serve_health — answer /api/health on $DS_PORT, `ok` only for the right token.
serve_health() {
  cat >"$STUBS/health.py" <<EOF
import http.server, json, os

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        good = self.path == "/api/health" and self.headers.get("Authorization") == "Bearer $TOKEN"
        self.send_response(200 if good else 401)
        self.end_headers()
        self.wfile.write(json.dumps({"status": "ok"} if good else {}).encode())
    def log_message(self, *a):
        pass

http.server.HTTPServer(("127.0.0.1", int(os.environ["DS_PORT"])), H).serve_forever()
EOF
  python3 "$STUBS/health.py" &
  SERVER_PID=$!
  curl -s -o /dev/null --retry 30 --retry-connrefused --retry-delay 1 "http://127.0.0.1:$DS_PORT/" || true
}

@test "start runs ds with the login on, bound to all interfaces" {
  run "$WSD/start"
  [ "$status" -eq 0 ]
  run cat "$STUBS/ds.log"
  [[ "$output" == *"--auth true"* ]] || false
  [[ "$output" == *"--host 0.0.0.0"* ]] || false
  [[ "$output" == *"--port $DS_PORT"* ]] || false
  [[ "$output" == *"--daemon-only"* ]] || false
  [[ "$output" == *"--runner claude"* ]] || false
  [[ "$output" == *"--home $WS_ROOT/data"* ]] || false
}

@test "start hands the secret to ds and keeps both token files private" {
  run "$WSD/start"
  [ "$status" -eq 0 ]
  grep -q "oauth=oauth-secret" "$STUBS/ds.log"
  [ "$(cat "$WS_ROOT/data/.ws-token")" = "$TOKEN" ]
  # mode 600 (GNU stat, then BSD stat)
  for f in .ws-token runtime/daemon.json; do
    perm="$(stat -c %a "$WS_ROOT/data/$f" 2>/dev/null || stat -f %Lp "$WS_ROOT/data/$f")"
    [ "$perm" = 600 ]
  done
}

@test "start links the seed runtime into the data folder on every start" {
  run "$WSD/start"
  [ "$status" -eq 0 ]
  [ "$(readlink "$WS_ROOT/data/runtime/python-env")" = "$DS_SEED/runtime/python-env" ]
  [ "$(readlink "$WS_ROOT/data/runtime/tools")" = "$DS_SEED/runtime/tools" ]
  # a link lost to an interrupted start or a restored data folder comes back
  rm "$WS_ROOT/data/runtime/tools"
  run "$WSD/start"
  [ "$status" -eq 0 ]
  [ -L "$WS_ROOT/data/runtime/tools" ]
}

@test "start sets PATH and IS_SANDBOX itself, not from the exec channel" {
  run env -u IS_SANDBOX "$WSD/start"
  [ "$status" -eq 0 ]
  grep -q "sandbox=1 " "$STUBS/ds.log"
  grep -q "path=/opt/ds/node_modules/.bin:" "$STUBS/ds.log"
}

@test "start keeps a real directory already in data/runtime" {
  mkdir -p "$WS_ROOT/data/runtime/python-env"
  touch "$WS_ROOT/data/runtime/python-env/rebuilt"
  run "$WSD/start"
  [ "$status" -eq 0 ]
  [ ! -L "$WS_ROOT/data/runtime/python-env" ]
  [ -e "$WS_ROOT/data/runtime/python-env/rebuilt" ]
  [ ! -e "$WS_ROOT/data/runtime/python-env/python-env" ]
  [ -L "$WS_ROOT/data/runtime/tools" ]
}

@test "start fails when the image has no seed" {
  rm -rf "$DS_SEED"
  run "$WSD/start"
  [ "$status" -eq 1 ]
  [ ! -e "$STUBS/ds.log" ]
}

@test "start stops the daemon and fails when ds reports no token" {
  touch "$STUBS/no-token"
  run "$WSD/start"
  [ "$status" -eq 1 ]
  grep -q -- "--stop" "$STUBS/ds.log"
  [ ! -e "$WS_ROOT/data/.ws-token" ]
}

@test "start stops the daemon, hides the token and fails when ds exits non-zero" {
  touch "$STUBS/ds-fail"
  run "$WSD/start"
  [ "$status" -eq 1 ]
  grep -q -- "--stop --home $WS_ROOT/data" "$STUBS/ds.log"
  [[ "$output" == *"Auth token"* ]] || false
  [[ "$output" != *"$TOKEN"* ]] || false
  [ ! -e "$WS_ROOT/data/.ws-token" ]
}

@test "start keeps the daemon log, which holds the token, outside /ws/data" {
  run "$WSD/start"
  [ "$status" -eq 0 ]
  [ -L "$WS_ROOT/data/logs" ]
  grep -q "$TOKEN" "$TMPDIR/ds-logs/daemon.log"
  [ "$(cd "$WS_ROOT/data/logs" && pwd -P)" = "$(cd "$TMPDIR/ds-logs" && pwd -P)" ]
}

@test "start replaces a real logs folder from an older start" {
  mkdir -p "$WS_ROOT/data/logs"
  echo "DeepScientist auth token: oldtoken" >"$WS_ROOT/data/logs/daemon.log"
  run "$WSD/start"
  [ "$status" -eq 0 ]
  [ -L "$WS_ROOT/data/logs" ]
  run grep -R oldtoken "$WS_ROOT" "$TMPDIR"
  [ "$status" -eq 1 ]
}

@test "run and steer exit 3: the verb is not supported" {
  for v in run steer; do
    run "$WSD/$v" "text"
    [ "$status" -eq 3 ]
  done
}

@test "start fails with no secrets file" {
  rm "$WS_ROOT/secrets.env"
  run "$WSD/start"
  [ "$status" -eq 1 ]
  [ ! -e "$STUBS/ds.log" ]
}

@test "status prints up and the link with the token on a healthy answer" {
  "$WSD/start"
  serve_health
  run "$WSD/status"
  [ "$status" -eq 0 ]
  [ "$output" = "up — /?token=$TOKEN" ]
}

@test "status prints down when nothing answers" {
  "$WSD/start"
  run "$WSD/status"
  [ "$status" -eq 0 ]
  [[ "$output" == "down — "* ]] || false
  [[ "$output" != *"$TOKEN"* ]] || false
}

@test "status prints down when the token is wrong" {
  "$WSD/start"
  serve_health
  echo "wrong" >"$WS_ROOT/data/.ws-token"
  run "$WSD/status"
  [[ "$output" == "down — "* ]] || false
}

@test "the token is in no file under /ws but .ws-token and daemon.json" {
  "$WSD/start"
  serve_health
  run "$WSD/status"
  [[ "$output" == *"$TOKEN"* ]] || false
  run grep -rl "$TOKEN" "$WS_ROOT"
  [ "$status" -eq 0 ]
  want="$(printf '%s\n%s\n' "$WS_ROOT/data/.ws-token" "$WS_ROOT/data/runtime/daemon.json" | LC_ALL=C sort)"
  [ "$(printf '%s\n' "$output" | LC_ALL=C sort)" = "$want" ]
}

@test "stop calls ds --stop on the data folder" {
  run "$WSD/stop"
  [ "$status" -eq 0 ]
  grep -q -- "--stop --home $WS_ROOT/data" "$STUBS/ds.log"
}

@test "the conf, the Dockerfile and the contract agree" {
  conf="$WSD/workspace.conf"
  grep -q '^kind=service$' "$conf"
  grep -q '^ports=20999,21000$' "$conf"
  grep -q '^secrets=CLAUDE_CODE_OAUTH_TOKEN$' "$conf"
  commit="$(sed -n 's/^commit=//p' "$conf")"
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || false
  grep -q "ARG COMMIT=$commit" "$WSD/Dockerfile"
}
