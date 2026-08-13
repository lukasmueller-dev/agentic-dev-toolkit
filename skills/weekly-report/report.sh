#!/usr/bin/env bash
#
# report.sh — the mechanical steps of weekly-report: resolve the week,
# collect the repo's own evidence for it, and seed the deck the skill fills in.
#
#   bash report.sh week [current|last|YYYY-Www]   the week and its date range
#   bash report.sh collect YYYY-Www [DIR]         this repo's evidence for it
#   bash report.sh sources [DIR]                  path to the repo's config
#   bash report.sh init-sources [DIR]             create that config if absent
#   bash report.sh seed YYYY-Www [DIR]            create the .tex, print compile
#
# Everything here is deliberately dumb. It gathers and it renders; it never
# decides what the week meant. `collect` prints evidence rather than prose,
# `seed` takes the week as an argument rather than resolving it, and neither
# reads the extra sources — those are declared per repo in prose that only a
# reader can follow, which is the SKILL.md's job and not a script's.
#
# `seed` never overwrites: a week already written gets `exists:` and an
# untouched file, so re-running is safe when a deck is half-finished.
set -euo pipefail

# ---------------------------------------------------------------------------
# Locating ourselves
#
# The skill is normally reached through a symlinked directory, so $PWD is the
# *target* repo, not ours. Resolve our own location and source the lib beside
# us. script_dir has to stay here: it is what finds it. `readlink -f` is
# avoided — macOS shipped BSD readlink without it for years.
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
LIB_DIR="$(dirname "$SKILL_DIR")/_lib"
# vibe-lib.sh is sourced for render_template and TEMPLATE_DIR only — the
# placeholder contract in templates/README.md has one implementation.
# shellcheck disable=SC1091  # path only exists at runtime, resolved above
. "$LIB_DIR/vibe-lib.sh"

PROG=weekly-report
die() {
  echo "$PROG: $*" >&2
  exit 1
}

usage() {
  echo "usage: bash report.sh week [current|last|YYYY-Www]" >&2
  echo "       bash report.sh collect YYYY-Www [DIR]" >&2
  echo "       bash report.sh sources [DIR]" >&2
  echo "       bash report.sh init-sources [DIR]" >&2
  echo "       bash report.sh seed YYYY-Www [DIR]" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# Dates
#
# GNU and BSD date share no arithmetic syntax, and BSD's `-d` means "set the
# DST flag" — so feeding it a date string does not fail loudly, it just
# ignores the argument and prints today. Probing --version once is the only
# discriminator that cannot silently answer the wrong question.
# ---------------------------------------------------------------------------
if date --version >/dev/null 2>&1; then DATE_GNU=1; else DATE_GNU=0; fi

# date_fmt DATE FMT — format a YYYY-MM-DD date.
date_fmt() {
  if [ "$DATE_GNU" = 1 ]; then
    date -d "$1" "$2" 2>/dev/null || die "cannot parse date: $1"
  else
    date -j -f '%Y-%m-%d' "$1" "$2" 2>/dev/null || die "cannot parse date: $1"
  fi
}

# date_shift DATE DAYS — DATE moved by DAYS, which may be negative.
date_shift() {
  if [ "$DATE_GNU" = 1 ]; then
    date -d "$1 $2 days" +%F 2>/dev/null || die "cannot shift date: $1 by $2"
  else
    date -j -v"${2}d" -f '%Y-%m-%d' "$1" +%F 2>/dev/null ||
      die "cannot shift date: $1 by $2"
  fi
}

# week_start YYYY-Www — the Monday of an ISO week.
#
# Derived from January 4th, which is in ISO week 1 of its year by definition.
# Neither date(1) can parse an ISO week directly, so this is the portable
# route rather than a shortcut.
week_start() {
  local w="$1" y n jan4 dow monday
  case "$w" in
    [0-9][0-9][0-9][0-9]-W[0-9][0-9]) ;;
    *) die "not an ISO week (YYYY-Www): $w" ;;
  esac
  y="${w%%-W*}"
  n="${w##*-W}"
  jan4="$y-01-04"
  dow="$(date_fmt "$jan4" '+%u')"
  monday="$(date_shift "$jan4" "-$((dow - 1))")"
  date_shift "$monday" "$(((10#$n - 1) * 7))"
}

# resolve_week [current|last|YYYY-Www] — an ISO week, defaulting to this one.
resolve_week() {
  local arg="${1:-current}" today
  case "$arg" in
    current | '') date '+%G-W%V' ;;
    last)
      today="$(date '+%F')"
      date_fmt "$(date_shift "$today" -7)" '+%G-W%V'
      ;;
    *)
      week_start "$arg" >/dev/null # validates
      printf '%s\n' "$arg"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Paths in the target repo
# ---------------------------------------------------------------------------

# docs_dir REPO — the repo's documentation directory, created if it has none.
# An existing directory under another name is used as-is; a second one is
# never invented.
docs_dir() {
  local repo="$1" d
  for d in docs doc documentation; do
    if [ -d "$repo/$d" ]; then
      echo "$repo/$d"
      return 0
    fi
  done
  mkdir -p "$repo/docs"
  echo "$repo/docs"
}

# repo_root DIR — the git repository DIR sits in.
#
# Always called as `root="$(repo_root "$d")" || exit 1`, never nested inside
# another substitution: `die` in a command substitution exits that subshell
# only, so a nested call would hand its caller an empty path — and docs_dir
# on an empty path means mkdir -p /docs.
repo_root() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null ||
    die "not inside a git repository: $1"
}

# reports_dir REPO — where decks and the per-repo config live.
reports_dir() {
  echo "$(docs_dir "$1")/reports"
}

# ---------------------------------------------------------------------------
# Evidence
# ---------------------------------------------------------------------------

# collect REPO WEEK — the repo's own record of a week, as sections.
#
# Sections, never prose: the caller decides what the week meant. Caps are
# stated in the output where they bite, so a truncated section cannot read
# as a complete one.
collect() {
  local repo="$1" week="$2" from to
  from="$(week_start "$week")"
  to="$(date_shift "$from" 6)"

  echo "week: $week"
  echo "period: $from .. $to"
  echo "repo: $(basename "$repo")"
  echo

  if ! git -C "$repo" rev-parse HEAD >/dev/null 2>&1; then
    echo "## commits"
    echo "  (repository has no commits)"
    return 0
  fi

  local -a range=(--since="$from 00:00:00" --until="$to 23:59:59")

  echo "## commits (up to 300, newest first)"
  git -C "$repo" log "${range[@]}" --no-merges -n 300 \
    --pretty=format:'  %h %ad %an %s' --date=short || true
  echo
  echo

  echo "## merges"
  git -C "$repo" log "${range[@]}" --merges -n 100 \
    --pretty=format:'  %h %ad %s' --date=short || true
  echo
  echo

  echo "## churn by top-level path"
  git -C "$repo" log "${range[@]}" --no-merges --numstat --pretty=format: |
    awk 'NF == 3 {
           split($3, p, "/")
           k = (p[2] == "" ? "(root)" : p[1])
           add[k] += ($1 == "-" ? 0 : $1)
           del[k] += ($2 == "-" ? 0 : $2)
         }
         END { for (k in add) printf "  %-28s +%d -%d\n", k, add[k], del[k] }' |
    sort
  echo

  # Where the roadmap lost items and the status gained lines is the clearest
  # signal of what actually finished, and it is invisible in a commit subject.
  local f
  for f in PROJECT_ROADMAP.md PROJECT_STATUS.md; do
    if [ -f "$repo/$f" ]; then
      echo "## $f — changes in period"
      # Diff headers dropped by their trailing space, not by a second +/-:
      # a markdown bullet removed from the roadmap *is* `-- item`, and that
      # is precisely the line worth reading here.
      git -C "$repo" log "${range[@]}" -p --unified=1 -- "$f" |
        sed -n -e '/^--- /d' -e '/^+++ /d' -e 's/^\([+-]\)/  \1/p' || true
      echo
    fi
  done

  # Optional: the host may have no pull-request tool, or no network. Either
  # way the section says so rather than vanishing, so a thin report is never
  # mistaken for a thin week.
  echo "## merged pull requests"
  if command -v gh >/dev/null 2>&1; then
    local prs
    # Run from inside the repo so gh resolves the host from its remote: the
    # --repo flag takes OWNER/REPO, never a path.
    prs="$(cd "$repo" && gh pr list --state merged --limit 100 \
      --search "merged:$from..$to" \
      --json number,title,author \
      --jq '.[] | "  #\(.number) \(.title) — \(.author.login)"' 2>/dev/null || true)"
    if [ -n "$prs" ]; then
      printf '%s\n' "$prs"
    else
      echo "  (none found, or this repo has no remote host)"
    fi
  else
    echo "  (no pull-request tool available — commits above are the record)"
  fi
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd="${1:-}"
[ -n "$cmd" ] || usage

case "$cmd" in
  week)
    w="$(resolve_week "${2:-current}")"
    s="$(week_start "$w")"
    echo "week: $w"
    echo "from: $s"
    echo "to: $(date_shift "$s" 6)"
    ;;

  collect)
    week="${2:-}"
    [ -n "$week" ] || usage
    dir="${3:-.}"
    [ -d "$dir" ] || die "not a directory: $dir"
    root="$(repo_root "$dir")" || exit 1
    collect "$root" "$week"
    ;;

  sources)
    dir="${2:-.}"
    [ -d "$dir" ] || die "not a directory: $dir"
    root="$(repo_root "$dir")" || exit 1
    src="$(reports_dir "$root")/SOURCES.md"
    if [ -f "$src" ]; then
      echo "found: $src"
    else
      # Absent is the default configuration, not an error: a repo with no
      # extra sources still gets a complete report from its own history.
      echo "none: $src"
    fi
    ;;

  init-sources)
    dir="${2:-.}"
    [ -d "$dir" ] || die "not a directory: $dir"
    root="$(repo_root "$dir")" || exit 1
    out="$(reports_dir "$root")/SOURCES.md"
    if [ -e "$out" ]; then
      echo "exists: $out"
      exit 0
    fi
    tpl="$TEMPLATE_DIR/report/SOURCES.md"
    [ -f "$tpl" ] || die "template not found: $tpl"
    mkdir -p "$(dirname "$out")"
    render_template "$tpl" '<repo>' "$(basename "$root")" >"$out"
    echo "created: $out"
    ;;

  seed)
    week="${2:-}"
    [ -n "$week" ] || usage
    dir="${3:-.}"
    [ -d "$dir" ] || die "not a directory: $dir"
    root="$(repo_root "$dir")" || exit 1
    start="$(week_start "$week")"
    out="$(reports_dir "$root")/$week.tex"
    if [ -e "$out" ]; then
      echo "exists: $out"
    else
      tpl="$TEMPLATE_DIR/report/weekly.tex"
      [ -f "$tpl" ] || die "template not found: $tpl"
      mkdir -p "$(dirname "$out")"
      render_template "$tpl" \
        '<repo>' "$(basename "$root")" \
        '<week>' "$week" \
        '<period>' "$start to $(date_shift "$start" 6)" \
        '<date>' "$(date '+%Y-%m-%d')" >"$out"
      echo "created: $out"
    fi
    # Printed, never run: compiling needs a TeX installation this script has
    # no business assuming, and the human wants the command anyway.
    #
    # Both forms compile from the deck's own directory, because the template
    # pulls in a sibling preamble.tex by relative path — run pdflatex from
    # anywhere else and a repo's own styling silently does not apply.
    echo "compile: latexmk -pdf -cd $out"
    echo "     or: (cd $(dirname "$out") && pdflatex $(basename "$out"))"
    ;;

  *) usage ;;
esac
