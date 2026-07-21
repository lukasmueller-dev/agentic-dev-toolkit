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

  local f="$dir/HANDOFF.md"
  if [[ ! -f "$f" ]]; then
    seed_handoff_file "$dir" "$repo" "$branch"
    [[ -f "$f" ]] || die "no HANDOFF template at $TEMPLATE_DIR/HANDOFF.md"
    echo "STATE=created"
  elif handoff_carries_content "$f"; then
    # A handoff with real content means a task already in flight — the caller
    # must show it and refine it, never start over.
    echo "STATE=existing-handoff"
  else
    # Scaffolding only (e.g. seeded earlier by vibe start): safe to fill in.
    echo "STATE=existing-scaffold"
  fi

  echo "REPO=$repo"
  echo "BRANCH=$branch"
  echo "WORKTREE=$dir"
  echo "HANDOFF_MD=$f"
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

  # The handoff must be finished before it ships: no unrendered tokens, and
  # the two sections a cold session depends on actually written. Blockers and
  # Gotchas may keep their placeholders — often there are none yet.
  if grep -qE '<(repo|branch|worktree|date|machine)>' "$f"; then
    die "HANDOFF.md still contains unrendered <tokens> — finish the handoff first."
  fi
  local heading
  for heading in '## State' '## Next action'; do
    grep -qxF "$heading" "$f" ||
      die "HANDOFF.md lost its '$heading' section — restore the template structure."
    if section_unfinished "$f" "$heading"; then
      die "the '$heading' section is still the template placeholder — write it before publishing."
    fi
  done

  git -C "$dir" add HANDOFF.md
  if [[ -n "$(git -C "$dir" status --porcelain -- HANDOFF.md)" ]]; then
    git -C "$dir" commit -q -m "vibe handoff: brief '$branch'"
    info "committed the handoff"
  fi
  git -C "$dir" push -q -u origin "$branch" ||
    die "push failed — resolve it by hand (never force-push a handoff)."
  info "pushed '$branch' to origin"

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
