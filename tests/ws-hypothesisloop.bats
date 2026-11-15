#!/usr/bin/env bats
#
# workspaces/hypothesisloop — start, stop and status against a stub docker, make and curl.

load helper

WS="$REPO_ROOT/workspaces/hypothesisloop"
KEYS="SANDBOX_PROVIDER SANDBOX_FLY_API_KEY MODEL_ANTHROPIC_OAUTH_TOKEN GIT_HOST_PROVIDER LOCAL_REACHABLE_ADDRESS"

setup() {
  HL="$BATS_TEST_TMPDIR/hl"
  LOG="$BATS_TEST_TMPDIR/calls.log"
  export LOG
  mkdir -p "$HL/localdev/controlplane" "$HL/controlplane/settings" "$HOME/.config/vibe/workspaces" "$BATS_TEST_TMPDIR/bin"
  : >"$HL/localdev/controlplane/docker-compose.yml"
  printf 'services:\n  api_port: 8081\n  metric_controller_port: 8084\n' >"$HL/controlplane/settings/hypothesisloop.yaml"
  echo abc123 >"$HL/localdev/.image-tag"
  echo 192.168.1.5 >"$HL/localdev/.host-address"
  write_env
  printf 'HLOOP_REPO=%s\n' "$HL" >"$HOME/.config/vibe/workspaces/hypothesisloop.env"
  chmod 600 "$HOME/.config/vibe/workspaces/hypothesisloop.env"
  # docker logs its argv and the compose values; `image inspect` fails under DOCKER_NO_IMAGE.
  cat >"$BATS_TEST_TMPDIR/bin/docker" <<'EOF'
#!/bin/sh
echo "docker $* TAG=$TAG REGISTRY=$REGISTRY BIND=$HLOOP_BIND PUBLISH=$REGISTRY_PUBLISH_IP API=$HL_API_PORT METRICS=$HL_METRICS_PORT" >>"$LOG"
if [ "$1 $2" = "image inspect" ] && [ -n "${DOCKER_NO_IMAGE:-}" ]; then exit 1; fi
exit 0
EOF
  cat >"$BATS_TEST_TMPDIR/bin/make" <<'EOF'
#!/bin/sh
echo "make $*" >>"$LOG"
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

@test "start reads the keys of a .env whose last command fails" {
  echo 'false' >>"$HL/.env"
  run "$WS/start"
  [ "$status" -eq 0 ]
}

@test "start refuses a host name in LOCAL_REACHABLE_ADDRESS and calls nothing" {
  sed -i.bak "s/^LOCAL_REACHABLE_ADDRESS=.*/LOCAL_REACHABLE_ADDRESS='turing.example'/" "$HL/.env"
  run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"LOCAL_REACHABLE_ADDRESS=turing.example"*"IPv4"* ]] || false
  [ ! -e "$LOG" ]
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

@test "start refuses an image this host does not hold and does not call compose" {
  DOCKER_NO_IMAGE=1 run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no image 192.168.1.5:5000/hypothesisloop-control-service:abc123"* ]] || false
  [ "$(grep -c 'docker compose' "$LOG")" -eq 0 ]
}

@test "start renders the settings, then brings up the compose file under HLOOP_REPO on the tailnet address" {
  run "$WS/start"
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$LOG")" = "make -C $HL -s render-settings" ]
  [ "$(grep 'docker compose' "$LOG")" = "docker compose -f $HL/localdev/controlplane/docker-compose.yml -f $WS/compose.tailnet.yml up -d postgres greptimedb memgraph minio control-service metrics-service TAG=abc123 REGISTRY=192.168.1.5:5000 BIND=100.64.0.9 PUBLISH=100.64.0.9 API=8081 METRICS=8084" ]
}

@test "stop takes the compose file under HLOOP_REPO down, keeps the volumes and needs no .env or make output" {
  rm "$HL/.env" "$HL/localdev/.image-tag" "$HL/localdev/.host-address"
  run "$WS/stop"
  [ "$status" -eq 0 ]
  [[ "$(cat "$LOG")" == "docker compose -f $HL/localdev/controlplane/docker-compose.yml -f $WS/compose.tailnet.yml down TAG="*" API=8081 METRICS=8084" ]] || false
  [ "$(grep -cE -- '--volumes|-v( |$)' "$LOG")" -eq 0 ]
}

@test "status prints up on a healthy answer, names a missing UI, and prints down on none" {
  run "$WS/status"
  [ "$status" -eq 0 ]
  [[ "$output" == "up — the control service answers http://127.0.0.1:8081/health" ]] || false
  CURL_FAIL=:3000 run "$WS/status"
  [ "$status" -eq 0 ]
  [[ "$output" == "up — "*"nothing serves the UI on :3000"* ]] || false
  CURL_FAIL=/health run "$WS/status"
  [ "$status" -eq 0 ]
  [[ "$output" == "down — "* ]] || false
}
