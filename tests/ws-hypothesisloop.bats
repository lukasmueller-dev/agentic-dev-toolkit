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
  # docker logs its argv and the compose values; make and curl log their argv.
  printf '#!/bin/sh\necho "docker $* TAG=$TAG REGISTRY=$REGISTRY BIND=$HLOOP_BIND PUBLISH=$REGISTRY_PUBLISH_IP" >>"$LOG"\n' >"$BATS_TEST_TMPDIR/bin/docker"
  printf '#!/bin/sh\necho "make $*" >>"$LOG"\n' >"$BATS_TEST_TMPDIR/bin/make"
  printf '#!/bin/sh\necho "curl $*" >>"$LOG"\nexit "${CURL_EXIT:-0}"\n' >"$BATS_TEST_TMPDIR/bin/curl"
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

@test "start refuses an env file with no HLOOP_REPO" {
  : >"$HOME/.config/vibe/workspaces/hypothesisloop.env"
  run "$WS/start"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not set HLOOP_REPO"* ]] || false
}

@test "start renders the settings, then brings up the compose file under HLOOP_REPO on the tailnet address" {
  run "$WS/start"
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$LOG")" = "make -C $HL -s render-settings" ]
  [ "$(sed -n 2p "$LOG")" = "docker compose -f $HL/localdev/controlplane/docker-compose.yml -f $WS/compose.tailnet.yml up -d TAG=abc123 REGISTRY=192.168.1.5:5000 BIND=100.64.0.9 PUBLISH=100.64.0.9" ]
}

@test "stop takes the compose file under HLOOP_REPO down and keeps the volumes" {
  run "$WS/stop"
  [ "$status" -eq 0 ]
  [[ "$(cat "$LOG")" == "docker compose -f $HL/localdev/controlplane/docker-compose.yml -f $WS/compose.tailnet.yml down TAG="* ]] || false
  [ "$(grep -cE -- '--volumes|-v( |$)' "$LOG")" -eq 0 ]
}

@test "status prints up on a healthy answer and down on none" {
  run "$WS/status"
  [ "$status" -eq 0 ]
  [[ "$output" == "up — "* ]] || false
  grep -q 'http://127.0.0.1:8081/health' "$LOG"
  CURL_EXIT=7 run "$WS/status"
  [ "$status" -eq 0 ]
  [[ "$output" == "down — "* ]] || false
}
