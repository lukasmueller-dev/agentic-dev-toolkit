# shellcheck shell=bash
#
# vibe-lib.sh — helpers shared by the skill scripts that stage vibe task
# briefs (loop-brief/brief.sh, handoff-brief/handoff.sh, babysit-pr/brief.sh).
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
# Pure bash: no sed, so a value containing slashes (worktree paths hold them)
# needs no escaping. The one character bash itself is not literal about is
# '&': from 5.2 the patsub_replacement option — on by default — expands an
# unescaped '&' in the replacement half of ${var//pat/rep} to whatever the
# pattern matched, so an --until command chain would render as '<until><until>'.
# Unset it around the loop and restore it after; shopt is shell-global, and
# bash 3.2 (macOS) has no such option, hence the guards.
render_template() {
  local tpl="$1"
  shift
  local patsub_was_set=0
  if shopt -q patsub_replacement 2>/dev/null; then patsub_was_set=1; fi
  shopt -u patsub_replacement 2>/dev/null || true
  local content
  content="$(cat "$tpl")"
  while (($# >= 2)); do
    content="${content//$1/$2}"
    shift 2
  done
  if ((patsub_was_set)); then shopt -s patsub_replacement 2>/dev/null || true; fi
  printf '%s\n' "$content"
}

# ---------------------------------------------------------------------------
# Config. Parsed, never sourced (like claude/hooks/statusline.sh): the config
# file is data, not code. Precedence must mirror bin/vibe exactly.
# ---------------------------------------------------------------------------
VIBE_CONFIG_FILE="${VIBE_CONFIG_FILE:-$HOME/.config/vibe/config}"

# The optional `export ` prefix is not cosmetic: bin/vibe *sources* the config,
# so `export KEY=value` works there, and `vibe doctor` explicitly accepts it as
# valid. A parser that does not would silently disagree with both — bin/vibe
# using the configured worktree root while this lib falls back to the default,
# which is how a brief gets re-seeded into a second worktree.
read_config() {
  local key="$1"
  [[ -r "$VIBE_CONFIG_FILE" ]] || return 0
  sed -nE "s/^[[:space:]]*(export[[:space:]]+)?${key}[[:space:]]*=[[:space:]]*//p" \
    "$VIBE_CONFIG_FILE" | tail -1 | tr -d '"'\'''
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
# needed, and tracked — so a brief pushed from another machine is picked up
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
# '- **Field:**' metadata, and single-line _placeholders_. Literal copy of
# VIBE_HANDOFF_SCAFFOLD_RE in bin/vibe ('vibe done's guard) — a third lives in
# claude/hooks/session-start-handoff.sh; update all three together. The
# template keeps every placeholder on one line so this stays a line filter.
handoff_carries_content() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -qvE '^[[:space:]]*$|^#|^>|^- \*\*|^_.*_[[:space:]]*$' "$f"
}

# stage_worktree BRANCH WHAT — set STAGED_DIR to BRANCH's worktree, creating it
# when it does not exist and refusing while a loop runner owns it. WHAT names
# the document in that refusal ("brief", "handoff"), which is the only thing the
# three create paths said differently. Editing a file under a live runner races
# the runner's own commit of that file, so this refuses rather than warns.
#
# Sets a global instead of echoing the path deliberately: 'git worktree add'
# writes its progress to stdout, and a command substitution here would swallow
# that into the variable instead of letting it reach the caller's stdout.
stage_worktree() {
  local branch="$1" what="$2"
  STAGED_DIR="$(worktree_dir "$(repo_name)" "$branch")"
  if [[ -d "$STAGED_DIR" ]] && loop_live "$STAGED_DIR"; then
    die "a loop is running for '$branch' — never edit a $what under a live runner."
  fi
  if [[ ! -d "$STAGED_DIR" ]]; then
    ensure_worktree "$(main_repo_root)" "$branch" "$STAGED_DIR"
  fi
}

# publish_brief DIR BRANCH COMMIT_MSG PUSH_HINT — validate DIR's LOOP.md, then
# commit it (with HANDOFF.md when present) and push BRANCH.
#
# The validation is the point: a brief ships only once it is finished, meaning
# no token survived the render and the two sections the loop actually reads
# were written. The iteration log keeps its placeholder — the loop fills that
# in. Both brief scripts had this written out identically; only the commit
# message and the push-failure hint ever differed, so those are arguments.
publish_brief() {
  local dir="$1" branch="$2" msg="$3" push_hint="$4"
  local f="$dir/LOOP.md"

  if grep -qE '<(repo|branch|worktree|goal|until|max|date|machine)>' "$f"; then
    die "LOOP.md still contains unrendered <tokens> — finish the brief first."
  fi
  local heading
  for heading in '## Done when' '## Constraints'; do
    grep -qxF "$heading" "$f" ||
      die "LOOP.md lost its '$heading' section — restore the template structure."
    if section_unfinished "$f" "$heading"; then
      die "the '$heading' section is still the template placeholder — write it before publishing."
    fi
  done

  git -C "$dir" add LOOP.md
  if [[ -f "$dir/HANDOFF.md" ]]; then git -C "$dir" add HANDOFF.md; fi
  if [[ -n "$(git -C "$dir" status --porcelain -- LOOP.md HANDOFF.md)" ]]; then
    git -C "$dir" commit -q -m "$msg"
    info "committed the brief"
  fi
  git -C "$dir" push -q -u origin "$branch" || die "$push_hint"
  info "pushed '$branch' to origin"
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
