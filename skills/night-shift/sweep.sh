#!/usr/bin/env bash
#
# sweep.sh [<repo>...] — the night-shift planner's input, per repo in rank
# order: goal, open roadmap items, handoff next actions, open PRs. Read-only.
#
# Repos: the arguments, else one per line in
# ${XDG_CONFIG_HOME:-~/.config}/night-shift/repos (# comments, highest rank
# first). A name without a slash resolves under NIGHT_SHIFT_ROOT (default: the
# directory that holds the toolkit checkout).
set -euo pipefail

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
LIB_PROG=night-shift
# shellcheck disable=SC1091  # path only exists at runtime, resolved above
. "$SKILL_DIR/../_lib/lib.sh"

ROOT="${NIGHT_SHIFT_ROOT:-$(dirname "$TOOLKIT_HOME")}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/night-shift/repos"

# roadmap FILE — headings and open items, an item joined to one line.
roadmap() {
  awk '
    function flush() { if (item != "") print item; item = "" }
    /^#/ { flush(); print "  " $0; next }
    /^[[:space:]]*- \[ \]/ { flush(); t = $0; sub(/^[[:space:]]*/, "", t); item = "  L" NR ": " t; next }
    item != "" && /^[[:space:]]+[^[:space:]]/ { t = $0; sub(/^[[:space:]]+/, "", t); item = item " " t; next }
    { flush() }
    END { flush() }' "$1"
}

sweep_repo() {
  local rank="$1" repo="$2" dir line wt="" br=""
  case "$repo" in */*) dir="$repo" ;; *) dir="$ROOT/$repo" ;; esac
  echo "# $rank. $(basename "$dir")  ($dir)"
  if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "  not a git repo — skipped"
    return 0
  fi
  if [[ -f "$dir/PROJECT_STATUS.md" ]]; then
    echo "## goal"
    md_section "$dir/PROJECT_STATUS.md" Goal "    "
  fi
  echo "## roadmap"
  if [[ -f "$dir/PROJECT_ROADMAP.md" ]]; then roadmap "$dir/PROJECT_ROADMAP.md"; else echo "  no PROJECT_ROADMAP.md"; fi
  echo "## handoffs"
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) wt="${line#worktree }" br="" ;;
      "branch "*) br="${line#branch refs/heads/}" ;;
      "")
        if [[ -n "$wt" && -f "$wt/HANDOFF.md" ]]; then
          echo "  $wt [${br:-detached}]$([[ -z "$(git -C "$wt" status --porcelain 2>/dev/null)" ]] || echo ' DIRTY')"
          echo "   next action:"
          md_section "$wt/HANDOFF.md" "Next action" "    "
          echo "   blockers:"
          md_section "$wt/HANDOFF.md" Blockers "    "
        fi
        wt=""
        ;;
    esac
  done < <(git -C "$dir" worktree list --porcelain && echo)
  echo "## open PRs"
  if command -v gh >/dev/null 2>&1; then
    (cd "$dir" && gh pr list --state open --json headRefName,isDraft,title,url \
      -q '.[] | "  \(.headRefName)\t\(if .isDraft then "draft" else "ready" end)\t\(.title)\t\(.url)"') 2>/dev/null ||
      echo "  gh failed — run sweep.sh outside the sandbox"
  else
    echo "  no gh"
  fi
  echo
}

repos=()
if (($#)); then
  repos=("$@")
elif [[ -f "$CONF" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | tr -d '[:space:]')"
    [[ -z "$line" ]] || repos+=("$line")
  done <"$CONF"
fi
((${#repos[@]})) || die "no repos — pass them, or list them in $CONF (highest rank first)"

n=0
for r in "${repos[@]}"; do
  n=$((n + 1))
  sweep_repo "$n" "$r"
done
