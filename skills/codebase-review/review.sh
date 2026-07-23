#!/usr/bin/env bash
#
# review.sh — stage the brief for an independent repo-review round on its own
# fresh-review-<n> branch, ready for a dedicated session (vibe start) to pick
# up.
#
#   review.sh create
#       Compute the round number from existing fresh-review-* branches (and
#       from round names surviving in the default branch's merge subjects, so
#       a deleted branch cannot reset the numbering), refuse while a prior
#       round other than the latest is unmerged, then create the round's
#       branch + worktree and seed HANDOFF.md from templates/. Prints
#       KEY=VALUE lines; ROUND_STATE tells the caller whether a new round was
#       staged or an existing unfinished one was adopted.
#
#   review.sh publish <branch>
#       Validate that the brief was actually written, then commit and push —
#       the same contract as handoff-brief's publish.
#
# The review mission prose never passes through this script: create renders
# the template, the caller edits the file, publish validates and ships it.
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
LIB_PROG=review
# shellcheck disable=SC1091  # path only exists at runtime, resolved above
. "$(dirname "$SKILL_DIR")/_lib/vibe-lib.sh"

# One review-round branch namespace, shared with the rounds staged by hand
# before this skill existed: 'fresh-review' (round 1) and 'fresh-review-<n>'.
BRANCH_PREFIX="fresh-review"

# default_branch — the branch review rounds merge into, from origin/HEAD with
# a reachable fallback: a remote added by `git remote add` (rather than clone)
# has no origin/HEAD ref at all.
default_branch() {
  local ref b
  ref="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$ref" ]]; then
    printf '%s\n' "${ref#origin/}"
    return 0
  fi
  for b in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$b"; then
      printf '%s\n' "$b"
      return 0
    fi
  done
  die "cannot resolve the default branch — no origin/HEAD, origin/main, or origin/master ref."
}

# round_number NAME — print NAME's round number, or nothing when NAME is not
# a round branch: 'fresh-review' is round 1, 'fresh-review-<digits>' is round
# <digits>, and anything else (e.g. 'fresh-review-fixes') is not a round.
# Digits pass through base-10 so a zero-padded name cannot trip octal
# arithmetic later.
round_number() {
  local n
  case "$1" in
    "$BRANCH_PREFIX") echo 1 ;;
    "$BRANCH_PREFIX"-*)
      n="${1#"$BRANCH_PREFIX"-}"
      if [[ "$n" =~ ^[0-9]+$ ]]; then echo "$((10#$n))"; fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# create
# ---------------------------------------------------------------------------
cmd_create() {
  [[ $# -eq 0 ]] || die "usage: review.sh create (the round number is computed, never passed)"

  local repo
  repo="$(repo_name)"
  git remote get-url origin >/dev/null 2>&1 ||
    die "no 'origin' remote — a staged round travels through git."

  # Count rounds staged from any machine, not this machine's stale view;
  # tolerate being offline (numbering then rests on already-fetched refs).
  git fetch -q origin "+refs/heads/$BRANCH_PREFIX*:refs/remotes/origin/$BRANCH_PREFIX*" 2>/dev/null || true

  local defbranch
  defbranch="$(default_branch)"

  local max=0 latest="" latest_merged_n=0 latest_merged="" unmerged=""
  local b n tip
  while IFS= read -r b; do
    n="$(round_number "$b")"
    [[ -n "$n" ]] || continue
    if ((n > max)); then
      max="$n"
      latest="$b"
    fi
    tip="refs/remotes/origin/$b"
    git show-ref --verify --quiet "$tip" || tip="refs/heads/$b"
    if git merge-base --is-ancestor "$tip" "refs/remotes/origin/$defbranch" 2>/dev/null; then
      if ((n > latest_merged_n)); then
        latest_merged_n="$n"
        latest_merged="$b"
      fi
    else
      unmerged="$unmerged $b"
    fi
  done < <(git for-each-ref --format='%(refname:short)' \
    "refs/heads/$BRANCH_PREFIX*" "refs/remotes/origin/$BRANCH_PREFIX*" |
    sed 's|^origin/||' | sort -u)

  # An unmerged prior round means its findings are still undecided — the
  # human merge gate between rounds is the design, not an accident. Only the
  # *latest* round may be unmerged, and it is then adopted below rather than
  # stacked on; anything older left unmerged needs the owner first.
  local stray
  stray="${unmerged/ "$latest"/}"
  if [[ -n "${stray// /}" ]]; then
    die "round branch(es) not merged into origin/$defbranch:$stray — merge or delete them before staging a new round."
  fi

  local round branch round_state=new
  if [[ -n "$latest" && "$unmerged " == *" $latest "* ]]; then
    # The latest round is staged or in flight — adopt it; whether to refine
    # or leave it is the caller's call, made with the user.
    round_state=existing
  elif [[ -n "$latest" ]]; then
    tip="refs/remotes/origin/$latest"
    git show-ref --verify --quiet "$tip" || tip="refs/heads/$latest"
    if [[ "$(git rev-parse "$tip")" == "$(git rev-parse "refs/remotes/origin/$defbranch")" ]]; then
      # No commits of its own: a staging leftover, not a completed round —
      # re-adopt it instead of burning its number.
      round_state=existing
    fi
  fi

  if [[ "$round_state" == existing ]]; then
    round="$max"
    branch="$latest"
  else
    # Round branches may be deleted after merge; their names survive in the
    # default branch's merge subjects. Never let the numbering restart — a
    # reused round number would collide with the coverage record that the
    # merged review PRs are.
    local hist
    hist="$(git log --format=%s "refs/remotes/origin/$defbranch" 2>/dev/null |
      grep -oE "$BRANCH_PREFIX(-[0-9]+)?" | sort -u || true)"
    while IFS= read -r b; do
      n="$(round_number "$b")"
      [[ -n "$n" ]] || continue
      if ((n > max)); then max="$n"; fi
    done <<<"$hist"
    round=$((max + 1))
    branch="$BRANCH_PREFIX-$round"
  fi

  stage_worktree "$branch" "review brief"
  handoff_stage_state "$STAGED_DIR" "$repo" "$branch"

  echo "ROUND=$round"
  echo "ROUND_STATE=$round_state"
  echo "REPO=$repo"
  echo "BRANCH=$branch"
  echo "DEFAULT_BRANCH=$defbranch"
  echo "LAST_ROUND_BRANCH=$latest_merged"
  echo "WORKTREE=$STAGED_DIR"
  echo "HANDOFF_MD=$STAGED_DIR/HANDOFF.md"
}

# ---------------------------------------------------------------------------
# publish
# ---------------------------------------------------------------------------
cmd_publish() {
  local branch="${1:-}"
  [[ -n "$branch" ]] || die "usage: review.sh publish <branch>"
  [[ -n "$(round_number "$branch")" ]] ||
    die "'$branch' is not a review-round branch — publish takes the BRANCH printed by create."

  local repo dir
  repo="$(repo_name)"
  dir="$(worktree_dir "$repo" "$branch")"
  [[ -d "$dir" ]] || die "no worktree for '$branch' at $dir — run: review.sh create"
  [[ -f "$dir/HANDOFF.md" ]] || die "no HANDOFF.md in $dir — run: review.sh create"
  if loop_live "$dir"; then
    die "a loop is running for '$branch' — never edit a brief under a live runner."
  fi

  publish_handoff "$dir" "$branch" "vibe handoff: brief '$branch'" \
    "push failed — resolve it by hand (never force-push a staged round)."

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
  *) die "usage: review.sh <create|publish [branch]>" ;;
esac
