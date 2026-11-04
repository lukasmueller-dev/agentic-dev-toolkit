#!/usr/bin/env bats
#
# vibe-web — the queue page's write endpoint. Each test starts the server on a
# free port and talks to it with curl, as tailscale serve would.

load helper

setup() {
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  mkdir -p "$HOME/.config/vibe" "$XDG_CONFIG_HOME/vibe" && echo server >"$HOME/.config/vibe/role"
  Q="$XDG_STATE_HOME/vibe"
  PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
  printf 'web_port=%s\nweb_login=me@example.com\n' "$PORT" >"$XDG_CONFIG_HOME/vibe/queue.conf"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"
  printf '#!/bin/sh\necho "$*" >>"%s/systemctl.log"\n' "$STUBS" >"$STUBS/systemctl"
  chmod +x "$STUBS/systemctl"
  PATH="$STUBS:$PATH"
  "$REPO_ROOT/bin/vibe-web" 2>"$BATS_TEST_TMPDIR/web.log" &
  WEB_PID=$!
  curl -s -o /dev/null --retry 30 --retry-connrefused --retry-delay 1 "http://127.0.0.1:$PORT/"
}

teardown() {
  kill "$WEB_PID" 2>/dev/null || true
}

# req METHOD PATH [CURL ARG...] — the HTTP code, then the body.
req() {
  local m="$1" p="$2"
  shift 2
  curl -s -w '\n%{http_code}' -X "$m" "$@" "http://127.0.0.1:$PORT$p"
}

# post PATH [CURL ARG...] — a write as the page sends it, by the right login.
post() {
  local p="$1"
  shift
  req POST "$p" -H 'Tailscale-User-Login: me@example.com' -H "Origin: https://127.0.0.1:$PORT" \
    -H 'Content-Type: application/json' -d '{}' "$@"
}

@test "vibe-web: the right login pauses and resumes; one log line per write; the page shows it" {
  run post /queue/api/pause
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  [ -e "$Q/paused" ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 1 ]
  grep -q $'\tme@example.com\tvibe queue pause\t0$' "$Q/actions.log"
  grep -q 'data-act="resume"' "$Q/web/index.html"
  grep -q 'vibe queue pause' "$Q/web/index.html"
  run post /resume
  [ "${lines[1]}" = 200 ]
  [ ! -e "$Q/paused" ]
  [ "$(wc -l <"$Q/actions.log" | tr -d ' ')" = 2 ]
  grep -q 'data-act="pause"' "$Q/web/index.html"
}

@test "vibe-web: a wrong or absent login, a foreign Origin, a non-JSON body get 403 and change nothing" {
  run req POST /queue/api/pause -H 'Tailscale-User-Login: other@example.com' -H "Origin: https://127.0.0.1:$PORT" -H 'Content-Type: application/json' -d '{}'
  [ "${lines[1]}" = 403 ]
  run req POST /queue/api/pause -H "Origin: https://127.0.0.1:$PORT" -H 'Content-Type: application/json' -d '{}'
  [ "${lines[1]}" = 403 ]
  run req POST /queue/api/pause -H 'Tailscale-User-Login: me@example.com' -H 'Origin: https://evil.example.com' -H 'Content-Type: application/json' -d '{}'
  [ "${lines[1]}" = 403 ]
  run post /queue/api/pause -H 'Origin: https://evil.example.com'
  [ "${lines[1]}" = 403 ]
  run req POST /queue/api/pause -H 'Tailscale-User-Login: me@example.com' -H 'Content-Type: application/json' -d '{}'
  [ "${lines[1]}" = 403 ]
  run req POST /queue/api/pause -H 'Tailscale-User-Login: me@example.com' -H "Origin: https://127.0.0.1:$PORT" -d 'a=1'
  [ "${lines[1]}" = 403 ]
  run post /queue/api/pause -d 'not json'
  [ "${lines[1]}" = 403 ]
  run post /queue/api/pause -d '[1]'
  [ "${lines[1]}" = 403 ]
  run req GET /queue/api/pause -H 'Tailscale-User-Login: me@example.com'
  [ "${lines[1]}" = 404 ]
  [ ! -e "$Q/paused" ]
  [ ! -e "$Q/actions.log" ]
}

@test "vibe-web: no web_login in queue.conf: 403 for everyone" {
  printf 'web_port=%s\n' "$PORT" >"$XDG_CONFIG_HOME/vibe/queue.conf"
  run post /queue/api/pause
  [ "${lines[1]}" = 403 ]
  run req GET /queue/api/whoami -H 'Tailscale-User-Login: me@example.com'
  [ "${lines[1]}" = 403 ]
  [ ! -e "$Q/paused" ]
}

@test "vibe-web: GET whoami returns the login, with and without the mount prefix" {
  run req GET /queue/api/whoami -H 'Tailscale-User-Login: me@example.com'
  [ "${lines[0]}" = '{"login": "me@example.com"}' ]
  [ "${lines[1]}" = 200 ]
  run req GET /whoami -H 'Tailscale-User-Login: me@example.com'
  [ "${lines[1]}" = 200 ]
  run req GET /queue/api/whoami
  [ "${lines[1]}" = 403 ]
}

@test "vibe-web: an unknown route is 404 and runs nothing" {
  run post /queue/api/nope
  [ "${lines[1]}" = 404 ]
  [ ! -e "$Q/actions.log" ]
}

@test "vibe-web: the unit runs only on a server" {
  grep -q '^ExecStart=%h/bin/vibe-web$' "$REPO_ROOT/claude/systemd/vibe-web.service"
  grep -q '^ExecCondition=.*grep -qx server %h/.config/vibe/role' "$REPO_ROOT/claude/systemd/vibe-web.service"
}

@test "vibe queue page: writes the page; buttons hidden until whoami" {
  run "$REPO_ROOT/bin/vibe" queue page
  [ "$status" -eq 0 ]
  grep -q 'data-act="pause"' "$Q/web/index.html"
  grep -q "fetch(api + 'whoami'" "$Q/web/page.js"
  grep -qF "closest('#queue button[data-act]')" "$Q/web/page.js"
  grep -q 'body.can .acts' "$Q/web/index.html"
}

@test "vibe queue page: CSP allows only page.js, so HTML in a note runs no script" {
  run "$REPO_ROOT/bin/vibe" queue page
  [ "$status" -eq 0 ]
  grep -q "Content-Security-Policy\" content=\"default-src 'self'; script-src 'self';" "$Q/web/index.html"
  grep -q '<script src="/queue/page.js"></script>' "$Q/web/index.html"
  [ "$(grep -c '<script' "$Q/web/index.html")" = 1 ]
  run grep -q "script-src[^;]*unsafe" "$Q/web/index.html"
  [ "$status" -eq 1 ]
}

@test "vibe-web: a bad Content-Length gets 403; a stalled client blocks nobody" {
  run post /queue/api/pause -H 'Content-Length: -1' --max-time 5
  [ "${lines[1]}" = 403 ]
  run post /queue/api/pause -H 'Content-Length: 70000' --max-time 5
  [ "${lines[1]}" = 403 ]
  python3 -c '
import socket, sys, time
s = socket.create_connection(("127.0.0.1", int(sys.argv[1])))
s.sendall(b"POST /pause HTTP/1.1\r\n")
time.sleep(5)' "$PORT" &
  sleep 0.5
  run req GET /queue/api/whoami -H 'Tailscale-User-Login: me@example.com' --max-time 2
  [ "${lines[1]}" = 200 ]
  [ ! -e "$Q/paused" ]
  kill $! 2>/dev/null || true
}

@test "vibe queue page: two writers at once leave a whole page and no tmp file" {
  local i pids=()
  for i in 1 2 3 4 5 6; do
    "$REPO_ROOT/bin/vibe" queue page >/dev/null &
    pids+=($!)
  done
  for i in "${pids[@]}"; do wait "$i"; done # each must exit 0; a bare wait also waits on the server
  grep -q '</html>' "$Q/web/index.html"
  [ "$(find "$Q/web" -name '*.tmp*' -o -name '*.js.*' | wc -l | tr -d ' ')" = 0 ]
  cmp -s "$REPO_ROOT/templates/queue-page.js" "$Q/web/page.js"
}

# act ROUTE BODY — a write by the right login with a JSON BODY.
act() {
  req POST "/queue/api/$1" -H 'Tailscale-User-Login: me@example.com' -H "Origin: https://127.0.0.1:$PORT" \
    -H 'Content-Type: application/json' -d "$2"
}

# qjob ID STATUS — a job dir in the queue; STATUS empty: queued.
qjob() {
  mkdir -p "$Q/queue/$1"
  printf 'repo=%s/proj\nbranch=task\n' "$BATS_TEST_TMPDIR" >"$Q/queue/$1/job"
  echo task >"$Q/queue/$1/prompt.md"
  if [ -n "$2" ]; then echo "$2" >"$Q/queue/$1/status"; fi
}

ID=20261104-080000-proj-task

@test "route conf: sets a key; vibe refuses an unknown key; a newline in the value is 400" {
  run act conf '{"set": "slots=2"}'
  [ "${lines[1]}" = 200 ]
  grep -qx slots=2 "$XDG_CONFIG_HOME/vibe/queue.conf"
  grep -q $'\tvibe queue conf slots=2\t0$' "$Q/actions.log"
  run act conf '{"set": "web_port=1"}'
  [[ "${lines[0]}" == *'"code": 1'* ]] || false
  grep -q $'\tvibe queue conf web_port=1\t1$' "$Q/actions.log"
  grep -qx "web_port=$PORT" "$XDG_CONFIG_HOME/vibe/queue.conf"
  run act conf '{"set": "slots=2\nweb_login=evil@example.com"}'
  [ "${lines[1]}" = 400 ]
  grep -qx web_login=me@example.com "$XDG_CONFIG_HOME/vibe/queue.conf"
  run grep -c evil "$XDG_CONFIG_HOME/vibe/queue.conf"
  [ "$output" = 0 ]
}

@test "route restart: systemctl restarts vibe-queue" {
  run act restart '{}'
  [ "${lines[1]}" = 200 ]
  [ "$(cat "$STUBS/systemctl.log")" = "--user restart vibe-queue" ]
  grep -q $'\tsystemctl --user restart vibe-queue\t0$' "$Q/actions.log"
}

@test "route unlimit: the usage limit goes" {
  mkdir -p "$Q"
  echo $(($(date +%s) + 3600)) >"$Q/limit"
  run act unlimit '{}'
  [ "${lines[1]}" = 200 ]
  [ ! -e "$Q/limit" ]
}

@test "route now and noreview: the queued job gets now=1 and after=; the card shows the buttons" {
  qjob "$ID"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -q "data-id=\"$ID\"><button data-act=\"now\">" "$Q/web/index.html"
  grep -q 'data-act="noreview"' "$Q/web/index.html"
  run act now "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 200 ]
  grep -qx now=1 "$Q/queue/$ID/job"
  run act noreview "{\"id\": \"$ID\"}"
  grep -qx after= "$Q/queue/$ID/job"
  run grep -c 'data-act="now"\|data-act="noreview"' "$Q/web/index.html"
  [ "$output" = 0 ]
}

@test "route retry: a failed job is queued again, the old one archived" {
  qjob "$ID" failed
  run act retry "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 200 ]
  [[ "${lines[0]}" == *'"code": 0'* ]] || false
  [ -d "$Q/archive/$(date +%Y-%m)/$ID" ]
  [ "$(find "$Q/queue" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = 1 ]
}

@test "route cancel: a queued job ends skipped; the card asks for a second tap" {
  qjob "$ID"
  run "$REPO_ROOT/bin/vibe" queue page
  grep -q 'data-act="cancel" data-confirm' "$Q/web/index.html"
  run act cancel "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 200 ]
  [ "$(cat "$Q/queue/$ID/status")" = skipped ]
}

@test "route stop: a running job gets the stop file" {
  qjob "$ID" running
  run act stop "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 200 ]
  [ -s "$Q/queue/$ID/stop" ]
}

@test "route hold: the note lands in held" {
  qjob "$ID" blocked
  run act hold "{\"id\": \"$ID\", \"note\": \"test it on the robot\"}"
  [ "${lines[1]}" = 200 ]
  [ "$(cat "$Q/queue/$ID/held")" = "test it on the robot" ]
}

@test "route archive: an ended job moves to the archive" {
  qjob "$ID" "done"
  run act archive "{\"id\": \"$ID\"}"
  [ "${lines[1]}" = 200 ]
  [ -d "$Q/archive/$(date +%Y-%m)/$ID" ]
}

@test "routes: an absent, non-string or bad id is 400 and runs nothing" {
  qjob "$ID"
  for body in '{}' '{"id": 1}' '{"id": "../x"}' '{"id": "20261104-080000-a/../b"}' '{"id": "--help"}'; do
    run act cancel "$body"
    [ "${lines[1]}" = 400 ]
  done
  run act hold "{\"id\": \"$ID\", \"note\": \"a\tb\"}"
  [ "${lines[1]}" = 400 ]
  [ ! -e "$Q/actions.log" ]
  [ ! -e "$Q/queue/$ID/status" ]
}
