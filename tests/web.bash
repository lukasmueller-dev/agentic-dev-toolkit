#!/usr/bin/env bash
# Shared setup of the vibe-web suites: the server on a free port, curl as tailscale serve, stub systemctl, gh and git.

# web_env — the environment, queue.conf and stubs of a test; web_start then starts the server.
web_env() {
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  mkdir -p "$HOME/.config/vibe" "$XDG_CONFIG_HOME/vibe" && echo server >"$HOME/.config/vibe/role"
  Q="$XDG_STATE_HOME/vibe"
  PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
  printf 'web_port=%s\nweb_login=me@example.com\n' "$PORT" >"$XDG_CONFIG_HOME/vibe/queue.conf"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"
  printf '#!/bin/sh\necho "$*" >>"%s/systemctl.log"\n[ ! -f "%s/hang" ] || exec sleep 30\n' "$STUBS" "$STUBS" >"$STUBS/systemctl"
  # gh: logs its args; per PR number N (the URL tail) prints STUBS/state-N, checks-N, files-N, else state, checks, files.
  cat >"$STUBS/gh" <<EOF
#!/bin/sh
echo "\$*" >>"$STUBS/gh.log"
n="\${3##*/}"
f() { cat "$STUBS/\$1-\$n" 2>/dev/null || cat "$STUBS/\$1" 2>/dev/null || true; }
case "\$1 \$2 \$*" in
  "pr view "*statusCheckRollup*) f checks ;;
  "pr view "*state*) f state ;;
  "pr diff "*) f files ;;
  "pr list "*) cat "$STUBS/prs" ;;
esac
EOF
  # git: origin's URL from STUBS/origin (none: exit 2), every other call to the real git; a clone's own origin never shows.
  # A page render makes two origin calls (gh_url in vibe and in an extension): a line each in STUBS/renders, 1 s more each with STUBS/slow.
  # shellcheck disable=SC2016  # the stub's own $3 $4 $5 and $@
  printf '#!/bin/sh\nif [ "$3 $4 $5" = "remote get-url origin" ]; then echo x >>"%s/renders"; [ ! -f "%s/slow" ] || sleep 1; cat "%s/origin" 2>/dev/null || exit 2; exit 0; fi\nexec "%s" "$@"\n' "$STUBS" "$STUBS" "$STUBS" "$(command -v git)" >"$STUBS/git"
  chmod +x "$STUBS/systemctl" "$STUBS/gh" "$STUBS/git"
  PATH="$STUBS:$PATH"
  git_env
  export VIBE_WEB_TIMEOUT=3 VIBE_ROOT="$BATS_TEST_TMPDIR"
}

# web_start — the server on $PORT, with the current environment; its pid in web.pid.
web_start() {
  "$REPO_ROOT/bin/vibe-web" 2>>"$BATS_TEST_TMPDIR/web.log" &
  echo $! >"$BATS_TEST_TMPDIR/web.pid"
  curl -s -o /dev/null --retry 30 --retry-connrefused --retry-delay 1 "http://127.0.0.1:$PORT/"
}

teardown() {
  eventually rendered || true # the render after the last write must not outlive the test
  kill "$(cat "$BATS_TEST_TMPDIR/web.pid")" 2>/dev/null || true
}

# eventually CMD... — CMD succeeds within 10 s: the server renders the page after it answers a write.
eventually() {
  for _ in $(seq 100); do
    if "$@"; then return 0; fi
    sleep 0.1
  done
  return 1
}

# rendered — false while a render runs or waits (GET writes); true with no server or a 403.
rendered() {
  case "$(req GET /queue/api/writes -H 'Tailscale-User-Login: me@example.com')" in *'"render": true'*) return 1 ;; esac
}

# page_lacks ERE — no line of the page matches ERE.
page_lacks() { ! grep -qE "$1" "$Q/web/index.html"; }

# writes_say JSON — GET writes answers JSON.
writes_say() { [ "$(req GET /writes -H 'Tailscale-User-Login: me@example.com' | sed -n 1p)" = "$1" ]; }

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

# act ROUTE BODY [CURL ARG...] — a write by the right login with a JSON BODY.
act() {
  local r="$1" b="$2"
  shift 2
  req POST "/queue/api/$r" -H 'Tailscale-User-Login: me@example.com' -H "Origin: https://127.0.0.1:$PORT" \
    -H 'Content-Type: application/json' -d "$b" "$@"
}

# qjob ID STATUS — a job dir in the queue; STATUS empty: queued.
qjob() {
  mkdir -p "$Q/queue/$1"
  printf 'repo=%s/proj\nbranch=task\n' "$BATS_TEST_TMPDIR" >"$Q/queue/$1/job"
  echo task >"$Q/queue/$1/prompt.md"
  if [ -n "$2" ]; then echo "$2" >"$Q/queue/$1/status"; fi
}
