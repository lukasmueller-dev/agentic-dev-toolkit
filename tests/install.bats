#!/usr/bin/env bats
#
# install.sh against a throwaway HOME. Every test sets HOME to a directory
# under $BATS_TEST_TMPDIR, so the real ~/.claude and ~/bin are never touched.

load helper

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  INSTALL="$REPO_ROOT/install.sh"
}

# Drops ANSI colour so assertions match on text, not escape sequences.
plain() { sed $'s/\033\\[[0-9;]*m//g'; }

@test "install: creates the expected symlinks" {
  run "$INSTALL"
  [ "$status" -eq 0 ]
  [ -L "$HOME/bin/vibe" ]
  [ -L "$HOME/.claude/skills/project-status-scaffold" ]
  [ -L "$HOME/.claude/CLAUDE.md" ]
  [ -L "$HOME/.claude/settings.json" ]
  [ -L "$HOME/.claude/hooks" ]
  [ -L "$HOME/.zsh/completions/_vibe" ]
  [ -L "$HOME/.local/share/bash-completion/completions/vibe" ]
}

@test "install: every symlink resolves back into the repo" {
  "$INSTALL" >/dev/null
  local l
  while IFS= read -r l; do
    [ -e "$l" ] # not dangling
    [[ "$(readlink "$l")" == "$REPO_ROOT"/* ]]
  done < <(find "$HOME" -type l)
}

@test "install: is idempotent — a second run creates nothing new" {
  "$INSTALL" >/dev/null
  run "$INSTALL"
  [ "$status" -eq 0 ]
  # no "linked" lines the second time round; everything reports ok
  [ "$(printf '%s\n' "$output" | plain | grep -c '^  linked')" -eq 0 ]
  [ "$(printf '%s\n' "$output" | plain | grep -c '^  ok ')" -gt 0 ]
}

@test "install: --dry changes nothing" {
  run "$INSTALL" --dry
  [ "$status" -eq 0 ]
  [ "$(find "$HOME" \( -type l -o -type f \) | wc -l | tr -d ' ')" -eq 0 ]
}

@test "install: skips skills/_template" {
  # Asserts against the template that really lives in the repo. An earlier
  # version of this test created a fixture under $REPO_ROOT and rm -rf'd it
  # afterwards, which deleted the real skills/_template. No test may write
  # anything outside $BATS_TEST_TMPDIR.
  [ -d "$REPO_ROOT/skills/_template" ]

  run "$INSTALL" skills
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/skills/_template" ]
  # and the real skills were still installed
  [ -L "$HOME/.claude/skills/codebase-health" ]
}

@test "tests never write outside BATS_TEST_TMPDIR" {
  # A standing guard: the repo must be clean of stray files after the suite
  # touches it. Catches the class of bug described above.
  run git -C "$REPO_ROOT" status --porcelain --untracked-files=all -- skills tests
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "install: backs up a real file instead of deleting it" {
  mkdir -p "$HOME/.claude"
  printf 'PRECIOUS\n' >"$HOME/.claude/CLAUDE.md"
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  [ -L "$HOME/.claude/CLAUDE.md" ]
  # the original content survives somewhere under the backup root
  run grep -rl PRECIOUS "$HOME/.agentic-dev-toolkit-backups"
  [ "$status" -eq 0 ]
}

@test "uninstall: removes every symlink it created" {
  "$INSTALL" >/dev/null
  run "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/bin/vibe" ]
  [ ! -e "$HOME/.claude/CLAUDE.md" ]
  [ ! -e "$HOME/.claude/settings.json" ]
  [ ! -e "$HOME/.claude/hooks" ]
  [ ! -e "$HOME/.claude/skills/project-status-scaffold" ]
  # nothing of ours is left anywhere in HOME
  [ "$(find "$HOME" -type l | wc -l | tr -d ' ')" -eq 0 ]
}

@test "uninstall: leaves a symlink that points outside this repo" {
  mkdir -p "$HOME/.claude" "$BATS_TEST_TMPDIR/elsewhere"
  printf '{}' >"$BATS_TEST_TMPDIR/elsewhere/settings.json"
  ln -s "$BATS_TEST_TMPDIR/elsewhere/settings.json" "$HOME/.claude/settings.json"

  run "$INSTALL" --uninstall claude
  [ "$status" -eq 0 ]
  [ -L "$HOME/.claude/settings.json" ]
  [[ "$(printf '%s\n' "$output" | plain)" == *"points outside this repo"* ]]
}

@test "uninstall: leaves a real file at a managed path" {
  mkdir -p "$HOME/bin"
  printf '#!/bin/sh\n' >"$HOME/bin/vibe"
  run "$INSTALL" --uninstall bin
  [ "$status" -eq 0 ]
  [ -f "$HOME/bin/vibe" ]
  [ ! -L "$HOME/bin/vibe" ]
  [[ "$(printf '%s\n' "$output" | plain)" == *"not ours to remove"* ]]
}

@test "uninstall: is safe to run twice" {
  "$INSTALL" >/dev/null
  "$INSTALL" --uninstall >/dev/null
  run "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
}

@test "doctor: reports healthy right after installing" {
  "$INSTALL" >/dev/null
  run "$INSTALL" doctor
  # ~/bin is not on PATH inside the test shell, so warnings are expected;
  # what must not happen is a FAIL.
  [[ "$(printf '%s\n' "$output" | plain)" != *"FAIL"* ]]
}

@test "doctor: notices a missing symlink" {
  "$INSTALL" >/dev/null
  rm "$HOME/bin/vibe"
  run "$INSTALL" doctor
  [[ "$(printf '%s\n' "$output" | plain)" == *"missing"* ]]
}

@test "doctor: notices a dangling symlink" {
  "$INSTALL" >/dev/null
  rm "$HOME/bin/vibe"
  ln -s "$REPO_ROOT/bin/vibe" "$HOME/bin/vibe"
  # point it at something that does not exist
  rm "$HOME/bin/vibe"
  ln -s "$REPO_ROOT/bin/does-not-exist" "$HOME/bin/vibe"
  run "$INSTALL" doctor
  [ "$status" -eq 1 ]
  [[ "$(printf '%s\n' "$output" | plain)" == *"dangling"* ]]
}

@test "install: rejects an unknown target" {
  run "$INSTALL" not-a-target
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# vscode merge
# ---------------------------------------------------------------------------
@test "vscode: merges into existing settings without losing keys" {
  local dir="$HOME/Library/Application Support/Code/User"
  [ "$(uname -s)" = "Darwin" ] || dir="$HOME/.config/Code/User"
  mkdir -p "$dir"
  cat >"$dir/settings.json" <<'EOF'
// a comment, as VS Code allows
{
  "editor.fontSize": 14,
  "terminal.integrated.profiles.osx": { "mine": { "path": "fish" } }
}
EOF
  run "$INSTALL" vscode
  [ "$status" -eq 0 ]
  jq -e '.["editor.fontSize"] == 14' "$dir/settings.json"
  jq -e '.["terminal.integrated.profiles.osx"].mine' "$dir/settings.json"
  # and a backup of the original was kept
  [ "$(find "$dir" -name 'settings.json.bak.*' | wc -l | tr -d ' ')" -eq 1 ]
}

@test "vscode: re-running does not rewrite an already-merged file" {
  local dir="$HOME/Library/Application Support/Code/User"
  [ "$(uname -s)" = "Darwin" ] || dir="$HOME/.config/Code/User"
  "$INSTALL" vscode >/dev/null
  run "$INSTALL" vscode
  [ "$status" -eq 0 ]
  [[ "$(printf '%s\n' "$output" | plain)" == *"already applied"* ]]
  [ "$(find "$dir" -name 'settings.json.bak.*' | wc -l | tr -d ' ')" -eq 0 ]
}
