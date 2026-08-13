#!/usr/bin/env bats
#
# report.sh — the mechanical half of the weekly-report skill. Everything runs
# in throwaway repos under $BATS_TEST_TMPDIR.
#
# Two things here are worth more than the rest. The ISO-week arithmetic is
# hand-rolled because neither date(1) can parse a week, and a week resolved
# one day off is silent — the deck is simply about the wrong seven days. And
# the config-absent path is the *default* configuration, so a change that
# makes a missing SOURCES.md an error would break every repo that never
# declares one.

load helper

setup() { git_env; }

REPORT="$REPO_ROOT/skills/weekly-report/report.sh"

# commit_on REPO DATE MESSAGE — a commit dated into a specific day.
commit_on() {
  local repo="$1" day="$2" msg="$3"
  echo "$msg" >>"$repo/log.txt"
  git -C "$repo" add log.txt
  GIT_AUTHOR_DATE="$day 12:00:00 +0000" \
    GIT_COMMITTER_DATE="$day 12:00:00 +0000" \
    git -C "$repo" commit -q -m "$msg"
}

# ---------------------------------------------------------------------------
# Weeks
# ---------------------------------------------------------------------------

@test "week: an explicit ISO week resolves to its Monday and Sunday" {
  # 2026-W33 is 2026-08-10 (Mon) .. 2026-08-16 (Sun). Checked against the
  # calendar, not against this implementation.
  run bash "$REPORT" week 2026-W33
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'week: 2026-W33'
  echo "$output" | grep -qx 'from: 2026-08-10'
  echo "$output" | grep -qx 'to: 2026-08-16'
}

@test "week: week 1 is the week containing January 4th, not January 1st" {
  # The ISO rule the Jan-4 derivation exists for. 2027 opens on a Friday, so
  # week 1 starts on 2027-01-04 and Jan 1st belongs to the previous year's
  # last week. A naive "first Monday" or "Jan 1 + 7n" gets this wrong.
  run bash "$REPORT" week 2027-W01
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'from: 2027-01-04'
}

@test "week: week 1 can start in the previous calendar year" {
  # The mirror case, and the one an off-by-one in the Monday shift breaks:
  # 2026 opens on a Thursday, so ISO week 1 starts on 2025-12-29.
  run bash "$REPORT" week 2026-W01
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'from: 2025-12-29'
}

@test "week: a leading-zero week number is not read as octal" {
  # 10#$n in the arithmetic. Without it, `08` and `09` abort the script.
  run bash "$REPORT" week 2026-W08
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'from: 2026-02-16'
  run bash "$REPORT" week 2026-W09
  [ "$status" -eq 0 ]
}

@test "week: current and last are seven days apart" {
  # Both resolve through date(1), so this also proves the GNU/BSD probe picked
  # a branch that actually works on this machine.
  local cur last cur_from last_from
  cur="$(bash "$REPORT" week current | sed -n 's/^from: //p')"
  last="$(bash "$REPORT" week last | sed -n 's/^from: //p')"
  cur_from="$(date -d "$cur" +%s 2>/dev/null || date -j -f %Y-%m-%d "$cur" +%s)"
  last_from="$(date -d "$last" +%s 2>/dev/null || date -j -f %Y-%m-%d "$last" +%s)"
  [ "$((cur_from - last_from))" -eq 604800 ]
}

@test "week: the default is the current week" {
  [ "$(bash "$REPORT" week | head -1)" = "$(bash "$REPORT" week current | head -1)" ]
}

@test "week: a malformed week is refused rather than guessed" {
  run bash "$REPORT" week 2026-33
  [ "$status" -ne 0 ]
  run bash "$REPORT" week 2026-W7
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# The BSD branch
#
# The GNU and BSD spellings of date arithmetic share no syntax, so half of
# report.sh's date handling never runs on the machine it is written on. CI's
# macOS leg is the real check, but it is opt-in and billed at 10x — and it
# already caught one bug here that a Linux run reported as green
# (`-v${n}d` combined with `-f`, which BSD refuses outright).
#
# So: put a stand-in BSD date(1) early on PATH and run the same assertions
# through it. It refuses --version, which is how report.sh decides it is not
# on GNU, and it refuses every flag the real BSD date refuses.
# ---------------------------------------------------------------------------

# with_bsd_date — put the stub on PATH for the rest of this test.
with_bsd_date() {
  local bin="$BATS_TEST_TMPDIR/bsd-bin"
  mkdir -p "$bin"
  cat >"$bin/date" <<EOF
#!/usr/bin/env bash
exec python3 "$REPO_ROOT/tests/bsd-date.py" "\$@"
EOF
  chmod +x "$bin/date"
  PATH="$bin:$PATH"
  export PATH
}

@test "bsd: the stub is taken for a non-GNU date" {
  command -v python3 >/dev/null || skip "python3 not available"
  with_bsd_date
  run date --version
  [ "$status" -ne 0 ]
}

@test "bsd: an explicit ISO week resolves the same as it does on GNU" {
  # The regression that reached CI: every week resolution died on macOS with
  # "cannot shift date", including a shift of zero days.
  command -v python3 >/dev/null || skip "python3 not available"
  with_bsd_date
  run bash "$REPORT" week 2026-W33
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'from: 2026-08-10'
  echo "$output" | grep -qx 'to: 2026-08-16'
}

@test "bsd: the awkward weeks resolve too" {
  # Week 1 in both directions, and a zero-day shift, which is the specific
  # case the old -v0d spelling could not express.
  command -v python3 >/dev/null || skip "python3 not available"
  with_bsd_date
  run bash "$REPORT" week 2027-W01
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'from: 2027-01-04'
  run bash "$REPORT" week 2026-W01
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'from: 2025-12-29'
}

@test "bsd: a deck seeds with the right period" {
  command -v python3 >/dev/null || skip "python3 not available"
  with_bsd_date
  local d
  d="$(make_repo bsddeck)"
  run bash "$REPORT" seed 2026-W33 "$d"
  [ "$status" -eq 0 ]
  grep -q '2026-08-10 to 2026-08-16' "$d/docs/reports/2026-W33.tex"
}

# ---------------------------------------------------------------------------
# Evidence
# ---------------------------------------------------------------------------

@test "collect: reports only commits inside the week" {
  # The boundary days are included and the days either side are not. An
  # off-by-one here silently reports the wrong week.
  local d
  d="$(make_repo period)"
  commit_on "$d" 2026-08-09 "sunday before"
  commit_on "$d" 2026-08-10 "monday inside"
  commit_on "$d" 2026-08-16 "sunday inside"
  commit_on "$d" 2026-08-17 "monday after"

  run bash "$REPORT" collect 2026-W33 "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'monday inside'
  echo "$output" | grep -q 'sunday inside'
  if echo "$output" | grep -qE 'sunday before|monday after'; then
    echo "commit outside the week leaked in: $output" >&2
    return 1
  fi
}

@test "collect: churn is grouped by top-level path" {
  local d
  d="$(make_repo churn)"
  mkdir -p "$d/src"
  echo "one" >"$d/src/a.txt"
  git -C "$d" add src/a.txt
  GIT_AUTHOR_DATE="2026-08-11 12:00:00 +0000" \
    GIT_COMMITTER_DATE="2026-08-11 12:00:00 +0000" \
    git -C "$d" commit -q -m "add src"

  run bash "$REPORT" collect 2026-W33 "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^## churn by top-level path$'
  echo "$output" | grep -qE '^  src +\+1 -0$'
}

@test "collect: a file at the repo root is not read as a directory" {
  local d
  d="$(make_repo rootfile)"
  commit_on "$d" 2026-08-11 "root change"
  run bash "$REPORT" collect 2026-W33 "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '(root)'
}

@test "collect: says the week was empty rather than printing nothing" {
  # A quiet week and a broken collector look identical unless the sections
  # are always present.
  local d
  d="$(make_repo quiet)"
  commit_on "$d" 2026-01-05 "long ago"
  run bash "$REPORT" collect 2026-W33 "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^## commits'
  echo "$output" | grep -q '^## merged pull requests$'
  echo "$output" | grep -q '^period: 2026-08-10 .. 2026-08-16$'
}

@test "collect: surfaces roadmap changes made during the week" {
  # An item deleted from the roadmap is a task someone finished, and that is
  # invisible in a commit subject.
  local d
  d="$(make_repo roadmap)"
  printf -- '- item one\n- item two\n' >"$d/PROJECT_ROADMAP.md"
  git -C "$d" add PROJECT_ROADMAP.md
  GIT_AUTHOR_DATE="2026-08-10 12:00:00 +0000" \
    GIT_COMMITTER_DATE="2026-08-10 12:00:00 +0000" \
    git -C "$d" commit -q -m "seed roadmap"
  printf -- '- item two\n' >"$d/PROJECT_ROADMAP.md"
  git -C "$d" add PROJECT_ROADMAP.md
  GIT_AUTHOR_DATE="2026-08-12 12:00:00 +0000" \
    GIT_COMMITTER_DATE="2026-08-12 12:00:00 +0000" \
    git -C "$d" commit -q -m "finish item one"

  run bash "$REPORT" collect 2026-W33 "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^## PROJECT_ROADMAP.md — changes in period$'
  echo "$output" | grep -q -- '-- item one'
}

@test "collect: a repo with no commits at all is reported, not an error" {
  local d="$BATS_TEST_TMPDIR/empty"
  git init -q -b main "$d"
  run bash "$REPORT" collect 2026-W33 "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'no commits'
}

@test "collect: refuses to run outside a git repository" {
  local d="$BATS_TEST_TMPDIR/not-a-repo"
  mkdir -p "$d"
  run bash "$REPORT" collect 2026-W33 "$d"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# The per-repo configuration — absent is the default, not a failure
# ---------------------------------------------------------------------------

@test "sources: a repo with no SOURCES.md succeeds and says where it would go" {
  # The config-absent path. This must never become an error: most repos never
  # declare a source, and the report is complete without one.
  local d
  d="$(make_repo nosources)"
  run bash "$REPORT" sources "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^none: .*/docs/reports/SOURCES.md$'
  [ ! -e "$d/docs/reports/SOURCES.md" ]
}

@test "sources: reports an existing config" {
  local d
  d="$(make_repo withsources)"
  mkdir -p "$d/docs/reports"
  echo "# sources" >"$d/docs/reports/SOURCES.md"
  run bash "$REPORT" sources "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^found: '
}

@test "sources: uses an existing docs directory under another name" {
  local d
  d="$(make_repo docnamed)"
  mkdir -p "$d/doc"
  run bash "$REPORT" sources "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^none: .*/doc/reports/SOURCES.md$'
  [ ! -d "$d/docs" ]
}

@test "sources: refuses to resolve a path outside a git repository" {
  # Not pedantry: `die` inside a command substitution exits only that
  # subshell, so a nested repo_root call once handed docs_dir an empty path —
  # and docs_dir on an empty path is `mkdir -p /docs`.
  local d="$BATS_TEST_TMPDIR/loose-sources"
  mkdir -p "$d"
  run bash "$REPORT" sources "$d"
  [ "$status" -ne 0 ]
  [ ! -e "$d/docs" ]
}

@test "init-sources: renders the template and never overwrites it" {
  local d before
  d="$(make_repo initsources)"
  run bash "$REPORT" init-sources "$d"
  [ "$status" -eq 0 ]
  [ -f "$d/docs/reports/SOURCES.md" ]
  grep -q '^# Report sources — initsources$' "$d/docs/reports/SOURCES.md"
  run grep -n '<repo>' "$d/docs/reports/SOURCES.md"
  [ "$status" -ne 0 ]

  echo "hand-written" >>"$d/docs/reports/SOURCES.md"
  before="$(cat "$d/docs/reports/SOURCES.md")"
  run bash "$REPORT" init-sources "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^exists: '
  [ "$(cat "$d/docs/reports/SOURCES.md")" = "$before" ]
}

# ---------------------------------------------------------------------------
# The deck
# ---------------------------------------------------------------------------

@test "seed: renders the deck into the reports directory with no leftover tokens" {
  local d
  d="$(make_repo deck)"
  run bash "$REPORT" seed 2026-W33 "$d"
  [ "$status" -eq 0 ]
  [ -f "$d/docs/reports/2026-W33.tex" ]
  [ ! -f "$d/2026-W33.tex" ]
  grep -q '\\title{deck}' "$d/docs/reports/2026-W33.tex"
  grep -q '2026-08-10 to 2026-08-16' "$d/docs/reports/2026-W33.tex"
  # An unrendered placeholder is an unfilled contract.
  run grep -nE '<(repo|week|period|date)>' "$d/docs/reports/2026-W33.tex"
  [ "$status" -ne 0 ] || {
    echo "unrendered placeholder: $output" >&2
    return 1
  }
}

@test "seed: prints a compile command and builds nothing" {
  local d
  d="$(make_repo compile)"
  run bash "$REPORT" seed 2026-W33 "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^compile: latexmk .*2026-W33\.tex$'
  # The boundary: a PDF here would mean the skill ran a toolchain it must not
  # assume exists.
  [ ! -e "$d/docs/reports/2026-W33.pdf" ]
}

@test "seed: never overwrites a deck, but still prints how to compile it" {
  # Half-finished decks are the normal case — written Friday, revised Monday.
  local d before
  d="$(make_repo redeck)"
  bash "$REPORT" seed 2026-W33 "$d"
  echo "% hand-written slide" >>"$d/docs/reports/2026-W33.tex"
  before="$(cat "$d/docs/reports/2026-W33.tex")"
  run bash "$REPORT" seed 2026-W33 "$d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^exists: '
  echo "$output" | grep -q '^compile: '
  [ "$(cat "$d/docs/reports/2026-W33.tex")" = "$before" ]
}

@test "seed: refuses a week it was not given" {
  local d
  d="$(make_repo noweek)"
  run bash "$REPORT" seed "$d"
  [ "$status" -ne 0 ]
}

@test "seed: refuses to write outside a git repository" {
  local d="$BATS_TEST_TMPDIR/loose"
  mkdir -p "$d"
  run bash "$REPORT" seed 2026-W33 "$d"
  [ "$status" -ne 0 ]
  [ ! -e "$d/docs" ]
}
