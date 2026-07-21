#!/usr/bin/env bash
#
# brief.sh — stage a refined LOOP.md brief on its own task branch, ready for
# an unattended loop to pick up.
#
#   brief.sh create <task> [--until <cmd>] [--max <n>]
#       Ensure the task's branch + worktree exist (adopting a branch that
#       exists only on origin), render LOOP.md from templates/, and seed
#       HANDOFF.md. Prints KEY=VALUE lines; STATE=existing-brief means a
#       LOOP.md was already there and was left untouched.
#
#   brief.sh publish <task>
#       Validate that the brief's placeholder sections were actually written,
#       then commit LOOP.md (+ HANDOFF.md) and push the branch.
#
# The refined Goal / Done when / Constraints prose never passes through this
# script: create renders the template, the caller edits the file, publish
# validates and ships it. Only --until and --max cross the argv boundary.
set -euo pipefail

# The skill directory is symlinked into ~/.claude/skills, so $PWD and $0 both
# point somewhere useless. Walk the symlink chain; `readlink -f` is avoided
# for BSD/macOS compatibility.
script_dir() {
  local src="${BASH_SOURCE[0]}" dir
  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

SKILL_DIR="$(script_dir)"
# shellcheck disable=SC2034  # read by the lib's die/info message prefix
LIB_PROG=brief
# shellcheck disable=SC1091  # path only exists at runtime, resolved above
. "$(dirname "$SKILL_DIR")/_lib/vibe-lib.sh"

# ---------------------------------------------------------------------------
# create
# ---------------------------------------------------------------------------
cmd_create() {
  local task="" until_cmd="" max=""
  while (($#)); do
    case "$1" in
      --until)
        until_cmd="${2-}"
        shift 2 || die "--until needs a command"
        ;;
      --until=*)
        until_cmd="${1#--until=}"
        shift
        ;;
      --max)
        max="${2-}"
        shift 2 || die "--max needs a number"
        ;;
      --max=*)
        max="${1#--max=}"
        shift
        ;;
      -*) die "unknown option '$1' (usage: brief.sh create <task> [--until <cmd>] [--max <n>])" ;;
      *)
        [[ -z "$task" ]] || die "one task only — got '$task' and '$1'"
        task="$1"
        shift
        ;;
    esac
  done
  [[ -n "$task" ]] || die "usage: brief.sh create <task> [--until <cmd>] [--max <n>]"
  [[ -z "$max" || "$max" =~ ^[0-9]+$ ]] || die "--max must be a number, got '$max'"
  max="${max:-10}"

  local repo branch dir
  repo="$(repo_name)"
  branch="$(slug "$task")"
  stage_worktree "$branch" brief
  dir="$STAGED_DIR"

  local f="$dir/LOOP.md"
  if [[ -f "$f" ]]; then
    # An existing brief is never regenerated — refine it in place instead.
    echo "STATE=existing-brief"
  else
    local tpl="$TEMPLATE_DIR/LOOP.md"
    [[ -f "$tpl" ]] || die "no LOOP template at $tpl"
    render_template "$tpl" \
      '<repo>' "$repo" \
      '<branch>' "$branch" \
      '<worktree>' "$dir" \
      '<goal>' "$task" \
      '<until>' "${until_cmd:-—}" \
      '<max>' "$max" \
      '<date>' "$(date '+%Y-%m-%d %H:%M %Z')" \
      '<machine>' "$(detect_env) ($(hostname))" >"$f"
    info "rendered LOOP.md from the shared template"
    echo "STATE=created"
  fi

  # Seed the handoff too: the task travels between machines, and every vibe
  # worktree carries one. Skips an existing file.
  seed_handoff_file "$dir" "$repo" "$branch"

  echo "REPO=$repo"
  echo "BRANCH=$branch"
  echo "WORKTREE=$dir"
  echo "LOOP_MD=$f"
}

# ---------------------------------------------------------------------------
# publish
# ---------------------------------------------------------------------------
cmd_publish() {
  local task="${1:-}"
  [[ -n "$task" ]] || die "usage: brief.sh publish <task>"

  local repo branch dir f
  repo="$(repo_name)"
  branch="$(slug "$task")"
  dir="$(worktree_dir "$repo" "$branch")"
  f="$dir/LOOP.md"

  [[ -d "$dir" ]] || die "no worktree for '$branch' at $dir — run: brief.sh create '$task'"
  [[ -f "$f" ]] || die "no LOOP.md in $dir — run: brief.sh create '$task'"
  if loop_live "$dir"; then
    die "a loop is running for '$branch' — never edit a brief under a live runner."
  fi

  publish_brief "$dir" "$branch" "vibe loop: brief '$branch'" \
    "push failed — resolve it by hand (never force-push a brief)."

  echo "STATE=published"
  echo "BRANCH=$branch"
  echo "WORKTREE=$dir"
}

# ---------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------
cmd="${1:-}"
shift || true
case "$cmd" in
  create) cmd_create "$@" ;;
  publish) cmd_publish "$@" ;;
  *) die "usage: brief.sh <create|publish> <task> [options]" ;;
esac
