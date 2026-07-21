#!/usr/bin/env bash
#
# brief.sh — stage a LOOP.md brief whose goal is "PR #N is mergeable", on the
# PR's own head branch, ready for an unattended loop to pick up.
#
#   brief.sh create <pr-number>
#       Resolve the PR's head branch through `gh`, ensure a worktree for it
#       (adopting the branch from origin), render LOOP.md from templates/ with
#       pr-ready.sh as the stop check, and seed HANDOFF.md. Prints KEY=VALUE
#       lines; STATE=existing-brief means a LOOP.md was already there and was
#       left untouched.
#
#   brief.sh publish <pr-number>
#       Validate that the brief's placeholder sections were actually written,
#       then commit LOOP.md (+ HANDOFF.md) and push the branch.
#
# As in skills/loop-brief/brief.sh, the refined Goal / Done when / Constraints
# prose never passes through this script: create renders the template, the
# caller edits the file, publish validates and ships it. Only the PR number
# crosses the argv boundary.
#
# This script never merges, closes, reviews or comments on the PR, and never
# starts the loop.
set -euo pipefail

# The skill directory is symlinked into the agent's skills directory, so $PWD
# and $0 both point somewhere useless. Walk the symlink chain; `readlink -f`
# is avoided for BSD/macOS compatibility.
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
LIB_PROG=babysit-pr
# shellcheck disable=SC1091  # path only exists at runtime, resolved above
. "$(dirname "$SKILL_DIR")/_lib/vibe-lib.sh"

# pr_number ARG — the PR number, or die.
pr_number() {
  local pr="${1:-}"
  [[ "$pr" =~ ^[0-9]+$ ]] || die "usage: brief.sh <create|publish> <pr-number>"
  printf '%s' "$pr"
}

# pr_json PR — the PR's headRefName/title/url as JSON, read through gh.
pr_json() {
  local pr="$1" out
  command -v gh >/dev/null 2>&1 || die "'gh' is required to look up PR #$pr."
  command -v jq >/dev/null 2>&1 || die "'jq' is required to read gh's output."
  out="$(gh pr view "$pr" --json headRefName,title,url 2>&1)" ||
    die "could not read PR #$pr through gh: $out"
  printf '%s' "$out"
}

# pr_field JSON FIELD — one field out of pr_json's output.
pr_field() { printf '%s' "$1" | jq -r ".$2 // empty"; }

# ---------------------------------------------------------------------------
# create
# ---------------------------------------------------------------------------
cmd_create() {
  local pr
  pr="$(pr_number "${1:-}")"
  [[ $# -le 1 ]] || die "usage: brief.sh create <pr-number>"

  local json branch title url
  json="$(pr_json "$pr")"
  branch="$(pr_field "$json" headRefName)"
  [[ -n "$branch" ]] || die "PR #$pr has no head branch — is the number right?"
  title="$(pr_field "$json" title)"
  url="$(pr_field "$json" url)"

  local repo main dir
  repo="$(repo_name)"
  main="$(main_repo_root)"
  dir="$(worktree_dir "$repo" "$branch")"

  if [[ -d "$dir" ]] && loop_live "$dir"; then
    die "a loop is running for '$branch' — never edit a brief under a live runner."
  fi
  [[ -d "$dir" ]] || ensure_worktree "$main" "$branch" "$dir"

  local until_cmd="bash $SKILL_DIR/pr-ready.sh $pr"
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
      '<goal>' "PR #$pr is mergeable — $title ($url)" \
      '<until>' "$until_cmd" \
      '<max>' "10" \
      '<date>' "$(date '+%Y-%m-%d %H:%M %Z')" \
      '<machine>' "$(detect_env) ($(hostname))" >"$f"
    info "rendered LOOP.md from the shared template"
    echo "STATE=created"
  fi

  # Seed the handoff too: the task travels between machines, and every vibe
  # worktree carries one. Skips an existing file.
  seed_handoff_file "$dir" "$repo" "$branch"

  echo "PR=$pr"
  echo "REPO=$repo"
  echo "BRANCH=$branch"
  echo "WORKTREE=$dir"
  echo "LOOP_MD=$f"
  echo "UNTIL=$until_cmd"
}

# ---------------------------------------------------------------------------
# publish
# ---------------------------------------------------------------------------
cmd_publish() {
  local pr
  pr="$(pr_number "${1:-}")"

  local repo branch dir f
  repo="$(repo_name)"
  branch="$(pr_field "$(pr_json "$pr")" headRefName)"
  [[ -n "$branch" ]] || die "PR #$pr has no head branch — is the number right?"
  dir="$(worktree_dir "$repo" "$branch")"
  f="$dir/LOOP.md"

  [[ -d "$dir" ]] || die "no worktree for '$branch' at $dir — run: brief.sh create $pr"
  [[ -f "$f" ]] || die "no LOOP.md in $dir — run: brief.sh create $pr"
  if loop_live "$dir"; then
    die "a loop is running for '$branch' — never edit a brief under a live runner."
  fi

  publish_brief "$dir" "$branch" "vibe loop: brief 'PR #$pr is mergeable'" \
    "push failed — resolve it by hand (never force-push a PR branch)."

  echo "STATE=published"
  echo "PR=$pr"
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
  *) die "usage: brief.sh <create|publish> <pr-number>" ;;
esac
