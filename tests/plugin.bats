#!/usr/bin/env bats
#
# The Claude Code plugin manifest. Two things are being guarded here:
#
#   1. The plugin stays a PURE ADDITION — install.sh must not see it, and it
#      must not need install.sh.
#   2. The two copies of the hook wiring stay in step. claude/settings.json
#      wires $HOME/.claude/hooks/…; .claude-plugin/hooks.json wires
#      ${CLAUDE_PLUGIN_ROOT}/claude/hooks/…. Neither is generated from the
#      other, so only a test can notice when one gains an event the other
#      never got.
#
# Nothing here launches Claude Code. `claude plugin validate` is the real
# schema check and it runs where the binary exists; everything else is
# assertions about files.

load helper

setup() {
  MANIFEST="$REPO_ROOT/.claude-plugin/plugin.json"
  PLUGIN_HOOKS="$REPO_ROOT/.claude-plugin/hooks.json"
  BASELINE="$REPO_ROOT/claude/settings.json"
}

@test "plugin: the manifest is valid JSON and names the plugin" {
  run jq -e '.name == "agentic-dev-toolkit"' "$MANIFEST"
  [ "$status" -eq 0 ]
  # version pins updates: without it every commit counts as a new release
  run jq -e '.version | type == "string"' "$MANIFEST"
  [ "$status" -eq 0 ]
}

@test "plugin: every agent file is listed in the manifest" {
  # `agents` must be a list of FILES — the validator rejects a directory — so
  # this is what replaces the installer's auto-discovery. Adding an agent and
  # forgetting the manifest line is meant to be loud, not silent.
  local f b
  for f in "$REPO_ROOT"/claude/agents/*.md; do
    b="$(basename "$f")"
    [ "$b" = README.md ] && continue
    run jq -e --arg p "./claude/agents/$b" 'any(.agents[]; . == $p)' "$MANIFEST"
    [ "$status" -eq 0 ]
  done
}

@test "plugin: the manifest lists no agent file that is gone" {
  local p
  while IFS= read -r p; do
    [ -f "$REPO_ROOT/${p#./}" ]
  done < <(jq -r '.agents[]' "$MANIFEST")
}

@test "plugin: README.md is not shipped as an agent" {
  # It documents the directory. A directory scan would have loaded it as an
  # agent definition, which is half the reason the manifest lists files.
  run jq -e 'any(.agents[]; test("README"))' "$MANIFEST"
  [ "$status" -ne 0 ]
}

@test "plugin: every hook command resolves to a file in the repo" {
  local cmd path
  while IFS= read -r cmd; do
    # strip the quoted ${CLAUDE_PLUGIN_ROOT} prefix the manifest uses
    path="${cmd#\"\$\{CLAUDE_PLUGIN_ROOT\}\"/}"
    [ "$path" != "$cmd" ] # every command must go through the variable
    [ -f "$REPO_ROOT/$path" ]
  done < <(jq -r '.hooks | to_entries[].value[].hooks[].command' "$PLUGIN_HOOKS")
}

@test "plugin: every hook event in the settings baseline is wired in the plugin too" {
  # The failure this catches: a hook added to claude/settings.json for the
  # symlink install, and never carried across, so the plugin silently ships a
  # session without it.
  local e
  while IFS= read -r e; do
    run jq -e --arg e "$e" '.hooks | has($e)' "$PLUGIN_HOOKS"
    [ "$status" -eq 0 ]
  done < <(jq -r '.hooks | keys[]' "$BASELINE")
}

@test "plugin: every hook script the baseline wires is wired in the plugin too" {
  # Compared by basename: the two configs address the same scripts through
  # different roots, which is the whole reason they cannot be one file.
  local b
  while IFS= read -r b; do
    run jq -e --arg b "$b" \
      '[.hooks | to_entries[].value[].hooks[].command] | any(endswith("/" + $b))' \
      "$PLUGIN_HOOKS"
    [ "$status" -eq 0 ]
  done < <(jq -r '[.hooks | to_entries[].value[].hooks[].command]
                  | map(sub(".*/"; "")) | unique[]' "$BASELINE")
}

@test "plugin: the two hooks the plugin adds are NOT wired in the baseline" {
  # They exist to replace things a plugin cannot do. Wiring them in the symlink
  # install would double-inject the global memory and duplicate a guard the
  # agent frontmatter already applies.
  local b
  for b in inject-global-memory.sh readonly-bash-for-reviewers.sh; do
    run jq -e --arg b "$b" \
      '[.hooks // {} | to_entries[].value[].hooks[].command] | any(test($b))' \
      "$BASELINE"
    [ "$status" -ne 0 ]
    # and the file they name really is there
    [ -f "$REPO_ROOT/claude/hooks/$b" ]
  done
}

@test "plugin: the reviewer guard fires for the read-only agents, scoped or bare" {
  local h="$REPO_ROOT/claude/hooks/readonly-bash-for-reviewers.sh" a
  for a in diff-reviewer docs-drift security-sweep; do
    for name in "$a" "agentic-dev-toolkit:$a"; do
      run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"agent_type\":\"$name\",\"tool_input\":{\"command\":\"rm -rf /tmp/x\"}}' | bash '$h'"
      [ "$status" -eq 2 ]
    done
  done
}

@test "plugin: the reviewer guard leaves everyone else alone" {
  local h="$REPO_ROOT/claude/hooks/readonly-bash-for-reviewers.sh" payload
  # test-hardener may write; the main thread has no agent_type at all; and a
  # foreign agent whose name merely ends in one of ours must not inherit the
  # guard — that is what the ':' anchor in the match is for.
  for payload in \
    '{"tool_name":"Bash","agent_type":"test-hardener","tool_input":{"command":"rm -rf /tmp/x"}}' \
    '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/x"}}' \
    '{"tool_name":"Bash","agent_type":"their-docs-drift","tool_input":{"command":"rm -rf /tmp/x"}}'; do
    run bash -c "printf '%s' '$payload' | bash '$h'"
    [ "$status" -eq 0 ]
  done
}

@test "plugin: the reviewer guard fails open on junk" {
  local h="$REPO_ROOT/claude/hooks/readonly-bash-for-reviewers.sh"
  run bash -c "printf 'not json' | bash '$h'"
  [ "$status" -eq 0 ]
  run bash -c "printf '' | bash '$h'"
  [ "$status" -eq 0 ]
}

@test "plugin: the memory hook injects on startup and clear only" {
  local h="$REPO_ROOT/claude/hooks/inject-global-memory.sh" src
  for src in startup clear; do
    run bash -c "printf '%s' '{\"source\":\"$src\"}' | bash '$h'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
    # the real memory, not a placeholder
    run bash -c "printf '%s' '{\"source\":\"$src\"}' | bash '$h' | jq -r '.hookSpecificOutput.additionalContext'"
    [[ "$output" == *"Where information goes"* ]]
  done
  # sources that already carry context forward must stay silent
  for src in resume compact fork; do
    run bash -c "printf '%s' '{\"source\":\"$src\"}' | bash '$h'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "plugin: the memory hook fails open on junk" {
  local h="$REPO_ROOT/claude/hooks/inject-global-memory.sh"
  run bash -c "printf 'not json' | bash '$h'"
  [ "$status" -eq 0 ]
  run bash -c "printf '' | bash '$h'"
  [ "$status" -eq 0 ]
}

@test "plugin: install.sh does not see the plugin directory" {
  # "Pure addition beside install.sh" is the roadmap item's own wording, and
  # this is what makes it checkable: nothing under .claude-plugin/ may end up
  # linked into HOME.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  run "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/plugin.json" ]
  [ ! -e "$HOME/.claude-plugin" ]
  run bash -c "find '$HOME' -type l -lname '*.claude-plugin*' | head -1"
  [ -z "$output" ]
}

@test "plugin: the manifest and hook config are the only files it adds" {
  # A drifting plugin tends to grow a parallel copy of things that already
  # live elsewhere in the repo. Keep the directory to its two config files.
  run bash -c "ls -A '$REPO_ROOT/.claude-plugin' | sort | tr '\n' ' '"
  [ "$output" = "hooks.json plugin.json " ]
}
