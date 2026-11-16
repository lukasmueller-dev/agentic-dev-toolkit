#!/usr/bin/env bats
#
# workspaces/_places/runpod — the place verbs against stub runpodctl, ssh, rsync and tailscale.

load helper

PLACE="$REPO_ROOT/workspaces/_places/runpod"

setup() {
  STUB="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB"
  # runpodctl: a pod exists while $STUB/pod does; its status is $STUB/status (default running);
  # create-fail-after, create-text, list-fail, delete-fail and get-error change a reply;
  # list-hook runs before a list reply.
  cat >"$STUB/runpodctl" <<'EOF'
#!/bin/sh
d="$(dirname "$0")"
echo "$*" >>"$d/runpodctl.log"
case "$1 $2" in
  "pod create")
    touch "$d/pod"
    [ ! -f "$d/create-fail-after" ] || exit 1
    [ ! -f "$d/create-text" ] || { echo "created pod pod123"; exit 0; }
    echo '{"id":"pod123","desiredStatus":"RUNNING"}' ;;
  "pod list")
    [ ! -f "$d/list-hook" ] || . "$d/list-hook"
    [ ! -f "$d/list-fail" ] || exit 1
    if [ -f "$d/pod" ]; then echo '[{"id":"pod123","name":"ws-tool"}]'; else echo '[]'; fi ;;
  "pod get")
    [ ! -f "$d/get-error" ] || { cat "$d/get-error" >&2; exit 1; }
    [ -f "$d/pod" ] || { echo '{"error":"failed to get pod: pod not found"}' >&2; exit 1; }
    printf '{"id":"pod123","runtimeStatus":"%s"}\n' "$(cat "$d/status" 2>/dev/null || echo running)" ;;
  "pod delete")
    [ ! -f "$d/delete-fail" ] || exit 1
    rm -f "$d/pod"
    echo '{"deleted":true,"id":"pod123"}' ;;
  "ssh info")
    echo '{"id":"pod123","ip":"203.0.113.7","port":22022,"ssh_key":{"path":"/keys/rp","exists":true}}' ;;
  *) exit 2 ;;
esac
EOF
  # ssh: -O check answers 0 while $STUB/tunnel-up exists; keeps what it gets on stdin for `cat >`; a /ws/scripts/ command prints and exits 7;
  # -N leaves a child on its stdout and stderr, as `ssh -f` does.
  cat >"$STUB/ssh" <<'EOF'
#!/bin/sh
d="$(dirname "$0")"
echo "$*" >>"$d/ssh.log"
case "$*" in *"-O check"*) [ -f "$d/tunnel-up" ] || exit 255; exit 0 ;; esac
case "$*" in *" -N "*) sleep 3 3>&- & ;; esac
case "$*" in *"cat >"*) cat >>"$d/ssh.stdin" ;; esac
case "$*" in *"/ws/scripts/"*) echo "script ran"; exit 7 ;; esac
exit 0
EOF
  cat >"$STUB/rsync" <<'EOF'
#!/bin/sh
d="$(dirname "$0")"
echo "$*" >>"$d/rsync.log"
[ ! -f "$d/rsync-fail" ] || exit 23
EOF
  printf '#!/bin/sh\necho 100.64.0.1\n' >"$STUB/tailscale"
  chmod +x "$STUB"/*
  export PATH="$STUB:$PATH"

  export WS_INSTANCE=tool WS_STATE="$BATS_TEST_TMPDIR/state/tool" WS_DIR="$BATS_TEST_TMPDIR/ws/tool"
  export WS_CONF_IMAGE=ghcr.io/example/tool WS_CONF_COMMIT=0123456789abcdef0123456789abcdef01234567
  export WS_CONF_HOURS=2 WS_CONF_PORTS=20999,21000
  mkdir -p "$WS_DIR" "$HOME/.config/vibe/places" "$HOME/.config/vibe/workspaces"
  echo "kind=run" >"$WS_DIR/workspace.conf"
  printf '%s\n' RUNPOD_API_KEY=rp-secret-key 'RUNPOD_GPU_ID=NVIDIA GeForce RTX 4090' \
    RUNPOD_WAIT=1 RUNPOD_POLL=0.1 >"$HOME/.config/vibe/places/runpod.env"
  chmod 600 "$HOME/.config/vibe/places/runpod.env"
  echo CLAUDE_CODE_OAUTH_TOKEN=sk-secret-token >"$HOME/.config/vibe/workspaces/tool.env"
  chmod 600 "$HOME/.config/vibe/workspaces/tool.env"
}

# pod_up — the state of an instance whose pod runs.
pod_up() {
  mkdir -p "$WS_STATE"
  echo pod123 >"$WS_STATE/id"
  touch "$STUB/pod"
}

@test "up: a pod that never runs, or fails a copy, is deleted" {
  echo initializing >"$STUB/status"
  run "$PLACE" up
  [ "$status" -ne 0 ]
  grep -qx 'pod delete pod123 --output json' "$STUB/runpodctl.log"
  [ ! -e "$STUB/pod" ]
  [ ! -e "$WS_STATE/id" ]

  rm "$STUB/status" "$STUB/runpodctl.log"
  touch "$STUB/rsync-fail"
  run "$PLACE" up
  [ "$status" -ne 0 ]
  grep -qx 'pod delete pod123 --output json' "$STUB/runpodctl.log"
  [ ! -e "$STUB/pod" ]
  [ ! -e "$WS_STATE/id" ]
}

@test "up finds and deletes a pod whose create prints no id or fails after the provider made it" {
  local f
  for f in create-text create-fail-after; do
    rm -f "$STUB"/create-* "$STUB/runpodctl.log"
    touch "$STUB/$f"
    run "$PLACE" up
    [ "$status" -ne 0 ]
    grep -qx 'pod delete pod123 --output json' "$STUB/runpodctl.log"
    [ ! -e "$STUB/pod" ]
    [ ! -e "$WS_STATE/id" ]
    [ ! -e "$WS_STATE/limit" ]
  done
}

@test "tick keeps the id when get fails with an auth error that says not found" {
  pod_up
  echo $(($(date +%s) - 1)) >"$WS_STATE/limit"
  touch "$STUB/delete-fail" "$STUB/list-fail"
  echo '{"error":"failed to get pod: API key not found"}' >"$STUB/get-error"
  run "$PLACE" tick
  [ "$status" -ne 0 ]
  [ "$(cat "$WS_STATE/id")" = pod123 ]
  [ -e "$STUB/pod" ]
}

@test "up: a create and a pod list that fail leave id=pending and limit=0; the next tick deletes" {
  touch "$STUB/create-fail-after" "$STUB/list-fail"
  run "$PLACE" up
  [ "$status" -ne 0 ]
  [ "$(cat "$WS_STATE/id")" = pending ]
  [ "$(cat "$WS_STATE/limit")" -eq 0 ]
  [ -e "$STUB/pod" ]
  rm "$STUB/list-fail"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  grep -qx 'pod delete pod123 --output json' "$STUB/runpodctl.log"
  [ ! -e "$STUB/pod" ]
  [ ! -e "$WS_STATE/id" ]
}

@test "tick: id=pending, as a killed up leaves it, stays while the list fails, then finds the pod" {
  mkdir -p "$WS_STATE"
  echo pending >"$WS_STATE/id"
  echo $(($(date +%s) - 1)) >"$WS_STATE/limit"
  touch "$STUB/pod" "$STUB/list-fail"
  run "$PLACE" tick
  [ "$status" -ne 0 ]
  [ "$(cat "$WS_STATE/id")" = pending ]
  [ -e "$STUB/pod" ]
  rm "$STUB/list-fail"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ ! -e "$STUB/pod" ]
  [ ! -e "$WS_STATE/id" ]
}

@test "tick: an empty list never removes the id that a running up wrote meanwhile" {
  mkdir -p "$WS_STATE"
  echo pending >"$WS_STATE/id"
  echo $(($(date +%s) + 3600)) >"$WS_STATE/limit"
  echo "echo pod123 >'$WS_STATE/id'" >"$STUB/list-hook"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_STATE/id")" = pod123 ]
  rm "$STUB/list-hook"
  echo pending >"$WS_STATE/id"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ ! -e "$WS_STATE/id" ]
}

@test "down: a failed delete sets limit=0, so the next tick deletes again" {
  pod_up
  echo $(($(date +%s) + 3600)) >"$WS_STATE/limit"
  touch "$STUB/delete-fail"
  run "$PLACE" down
  [ "$status" -ne 0 ]
  [ "$(cat "$WS_STATE/limit")" -eq 0 ]
  [ "$(cat "$WS_STATE/id")" = pod123 ]
}

@test "pull: each copy back has --safe-links, so a symlink out of the tree stays on the pod" {
  pod_up
  run "$PLACE" pull
  [ "$status" -eq 0 ]
  [ "$(grep -c -- "--safe-links root@203.0.113.7:/ws/" "$STUB/rsync.log")" -eq 2 ]
}

@test "up, exec, pull, down: no secret value is in any stub's argv" {
  mkdir -p "$WS_STATE/in"
  echo brief >"$WS_STATE/in/brief.md"
  echo "[203.0.113.7]:22022 ssh-ed25519 old-key" >"$WS_STATE/known_hosts"
  mkdir -p "$WS_STATE/data"
  echo kept >"$WS_STATE/data/project.json"
  WS_CONF_KIND=run run "$PLACE" up
  [ "$status" -eq 0 ]
  [ "$(cat "$WS_STATE/id")" = pod123 ]
  [ ! -e "$WS_STATE/known_hosts" ]
  [ "$(cat "$WS_STATE/limit")" -eq $(($(cat "$WS_STATE/started") + 7200)) ]
  grep -q -- "--gpu-id NVIDIA GeForce RTX 4090 --image $WS_CONF_IMAGE:$WS_CONF_COMMIT" "$STUB/runpodctl.log"
  grep -q -- '--ports 22/tcp --cloud-type SECURE --docker-args sleep infinity' "$STUB/runpodctl.log"
  grep -q "$WS_DIR/ root@203.0.113.7:/ws/scripts/" "$STUB/rsync.log"
  grep -q "$WS_STATE/in/ root@203.0.113.7:/ws/in/" "$STUB/rsync.log"
  grep -q "$WS_STATE/data/ root@203.0.113.7:/ws/data/" "$STUB/rsync.log"
  grep -qx CLAUDE_CODE_OAUTH_TOKEN=sk-secret-token "$STUB/ssh.stdin"
  run "$PLACE" exec steer "hello world"
  run "$PLACE" pull
  [ "$status" -eq 0 ]
  run "$PLACE" down
  [ "$status" -eq 0 ]
  [ ! -e "$STUB/pod" ]
  run grep -rF -e sk-secret-token -e rp-secret-key "$STUB/runpodctl.log" "$STUB/ssh.log" "$STUB/rsync.log"
  [ "$status" -eq 1 ]
}

@test "up refuses a second pod, bad hours, a run with no input and an env file others can read" {
  pod_up
  run "$PLACE" up
  [ "$status" -ne 0 ]
  [[ "$output" == *"already up: pod pod123"* ]] || false
  rm "$WS_STATE/id"
  local h
  for h in 0 00 08; do
    WS_CONF_HOURS="$h" run "$PLACE" up
    [ "$status" -ne 0 ]
    [[ "$output" == *"hours must be"* ]] || false
    [ ! -e "$WS_STATE/started" ]
  done
  WS_CONF_KIND=run run "$PLACE" up
  [ "$status" -ne 0 ]
  [[ "$output" == *"no input"* ]] || false
  chmod 644 "$HOME/.config/vibe/places/runpod.env"
  run "$PLACE" up
  [ "$status" -ne 0 ]
  [[ "$output" == *"others can read it"* ]] || false
  [ ! -e "$STUB/runpodctl.log" ]
}

@test "tick past the limit with a bad env file: one delete per tick, the id stays until the pod is gone" {
  pod_up
  echo $(($(date +%s) - 1)) >"$WS_STATE/limit"
  chmod 644 "$HOME/.config/vibe/places/runpod.env"
  echo 'RUNPOD_API_KEY = spaced' >>"$HOME/.config/vibe/places/runpod.env"
  touch "$STUB/delete-fail"
  run "$PLACE" tick
  [ "$status" -ne 0 ]
  [ "$(grep -c '^pod delete pod123' "$STUB/runpodctl.log")" -eq 1 ]
  [ "$(cat "$WS_STATE/id")" = pod123 ]
  [ -e "$STUB/pod" ]
  rm "$STUB/delete-fail"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ ! -e "$WS_STATE/id" ]
  [ ! -e "$STUB/pod" ]
}

@test "down: a RUNPOD_WAIT or RUNPOD_POLL that is no number falls back to its default and deletes" {
  pod_up
  printf '%s\n' RUNPOD_WAIT=10m RUNPOD_POLL=1s >>"$HOME/.config/vibe/places/runpod.env"
  run "$PLACE" down
  [ "$status" -eq 0 ]
  [[ "$output" == *"RUNPOD_WAIT='10m' is no whole number"* ]] || false
  [[ "$output" == *"RUNPOD_POLL='1s' is no number"* ]] || false
  grep -qx 'pod delete pod123 --output json' "$STUB/runpodctl.log"
  [ ! -e "$STUB/pod" ]
  [ ! -e "$WS_STATE/id" ]
}

@test "down: a failed pull still deletes the pod" {
  pod_up
  touch "$STUB/rsync-fail"
  run "$PLACE" down
  [ "$status" -ne 0 ]
  [[ "$output" == *"pull failed"* ]] || false
  grep -qx 'pod delete pod123 --output json' "$STUB/runpodctl.log"
  [ ! -e "$STUB/pod" ]
  [ ! -e "$WS_STATE/id" ]
}

@test "tick: past the limit deletes the pod" {
  pod_up
  echo $(($(date +%s) - 1)) >"$WS_STATE/limit"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  grep -qx 'pod delete pod123 --output json' "$STUB/runpodctl.log"
  [ ! -e "$STUB/pod" ]
  [ ! -e "$WS_STATE/id" ]
}

@test "tick: pulls when pulled is 10 min old or more, not before" {
  local now
  pod_up
  now="$(date +%s)"
  echo $((now + 3600)) >"$WS_STATE/limit"
  echo $((now - 590)) >"$WS_STATE/pulled"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ ! -e "$STUB/rsync.log" ]
  echo $((now - 600)) >"$WS_STATE/pulled"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  grep -q "root@203.0.113.7:/ws/data/ $WS_STATE/data/" "$STUB/rsync.log"
  grep -q "root@203.0.113.7:/ws/out/ $WS_STATE/out/" "$STUB/rsync.log"
  [ "$(cat "$WS_STATE/pulled")" -ge "$now" ]
  [ -e "$STUB/pod" ]
}

@test "tick, and down past the limit, stop a pull after 5 min; down before the limit has no bound" {
  local now
  pod_up
  now="$(date +%s)"
  echo $((now + 3600)) >"$WS_STATE/limit"
  run "$PLACE" down
  [ "$status" -eq 0 ]
  [ "$(grep -c -- '--timeout=60 ' "$STUB/rsync.log")" -eq 2 ]
  run grep -q -- --stop-after "$STUB/rsync.log"
  [ "$status" -eq 1 ]
  rm "$STUB/rsync.log"
  pod_up
  echo $((now - 600)) >"$WS_STATE/pulled"
  run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ "$(grep -c -- '--stop-after=5 root@' "$STUB/rsync.log")" -eq 2 ]
  [ "$(grep -c -- '--partial-dir=.rsync-partial ' "$STUB/rsync.log")" -eq 2 ]
  rm "$STUB/rsync.log"
  echo $((now - 1)) >"$WS_STATE/limit"
  run "$PLACE" down
  [ "$status" -eq 0 ]
  [ "$(grep -c -- '--stop-after=5 root@' "$STUB/rsync.log")" -eq 2 ]
}

@test "up: a TERM in the wait for ssh deletes the pod" {
  local pid rc=0
  echo initializing >"$STUB/status"
  printf '%s\n' RUNPOD_GPU_ID=gpu RUNPOD_WAIT=30 RUNPOD_POLL=0.1 >"$HOME/.config/vibe/places/runpod.env"
  "$PLACE" up >/dev/null 2>&1 3>&- &
  pid=$!
  for _ in $(seq 100); do
    if grep -q '^pod get' "$STUB/runpodctl.log" 2>/dev/null; then break; fi
    sleep 0.1
  done
  kill -TERM "$pid"
  wait "$pid" || rc=$?
  [ "$rc" -eq 1 ]
  grep -qx 'pod delete pod123 --output json' "$STUB/runpodctl.log"
  [ ! -e "$STUB/pod" ]
  [ ! -e "$WS_STATE/id" ]
}

@test "url reuses a live tunnel; down closes it" {
  pod_up
  touch "$STUB/tunnel-up"
  run "$PLACE" url
  [ "$status" -eq 0 ]
  [ "$output" = "http://100.64.0.1:20999" ]
  run grep -q -- ' -M ' "$STUB/ssh.log"
  [ "$status" -eq 1 ]
  run "$PLACE" down
  [ "$status" -eq 0 ]
  grep -q -- "-S $WS_STATE/tunnel.sock -O exit pod" "$STUB/ssh.log"
}

@test "tick re-opens a dead tunnel of a service, and leaves a live one" {
  pod_up
  echo $(($(date +%s) + 3600)) >"$WS_STATE/limit"
  date +%s >"$WS_STATE/pulled"
  WS_CONF_KIND=service run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ "$(grep -c -- ' -M ' "$STUB/ssh.log")" -eq 1 ]
  touch "$STUB/tunnel-up"
  WS_CONF_KIND=service run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ "$(grep -c -- ' -M ' "$STUB/ssh.log")" -eq 1 ]
  rm "$STUB/tunnel-up"
  WS_CONF_KIND=run run "$PLACE" tick
  [ "$status" -eq 0 ]
  [ "$(grep -c -- ' -M ' "$STUB/ssh.log")" -eq 1 ]
}

@test "pull: the out copy never starts once the 5 min bound is used up" {
  pod_up
  # date: a fixed clock that jumps 6 min once rsync has run.
  cat >"$STUB/date" <<'EOF'
#!/bin/sh
d="$(dirname "$0")"
t=1000000
[ ! -f "$d/rsync.log" ] || t=$((t + 360))
echo "$t"
EOF
  chmod +x "$STUB/date"
  echo 1003600 >"$WS_STATE/limit"
  echo 999400 >"$WS_STATE/pulled"
  run "$PLACE" tick
  [ "$status" -eq 1 ]
  [[ "$output" == *"pull ran past its bound of 300s"* ]] || false
  [ "$(grep -c '' "$STUB/rsync.log")" -eq 1 ]
  grep -q -- '--stop-after=5 root@203.0.113.7:/ws/data/' "$STUB/rsync.log"
  [ "$(cat "$WS_STATE/pulled")" -eq 999400 ]
}

@test "exec passes stdout and the exit code; url tunnels the first port to the tailnet address" {
  pod_up
  run "$PLACE" exec steer "it's late"
  [ "$status" -eq 7 ]
  [ "$output" = "script ran" ]
  grep -qF "exec /ws/scripts/'steer' 'it'\\''s late'" "$STUB/ssh.log"
  grep -q -- '-o ServerAliveCountMax=20 ' "$STUB/ssh.log"
  local t0
  t0="$(date +%s)"
  run "$PLACE" url
  [ $(($(date +%s) - t0)) -lt 2 ]
  [ "$status" -eq 0 ]
  [ "$output" = "http://100.64.0.1:20999" ]
  grep -q -- '-L 100.64.0.1:20999:localhost:20999 root@203.0.113.7' "$STUB/ssh.log"
}
