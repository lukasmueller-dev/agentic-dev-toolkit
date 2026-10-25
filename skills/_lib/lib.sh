# shellcheck shell=bash
#
# lib.sh — helpers shared by the skill scripts: template rendering for every
# seed script, and brief staging for handoff-brief/handoff.sh and
# codebase-review/review.sh. One renderer for the placeholder contract in
# templates/README.md.
#
# Sourced, never executed. The caller runs under `set -euo pipefail` and has
# resolved its own real location first (script_dir cannot live here).
#
# The `_lib` name keeps this directory out of ~/.claude/skills: install.sh
# skips `skills/_*`.

die() {
  echo "${LIB_PROG:-lib}: $*" >&2
  exit 1
}
info() { echo "${LIB_PROG:-lib}: $*" >&2; }

command -v git >/dev/null 2>&1 || die "'git' is required but not installed."

# ---------------------------------------------------------------------------
# Locating the templates. This file lives at skills/_lib/, so the toolkit
# root is two levels up. The caller sourced us by an already-resolved
# physical path, so BASH_SOURCE needs no symlink walking of its own.
# ---------------------------------------------------------------------------
LIB_DIR_SELF="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_HOME="$(dirname "$(dirname "$LIB_DIR_SELF")")"
# shellcheck disable=SC2034  # consumed by the sourcing scripts
TEMPLATE_DIR="${TOOLKIT_TEMPLATE_DIR:-$TOOLKIT_HOME/templates}"

# render_template FILE [TOKEN VALUE]... — print FILE with each TOKEN replaced.
# Pure bash: no sed, so a value containing slashes (worktree paths hold them)
# needs no escaping. One left-to-right scan: the earliest remaining token
# occurrence is copied out with its value and scanning resumes AFTER the
# inserted value, so a value that itself contains another token renders
# literally instead of being re-substituted by a later pass — the old
# one-token-at-a-time ${content//tok/val} loop got that wrong. Avoiding
# ${var//pat/rep} entirely also retires the bash ≥5.2 patsub_replacement
# hazard ('&' in the value expanding to the matched pattern) this function
# used to shopt around.
render_template() {
  local tpl="$1"
  shift
  local -a toks=() vals=()
  while (($# >= 2)); do
    toks+=("$1")
    vals+=("$2")
    shift 2
  done
  local rest out="" pre
  rest="$(cat "$tpl")"
  local i best_at best_i
  while [[ -n "$rest" ]]; do
    best_at=-1 best_i=0
    for ((i = 0; i < ${#toks[@]}; i++)); do
      # prefix before the token's first occurrence; unchanged means absent
      pre="${rest%%"${toks[$i]}"*}"
      if [[ "$pre" != "$rest" ]] && ((best_at < 0 || ${#pre} < best_at)); then
        best_at=${#pre}
        best_i=$i
      fi
    done
    if ((best_at < 0)); then
      out+="$rest"
      break
    fi
    out+="${rest:0:best_at}${vals[$best_i]}"
    rest="${rest:$((best_at + ${#toks[$best_i]}))}"
  done
  printf '%s\n' "$out"
}

# ---------------------------------------------------------------------------
# Git helpers.
# ---------------------------------------------------------------------------
main_repo_root() {
  local common
  common="$(git rev-parse --git-common-dir 2>/dev/null)" || die "not inside a git repository."
  common="$(cd "$(dirname "$common")" && pwd)/$(basename "$common")"
  dirname "$common"
}
repo_name() { basename "$(main_repo_root)"; }
slug() { echo "$1" | tr '[:upper:] /' '[:lower:]--' | sed 's/[^a-z0-9._-]//g'; }
# worktree_dir BRANCH — where a brief is staged: the same place Claude Code
# puts its own worktrees, so one 'git worktree list' shows both.
worktree_dir() { echo "$(main_repo_root)/.claude/worktrees/$1"; }

# ff_main_quiet MAIN — best-effort fast-forward of MAIN's checked-out branch
# to its upstream, right before a new task branch is cut from MAIN's HEAD.
# Never refuses: a dirty tree, no upstream, or a failed fetch/merge is
# skipped. Untracked files are ignored — .claude/worktrees/ is one.
ff_main_quiet() {
  local main="$1"
  [[ -z "$(git -C "$main" status --porcelain --untracked-files=no 2>/dev/null)" ]] || return 0
  git -C "$main" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 || return 0
  git -C "$main" fetch -q 2>/dev/null || return 0
  local base
  base="$(git -C "$main" merge-base @ '@{u}' 2>/dev/null)" || return 0
  [[ "$base" == "$(git -C "$main" rev-parse @)" ]] || return 0
  [[ "$base" != "$(git -C "$main" rev-parse '@{u}')" ]] || return 0
  local branch
  branch="$(git -C "$main" rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 0
  git -C "$main" merge -q --ff-only '@{u}' 2>/dev/null &&
    info "fast-forwarded $branch before branching"
}

# ensure_worktree MAIN BRANCH DIR [BASE] — create DIR as a worktree for BRANCH.
# Preference order: existing local branch; branch on origin (fetched when
# needed, and tracked — so a brief pushed from another machine is picked up
# instead of shadowed by a fresh branch off HEAD); new branch off BASE when it
# resolves (untracked, so it never pushes to BASE); new branch off HEAD. Only
# the last case calls ff_main_quiet: the others do not depend on MAIN's HEAD.
ensure_worktree() {
  local main="$1" branch="$2" dir="$3" base="${4:-}"
  mkdir -p "$(dirname "$dir")"
  if git -C "$main" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$main" worktree add "$dir" "$branch"
  else
    git -C "$main" show-ref --verify --quiet "refs/remotes/origin/$branch" ||
      git -C "$main" fetch -q origin "$branch" >/dev/null 2>&1 || true
    if git -C "$main" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      git -C "$main" worktree add --track -b "$branch" "$dir" "origin/$branch"
    elif [[ -n "$base" ]] && git -C "$main" rev-parse -q --verify "$base^{commit}" >/dev/null; then
      git -C "$main" worktree add --no-track -b "$branch" "$dir" "$base"
    else
      ff_main_quiet "$main"
      git -C "$main" worktree add -b "$branch" "$dir"
    fi
  fi
  info "created worktree: $dir (branch: $branch)"
}

# seed_handoff_file DIR REPO BRANCH — render templates/HANDOFF.md into DIR
# unless one is already there.
seed_handoff_file() {
  local dir="$1" repo="$2" branch="$3"
  [[ ! -f "$dir/HANDOFF.md" && -f "$TEMPLATE_DIR/HANDOFF.md" ]] || return 0
  render_template "$TEMPLATE_DIR/HANDOFF.md" \
    '<repo>' "$repo" \
    '<branch>' "$branch" \
    '<worktree>' "$dir" \
    '<date>' "$(date '+%Y-%m-%d %H:%M %Z')" \
    '<machine>' "$(hostname)" >"$dir/HANDOFF.md"
  info "seeded HANDOFF.md"
}

# handoff_carries_content FILE — true when FILE holds anything beyond the
# template's own scaffolding: blank lines, headings, '>' guidance quotes,
# '- **Field:**' metadata, and single-line _placeholders_. A literal copy lives
# in claude/hooks/session-start-handoff.sh; update both together. The
# template keeps every placeholder on one line so this stays a line filter.
handoff_carries_content() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -qvE '^[[:space:]]*$|^#|^>|^- \*\*|^_.*_[[:space:]]*$' "$f"
}

# stage_worktree BRANCH — set STAGED_DIR to BRANCH's worktree, creating it
# when it does not exist.
#
# Sets a global instead of echoing the path deliberately: 'git worktree add'
# writes its progress to stdout, and a command substitution here would swallow
# that into the variable instead of letting it reach the caller's stdout.
stage_worktree() {
  local branch="$1"
  STAGED_DIR="$(worktree_dir "$branch")"
  if [[ ! -d "$STAGED_DIR" ]]; then
    ensure_worktree "$(main_repo_root)" "$branch" "$STAGED_DIR"
  fi
}

# handoff_stage_state DIR REPO BRANCH — seed DIR's HANDOFF.md when absent and
# print the STATE line telling the caller what it found: created (rendered
# fresh from the template), existing-scaffold (already there but holding only
# the template's scaffolding — fill it in like a fresh one), existing-handoff
# (real content — refine it in place, never overwrite). Shared by
# handoff-brief and codebase-review, which stage the same document.
handoff_stage_state() {
  local dir="$1" repo="$2" branch="$3" f="$1/HANDOFF.md"
  if [[ ! -f "$f" ]]; then
    seed_handoff_file "$dir" "$repo" "$branch"
    [[ -f "$f" ]] || die "no HANDOFF template at $TEMPLATE_DIR/HANDOFF.md"
    echo "STATE=created"
  elif handoff_carries_content "$f"; then
    echo "STATE=existing-handoff"
  else
    echo "STATE=existing-scaffold"
  fi
}

# publish_handoff DIR BRANCH COMMIT_MSG PUSH_HINT — validate that DIR's
# HANDOFF.md is finished, commit and push BRANCH, then remove the staging
# worktree so a new session can 'git switch BRANCH'. Only the commit message
# and the push-failure hint differ between the callers.
#
# Finished means: no token survived the render, and the two sections a cold
# session depends on were actually written. Blockers and Gotchas may keep
# their placeholders — often there are none yet.
publish_handoff() {
  local dir="$1" branch="$2" msg="$3" push_hint="$4" f="$1/HANDOFF.md"

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
    git -C "$dir" commit -q -m "$msg"
    info "committed the handoff"
  fi
  git -C "$dir" push -q -u origin "$branch" || die "$push_hint"
  info "pushed '$branch' to origin"
  if git -C "$(main_repo_root)" worktree remove "$dir" 2>/dev/null; then
    info "removed the staging worktree — '$branch' is free to check out"
  else
    info "could not remove $dir — run: git worktree remove '$dir'"
  fi
}

# section_unfinished FILE HEADING — true while the section under HEADING is
# empty or still holds only the template's _italic_ placeholder paragraph
# (which may wrap across lines: it starts with '_' and ends with '_').
# Structural, not wording-based, so editing the template cannot silently
# break the check.
section_unfinished() {
  awk -v h="$2" '
    BEGIN { unfinished = 1; insec = 0; decided = 0; inpar = 0 }
    $0 == h { insec = 1; next }
    insec && !decided {
      if ($0 ~ /^##/) {
        if (inpar) unfinished = (first ~ /^_/ && last ~ /_$/)
        decided = 1
      } else if (NF) {
        if (!inpar) { inpar = 1; first = $0 }
        last = $0
      } else if (inpar) {
        unfinished = (first ~ /^_/ && last ~ /_$/)
        decided = 1
      }
    }
    END {
      if (insec && !decided && inpar) unfinished = (first ~ /^_/ && last ~ /_$/)
      if (!insec) unfinished = 0
      exit unfinished ? 0 : 1
    }
  ' "$1"
}
