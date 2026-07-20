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

die() {
  echo "brief: $*" >&2
  exit 1
}
info() { echo "brief: $*" >&2; }

command -v git >/dev/null 2>&1 || die "'git' is required but not installed."

# ---------------------------------------------------------------------------
# Locating the templates
#
# Same pattern as scaffold.sh: the skill directory is symlinked into
# ~/.claude/skills, so $PWD and $0 both point somewhere useless. Walk the
# symlink chain; `readlink -f` is avoided for BSD/macOS compatibility.
# ---------------------------------------------------------------------------
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
TOOLKIT_HOME="$(dirname "$(dirname "$SKILL_DIR")")" # skills/<name>/ -> repo root
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
# file is data, not code. Precedence must mirror bin/vibe exactly — env over
# config over default. If this script resolved a different worktree root than
# vibe, the loop would later re-seed a blank brief into a second worktree.
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
# Git helpers — kept in lockstep with bin/vibe.
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

  local repo main branch dir
  repo="$(repo_name)"
  main="$(main_repo_root)"
  branch="$(slug "$task")"
  dir="$(worktree_dir "$repo" "$branch")"

  if [[ -d "$dir" ]] && loop_live "$dir"; then
    die "a loop is running for '$branch' — never edit a brief under a live runner."
  fi
  [[ -d "$dir" ]] || ensure_worktree "$main" "$branch" "$dir"

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
  if [[ ! -f "$dir/HANDOFF.md" && -f "$TEMPLATE_DIR/HANDOFF.md" ]]; then
    render_template "$TEMPLATE_DIR/HANDOFF.md" \
      '<repo>' "$repo" \
      '<branch>' "$branch" \
      '<worktree>' "$dir" \
      '<date>' "$(date '+%Y-%m-%d %H:%M %Z')" \
      '<machine>' "$(detect_env) ($(hostname))" >"$dir/HANDOFF.md"
    info "seeded HANDOFF.md"
  fi

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

  # The brief must be finished before it ships: no unrendered tokens, and the
  # two sections the loop depends on actually written. The iteration log keeps
  # its placeholder — the loop fills that in.
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
  [[ -f "$dir/HANDOFF.md" ]] && git -C "$dir" add HANDOFF.md
  if [[ -n "$(git -C "$dir" status --porcelain -- LOOP.md HANDOFF.md)" ]]; then
    git -C "$dir" commit -q -m "vibe loop: brief '$branch'"
    info "committed the brief"
  fi
  git -C "$dir" push -q -u origin "$branch" ||
    die "push failed — resolve it by hand (never force-push a brief)."
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
  *) die "usage: brief.sh <create|publish> <task> [options]" ;;
esac
