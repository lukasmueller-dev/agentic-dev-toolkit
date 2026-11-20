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

@test "ext list: the checkout's extensions/<name>/<name>" {
  run "$VIBE" ext list
  [ "$status" -eq 0 ]
  [[ "$output" == *"research	$REPO_ROOT/extensions/research/research"* ]] || false
}

@test "ext list: config lines first, ~/ expanded, comments skipped; the first of a name wins" {
  local a b
  a="$(stub alpha)"
  b="$(stub research)"
  mkdir -p "$HOME/x" && cp "$a" "$HOME/x/beta"
  printf '%s\n' "# a comment" "" "$b" "~/x/beta" "$a" >"$HOME/.config/vibe/extensions"
  run "$VIBE" ext list
  [ "$status" -eq 0 ]
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

@test "a command no extension describes stays vibe's: one error line" {
  stub hello "command hello" >"$HOME/.config/vibe/extensions"
  run "$VIBE" nosuch
  [ "$status" -eq 1 ]
  [ "$output" = "vibe: unknown command 'nosuch' — vibe help" ]
}

@test "the runner's pass runs each extension's pass event" {
  stub alpha >"$HOME/.config/vibe/extensions"
  run "$VIBE" queue run --claude --drain
  [ "$status" -eq 0 ]
  grep -qxF "alpha event pass | $VIBE | $XDG_STATE_HOME/vibe" "$LOG"
}

@test "a failed pass event warns; the runner goes on" {
  mkdir -p "$BATS_TEST_TMPDIR/ext/bad"
  printf '%s\n' '#!/usr/bin/env bash' '[ "$1" != event ] || exit 4' >"$BATS_TEST_TMPDIR/ext/bad/bad"
  chmod +x "$BATS_TEST_TMPDIR/ext/bad/bad"
  echo "$BATS_TEST_TMPDIR/ext/bad/bad" >"$HOME/.config/vibe/extensions"
  run "$VIBE" queue run --claude --drain
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: an extension's pass event failed"* ]] || false
  [[ "$output" == *"queue drained"* ]] || false
}

@test "the research stub owns no command and is silent at an event" {
  run "$REPO_ROOT/extensions/research/research" describe
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$REPO_ROOT/extensions/research/research" event pass
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$REPO_ROOT/extensions/research/research" nosuch
  [ "$status" -eq 2 ]
}
