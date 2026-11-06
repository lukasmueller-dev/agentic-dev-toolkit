#!/usr/bin/env bash
#
# cleanup.sh — find and remove the git worktrees of a repo whose work has
# landed on the default branch.
#
#   cleanup.sh scan [<repo>]
#       Fetch (best effort), then print one tab-separated line per linked
#       worktree of <repo> (default: the current repo):
#         <state>  <path>  <branch>  <reason>
#       merged    work is on the default branch, or a merged PR has it
#                 and its upstream was deleted
#       prunable  directory is gone; only git's record is left
#       dirty     uncommitted or untracked changes
#       ignored   git-ignored files that removal would delete
#       unpushed  commits that are not on the default branch
#       locked    held by a running session
#       current   the worktree this command runs in
#
#   cleanup.sh remove <path>...
#       Remove each worktree that scan rates merged or prunable, and delete
#       its local branch. Refuses every other state. Never forces.
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
LIB_PROG=cleanup
# shellcheck disable=SC1091  # path only exists at runtime, resolved above
. "$(dirname "$SKILL_DIR")/_lib/lib.sh"

# default_ref — origin's default branch as a ref, e.g. origin/main.
default_ref() {
  local ref b
  ref="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$ref" ]]; then
    printf '%s\n' "$ref"
    return 0
  fi
  for b in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$b"; then
      printf 'origin/%s\n' "$b"
      return 0
    fi
  done
  die "cannot resolve the default branch — no origin/HEAD, origin/main, or origin/master ref."
}

# physical DIR — DIR with symlinks resolved; when DIR is gone, its parent is.
physical() {
  (cd -P "$1" 2>/dev/null && pwd) ||
    (cd -P "$(dirname "$1")" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$(basename "$1")") ||
    printf '%s\n' "$1"
}

# The worktree the caller runs in, resolved before any cd: never removable.
CUR_WT="$(physical "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"

# ignored_keep PATH — the git-ignored files of worktree PATH that removal
# would lose, as "a, b, c (+N more)"; empty when nothing but caches is left.
ignored_keep() {
  local all
  all="$(git -C "$1" -c core.quotePath=false ls-files --others --ignored --exclude-standard 2>/dev/null)" || {
    printf 'cannot list the git-ignored files\n'
    return 0
  }
  awk '
    function regen(p) {
      return p ~ /(^|\/)(\.venv|node_modules|__pycache__|\.pytest_cache|\.mypy_cache|\.ruff_cache|\.tox|\.vscode)(\/|$)/ ||
        p ~ /(^|\/)[^\/]+\.egg-info(\/|$)/ ||
        p ~ /(^|\/)(\.DS_Store|[^\/]+\.sw[po])$/ ||
        p ~ /^(target|dist|build)(\/|$)/ ||
        p == ".claude/settings.local.json"
    }
    length($0) && !regen($0) {
      n++
      if (n <= 3) l = l (n > 1 ? ", " : "") $0
    }
    END { if (n > 3) l = l " (+" (n - 3) " more)"; if (n) print l }
  ' <<<"$all"
}

# landed_or_ignored PATH REASON — "merged<TAB>REASON", or "ignored" when
# PATH holds git-ignored files that removal would delete.
landed_or_ignored() {
  local keep
  keep="$(ignored_keep "$1")"
  if [[ -n "$keep" ]]; then
    printf 'ignored\t%s\n' "$keep"
  else
    printf 'merged\t%s\n' "$2"
  fi
}

# pr_landed PATH BRANCH — succeed when a merged PR of BRANCH has the HEAD of
# PATH in its history. Fails when gh is missing or errors.
pr_landed() {
  local oids oid
  command -v gh >/dev/null 2>&1 || return 1
  oids="$(gh pr list --head "$2" --state merged --json headRefOid --jq '.[].headRefOid' 2>/dev/null)" || return 1
  while IFS= read -r oid; do
    [[ -n "$oid" ]] || continue
    if git -C "$1" merge-base --is-ancestor HEAD "$oid" 2>/dev/null; then return 0; fi
  done <<<"$oids"
  return 1
}

# classify PATH BRANCH LOCKED PRUNABLE REF CURRENT — print "state<TAB>reason".
classify() {
  local path="$1" branch="$2" locked="$3" prunable="$4" ref="$5" cur="$6" track
  if [[ "$prunable" == 1 || ! -d "$path" ]]; then
    printf 'prunable\tdirectory is gone\n'
  elif [[ "$(physical "$path")" == "$cur" ]]; then
    printf 'current\tthis command runs here\n'
  elif [[ "$locked" == 1 ]]; then
    printf 'locked\theld by a running session\n'
  elif [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
    printf 'dirty\tuncommitted or untracked changes\n'
  elif git -C "$path" merge-base --is-ancestor HEAD "$ref" 2>/dev/null; then
    landed_or_ignored "$path" "all commits are on $ref"
  else
    track=""
    if [[ -n "$branch" ]]; then
      track="$(git for-each-ref --format='%(upstream:track)' "refs/heads/$branch" 2>/dev/null || true)"
    fi
    if [[ "$track" == "[gone]" ]] && pr_landed "$path" "$branch"; then
      landed_or_ignored "$path" "upstream branch was deleted after a merged PR"
    else
      printf 'unpushed\tcommits that are not on %s\n' "$ref"
    fi
  fi
}

# scan_lines [PATH] — one "state<TAB>path<TAB>branch<TAB>reason" line per linked
# worktree of the repo in $PWD, or only for PATH; branch is "-" when detached.
# The first porcelain record is the main checkout and is skipped.
scan_lines() {
  local ref cur="${CUR_WT:-}" only="" line path="" branch="" locked=0 prunable=0 n=0
  [[ $# -eq 0 ]] || only="$(physical "$1")"
  ref="$(default_ref)"
  emit() {
    if ((n > 1)) && [[ -n "$path" ]] && { [[ -z "$only" ]] || [[ "$(physical "$path")" == "$only" ]]; }; then
      local verdict
      verdict="$(classify "$path" "$branch" "$locked" "$prunable" "$ref" "$cur")"
      printf '%s\t%s\t%s\t%s\n' "${verdict%%$'\t'*}" "$path" "${branch:--}" "${verdict#*$'\t'}"
    fi
  }
  while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        n=$((n + 1))
        path="${line#worktree }" branch="" locked=0 prunable=0
        ;;
      "branch refs/heads/"*) branch="${line#branch refs/heads/}" ;;
      locked | "locked "*) locked=1 ;;
      prunable | "prunable "*) prunable=1 ;;
      "")
        emit
        path=""
        ;;
    esac
  done < <(git worktree list --porcelain)
  emit
}

cmd_scan() {
  local repo="${1:-.}"
  cd "$repo" 2>/dev/null || die "no such directory: $repo"
  cd "$(main_repo_root)"
  if git fetch -q --prune origin 2>/dev/null; then
    echo "FETCH=ok"
  else
    echo "FETCH=failed — states use the last fetched remote refs"
  fi
  echo "REPO=$(pwd)"
  echo "DEFAULT=$(default_ref)"
  scan_lines
}

cmd_remove() {
  (($# > 0)) || die "usage: cleanup.sh remove <path>..."
  local p dir main state path branch reason found rc=0
  for p in "$@"; do
    dir="$(dirname "$p")"
    [[ -d "$p" ]] && dir="$p"
    main="$(cd "$dir" 2>/dev/null && main_repo_root)" || {
      info "skip $p: not inside a git repository"
      rc=1
      continue
    }
    found=0
    while IFS=$'\t' read -r state path branch reason; do
      found=1
      case "$state" in
        merged)
          git -C "$main" worktree remove "$path" || die "git refused to remove $path"
          info "removed worktree $path"
          if [[ "$branch" != "-" ]]; then
            git -C "$main" branch -D "$branch" >/dev/null
            info "deleted branch $branch"
          fi
          ;;
        prunable)
          git -C "$main" worktree prune
          info "pruned the record of $path"
          ;;
        *)
          info "skip $path: $state — $reason"
          rc=1
          ;;
      esac
    done < <(cd "$main" && scan_lines "$p")
    if ((found == 0)); then
      info "skip $p: not a linked worktree of $main"
      rc=1
    fi
  done
  return "$rc"
}

cmd="${1:-}"
shift || true
case "$cmd" in
  scan) cmd_scan "$@" ;;
  remove) cmd_remove "$@" ;;
  *) die "usage: cleanup.sh <scan [repo]|remove <path>...>" ;;
esac
