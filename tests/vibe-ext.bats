#!/usr/bin/env bats
#
# vibe extensions — discovery (the checkout's extensions/, ~/.config/vibe/extensions),
# a command an extension describes, and the runner's pass event. A stub extension logs each call.

load helper

VIBE="$REPO_ROOT/bin/vibe"

setup() {
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" XDG_CONFIG_HOME="$HOME/.config"
  export VIBE_TOOLKIT="$BATS_TEST_TMPDIR/no-toolkit" VIBE_QUEUE_POLL=0
  unset VIBE_JOB_DIR # this suite may run inside a queue job: vibe queue gpu writes there
  mkdir -p "$HOME/.config/vibe"
  echo server >"$HOME/.config/vibe/role"
  LOG="$BATS_TEST_TMPDIR/ext.log"
}

# stub NAME [DESCRIBE-LINE...] — $BATS_TEST_TMPDIR/ext/NAME/NAME: logs `NAME ARG...` and its env, prints the lines at describe.
stub() {
  local f="$BATS_TEST_TMPDIR/ext/$1/$1"
  mkdir -p "${f%/*}"
  printf '%s\n' "${@:2}" >"${f%/*}/describe"
  cat >"$f" <<EOF
#!/usr/bin/env bash
echo "$1 \$* | \$VIBE_BIN | \$VIBE_STATE" >>"$LOG"
case "\$1" in
  describe) cat "${f%/*}/describe" ;;
  cmd) echo "ran \${*:2}"; read -r l || true; echo "stdin: \$l"; exit 7 ;;
  event) echo "heard \$2" ;;
esac
EOF
  chmod +x "$f"
  echo "$f"
}

@test "bin/vibe, bin/vibe-web and the queue page name no research or workspace term" {
  run grep -liE 'research|workspace' "$REPO_ROOT/bin/vibe" "$REPO_ROOT/bin/vibe-web" \
    "$REPO_ROOT/templates/queue-page.html" "$REPO_ROOT/templates/queue-page.js"
  [ "$status" -eq 1 ]
}

@test "ext list: the checkout's extensions/<name>/<name>" {
  run "$VIBE" ext list
  [ "$status" -eq 0 ]
  [[ "$output" == *"research	$REPO_ROOT/extensions/research/research"* ]] || false
}

@test "ext list: config lines first, trimmed, ~/ expanded, blank and comment lines skipped; the first of a name wins" {
  local a b
  a="$(stub alpha)"
  b="$(stub research)"
  mkdir -p "$HOME/x" && cp "$a" "$HOME/x/beta"
  # shellcheck disable=SC2088 # a literal ~/ the config file holds
  printf '%s\n' "# a comment" "" "   " "  # indented" "$b " "  ~/x/beta" "$a" >"$HOME/.config/vibe/extensions"
  run "$VIBE" ext list
  [ "$status" -eq 0 ]
  [[ "$output" != *warning* ]] || false
  [ "${lines[0]}" = "research	$b" ]
  [ "${lines[1]}" = "beta	$HOME/x/beta" ]
  [ "${lines[2]}" = "alpha	$a" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "ext list: a line that names no executable warns and is skipped" {
  printf '%s\n' "$BATS_TEST_TMPDIR/none/none" >"$HOME/.config/vibe/extensions"
  run "$VIBE" ext list
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: extension $BATS_TEST_TMPDIR/none/none is no executable file"* ]] || false
  [[ "$output" == *"research	$REPO_ROOT/extensions/research/research"* ]] || false
}

@test "a command an extension describes runs it: argv, stdin, exit status and env pass through" {
  stub hello "command hello world" >"$HOME/.config/vibe/extensions"
  run "$VIBE" hello world again <<<"input line"
  [ "$status" -eq 7 ]
  [ "${lines[0]}" = "ran hello world again" ]
  [ "${lines[1]}" = "stdin: input line" ]
  grep -qxF "hello cmd hello world again | $VIBE | $XDG_STATE_HOME/vibe" "$LOG"
}

@test "a describe longer than a pipe buffer routes its first line with no warning" {
  local a
  a="$(stub big "command hello")"
  seq 1 30000 | sed 's/^/help line /' >>"${a%/*}/describe"
  echo "$a" >"$HOME/.config/vibe/extensions"
  run "$VIBE" hello </dev/null
  [ "$status" -eq 7 ]
  [ "${lines[0]}" = "ran hello" ]
  [[ "$output" != *warning* ]] || false
}

@test "a described command matches --x=v, and only as a prefix of the arguments" {
  stub place "command queue gpu --place" >"$HOME/.config/vibe/extensions"
  run "$VIBE" queue gpu --place=runpod -- true </dev/null
  [ "$status" -eq 7 ]
  [ "${lines[0]}" = "ran queue gpu --place=runpod -- true" ]
  run "$VIBE" queue gpu -- true
  [ "$status" -ne 7 ]
  [[ "$output" == *"vibe queue gpu runs inside a queue job"* ]] || false
  run "$VIBE" queue
  [ "$status" -ne 7 ]
}

@test "on a client, a described command that changes state stops before the extension runs" {
  stub hello "command queue worker" >"$HOME/.config/vibe/extensions"
  echo "client example.invalid" >"$HOME/.config/vibe/role"
  run "$VIBE" queue worker h1 </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"the queue runs on the server"* ]] || false
  if grep -q "^hello cmd" "$LOG"; then false; fi
}

@test "a command no extension describes stays vibe's: one error line" {
  stub hello "command hello" >"$HOME/.config/vibe/extensions"
  run "$VIBE" nosuch
  [ "$status" -eq 1 ]
  [ "$output" = "vibe: unknown command 'nosuch' — vibe help" ]
}

@test "a describe that hangs is cut after 10 s with a warning; vibe goes on" {
  command -v timeout >/dev/null || command -v gtimeout >/dev/null || skip "no timeout(1): no cut"
  mkdir -p "$BATS_TEST_TMPDIR/ext/slow"
  printf '%s\n' '#!/usr/bin/env bash' 'sleep 60' >"$BATS_TEST_TMPDIR/ext/slow/slow"
  chmod +x "$BATS_TEST_TMPDIR/ext/slow/slow"
  echo "$BATS_TEST_TMPDIR/ext/slow/slow" >"$HOME/.config/vibe/extensions"
  SECONDS=0
  run "$VIBE" nosuch
  [ "$SECONDS" -lt 30 ]
  [ "$status" -eq 1 ]
  [[ "$output" == *"warning: extension slow: describe exit 124"* ]] || false
  [[ "$output" == *"unknown command 'nosuch'"* ]] || false
}

@test "the runner's pass runs each extension's pass event" {
  stub alpha >"$HOME/.config/vibe/extensions"
  run "$VIBE" queue run --claude --drain
  [ "$status" -eq 0 ]
  grep -qxF "alpha event pass | $VIBE | $XDG_STATE_HOME/vibe" "$LOG"
}

@test "a failed pass event warns with its name; the next extension still hears it; the runner goes on" {
  local a
  mkdir -p "$BATS_TEST_TMPDIR/ext/bad"
  # shellcheck disable=SC2016 # the stub's own $1
  printf '%s\n' '#!/usr/bin/env bash' '[ "$1" != event ] || exit 4' >"$BATS_TEST_TMPDIR/ext/bad/bad"
  chmod +x "$BATS_TEST_TMPDIR/ext/bad/bad"
  a="$(stub alpha)"
  printf '%s\n' "$BATS_TEST_TMPDIR/ext/bad/bad" "$a" >"$HOME/.config/vibe/extensions"
  run "$VIBE" queue run --claude --drain
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: extension bad: event pass exit 4"* ]] || false
  [[ "$output" == *"queue drained"* ]] || false
  grep -q "^alpha event pass " "$LOG"
}

@test "the research extension owns ws and queue gpu --place, is silent at an event it does not hear; with none, each prints one error line" {
  local x="$REPO_ROOT/extensions/research/research" tk="$BATS_TEST_TMPDIR/tk"
  VIBE_BIN="$VIBE" VIBE_STATE="$XDG_STATE_HOME/vibe" run "$x" describe
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "command ws" ]
  [ "${lines[1]}" = "command queue gpu --place" ]
  VIBE_BIN="$VIBE" VIBE_STATE="$XDG_STATE_HOME/vibe" run "$x" event nosuch
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  VIBE_BIN="$VIBE" VIBE_STATE="$XDG_STATE_HOME/vibe" run "$x" nosuch
  [ "$status" -eq 2 ]
  run "$x" describe
  [ "$status" -eq 2 ]
  run "$VIBE" --help
  grep -qF '  vibe ws stop <instance>         its stop script' <<<"$output"
  mkdir -p "$tk/bin" "$tk/skills"
  cp "$VIBE" "$tk/bin/vibe"
  ln -s "$REPO_ROOT/skills/_lib" "$tk/skills/_lib"
  run "$tk/bin/vibe" ws list
  [ "$status" -eq 1 ]
  [ "$output" = "vibe: unknown command 'ws' — vibe help" ]
  mkdir -p "$BATS_TEST_TMPDIR/job" && touch "$BATS_TEST_TMPDIR/job/job"
  VIBE_JOB_DIR="$BATS_TEST_TMPDIR/job" run "$tk/bin/vibe" queue gpu --place vast -- train
  [ "$status" -eq 1 ]
  [ "$output" = "vibe: usage: vibe queue gpu -- CMD..." ]
  run "$tk/bin/vibe" queue stop --research q1
  [ "$status" -eq 1 ]
  [ "$output" = "vibe: usage: vibe queue stop <id>" ]
  VIBE_JOB_DIR="$BATS_TEST_TMPDIR/job" run "$tk/bin/vibe" queue worker h1
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 1 ]
  run "$tk/bin/vibe" --help
  [[ "$output" != *"vibe ws"* ]] || false
  [[ "$output" != *"--research"* ]] || false
}

@test "an extension's handled line ends vibe queue answer; its result line is the Result line of a GPU follow-up" {
  local q="$XDG_STATE_HOME/vibe/queue" f="$BATS_TEST_TMPDIR/ext/lines/lines"
  mkdir -p "$q/01-a" "${f%/*}"
  printf 'repo=%s\nbranch=a\ntool=t\n' "$BATS_TEST_TMPDIR" >"$q/01-a/job"
  echo 'Do it.' >"$q/01-a/prompt.md"
  echo blocked >"$q/01-a/status"
  # shellcheck disable=SC2016 # the stub's own $1 $2 $4
  printf '%s\n' '#!/usr/bin/env bash' "echo \"\$*\" >>$LOG" 'case "$1 ${2:-}" in' \
    '  "event answer") echo "handled took $4" ;;' '  "event follow") echo "result 42" ;;' 'esac' >"$f"
  chmod +x "$f"
  echo "$f" >"$HOME/.config/vibe/extensions"
  run "$VIBE" queue answer 01-a my text
  [ "$status" -eq 0 ]
  [ "$output" = "took my text" ]
  [ "$(ls "$q")" = 01-a ]
  GPUQ_EXIT=0 GPUQ_LOG=/dev/null run "$VIBE" queue follow "$q/01-a"
  [ "$status" -eq 0 ]
  grep -qxF -- '- Result: 42' "$q/01-a-gpu/prompt.md"
  grep -qx "event follow $q/01-a $q/\.follow\.[A-Za-z0-9]* gpu" "$LOG"
  # The research extension drops tool= at a GPU follow-up: it runs no tool.
  run grep -c '^tool=' "$q/01-a-gpu/job"
  [ "$output" = 0 ]
  [ -z "$(find "$q" -mindepth 1 -maxdepth 1 -name '.*')" ]
}

@test "the research extension edited in place while a command works keeps that command's exit status" {
  local x="$BATS_TEST_TMPDIR/xt/research" w="$BATS_TEST_TMPDIR/ws" st="$XDG_STATE_HOME/vibe/workspaces/t1" pid
  mkdir -p "${x%/*}" "$w/t1" "$w/_places" "$st"
  cp "$REPO_ROOT/extensions/research/research" "$x"
  printf '%s\n' kind=run places=turing result=folder >"$w/t1/workspace.conf"
  # shellcheck disable=SC2016 # the stub's own $1 $2
  printf '#!/bin/sh\nif [ "$1 $2" = "exec run" ]; then sleep 1; fi\n' >"$w/_places/turing"
  chmod +x "$w/_places/turing"
  echo turing >"$st/place"
  VIBE_WORKSPACES="$w" VIBE_BIN="$VIBE" VIBE_STATE="$XDG_STATE_HOME/vibe" "$x" cmd ws run t1 &
  pid=$!
  sleep 0.5
  { head -n 1 "$x" && echo '# a line the running extension never reads, long enough to move its end offset' && tail -n +2 "$x"; } >"$x.new"
  cat "$x.new" >"$x"
  wait "$pid"
}

@test "card, status and report: an extension's tab, CSS, rows and blocks reach the page, <job-buttons ID> as the job's buttons; a card= job leaves its repo group" {
  local f="$BATS_TEST_TMPDIR/ext/kard/kard" q="$XDG_STATE_HOME/vibe/queue" p="$XDG_STATE_HOME/vibe/web/index.html"
  mkdir -p "${f%/*}"
  rjob "$q" 20261117-100000-proj-a failed /x/proj a card=kard
  cat >"$f" <<'STUB'
#!/usr/bin/env bash
[ "$1" = event ] || exit 0
case "$2" in
  card) printf '%s\n' 'title	kt	Kards' dot 'tab	<p>the tab</p>' 'style	.kard { color: red; }' \
    'you	<div class="row" data-k="kard/a">row a</div>' 'blk	<div class="blk" id="job-kard/a" hidden>blk a<job-buttons 20261117-100000-proj-a>end</div>' ;;
  status) printf '\nKards\n  a · needs you\n' ;;
  report) printf '\n## Kards\n\n| a |\n' ;;
esac
STUB
  chmod +x "$f" && echo "$f" >"$HOME/.config/vibe/extensions"
  "$VIBE" queue page
  grep -qF '<a class="tw" href="#kt">Kards <i class="lamp l-ok"></i></a>' "$p"
  [[ "$(cat "$p")" == *$'<section id="kt" class="page ext">\n<p>the tab</p>'* ]] || false
  grep -qxF '.kard { color: red; }' "$p"
  grep -qF '<h2>Needs you <span class="n">1</span></h2><div class="card"><div class="row" data-k="kard/a">row a</div></div>' "$p"
  grep -qF 'blk a<div class="jacts" data-id="20261117-100000-proj-a"><span class="ask note">' "$p"
  [ "$(grep -o '<div class="row"' "$p" | wc -l)" -eq 1 ]
  run "$VIBE" queue status
  [[ "$output" == *$'\nKards\n  a · needs you'* && "$output" != *proj* ]] || false
  run "$VIBE" queue report
  [[ "$output" == *$'\n## Kards\n\n| a |'* ]] || false
}

@test "a branch line: queue add takes <prefix>/<slug>/<slug> for a described prefix only" {
  local d="$BATS_TEST_TMPDIR/j" r
  r="$(make_repo proj)"
  mkdir -p "$d" && printf 'repo=%s\nbranch=kb/a/b\n' "$r" >"$d/job" && echo task >"$d/prompt.md"
  run "$VIBE" queue add "$d"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bad branch 'kb/a/b'"* ]] || false
  stub kard "branch kb" >"$HOME/.config/vibe/extensions"
  run "$VIBE" queue add "$d"
  [ "$status" -eq 0 ]
  [[ "$output" == *"queued "*"-proj-kb-a-b"* ]] || false
}

@test "ext lines: a describe that exits non-zero warns with its name and keeps its lines" {
  local x="$BATS_TEST_TMPDIR/ext/bad/bad"
  mkdir -p "${x%/*}"
  # shellcheck disable=SC2016 # the stub's own $1
  printf '%s\n' '#!/bin/sh' '[ "$1" = describe ] || exit 0' 'echo "wip FOO.md"' 'exit 1' >"$x"
  chmod +x "$x" && echo "$x" >"$HOME/.config/vibe/extensions"
  run "$VIBE" ext lines wip
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: extension bad: describe exit 1"* ]] || false
  [[ "$output" == *$'\nFOO.md'* || "$output" == "FOO.md"* ]] || false
}

@test "an extension that fails at follow stops vibe queue retry: no follow-up is queued, the old job stays" {
  local q="$XDG_STATE_HOME/vibe/queue" f="$BATS_TEST_TMPDIR/ext/nofollow/nofollow"
  mkdir -p "$q/01-a" "${f%/*}"
  printf 'repo=%s\nbranch=a\n' "$BATS_TEST_TMPDIR" >"$q/01-a/job"
  echo 'Do it.' >"$q/01-a/prompt.md"
  echo failed >"$q/01-a/status"
  # shellcheck disable=SC2016 # the stub's own $1 $2
  printf '%s\n' '#!/usr/bin/env bash' 'if [ "$1 $2" = "event follow" ]; then exit 1; fi' >"$f"
  chmod +x "$f"
  echo "$f" >"$HOME/.config/vibe/extensions"
  run "$VIBE" queue retry 01-a
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed at the follow-up of 01-a: nothing queued"* ]] || false
  [ "$(ls "$q")" = 01-a ]
  [ "$(cat "$q/01-a/status")" = failed ]
}
