# shellcheck shell=bash
#
# vibe-lib.sh — helpers shared by the skill scripts that stage vibe task
# briefs (loop-brief/brief.sh, handoff-brief/handoff.sh).
#
# Sourced, never executed. The caller is expected to run under
# `set -euo pipefail` and to have resolved its own real location first
# (script_dir cannot live here — a script needs it to *find* this file).
#
# Everything below is kept in lockstep with bin/vibe: worktree layout, config
# precedence (env over config over default), the loop state file, and the
# handoff content filter. If this lib resolved a different worktree root than
# vibe, the loop would later re-seed a blank brief into a second worktree.
#
# The `_lib` name matters: install.sh skips `skills/_*`, which is the only
# thing keeping this directory out of ~/.claude/skills.

die() {
  echo "${LIB_PROG:-vibe-lib}: $*" >&2
  exit 1
}
info() { echo "${LIB_PROG:-vibe-lib}: $*" >&2; }

command -v git >/dev/null 2>&1 || die "'git' is required but not installed."

# ---------------------------------------------------------------------------
# Locating the templates. This file lives at skills/_lib/, so the toolkit
# root is two levels up. The caller sourced us by an already-resolved
# physical path, so BASH_SOURCE needs no symlink walking of its own.
# ---------------------------------------------------------------------------
VIBE_LIB_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_HOME="$(dirname "$(dirname "$VIBE_LIB_DIR")")"
# shellcheck disable=SC2034  # consumed by the sourcing scripts
TEMPLATE_DIR="${TOOLKIT_TEMPLATE_DIR:-$TOOLKIT_HOME/templates}"

# render_template FILE [TOKEN VALUE]... — print FILE with each TOKEN replaced.
# Pure bash: no sed, so a value containing slashes cannot corrupt the result.
render_template() {
  local tpl="$1"
  shift
  local content
  content="$(cat "$tpl")"
  while (($# >= 2)); do
    content="${content//$1/$2}"
    shift 2
  done
  printf '%s\n' "$content"
}

# ---------------------------------------------------------------------------
# Config. Parsed, never sourced (like claude/hooks/statusline.sh): the config
# file is data, not code. Precedence must mirror bin/vibe exactly.
# ---------------------------------------------------------------------------
VIBE_CONFIG_FILE="${VIBE_CONFIG_FILE:-$HOME/.config/vibe/config}"

read_config() {
  local key="$1"
  [[ -r "$VIBE_CONFIG_FILE" ]] || return 0
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$VIBE_CONFIG_FILE" |
    tail -1 | tr -d '"'\'''
}

VIBE_WORKTREE_ROOT="${VIBE_WORKTREE_ROOT:-$(read_config VIBE_WORKTREE_ROOT)}"
VIBE_WORKTREE_ROOT="${VIBE_WORKTREE_ROOT:-$HOME/git/worktrees}"
VIBE_SERVER_HOSTNAME="${VIBE_SERVER_HOSTNAME:-$(read_config VIBE_SERVER_HOSTNAME)}"

# The loop runner's gitignored per-worktree state file (see bin/vibe).
LOOP_STATE_FILE=".vibe-loop.state"

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
worktree_dir() { echo "$VIBE_WORKTREE_ROOT/$1/$2"; }

# ensure_worktree MAIN BRANCH DIR — create DIR as a worktree for BRANCH.
# Preference order: existing local branch; branch on origin (fetched when
# needed, and tracked — so a brief pushed from the other machine is picked up
# instead of shadowed by a fresh branch off HEAD); new branch off HEAD.
ensure_worktree() {
  local main="$1" branch="$2" dir="$3"
  mkdir -p "$(dirname "$dir")"
  if git -C "$main" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$main" worktree add "$dir" "$branch"
  else
    git -C "$main" show-ref --verify --quiet "refs/remotes/origin/$branch" ||
      git -C "$main" fetch -q origin "$branch" >/dev/null 2>&1 || true
    if git -C "$main" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      git -C "$main" worktree add --track -b "$branch" "$dir" "origin/$branch"
    else
      git -C "$main" worktree add -b "$branch" "$dir"
    fi
  fi
  info "created worktree: $dir (branch: $branch)"
}

detect_env() {
  if [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_TTY:-}" ]]; then
    echo server
  elif [[ -n "$VIBE_SERVER_HOSTNAME" && "$(hostname)" == "$VIBE_SERVER_HOSTNAME" ]]; then
    echo server
  else
    echo local
  fi
}

# loop_live DIR — true only when a loop runner is genuinely running there:
# STATUS=running and its recorded PID still alive (same test as bin/vibe).
loop_live() {
  local dir="$1" sf status pid
  sf="$dir/$LOOP_STATE_FILE"
  [[ -f "$sf" ]] || return 1
  status="$(sed -n 's/^STATUS=//p' "$sf" | tail -1)"
  [[ "$status" == "running" ]] || return 1
  pid="$(sed -n 's/^PID=//p' "$sf" | tail -1)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

# seed_handoff_file DIR REPO BRANCH — render templates/HANDOFF.md into DIR
# unless one is already there. Every vibe worktree carries a handoff; both
# brief scripts seed it the same way.
seed_handoff_file() {
  local dir="$1" repo="$2" branch="$3"
  [[ ! -f "$dir/HANDOFF.md" && -f "$TEMPLATE_DIR/HANDOFF.md" ]] || return 0
  render_template "$TEMPLATE_DIR/HANDOFF.md" \
    '<repo>' "$repo" \
    '<branch>' "$branch" \
    '<worktree>' "$dir" \
    '<date>' "$(date '+%Y-%m-%d %H:%M %Z')" \
    '<machine>' "$(detect_env) ($(hostname))" >"$dir/HANDOFF.md"
  info "seeded HANDOFF.md"
}

# handoff_carries_content FILE — true when FILE holds anything beyond the
# template's own scaffolding: blank lines, headings, '>' guidance quotes,
# '- **Field:**' metadata, and single-line _placeholders_. Same line filter
# as bin/vibe's guard behind 'vibe done'; the template keeps every
# placeholder on one line precisely so this stays a line filter.
handoff_carries_content() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -qvE '^[[:space:]]*$|^#|^>|^- \*\*|^_.*_[[:space:]]*$' "$f"
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
