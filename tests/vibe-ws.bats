#!/usr/bin/env bats
#
# vibe ws — the workspaces folder (VIBE_WORKSPACES, a temp one per test) and
# the instance state files under $XDG_STATE_HOME/vibe/workspaces.

load helper

VIBE="$REPO_ROOT/bin/vibe"

setup() {
  export VIBE_WORKSPACES="$BATS_TEST_TMPDIR/workspaces" XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export VIBE_TOOLKIT="$BATS_TEST_TMPDIR/no-toolkit"
  STATES="$XDG_STATE_HOME/vibe/workspaces"
  mkdir -p "$VIBE_WORKSPACES/_places" "$HOME/.config/vibe"
  echo server >"$HOME/.config/vibe/role"
  echo '#!/usr/bin/env bash' >"$VIBE_WORKSPACES/_places/turing"
  echo '# Workspaces' >"$VIBE_WORKSPACES/README.md"
  HEX=0123456789abcdef0123456789abcdef01234567
}

# conf NAME LINE... — write NAME/workspace.conf, one LINE per line.
conf() {
  mkdir -p "$VIBE_WORKSPACES/$1"
  printf '%s\n' "${@:2}" >"$VIBE_WORKSPACES/$1/workspace.conf"
}

# good NAME KIND [LINE...] — a conf that obeys the contract, plus LINEs.
good() {
  local r=()
  if [ "$2" = run ]; then r=(result=branch); fi
  conf "$1" "# a comment" "" label=Tool role="Does one thing." "kind=$2" places=turing,runpod \
    image=ghcr.io/x/tool "commit=$HEX" hours=4 "secrets=API_KEY OTHER_KEY" ports=8080,8081 "${r[@]+"${r[@]}"}" "${@:3}"
}

@test "ws list: one line per tool; _places and files are no workspace" {
  good svc service gpu=yes
  good loop run
  run "$VIBE" ws list
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == "loop "*" run "*" gpu=no "*" turing,runpod "*" Tool: Does one thing." ]] || false
  [[ "${lines[1]}" == "svc "*" service gpu=yes turing,runpod "*" Tool: Does one thing." ]] || false
}

@test "ws list: a bad conf prints why and exits 1; the good ones still list" {
  good ok run
  conf a-nokind places=turing
  conf b-noplaces kind=service
  good c-key service gpus=yes
  good d-twice service gpu=yes gpu=no
  conf f-place kind=service places=turing,aws
  good k-svcresult service result=folder
  conf l-runnoresult kind=run places=vast
  conf m-line kind=service places=turing "just text"
  good n-runs service runs=vm
  good o-gpu service gpu=maybe
  mkdir -p "$VIBE_WORKSPACES/q-noconf" "$VIBE_WORKSPACES/Upper"
  cp "$VIBE_WORKSPACES/ok/workspace.conf" "$VIBE_WORKSPACES/Upper/"
  run "$VIBE" ws list
  [ "$status" -eq 1 ]
  [ "$(grep -c 'bad conf' <<<"$output")" -eq 12 ]
  grep -qE '^ok +run ' <<<"$output"
  for want in "Upper +bad conf: bad name" "a-nokind +bad conf: no kind" "b-noplaces +bad conf: no places" \
    "c-key +bad conf: unknown key gpus" "d-twice +bad conf: twice: gpu" "f-place +bad conf: unknown place aws" \
    "k-svcresult +bad conf: result on a service" "l-runnoresult +bad conf: kind=run needs result" \
    "m-line +bad conf: not key=value: just text" "n-runs +bad conf: runs=vm: container or host" \
    "o-gpu +bad conf: gpu=maybe: yes or no" "q-noconf +bad conf: no readable workspace.conf"; do
    grep -qE "^$want" <<<"$output" || {
      echo "missing: $want"
      false
    }
  done
}

@test "ws list: each value check names the value" {
  conf e kind=job places=turing
  conf g kind=service places=turing commit=abc
  conf h kind=service places=turing hours=0
  conf h2 kind=service places=turing hours=08
  conf i kind=service places=turing "secrets=API_KEY lower"
  conf j kind=service places=turing ports=80,ui
  conf p kind=run places=turing result=pr
  run "$VIBE" ws list
  [ "$status" -eq 1 ]
  [ "$output" = "$(printf '%-16s bad conf: %s\n' e "kind=job: service or run" g "commit=abc: 40 hex" \
    h "hours=0: a whole number above 0" h2 "hours=08: a whole number above 0" i "bad env name lower" j "bad port ui" p "result=pr: branch or folder")" ]
}

@test "ws list: an unreadable conf is a bad conf; the next tool still lists" {
  [ "$(id -u)" -ne 0 ] || skip "root reads a mode 000 file"
  good a-unread service
  good b-next service
  chmod 000 "$VIBE_WORKSPACES/a-unread/workspace.conf"
  run "$VIBE" ws list
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == "a-unread "*"bad conf: no readable workspace.conf" ]] || false
  [[ "${lines[1]}" == "b-next "*" service "* ]] || false
}

@test "ws list: no folder stops with its path" {
  rm -rf "$VIBE_WORKSPACES"
  run "$VIBE" ws list
  [ "$status" -ne 0 ]
  [[ "$output" == *"no folder $VIBE_WORKSPACES"* ]] || false
}

@test "ws list: every workspace in the repo obeys the contract" {
  unset VIBE_WORKSPACES
  run "$VIBE" ws list
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "ws list and status: a client runs them on the server over ssh" {
  printf '#!/bin/sh\necho "$@" >>"%s/ssh.log"\n' "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/ssh"
  chmod +x "$BATS_TEST_TMPDIR/ssh"
  echo "client turing" >"$HOME/.config/vibe/role"
  PATH="$BATS_TEST_TMPDIR:$PATH" "$VIBE" ws list
  PATH="$BATS_TEST_TMPDIR:$PATH" "$VIBE" ws status svc
  [ "$(cat "$BATS_TEST_TMPDIR/ssh.log")" = "$(printf '%s\n' "turing \$HOME/bin/vibe ws list" "turing \$HOME/bin/vibe ws status svc")" ]
}

@test "ws status: up, past limit and down from the state files alone" {
  local now
  now="$(date +%s)"
  mkdir -p "$STATES/svc" "$STATES/loop-20261115-1" "$STATES/old"
  echo turing >"$STATES/svc/place"
  echo c1 >"$STATES/svc/id"
  echo $((now + 3600)) >"$STATES/svc/limit"
  echo http://turing:8080 >"$STATES/svc/url"
  echo runpod >"$STATES/loop-20261115-1/place"
  echo p1 >"$STATES/loop-20261115-1/id"
  echo $((now - 60)) >"$STATES/loop-20261115-1/limit"
  echo turing >"$STATES/old/place"
  echo http://turing:9090 >"$STATES/old/url"
  run "$VIBE" ws status
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [[ "${lines[0]}" == "loop-20261115-1 "*" past limit runpod  until "* ]] || false
  [[ "${lines[1]}" == "old "*" down       turing" ]] || false
  [[ "${lines[2]}" == "svc "*" up "*" turing  until "*" http://turing:8080" ]] || false
  run "$VIBE" ws status svc
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == "svc "*" up "* ]] || false
}

@test "ws status: an unknown instance stops; no instance prints nothing" {
  run "$VIBE" ws status
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$VIBE" ws status nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"no instance 'nope'"* ]] || false
  mkdir -p "$STATES"
  for bad in ../x .. . ''; do
    run "$VIBE" ws status "$bad"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no instance '$bad'"* ]] || false
  done
}

# stubs — the real turing place with stub docker, tailscale and gpu-queue in $S (logs, containers/).
# $S/fail-run, fail-secrets, fail-cp, fail-rm: that docker step fails; $S/slow-cp: a copy out takes 1 s;
# $S/exit-<script>: its exit; $S/hang-<script>: it sleeps 5 s; $S/gpu-busy: the lock waits.
stubs() {
  S="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$S/containers" "$HOME/.config/vibe/workspaces"
  cp "$REPO_ROOT/workspaces/_places/turing" "$VIBE_WORKSPACES/_places/turing"
  chmod +x "$VIBE_WORKSPACES/_places/turing"
  cat >"$S/docker" <<STUB
#!/bin/sh
S="$S"
STUB
  cat >>"$S/docker" <<'STUB'
echo "$*" >>"$S/docker.log"
cmd="$1"
shift
case "$cmd" in
  run)
    name="" prev=""
    for a; do
      [ "$prev" != --name ] || name="$a"
      prev="$a"
    done
    echo "$*" >"$S/containers/$name"
    [ ! -e "$S/fail-run" ] || { echo "docker: port is already allocated" >&2; exit 125; }
    echo "$name"
    ;;
  exec)
    i=0
    while :; do case "$1" in -i) i=1 && shift ;; -*) shift 2 ;; *) break ;; esac; done
    [ -e "$S/containers/$1" ] || { echo "No such container: $1" >&2; exit 1; }
    if [ "$i" = 1 ]; then
      [ ! -e "$S/fail-secrets" ] || exit 1
      cat >"$S/secrets.got"
      exit 0
    fi
    shift 5
    echo "$*" >>"$S/exec.log"
    [ ! -e "$S/hang-$1" ] || exec sleep 5
    exit "$(cat "$S/exit-$1" 2>/dev/null || echo 0)"
    ;;
  cp)
    case "$1" in
      *:/ws/*)
        [ ! -e "$S/slow-cp" ] || sleep 1
        [ ! -e "$S/fail-cp" ] && [ -e "$S/containers/${1%%:*}" ] || { echo "No such container" >&2; exit 1; }
        mkdir -p "$2" && echo "$1" >"$2/from-container"
        ;;
    esac
    ;;
  rm)
    [ ! -e "$S/fail-rm" ] || exit 1
    rm -f "$S/containers/$2"
    ;;
  inspect) [ -e "$S/containers/$1" ] ;;
esac
STUB
  printf '#!/bin/sh\necho 100.64.0.1\n' >"$S/tailscale"
  cat >"$S/gpu-queue" <<STUB
#!/bin/sh
[ "\$1" = lock ] && shift && shift
while [ -e "$S/gpu-busy" ]; do sleep 0.1; done
echo \$\$ >"$S/gpu.pid"
exec "\$@"
STUB
  chmod +x "$S/docker" "$S/tailscale" "$S/gpu-queue"
  PATH="$S:$PATH"
  export VIBE_WS_POLL=0.1
}

# secrets NAME — a mode 600 env file that sets the secrets of good().
secrets() {
  printf 'API_KEY=secret-value\nOTHER_KEY=other-value\n' >"$HOME/.config/vibe/workspaces/$1.env"
  chmod 600 "$HOME/.config/vibe/workspaces/$1.env"
}

# within5 CMD... — CMD succeeds within 5 s.
within5() {
  local n=0
  until "$@"; do
    n=$((n + 1))
    [ "$n" -lt 50 ] || return 1
    sleep 0.1
  done
}
dead() { ! kill -0 "$1" 2>/dev/null; }

@test "ws start: refuses a missing secret and an env file that others can read; no docker call" {
  stubs
  good svc service
  local f="$HOME/.config/vibe/workspaces/svc.env"
  run "$VIBE" ws start svc
  [ "$status" -ne 0 ]
  [[ "$output" == *"svc needs API_KEY OTHER_KEY: write KEY=VALUE lines to $f, mode 600"* ]] || false
  secrets svc
  for m in 644 640; do
    chmod "$m" "$f"
    run "$VIBE" ws start svc
    [ "$status" -ne 0 ]
    [[ "$output" == *"$f: others can read it — chmod 600 $f"* ]] || false
  done
  printf 'API_KEY=a\nOTHER_KEY=\n' >"$f"
  chmod 600 "$f"
  run "$VIBE" ws start svc
  [ "$status" -ne 0 ]
  [[ "$output" == *"$f does not set: OTHER_KEY"* ]] || false
  [ ! -e "$S/docker.log" ]
}

@test "ws start and stop: a service on turing in a container; secrets on stdin; data back at stop" {
  stubs
  good svc service
  secrets svc
  run "$VIBE" ws start svc
  [ "$status" -eq 0 ]
  [[ "$output" == *"svc up — http://100.64.0.1:8080" ]] || false
  c="$(cat "$S/containers/ws-svc")"
  [[ "$c" == "-d --name ws-svc -p 100.64.0.1:8080:8080 -p 100.64.0.1:8081:8081 -v $VIBE_WORKSPACES/svc:/ws/scripts:ro -v $STATES/svc/in:/ws/in:ro "* ]] || false
  [[ "$c" == *" -e WS_PLACE=turing -e WS_HOURS=4 ghcr.io/x/tool:$HEX sleep infinity" ]] || false
  [[ "$c" != *--gpus* ]] || false
  cmp "$S/secrets.got" "$HOME/.config/vibe/workspaces/svc.env"
  [ "$(grep -c -e secret-value -e other-value "$S/docker.log")" -eq 0 ]
  [ "$(cat "$S/exec.log")" = start ]
  [ "$(cat "$STATES/svc/place")" = turing ]
  [ "$(cat "$STATES/svc/limit")" -gt "$(date +%s)" ]
  run "$VIBE" ws status svc
  [[ "$output" == "svc "*" up "*" http://100.64.0.1:8080" ]] || false
  run "$VIBE" ws start svc
  [ "$status" -ne 0 ]
  [[ "$output" == *"svc is up — vibe ws stop svc first"* ]] || false
  run "$VIBE" ws stop svc
  [ "$status" -eq 0 ]
  [ "$output" = "svc down" ]
  [ "$(tail -n 1 "$S/exec.log")" = stop ]
  [ ! -e "$S/containers/ws-svc" ]
  [ "$(cat "$STATES/svc/data/from-container")" = "ws-svc:/ws/data" ]
  [ "$(cat "$STATES/svc/out/from-container")" = "ws-svc:/ws/out" ]
  run "$VIBE" ws status svc
  [[ "$output" == "svc "*" down "*" turing" ]] || false
  run "$VIBE" ws stop svc
  [ "$status" -ne 0 ]
  [[ "$output" == *"svc is down"* ]] || false
}

@test "ws start: a failed up or a failed start script leaves no container" {
  stubs
  good svc service
  secrets svc
  for fail in fail-run fail-secrets; do
    touch "$S/$fail"
    run "$VIBE" ws start svc
    [ "$status" -ne 0 ]
    [[ "$output" == *"up of svc failed"* ]] || false
    [ -z "$(ls "$S/containers")" ]
    [ ! -e "$STATES/svc/id" ]
    rm "$S/$fail"
  done
  echo 1 >"$S/exit-start"
  run "$VIBE" ws start svc
  [ "$status" -ne 0 ]
  [[ "$output" == *"start of svc failed — it is down again"* ]] || false
  [ -z "$(ls "$S/containers")" ]
  run "$VIBE" ws status svc
  [[ "$output" == "svc "*" down "* ]] || false
}

@test "ws start: a gpu=yes service holds the lock until stop" {
  stubs
  good svc service gpu=yes
  secrets svc
  run "$VIBE" ws start svc
  [ "$status" -eq 0 ]
  [[ "$output" == "svc up — http://100.64.0.1:8080" ]] || false
  [[ "$(cat "$S/containers/ws-svc")" == *" --gpus all "* ]] || false
  pid="$(cat "$S/gpu.pid")"
  sleep 0.5
  kill -0 "$pid"
  run "$VIBE" ws stop svc
  [ "$status" -eq 0 ]
  within5 dead "$pid"
  [ ! -e "$S/containers/ws-svc" ]
}

@test "ws start: a gpu=yes service waits for a busy lock; stop ends the wait, a free lock brings it up" {
  stubs
  good svc service gpu=yes
  secrets svc
  touch "$S/gpu-busy"
  run "$VIBE" ws start svc
  [ "$status" -eq 0 ]
  [ "$output" = "svc waits for the GPU — vibe ws status svc" ]
  run "$VIBE" ws status svc
  [[ "$output" == "svc "*" waits for the GPU turing" ]] || false
  run "$VIBE" ws stop svc
  [ "$output" = "svc stopped — it waited for the GPU" ]
  run "$VIBE" ws status svc
  [[ "$output" == "svc "*" down "* ]] || false
  [ ! -e "$S/docker.log" ]
  "$VIBE" ws start svc
  rm "$S/gpu-busy"
  within5 grep -qx 'vibe: holds the GPU' "$STATES/svc/hold.log"
  run "$VIBE" ws status svc
  [[ "$output" == "svc "*" up "* ]] || false
  pid="$(cat "$S/gpu.pid")"
  "$VIBE" ws stop svc
  within5 dead "$pid"
}

@test "ws tick: runs the stop script past the limit, then removes the container; pulls one 10 min after its last pull" {
  stubs
  good old service
  good new service
  secrets old
  secrets new
  "$VIBE" ws start old
  "$VIBE" ws start new
  echo $(($(date +%s) - 1)) >"$STATES/old/limit"
  echo $(($(date +%s) - 600)) >"$STATES/new/pulled"
  run "$VIBE" ws tick
  [ "$status" -eq 0 ]
  [ "$(grep -c '^stop' "$S/exec.log")" -eq 1 ]
  [ ! -e "$S/containers/ws-old" ]
  [ ! -e "$STATES/old/id" ]
  [ -f "$STATES/old/data/from-container" ]
  [ -e "$S/containers/ws-new" ]
  [ "$(cat "$STATES/new/pulled")" -ge $(($(date +%s) - 5)) ]
  [ -f "$STATES/new/data/from-container" ]
  run "$VIBE" ws status
  [[ "${lines[0]}" == "new "*" up "* ]] || false
  [[ "${lines[1]}" == "old "*" down "* ]] || false
}

@test "ws tick and stop at once: each pull finishes, data/ and out/ stay" {
  stubs
  good svc service
  secrets svc
  "$VIBE" ws start svc
  touch "$S/slow-cp"
  "$VIBE" ws tick 3>&- &
  sleep 0.3
  run "$VIBE" ws stop svc
  wait
  [ "$status" -eq 0 ]
  [ "$(grep -c '^cp ws-svc:/ws/data ' "$S/docker.log")" -eq 2 ]
  [ -f "$STATES/svc/data/from-container" ]
  [ -f "$STATES/svc/out/from-container" ]
  [ -z "$(find "$STATES/svc" -maxdepth 1 -name '.*' ! -name . ! -name ..)" ]
}

@test "ws tick: the runner pass ticks the instances" {
  stubs
  good old service
  secrets old
  "$VIBE" ws start old
  echo $(($(date +%s) - 1)) >"$STATES/old/limit"
  "$VIBE" queue run --claude --drain >/dev/null 2>&1
  within5 test ! -e "$S/containers/ws-old"
  [ ! -e "$STATES/old/id" ]
}

@test "ws build: the image at its pinned commit, tagged with it; runs=host has none" {
  stubs
  good svc service
  good h service runs=host
  run "$VIBE" ws build svc
  [ "$status" -eq 0 ]
  [ "$(cat "$S/docker.log")" = "build -t ghcr.io/x/tool:$HEX --build-arg COMMIT=$HEX $VIBE_WORKSPACES/svc" ]
  run "$VIBE" ws build h
  [ "$status" -ne 0 ]
  [[ "$output" == *"h runs on the host: no image to build"* ]] || false
}

@test "ws start: refuses kind=run, a bad conf and no workspace" {
  stubs
  good loop run
  conf bad kind=service
  run "$VIBE" ws start loop
  [ "$status" -ne 0 ]
  [[ "$output" == *"loop is kind=run: the queue runs it as a job"* ]] || false
  run "$VIBE" ws start bad
  [ "$status" -ne 0 ]
  [[ "$output" == *"bad: bad conf: no places"* ]] || false
  for n in nope _places ../x ''; do
    run "$VIBE" ws start "$n"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no workspace '$n'"* ]] || false
  done
  [ ! -e "$S/docker.log" ]
}

@test "ws start and stop: runs=host runs the scripts on the host; no stop script is no error" {
  stubs
  conf h kind=service runs=host places=turing ports=3000
  # shellcheck disable=SC2016  # the stub expands them
  printf '#!/bin/sh\necho "start $WS_NAME $WS_INSTANCE $WS_PLACE $PWD" >>"%s/host.log"\n' "$S" >"$VIBE_WORKSPACES/h/start"
  chmod +x "$VIBE_WORKSPACES/h/start"
  run "$VIBE" ws start h
  [ "$status" -eq 0 ]
  [ "$output" = "h up — http://100.64.0.1:3000" ]
  [ "$(cat "$S/host.log")" = "start h h turing $STATES/h" ]
  run "$VIBE" ws stop h
  [ "$status" -eq 0 ]
  [ "$output" = "h down" ]
  run "$VIBE" ws status h
  [[ "$output" == "h "*" down "* ]] || false
  [ ! -e "$S/docker.log" ]
}

@test "ws tick: a runs=host tool past its limit gets its stop script on the host" {
  stubs
  conf h kind=service runs=host places=turing hours=1
  for v in start stop; do
    printf '#!/bin/sh\necho %s >>"%s/host.log"\n' "$v" "$S" >"$VIBE_WORKSPACES/h/$v"
    chmod +x "$VIBE_WORKSPACES/h/$v"
  done
  "$VIBE" ws start h
  echo $(($(date +%s) - 1)) >"$STATES/h/limit"
  run "$VIBE" ws tick
  [ "$status" -eq 0 ]
  [ "$(cat "$S/host.log")" = "$(printf 'start\nstop')" ]
  run "$VIBE" ws status h
  [[ "$output" == "h "*" down "* ]] || false
}

@test "ws stop: a container down cannot remove keeps its id and the GPU lock; a failed pull still removes it" {
  stubs
  good svc service gpu=yes
  secrets svc
  "$VIBE" ws start svc
  pid="$(cat "$S/gpu.pid")"
  touch "$S/fail-rm"
  run "$VIBE" ws stop svc
  [ "$status" -ne 0 ]
  [[ "$output" == *"container ws-svc still exists"* ]] || false
  [[ "$output" == *"down of svc failed"* ]] || false
  [ -s "$STATES/svc/id" ]
  [ -e "$S/containers/ws-svc" ]
  sleep 0.3
  kill -0 "$pid"
  rm "$S/fail-rm"
  touch "$S/fail-cp"
  run "$VIBE" ws stop svc
  [ "$status" -ne 0 ]
  [[ "$output" == *"pull failed; removing ws-svc anyway"* ]] || false
  [ ! -e "$S/containers/ws-svc" ]
  [ ! -e "$STATES/svc/id" ]
  within5 dead "$pid"
}

@test "ws start: a start script past its time fails the start, leaves no container and frees the GPU lock" {
  { command -v timeout || command -v gtimeout; } >/dev/null 2>&1 || skip "no timeout(1)"
  stubs
  export VIBE_WS_START_SECS=1
  good svc service
  good gsv service gpu=yes
  secrets svc
  secrets gsv
  touch "$S/hang-start"
  run "$VIBE" ws start svc
  [ "$status" -ne 0 ]
  [[ "$output" == *"start of svc ran past 1 s — it is down again"* ]] || false
  run "$VIBE" ws start gsv
  [ "$status" -ne 0 ]
  [[ "$output" == *"start of gsv ran past 1 s — it is down again"* ]] || false
  [ -z "$(ls "$S/containers")" ]
  within5 dead "$(cat "$S/gpu.pid")"
}
