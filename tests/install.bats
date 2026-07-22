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
  [ -L "$HOME/.claude/hooks" ]
  [ -L "$HOME/.claude/agents" ]
  # settings.json is merged, not symlinked — Claude Code writes to it itself
  [ -f "$HOME/.claude/settings.json" ]
  [ ! -L "$HOME/.claude/settings.json" ]
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

@test "install: the global agent roster is reachable through the link" {
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  local a
  for a in diff-reviewer test-hardener docs-drift security-sweep; do
    [ -f "$HOME/.claude/agents/$a.md" ]
    # the frontmatter name must match the filename, or the agent cannot be
    # addressed by the name the roster advertises
    run grep -qx "name: $a" "$HOME/.claude/agents/$a.md"
    [ "$status" -eq 0 ]
  done
  # the README documents the directory and must not be mistaken for an agent
  [ -f "$HOME/.claude/agents/README.md" ]
}

@test "install: a claude/ directory holding only a README is not linked" {
  # The rule that kept agents/ out of ~/.claude while it was empty. Exercised
  # against a *copy* of the repo — no test may create files under $REPO_ROOT.
  local copy="$BATS_TEST_TMPDIR/repo"
  cp -R "$REPO_ROOT" "$copy"
  rm -rf "$copy/.git"
  mkdir -p "$copy/claude/emptyish"
  printf '# nothing here yet\n' >"$copy/claude/emptyish/README.md"

  run "$copy/install.sh" claude
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/emptyish" ]
  # and a populated directory beside it still links
  [ -L "$HOME/.claude/agents" ]
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

@test "the suite creates and deletes nothing under skills/" {
  # A standing guard against the bug described above. Only additions (??) and
  # deletions (D) are checked: ordinary uncommitted *edits* are normal while
  # working, but a test that leaves a new file behind — or removes a tracked
  # one — is always wrong.
  run bash -c "git -C '$REPO_ROOT' status --porcelain --untracked-files=all -- skills \
    | grep -E '^(\\?\\?|.?D)' || true"
  [ -z "$output" ]
  # the file the original bug destroyed, named explicitly
  [ -f "$REPO_ROOT/skills/_template/SKILL.md" ]
}

@test "install: never chmods a script inside the checkout" {
  # The installer used to chmod +x bin/* and every *.sh under linked
  # directories — mutating the developer's working tree on every run (and
  # the suite runs the installer ~25×). Exercised against a copy: a
  # deliberately non-executable script must keep its mode.
  local copy="$BATS_TEST_TMPDIR/repo"
  cp -R "$REPO_ROOT" "$copy"
  rm -rf "$copy/.git"
  printf '#!/bin/sh\n' >"$copy/skills/codebase-health/noexec.sh"
  chmod 644 "$copy/skills/codebase-health/noexec.sh"

  run "$copy/install.sh" skills
  [ "$status" -eq 0 ]
  [ ! -x "$copy/skills/codebase-health/noexec.sh" ]
}

@test "install: warns about a non-executable bin/ file instead of fixing it" {
  local copy="$BATS_TEST_TMPDIR/repo"
  cp -R "$REPO_ROOT" "$copy"
  rm -rf "$copy/.git"
  printf '#!/bin/sh\necho hi\n' >"$copy/bin/newtool"
  chmod 644 "$copy/bin/newtool"

  run "$copy/install.sh" bin
  [ "$status" -eq 0 ]
  [ ! -x "$copy/bin/newtool" ]
  [[ "$(printf '%s\n' "$output" | plain)" == *"not executable"* ]]
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

@test "install: two displaced files sharing a basename both survive backup" {
  # ~/bin/vibe and the bash completion back up under the same kind and
  # basename ("bin/vibe") in one run — the second must not clobber the first.
  mkdir -p "$HOME/bin" "$HOME/.local/share/bash-completion/completions"
  printf 'REAL-CLI\n' >"$HOME/bin/vibe"
  printf 'REAL-COMPLETION\n' >"$HOME/.local/share/bash-completion/completions/vibe"
  run "$INSTALL" bin
  [ "$status" -eq 0 ]
  run grep -rl REAL-CLI "$HOME/.agentic-dev-toolkit-backups"
  [ "$status" -eq 0 ]
  run grep -rl REAL-COMPLETION "$HOME/.agentic-dev-toolkit-backups"
  [ "$status" -eq 0 ]
}

@test "uninstall: removes every symlink it created" {
  "$INSTALL" >/dev/null
  run "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/bin/vibe" ]
  [ ! -e "$HOME/.claude/CLAUDE.md" ]
  [ ! -e "$HOME/.claude/hooks" ]
  [ ! -e "$HOME/.claude/skills/project-status-scaffold" ]
  # nothing of ours is left anywhere in HOME
  [ "$(find "$HOME" -type l | wc -l | tr -d ' ')" -eq 0 ]
}

@test "uninstall: leaves a symlink that points outside this repo" {
  mkdir -p "$HOME/.claude" "$BATS_TEST_TMPDIR/elsewhere"
  printf 'not ours' >"$BATS_TEST_TMPDIR/elsewhere/CLAUDE.md"
  ln -s "$BATS_TEST_TMPDIR/elsewhere/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

  run "$INSTALL" --uninstall claude
  [ "$status" -eq 0 ]
  [ -L "$HOME/.claude/CLAUDE.md" ]
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

# ---------------------------------------------------------------------------
# Portable global memory
#
# One file, three agent homes. The failure this guards against is silent: the
# symlinks can all be correct while Claude Code still loads none of it, because
# it reads CLAUDE.md alone and reaches the shared half only through the import.
# ---------------------------------------------------------------------------
@test "memory: the one file lands in all three agent homes" {
  run "$INSTALL"
  [ "$status" -eq 0 ]
  local src="$REPO_ROOT/memory/GLOBAL.md"
  [ "$(readlink "$HOME/.claude/global-memory.md")" = "$src" ]
  [ "$(readlink "$HOME/.codex/AGENTS.md")" = "$src" ]
  [ "$(readlink "$HOME/.gemini/GEMINI.md")" = "$src" ]
  # and the directory READMEs stay in the repo — they document the directory,
  # they are not config. A `case $skip)` alternation used to leak them here.
  [ ! -e "$HOME/.codex/README.md" ]
  [ ! -e "$HOME/.gemini/README.md" ]
}

@test "memory: the Claude memory imports the portable half" {
  "$INSTALL" claude >/dev/null
  # Claude Code loads exactly one global memory file. Drop this import and the
  # workflow memory vanishes with every symlink still reporting ok.
  run grep -q '^@~/.claude/global-memory.md' "$HOME/.claude/CLAUDE.md"
  [ "$status" -eq 0 ]
}

@test "memory: doctor FAILs when the import is gone" {
  "$INSTALL" claude >/dev/null
  # stand a real file at the managed path, without the import line
  rm "$HOME/.claude/CLAUDE.md"
  printf '# Response style\n' >"$HOME/.claude/CLAUDE.md"
  run "$INSTALL" doctor claude
  [ "$status" -eq 1 ]
  [[ "$(printf '%s\n' "$output" | plain)" == *"will not load the shared memory"* ]]
}

@test "memory: installing one agent leaves the other agents' homes alone" {
  run "$INSTALL" codex
  [ "$status" -eq 0 ]
  [ -L "$HOME/.codex/AGENTS.md" ]
  [ ! -e "$HOME/.gemini/GEMINI.md" ]
  [ ! -e "$HOME/.claude/global-memory.md" ]
}

@test "memory: uninstall removes every agent's copy" {
  "$INSTALL" >/dev/null
  run "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/global-memory.md" ]
  [ ! -e "$HOME/.codex/AGENTS.md" ]
  [ ! -e "$HOME/.gemini/GEMINI.md" ]
}

@test "memory: names no specific agent or vendor" {
  # The whole point of the split: this file is installed for every agent, so a
  # sentence about one of them is wrong in two homes out of three.
  # Mirrors ci.yml's guard — update both together. Bare 'Claude'/'Gemini'
  # stay allowed (the file names the instruction files CLAUDE.md/GEMINI.md);
  # vendor names, product compounds, and per-agent config paths do not.
  run grep -niE 'Claude Code|Anthropic|OpenAI|ChatGPT|\bGPT\b|Copilot|Cursor|Codex|Gemini CLI|~/\.claude|~/\.codex|~/\.gemini' "$REPO_ROOT/memory/GLOBAL.md"
  [ "$status" -ne 0 ]
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

# ---------------------------------------------------------------------------
# claude settings merge
# ---------------------------------------------------------------------------
@test "claude settings: creates settings.json when none exists" {
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  jq -e '.permissions.allow | length > 0' "$HOME/.claude/settings.json"
  jq -e '.hooks.SessionEnd' "$HOME/.claude/settings.json"
  jq -e '.statusLine.type == "command"' "$HOME/.claude/settings.json"
}

@test "claude settings: every hook and statusLine command resolves to a real file" {
  # Rename or delete a script in claude/hooks/ and Claude Code silently runs
  # nothing — which is indistinguishable from the hooks' own "stay quiet when a
  # dependency is missing" contract, so it fails completely silently and stays
  # broken. Nothing else in the suite ties the baseline's command strings to
  # the files they name.
  local cmd path checked=0
  while IFS= read -r cmd; do
    checked=$((checked + 1))
    # The baseline stores the literal $HOME; expand it against the real repo,
    # since ~/.claude/hooks is a symlink to claude/hooks in this checkout.
    path="${cmd%% *}"
    path="${path/\$HOME\/.claude\/hooks/$REPO_ROOT/claude/hooks}"
    [ -f "$path" ] || {
      echo "settings.json names a command that does not exist: $cmd" >&2
      return 1
    }
    [ -x "$path" ] || {
      echo "settings.json names a command that is not executable: $cmd" >&2
      return 1
    }
  done < <(jq -r '
    [(.hooks // {} | .[][]?.hooks[]?.command), (.statusLine.command // empty)][]
  ' "$REPO_ROOT/claude/settings.json")

  # Without this the test passes on an empty loop, which is exactly what a
  # broken jq path or a renamed key would produce.
  [ "$checked" -ge 5 ]
}

@test "claude settings: never clobbers runtime state Claude Code owns" {
  mkdir -p "$HOME/.claude"
  cat >"$HOME/.claude/settings.json" <<'EOF'
{ "model": "sonnet", "effortLevel": "xhigh", "agentPushNotifEnabled": true }
EOF
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  jq -e '.model == "sonnet"' "$HOME/.claude/settings.json"
  jq -e '.effortLevel == "xhigh"' "$HOME/.claude/settings.json"
  jq -e '.agentPushNotifEnabled == true' "$HOME/.claude/settings.json"
}

@test "claude settings: unions permission arrays instead of replacing them" {
  mkdir -p "$HOME/.claude"
  cat >"$HOME/.claude/settings.json" <<'EOF'
{ "permissions": { "allow": ["Bash(my-own-rule:*)"] } }
EOF
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  # jq's `*` would have replaced this array wholesale, losing the user's rule
  jq -e '.permissions.allow | index("Bash(my-own-rule:*)")' "$HOME/.claude/settings.json"
  jq -e '.permissions.allow | index("Bash(git status:*)")' "$HOME/.claude/settings.json"
}

@test "claude settings: sandbox baseline lands on create" {
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  jq -e '.sandbox.enabled == true' "$HOME/.claude/settings.json"
  # degrade, don't break, where bubblewrap/socat are missing
  jq -e '.sandbox.allowUnsandboxedCommands == true' "$HOME/.claude/settings.json"
  jq -e '.sandbox.excludedCommands | length > 0' "$HOME/.claude/settings.json"
}

@test "claude settings: unions sandbox arrays instead of replacing them" {
  mkdir -p "$HOME/.claude"
  cat >"$HOME/.claude/settings.json" <<'EOF'
{ "sandbox": { "network": { "allowedDomains": ["my.internal.host"] },
               "excludedCommands": ["docker *"] } }
EOF
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  # jq's `*` would have replaced these arrays wholesale, losing the user's entries
  jq -e '.sandbox.network.allowedDomains | index("my.internal.host")' "$HOME/.claude/settings.json"
  jq -e '.sandbox.network.allowedDomains | index("github.com")' "$HOME/.claude/settings.json"
  jq -e '.sandbox.excludedCommands | index("docker *")' "$HOME/.claude/settings.json"
  jq -e '.sandbox.excludedCommands | index("git push *")' "$HOME/.claude/settings.json"
}

@test "claude settings: a sandbox array only in the live file is left alone" {
  mkdir -p "$HOME/.claude"
  cat >"$HOME/.claude/settings.json" <<'EOF'
{ "sandbox": { "filesystem": { "denyRead": ["~/secrets"] } } }
EOF
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  jq -e '.sandbox.filesystem.denyRead == ["~/secrets"]' "$HOME/.claude/settings.json"
}

@test "claude settings: re-running is a no-op that leaves no backup" {
  "$INSTALL" claude >/dev/null
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  [[ "$(printf '%s\n' "$output" | plain)" == *"already applied"* ]]
  [ "$(find "$HOME/.claude" -name 'settings.json.bak.*' | wc -l | tr -d ' ')" -eq 0 ]
}

@test "claude settings: a later model switch survives re-installing" {
  "$INSTALL" claude >/dev/null
  tmp="$BATS_TEST_TMPDIR/s.json"
  jq '.model = "opus"' "$HOME/.claude/settings.json" >"$tmp"
  mv "$tmp" "$HOME/.claude/settings.json"
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  jq -e '.model == "opus"' "$HOME/.claude/settings.json"
}

@test "claude settings: refuses to touch invalid JSON" {
  mkdir -p "$HOME/.claude"
  printf 'not json {{{' >"$HOME/.claude/settings.json"
  run "$INSTALL" claude
  [ "$(cat "$HOME/.claude/settings.json")" = 'not json {{{' ]
}
