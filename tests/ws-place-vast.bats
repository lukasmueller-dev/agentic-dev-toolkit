#!/usr/bin/env bats
#
# workspaces/_places/vast — the place contract against stub vastai, ssh and
# rsync. Each stub logs its argv, one call per line, under $STUBS.

load helper

PLACE="$REPO_ROOT/workspaces/_places/vast"
SECRET="s3cr3t-value-9f2c"

setup() {
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS/bin"
  cat >"$STUBS/bin/vastai" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUBS/vastai.argv"
case "$1 $2" in
  "search offers") echo '[{"id": 111, "dph_total": 0.4}, {"id": 222, "dph_total": 0.9}]' ;;
  "create instance") echo '{"success": true, "new_contract": 4242}' ;;
  "show instance")
    printf '{"id": 4242, "actual_status": "%s", "public_ipaddr": "203.0.113.7", "ports": {"22/tcp": [{"HostPort": "%s"}]}}\n' \
      "${VAST_STATUS:-running}" "${VAST_PORT:-40022}"
    ;;
  "destroy instance") echo "{\"success\": ${VAST_DESTROY:-true}}" ;;
esac
EOF
  cat >"$STUBS/bin/ssh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUBS/ssh.argv"
stdin=1
for a in "$@"; do case "$a" in -n | -f | -O) stdin=0 ;; esac; done
if [ "$stdin" = 1 ]; then cat >>"$STUBS/ssh.stdin"; fi
case " $* " in *" -O check "*) exit 1 ;; esac
exit "${SSH_EXIT:-0}"
EOF
  cat >"$STUBS/bin/rsync" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUBS/rsync.argv"
exit "${RSYNC_EXIT:-0}"
EOF
  printf '#!/bin/sh\nexit 0\n' >"$STUBS/bin/sleep"
  printf '#!/bin/sh\necho 100.64.0.1\n' >"$STUBS/bin/tailscale"
  chmod +x "$STUBS/bin/"*
  : >"$STUBS/vastai.argv"
  export STUBS PATH="$STUBS/bin:$PATH"

  export WS_INSTANCE=demo-j1 WS_STATE="$BATS_TEST_TMPDIR/state/demo-j1" WS_DIR="$BATS_TEST_TMPDIR/workspaces/demo"
  export WS_CONF_IMAGE=ghcr.io/example/demo WS_CONF_COMMIT=0123456789abcdef0123456789abcdef01234567
  export WS_CONF_HOURS=08 WS_CONF_SECRETS=DEMO_TOKEN WS_CONF_PORTS=8080,8081
  mkdir -p "$WS_DIR" "$HOME/.config/vibe/workspaces"
  printf '#!/bin/sh\necho up\n' >"$WS_DIR/status"
  printf 'DEMO_TOKEN=%s\nVAST_QUERY=gpu_name=RTX_4090\nVAST_WAIT=2\n' "$SECRET" >"$HOME/.config/vibe/workspaces/demo.env"
  chmod 600 "$HOME/.config/vibe/workspaces/demo.env"
}

@test "up, exec, pull, down: a datacenter on-demand offer; no secret value in any stub's argv" {
  mkdir -p "$WS_STATE"
  : >"$WS_STATE/tunnel.sock" # a dead master's socket, left by a reboot
  run "$PLACE" up
  [ "$status" -eq 0 ]
  grep -q '^search offers gpu_name=RTX_4090 verified=true rentable=true datacenter=True -o dph --raw$' "$STUBS/vastai.argv"
  grep -q "^create instance 111 --image $WS_CONF_IMAGE:$WS_CONF_COMMIT --disk 50 .*--cancel-unavail" "$STUBS/vastai.argv"
  [ "$(grep -c -- --bid_price "$STUBS/vastai.argv")" -eq 0 ]
  [ "$(cat "$WS_STATE/id")" = 4242 ]
  [ "$(($(cat "$WS_STATE/limit") - $(cat "$WS_STATE/started")))" -eq 28800 ]
  grep -q 'HostName 203.0.113.7' "$WS_STATE/ssh_config"
  grep -q "^DEMO_TOKEN=$SECRET$" "$STUBS/ssh.stdin"
  [ "$(grep -c VAST_QUERY "$STUBS/ssh.stdin")" -eq 0 ]
  [ "$(cat "$WS_STATE/url")" = http://100.64.0.1:8080 ]
  grep -q -- '-L 100.64.0.1:8080:localhost:8080 vast$' "$STUBS/ssh.argv"
  [ ! -e "$WS_STATE/tunnel.sock" ]

  SSH_EXIT=3 run "$PLACE" exec steer "it's late"
  [ "$status" -eq 3 ]
  grep -qF "WS_PLACE=vast WS_HOURS='08' exec '/ws/scripts/steer' 'it'\\''s late'" "$STUBS/ssh.argv"

  run "$PLACE" pull
  [ "$status" -eq 0 ]
  grep -q -- "--safe-links -e .* vast:/ws/data vast:/ws/out $WS_STATE/$" "$STUBS/rsync.argv"
  [ -s "$WS_STATE/pulled" ]

  run "$PLACE" down
  [ "$status" -eq 0 ]
  grep -q '^destroy instance 4242 -y --raw$' "$STUBS/vastai.argv"
  [ ! -e "$WS_STATE/id" ]
  [ "$(cat "$STUBS"/*.argv | grep -c "$SECRET")" -eq 0 ]
}

@test "up: a status that never reaches running ends in a destroy" {
  VAST_STATUS=loading run "$PLACE" up
  [ "$status" -ne 0 ]
  [[ "$output" == *"not running after 2 s"* ]] || false
  grep -q '^destroy instance 4242 -y' "$STUBS/vastai.argv"
  [ ! -e "$WS_STATE/id" ]

  : >"$STUBS/vastai.argv"
  VAST_STATUS=exited run "$PLACE" up
  [ "$status" -ne 0 ]
  [ "$(grep -c '^show instance 4242' "$STUBS/vastai.argv")" -eq 1 ]
  grep -q '^destroy instance 4242 -y' "$STUBS/vastai.argv"
  [ ! -e "$WS_STATE/id" ]
}

@test "up: a host port that is not a number never reaches the ssh config" {
  VAST_PORT='22\nProxyCommand touch pwned' run "$PLACE" up
  [ "$status" -ne 0 ]
  [ ! -e "$STUBS/ssh.argv" ]
  grep -q '^destroy instance 4242 -y' "$STUBS/vastai.argv"
  [ ! -e "$WS_STATE/id" ]
}

@test "down: destroys after a failed pull, and says the pull failed" {
  "$PLACE" up >/dev/null
  RSYNC_EXIT=23 run "$PLACE" down
  [ "$status" -ne 0 ]
  [[ "$output" == *"pull failed"* ]] || false
  grep -q '^destroy instance 4242 -y' "$STUBS/vastai.argv"
  [ ! -e "$WS_STATE/id" ]
}

@test "tick: pulls when pulled is 10 min old; destroys past limit" {
  "$PLACE" up >/dev/null
  date +%s >"$WS_STATE/pulled"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ "$(grep -c 'vast:/ws/data' "$STUBS/rsync.argv")" -eq 0 ]

  echo "$(($(date +%s) - 600))" >"$WS_STATE/pulled"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ "$(grep -c 'vast:/ws/data' "$STUBS/rsync.argv")" -eq 1 ]
  [ "$(grep -c '^destroy instance' "$STUBS/vastai.argv")" -eq 0 ]

  echo "$(($(date +%s) - 1))" >"$WS_STATE/limit"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  grep -q '^destroy instance 4242 -y' "$STUBS/vastai.argv"
  [ ! -e "$WS_STATE/id" ]
}

@test "up refuses a recorded instance; an unconfirmed destroy keeps the id" {
  "$PLACE" up >/dev/null
  run "$PLACE" up
  [ "$status" -ne 0 ]
  [ "$(grep -c '^create instance' "$STUBS/vastai.argv")" -eq 1 ]

  VAST_DESTROY=false run "$PLACE" down
  [ "$status" -ne 0 ]
  [[ "$output" == *"still alive"* ]] || false
  [ "$(cat "$WS_STATE/id")" = 4242 ]
}
