#!/usr/bin/env bash
#
# handoff.sh — stage a refined HANDOFF.md on its own task branch, ready for a
# dedicated interactive session (vibe start / vibe attach) to pick up.
#
#   handoff.sh create <task>
#       Ensure the task's branch + worktree exist (adopting a branch that
#       exists only on origin) and seed HANDOFF.md from templates/. Prints
#       KEY=VALUE lines; STATE tells the caller what it found:
#         created           — handoff rendered fresh from the template
#         existing-scaffold — a handoff was already there, but holds only the
#                             template's scaffolding; fill it in like a fresh one
#         existing-handoff  — a handoff with real content exists; refine it in
#                             place, never overwrite it
#
#   handoff.sh publish <task>
#       Validate that the handoff was actually written, then commit and push.
#
# The refined State / Next action prose never passes through this script:
# create renders the template, the caller edits the file, publish validates
# and ships it.
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
LIB_PROG=handoff
# shellcheck disable=SC1091  # path only exists at runtime, resolved above
. "$(dirname "$SKILL_DIR")/_lib/vibe-lib.sh"

# ---------------------------------------------------------------------------
# create
# ---------------------------------------------------------------------------
cmd_create() {
  local task="${1:-}"
  [[ -n "$task" ]] || die "usage: handoff.sh create <task>"
  [[ $# -le 1 ]] || die "one task only — got '$task' and '$2'"

  local repo branch dir
  repo="$(repo_name)"
  branch="$(slug "$task")"
  stage_worktree "$branch" handoff
  dir="$STAGED_DIR"

  handoff_stage_state "$dir" "$repo" "$branch"

  echo "REPO=$repo"
  echo "BRANCH=$branch"
  echo "WORKTREE=$dir"
  echo "HANDOFF_MD=$dir/HANDOFF.md"
}

# ---------------------------------------------------------------------------
# publish
# ---------------------------------------------------------------------------
cmd_publish() {
  local task="${1:-}"
  [[ -n "$task" ]] || die "usage: handoff.sh publish <task>"

  local repo branch dir f
  repo="$(repo_name)"
  branch="$(slug "$task")"
  dir="$(worktree_dir "$repo" "$branch")"
  f="$dir/HANDOFF.md"

  [[ -d "$dir" ]] || die "no worktree for '$branch' at $dir — run: handoff.sh create '$task'"
  [[ -f "$f" ]] || die "no HANDOFF.md in $dir — run: handoff.sh create '$task'"
  if loop_live "$dir"; then
    die "a loop is running for '$branch' — never edit a handoff under a live runner."
  fi

  publish_handoff "$dir" "$branch" "vibe handoff: brief '$branch'" \
    "push failed — resolve it by hand (never force-push a handoff)."

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
  *) die "usage: handoff.sh <create|publish> <task>" ;;
esac
