#!/usr/bin/env bats
#
# readonly-bash.sh — the PreToolUse guard that keeps the reviewer subagents'
# Bash read-only. Allowed commands pass silently (exit 0); mutating ones are
# blocked (exit 2) with the reason on stderr; and like every hook, a missing
# dependency degrades to a no-op instead of breaking the session.

load helper

HOOK="$REPO_ROOT/claude/hooks/readonly-bash.sh"

# vet COMMAND — run the hook exactly as Claude Code would: the PreToolUse
# JSON payload on stdin. jq builds the payload so quoting in COMMAND survives.
vet() {
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' \
    "$(printf '%s' "$1" | jq -Rs .)" | "$HOOK"
}

# ---------------------------------------------------------------------------
# Allowed: inspection stays friction-free
# ---------------------------------------------------------------------------
@test "readonly-bash: allows the reviewer's bread and butter" {
  local c
  for c in \
    'git diff HEAD' \
    'git -C /some/repo log --oneline -20' \
    'git status --porcelain && git diff --stat' \
    'rg -n "TODO" src/' \
    'git show HEAD:file | head -50' \
    'shellcheck bin/vibe' \
    'shfmt -d -i 2 -ci .' \
    'bats tests/ 2>&1 | tail -5' \
    'sed -n "1,40p" file' \
    'find . -name "*.sh" -print' \
    'git branch --list -vv' \
    'git worktree list' \
    'shfmt -f . | xargs shellcheck'; do
    run vet "$c"
    [ "$status" -eq 0 ] || {
      echo "wrongly blocked: $c — $output" >&2
      return 1
    }
  done
}

@test "readonly-bash: a quoted '>' or '|' is data, not syntax" {
  # grep patterns hold alternation and redirect characters all the time; the
  # quote-aware pass must not read them as shell operators.
  run vet 'grep -E "foo|bar" file'
  [ "$status" -eq 0 ]
  run vet 'rg "=>" src/'
  [ "$status" -eq 0 ]
  # single quotes too — awk's quote tracking must recognize both kinds
  run vet "grep -E 'foo|bar' file"
  [ "$status" -eq 0 ]
  run vet "rg 'a > b' docs/"
  [ "$status" -eq 0 ]
}

@test "readonly-bash: /dev/null and fd duplication are not writes" {
  run vet 'git diff 2>/dev/null'
  [ "$status" -eq 0 ]
  run vet 'bats tests/ 2>&1'
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Blocked: every road to mutation exits 2 with the reason on stderr
# ---------------------------------------------------------------------------
@test "readonly-bash: blocks direct mutation and off-list commands" {
  local c
  for c in \
    'rm -rf build' \
    'git commit -m "x"' \
    'git push --force' \
    'git checkout .' \
    'git stash pop' \
    'npm install' \
    'python3 -c "anything"'; do
    run vet "$c"
    [ "$status" -eq 2 ] || {
      echo "wrongly allowed: $c" >&2
      return 1
    }
    [[ "$output" == *"read-only reviewer guard"* ]]
  done
}

@test "readonly-bash: blocks the write-capable flags of allowed tools" {
  local c
  for c in \
    'sed -i "s/a/b/" file' \
    'sed -ni "s/a/b/" file' \
    'shfmt -w .' \
    'sort -o out in' \
    'find . -name "*.tmp" -delete' \
    'find . -name "*.sh" -exec rm {} +'; do
    run vet "$c"
    [ "$status" -eq 2 ] || {
      echo "wrongly allowed: $c" >&2
      return 1
    }
  done
}

@test "readonly-bash: blocks redirection anywhere but /dev/null" {
  run vet 'echo x > file'
  [ "$status" -eq 2 ]
  run vet 'git diff >> notes.txt'
  [ "$status" -eq 2 ]
  run vet 'cat a | tee b'
  [ "$status" -eq 2 ]
}

@test "readonly-bash: blocks a mutating segment hidden in an allowed chain" {
  run vet 'git diff && git add -A'
  [ "$status" -eq 2 ]
  run vet 'ls; rm x'
  [ "$status" -eq 2 ]
  run vet 'true | xargs rm'
  [ "$status" -eq 2 ]
}

@test "readonly-bash: blocks command substitution rather than guess at it" {
  # shellcheck disable=SC2016  # the literal $(...) is the payload under test
  run vet 'git diff $(git merge-base HEAD main)'
  [ "$status" -eq 2 ]
  [[ "$output" == *"own Bash call"* ]]
  # shellcheck disable=SC2016
  run vet 'cat `ls`'
  [ "$status" -eq 2 ]
}

@test "readonly-bash: an env-var prefix does not smuggle a command past" {
  run vet 'GIT_PAGER=cat git diff'
  [ "$status" -eq 0 ]
  run vet 'FOO=1 rm -rf x'
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Degrade paths: never break the session
# ---------------------------------------------------------------------------
@test "readonly-bash: no-ops when jq is unavailable" {
  run env PATH= /bin/bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "readonly-bash: ignores payloads for other tools" {
  run bash -c "echo '{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/etc/passwd\"}}' | '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "readonly-bash: survives malformed stdin without complaining" {
  run bash -c "echo 'not json' | '$HOOK'"
  [ "$status" -eq 0 ]
  run bash -c "printf '' | '$HOOK'"
  [ "$status" -eq 0 ]
}
