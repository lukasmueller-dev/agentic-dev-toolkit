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
    "o-gpu +bad conf: gpu=maybe: yes or no" "q-noconf +bad conf: no workspace.conf"; do
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
  conf i kind=service places=turing "secrets=API_KEY lower"
  conf j kind=service places=turing ports=80,ui
  conf p kind=run places=turing result=pr
  run "$VIBE" ws list
  [ "$status" -eq 1 ]
  [ "$output" = "$(printf '%-16s bad conf: %s\n' e "kind=job: service or run" g "commit=abc: 40 hex" \
    h "hours=0: a whole number above 0" i "bad env name lower" j "bad port ui" p "result=pr: branch or folder")" ]
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
  for bad in ../x .. .; do
    run "$VIBE" ws status "$bad"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no instance '$bad'"* ]] || false
  done
}
