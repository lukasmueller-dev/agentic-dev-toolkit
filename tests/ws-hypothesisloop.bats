#!/usr/bin/env bats
#
# workspaces/hypothesisloop — start, stop and status against a stub docker, make and curl.

load helper

WS_SRC="$REPO_ROOT/workspaces/hypothesisloop"
KEYS="SANDBOX_PROVIDER SANDBOX_FLY_API_KEY MODEL_ANTHROPIC_OAUTH_TOKEN GIT_HOST_PROVIDER LOCAL_REACHABLE_ADDRESS OBJECT_STORE_MINIO_SECRET_ACCESS_KEY"

setup() {
  HL="$BATS_TEST_TMPDIR/hl"
  LOG="$BATS_TEST_TMPDIR/calls.log"
  export LOG
  mkdir -p "$HL/localdev/controlplane" "$HL/controlplane/settings" "$HOME/.config/vibe/workspaces" "$BATS_TEST_TMPDIR/bin"
  : >"$HL/localdev/controlplane/docker-compose.yml"
  # A copy of the workspace whose start pins the sha256 of the empty compose file above.
  WS="$BATS_TEST_TMPDIR/ws"
  cp -R "$WS_SRC" "$WS"
  sed -i.bak "s/^HL_COMPOSE_SHA256=.*/HL_COMPOSE_SHA256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855/" "$WS/start"
  printf 'services:\n  api_port: 8081\n  metric_controller_port: 8084\n' >"$HL/controlplane/settings/hypothesisloop.yaml"
  echo abc123 >"$HL/localdev/.image-tag"
  write_env
  printf 'HLOOP_REPO=%s\n' "$HL" >"$HOME/.config/vibe/workspaces/hypothesisloop.env"
  chmod 600 "$HOME/.config/vibe/workspaces/hypothesisloop.env"
  # docker logs its argv and the compose values; `image inspect` fails under DOCKER_NO_IMAGE.
  cat >"$BATS_TEST_TMPDIR/bin/docker" <<'EOF'
#!/bin/sh
echo "docker $* TAG=$TAG REGISTRY=$REGISTRY BIND=$HLOOP_BIND PUBLISH=$REGISTRY_PUBLISH_IP GOOGLE=$HL_GOOGLE_CREDENTIALS_FILE API=$HL_API_PORT METRICS=$HL_METRICS_PORT" >>"$LOG"
if [ "$1 $2" = "image inspect" ] && [ -n "${DOCKER_NO_IMAGE:-}" ]; then exit 1; fi
# compose up fails under DOCKER_UP_FAIL and hangs under DOCKER_UP_SLEEP.
case " $* " in *" up "*)
  if [ -n "${DOCKER_UP_FAIL:-}" ]; then exit 1; fi
  if [ -n "${DOCKER_UP_SLEEP:-}" ]; then sleep 30; fi
  ;;
esac
# compose ps lists metrics-service as running, except under DOCKER_METRICS_DOWN.
case " $* " in *" ps "*) [ -n "${DOCKER_METRICS_DOWN:-}" ] || echo metrics-service ;; esac
exit 0
EOF
  # make fails on stderr under MAKE_FAIL.
  cat >"$BATS_TEST_TMPDIR/bin/make" <<'EOF'
#!/bin/sh
echo "make $*" >>"$LOG"
if [ -n "${MAKE_FAIL:-}" ]; then echo "render-settings: .env does not set UI_ORIGIN" >&2 && exit 1; fi
# render-settings writes the rendered settings as mode 600.
f="$2/controlplane/settings/.hypothesisloop.rendered.yaml"
: >"$f" && chmod 600 "$f"
exit 0
EOF
  # sleep 5 (start's wait on metrics-service) returns at once; any other sleep is real.
  cat >"$BATS_TEST_TMPDIR/bin/sleep" <<'EOF'
#!/bin/sh
[ "$1" = 5 ] && exit 0
exec /bin/sleep "$@"
EOF
  # tmux logs its argv, so no test ends a real session.
  cat >"$BATS_TEST_TMPDIR/bin/tmux" <<'EOF'
#!/bin/sh
echo "tmux $*" >>"$LOG"
EOF
  # curl fails for a URL that holds CURL_FAIL.
  cat >"$BATS_TEST_TMPDIR/bin/curl" <<'EOF'
#!/bin/sh
echo "curl $*" >>"$LOG"
case "$*" in *"${CURL_FAIL:-no match}"*) exit 7 ;; esac
exit 0
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/"*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# write_env [DROP]: the checkout's .env with every required key, less the key DROP.
write_env() {
  local key
  {
    echo "CLOUD_COMPUTE_PROVIDERS='vast'"
    for key in $KEYS; do
      [ "$key" = "${1:-}" ] && continue
      case "$key" in
        SANDBOX_PROVIDER) echo "SANDBOX_PROVIDER='fly'" ;;
        LOCAL_REACHABLE_ADDRESS) echo "LOCAL_REACHABLE_ADDRESS='100.64.0.9'" ;;
        *) echo "$key='x'" ;;
      esac
    done
  } >"$HL/.env"
}

@test "start refuses an unset or empty CLOUD_COMPUTE_PROVIDERS and calls nothing" {
  sed -i.bak '/^CLOUD_COMPUTE_PROVIDERS=/d' "$HL/.env"
  run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == "error — "*"does not set CLOUD_COMPUTE_PROVIDERS"* ]] || false
  echo "CLOUD_COMPUTE_PROVIDERS=''" >>"$HL/.env"
  run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CLOUD_COMPUTE_PROVIDERS"* ]] || false
  [ ! -e "$LOG" ]
}

@test "start takes the older CLOUD_COMPUTE_PROVIDER as the consent" {
  sed -i.bak "s/^CLOUD_COMPUTE_PROVIDERS=.*/CLOUD_COMPUTE_PROVIDER='vast'/" "$HL/.env"
  run "$WS/start"
  [ "$status" -eq 0 ]
}

@test "start refuses each missing key by name and calls nothing" {
  local key
  for key in $KEYS; do
    write_env "$key"
    run "$WS/start"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not set:"*" $key"* ]] || false
  done
  write_env
  sed -i.bak "s/^SANDBOX_PROVIDER=.*/SANDBOX_PROVIDER='e2b'/" "$HL/.env"
  run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SANDBOX_E2B_API_KEY"* ]] || false
  [ ! -e "$LOG" ]
}

@test "start refuses a plain git host or registry and calls nothing" {
  local key
  for key in GIT_HOST_PROVIDER CONTAINER_REGISTRY_PROVIDER; do
    write_env
    echo "$key='plain'" >>"$HL/.env"
    run "$WS/start"
    [ "$status" -eq 1 ]
    [[ "$output" == "error — "*"$key=plain"*"make dev"* ]] || false
  done
  [ ! -e "$LOG" ]
}

@test "start takes cloudrun, which has no account key" {
  write_env SANDBOX_FLY_API_KEY
  sed -i.bak "s/^SANDBOX_PROVIDER=.*/SANDBOX_PROVIDER='cloudrun'/" "$HL/.env"
  run "$WS/start"
  [ "$status" -eq 0 ]
}

@test "start shows the stderr of a failed make on stdout" {
  MAKE_FAIL=1 run bash -c '"$0/start" 2>/dev/null' "$WS"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not set UI_ORIGIN"* ]] || false
}

@test "start reads the keys of a .env whose last command fails" {
  echo 'false' >>"$HL/.env"
  run "$WS/start"
  [ "$status" -eq 0 ]
}

@test "start refuses a LOCAL_REACHABLE_ADDRESS outside the tailnet and calls nothing" {
  local addr
  for addr in turing.example 0.0.0.0 192.168.1.5 100.128.0.1; do
    sed -i.bak "s/^LOCAL_REACHABLE_ADDRESS=.*/LOCAL_REACHABLE_ADDRESS='$addr'/" "$HL/.env"
    run "$WS/start"
    [ "$status" -eq 1 ]
    [[ "$output" == *"LOCAL_REACHABLE_ADDRESS=$addr"*"IPv4"* ]] || false
  done
  [ ! -e "$LOG" ]
  sed -i.bak "s/^LOCAL_REACHABLE_ADDRESS=.*/LOCAL_REACHABLE_ADDRESS='100.127.255.254'/" "$HL/.env"
  run "$WS/start"
  [ "$status" -eq 0 ]
}

@test "start refuses no .env, no .image-tag and no HLOOP_REPO, and calls nothing" {
  rm "$HL/localdev/.image-tag"
  run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no $HL/localdev/.image-tag"* ]] || false
  rm "$HL/.env"
  run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no $HL/.env"* ]] || false
  : >"$HOME/.config/vibe/workspaces/hypothesisloop.env"
  run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not set HLOOP_REPO"* ]] || false
  [ ! -e "$LOG" ]
}

@test "start refuses a compose file other than the pinned one and calls nothing" {
  grep -qE '^HL_COMPOSE_SHA256=[0-9a-f]{64}$' "$WS_SRC/start"
  echo '    ports: ["8090:8090"]' >>"$HL/localdev/controlplane/docker-compose.yml"
  run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == "error — $HL/localdev/controlplane/docker-compose.yml differs from the commit in workspace.conf"* ]] || false
  [ ! -e "$LOG" ]
}

@test "start refuses an image this host does not hold and does not call compose" {
  DOCKER_NO_IMAGE=1 run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no image localhost:5000/hypothesisloop-control-service:abc123"* ]] || false
  [ "$(grep -c 'docker compose' "$LOG")" -eq 0 ]
}

@test "start renders the settings, then brings up the compose file under HLOOP_REPO on the tailnet address" {
  run "$WS/start"
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$LOG")" = "make -C $HL -s render-settings TAG=abc123" ]
  [ "$(grep 'docker compose .* up -d ' "$LOG")" = "docker compose -f $HL/localdev/controlplane/docker-compose.yml -f $WS/compose.tailnet.yml up -d postgres greptimedb memgraph minio control-service metrics-service TAG=abc123 REGISTRY=localhost:5000 BIND=100.64.0.9 PUBLISH=100.64.0.9 GOOGLE=/dev/null API=8081 METRICS=8084" ]
}

@test "start makes the rendered settings readable by metrics-service" {
  run "$WS/start"
  [ "$status" -eq 0 ]
  [ -n "$(find "$HL/controlplane/settings/.hypothesisloop.rendered.yaml" -perm -044)" ]
}

@test "start shows the metrics-service log and takes the stack down when it is not running" {
  DOCKER_METRICS_DOWN=1 run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"error — metrics-service is not running"* ]] || false
  [ "$(grep 'docker compose' "$LOG" | tail -n 2 | head -n 1 | grep -c ' logs --tail 20 metrics-service ')" -eq 1 ]
  [ "$(grep 'docker compose' "$LOG" | tail -n 1 | grep -c ' down TAG=')" -eq 1 ]
}

@test "start mounts the Google identity for the gcp registry only" {
  local google="$HOME/.config/gcloud/application_default_credentials.json"
  mkdir -p "${google%/*}" && echo '{}' >"$google"
  run "$WS/start"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'docker compose .* up -d .* GOOGLE=/dev/null ' "$LOG")" -eq 1 ]
  echo "CONTAINER_REGISTRY_PROVIDER='gcp'" >>"$HL/.env"
  run "$WS/start"
  [ "$status" -eq 0 ]
  [ "$(grep -c "docker compose .* up -d .* GOOGLE=$google " "$LOG")" -eq 1 ]
}

@test "start waits on the health check, and with no answer shows the control service log and takes the stack down" {
  run "$WS/start"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^curl .*http://127.0.0.1:8081/health' "$LOG")" -eq 1 ]
  : >"$LOG"
  CURL_FAIL=/health run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"error — the control service did not answer http://127.0.0.1:8081/health"* ]] || false
  [ "$(grep 'docker compose' "$LOG" | tail -n 2 | head -n 1 | grep -c ' logs --tail 20 control-service ')" -eq 1 ]
  [ "$(grep 'docker compose' "$LOG" | tail -n 1 | grep -c ' down TAG=')" -eq 1 ]
}

@test "start takes the stack down when compose up fails" {
  DOCKER_UP_FAIL=1 run "$WS/start"
  [ "$status" -ne 0 ]
  [ "$(grep -c 'docker compose .* up -d ' "$LOG")" -eq 1 ]
  [ "$(grep 'docker compose' "$LOG" | tail -n 1 | grep -c ' down TAG=')" -eq 1 ]
}

@test "start takes the stack down when the time limit ends it" {
  command -v timeout >/dev/null || skip "no timeout(1)"
  DOCKER_UP_SLEEP=1 run timeout 2 "$WS/start"
  [ "$status" -eq 124 ]
  [ "$(grep 'docker compose' "$LOG" | tail -n 1 | grep -c ' down TAG=')" -eq 1 ]
}

@test "stop ends the UI session, takes the compose file under HLOOP_REPO down, keeps the volumes and needs no .env or make output" {
  rm "$HL/.env" "$HL/localdev/.image-tag"
  run "$WS/stop"
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$LOG")" = "tmux kill-session -t =hloop-ui" ]
  [[ "$(grep -v '^tmux ' "$LOG")" == "docker compose -f $HL/localdev/controlplane/docker-compose.yml -f $WS/compose.tailnet.yml down TAG="*" API=8081 METRICS=8084" ]] || false
  [ "$(grep -cE -- '--volumes|-v( |$)' "$LOG")" -eq 0 ]
}

@test "status prints up on a healthy answer, probes the UI on the tailnet address, names a missing UI, and prints down on none" {
  run "$WS/status"
  [ "$status" -eq 0 ]
  [[ "$output" == "up — the control service answers http://127.0.0.1:8081/health" ]] || false
  [ "$(grep -c 'http://100.64.0.9:3000' "$LOG")" -eq 1 ]
  [ "$(grep -c '127.0.0.1:3000' "$LOG")" -eq 0 ]
  CURL_FAIL=:3000 run "$WS/status"
  [ "$status" -eq 0 ]
  [[ "$output" == "up — "*"nothing serves the UI on http://100.64.0.9:3000"* ]] || false
  CURL_FAIL=/health run "$WS/status"
  [ "$status" -eq 0 ]
  [[ "$output" == "down — "* ]] || false
}

@test "compose.tailnet.yml replaces the ports of each service start brings up, each on loopback or the tailnet address" {
  local f="$WS_SRC/compose.tailnet.yml" s bad
  for s in postgres greptimedb memgraph minio control-service metrics-service; do
    grep -qx "  $s:" "$f"
  done
  bad="$(grep -E '^ +ports:' "$f" | grep -v ': !override$' || true)"
  [ -z "$bad" ]
  [ "$(grep -cE '^ +- ' "$f")" -ge 6 ]
  bad="$(grep -E '^ +- ' "$f" | grep -vE '^ +- "(127\.0\.0\.1|\$\{HLOOP_BIND:\?start sets it\}):[^:"]+:[^:"]+"$' || true)"
  [ -z "$bad" ]
}
