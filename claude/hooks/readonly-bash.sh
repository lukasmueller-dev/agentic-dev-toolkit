#!/usr/bin/env bash
#
# readonly-bash.sh — PreToolUse(Bash) guard for the read-only reviewer
# subagents (diff-reviewer, docs-drift, security-sweep). Wired up in each
# agent's own frontmatter `hooks:` block, so it fires only while one of them
# runs; the main session and writing agents are untouched.
#
# Why it exists: agent frontmatter `tools:` takes bare tool names only, so
# granting Bash grants all of Bash — and the merged settings baseline
# auto-allows write-capable commands (shfmt -w, sort -o, echo >file). This
# hook restores the recorded "read-only by allowlist" decision at the only
# layer that can see the command's arguments.
#
# Policy (deny by default):
#   - each pipeline segment's command word must be on the allowlist below;
#     `git` additionally needs a read-only subcommand
#   - no redirection except fd duplication (2>&1) and >/dev/null
#   - no command substitution ($(...) or backticks) — the inner command is
#     invisible to this vet, so run it as its own Bash call instead
#   - per-tool teeth: sed -i, sort -o, shfmt -w/-s, find -delete/-exec,
#     tee, and awk programs that redirect or call system() are denied
#
# Exit 2 blocks the call; stderr becomes the message the agent sees, so every
# denial says what to do instead. A blocked command is a nudge to decompose,
# not a dead end.
#
# Known limits, accepted: this is defense in depth for agents that are
# *instructed* to be read-only, not a sandbox. sed's obscure `w file` script
# command and interpreter escapes inside allowed tools are out of scope.
#
# Fail-open by design (rule 1 in README.md: never break the session): missing
# jq, malformed stdin, or a payload for some other tool all exit 0 silently.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
[[ "$tool" == "Bash" ]] || exit 0
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
[[ -n "$cmd" ]] || exit 0

# The vetting below word-splits command text on purpose; globbing must not
# expand a word like *.sh against the cwd while it does.
set -f

ALLOWED_SUMMARY="inspection commands only: git <read subcommand>, rg/grep, \
find, ls, cat/head/tail, wc, sort, uniq, cut, tr, diff, sed -n, awk, stat, \
file, jq, shellcheck, shfmt -d, bats. No redirects (except >/dev/null and \
2>&1), no \$(...) — run inner commands as their own calls."

deny() {
  printf 'read-only reviewer guard: %s\nThis subagent reports; it never mutates. Allowed: %s\n' \
    "$1" "$ALLOWED_SUMMARY" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# Quote-aware pre-pass. awk walks the command once and
#   - splits it into pipeline/list segments on unquoted | ; & and newlines
#   - marks unquoted '>' as \001 (quoted '>' — a grep pattern — stays '>')
#   - marks '$(' and '`' as \002 wherever they are live (i.e. outside single
#     quotes; both expand inside double quotes)
# so the shell below can judge redirection and substitution without ever
# mistaking quoted text for syntax. POSIX awk only: BSD and GNU agree here.
# ---------------------------------------------------------------------------
segments="$(printf '%s\n' "$cmd" | awk '
  BEGIN { seg = ""; insq = 0; indq = 0; esc = 0 }
  {
    line = $0
    n = length(line)
    for (i = 1; i <= n; i++) {
      c = substr(line, i, 1)
      if (esc) { seg = seg c; esc = 0; continue }
      if (c == "\\" && !insq) { seg = seg c; esc = 1; continue }
      if (c == "\047" && !indq) { insq = !insq; seg = seg c; continue }
      if (c == "\"" && !insq) { indq = !indq; seg = seg c; continue }
      if (!insq) {
        if (c == "`") { seg = seg "\002"; continue }
        if (c == "$" && substr(line, i + 1, 1) == "(") { seg = seg "\002"; i++; continue }
      }
      if (!insq && !indq) {
        if (c == ">") { seg = seg "\001"; continue }
        # ">&" / "2>&1": & directly after a redirect is part of it
        if (c == "&" && substr(seg, length(seg), 1) == "\001") { seg = seg "&"; continue }
        if (c == "|" || c == ";" || c == "&") { print seg; seg = ""; continue }
      }
      seg = seg c
    }
    # an unquoted newline separates commands like ";" does
    if (!insq && !indq && !esc) { print seg; seg = "" } else seg = seg "\n"
  }
  END { if (seg != "") print seg }
')"

R=$'\001' # unquoted >
S=$'\002' # live command substitution

# vet_flags SEGMENT PATTERNS WHAT — deny when any word of SEGMENT matches one
# of the |-separated glob PATTERNS. The list has to be split by hand: a '|'
# that arrives in a case pattern via expansion is a literal character, not
# alternation.
vet_flags() {
  local w p seg="$1" what="$3"
  local oldifs="$IFS"
  IFS='|'
  # shellcheck disable=SC2086  # splitting the pattern list is the point
  set -- $2
  IFS="$oldifs"
  for w in $seg; do
    for p in "$@"; do
      # shellcheck disable=SC2254  # p must glob-match on purpose
      case "$w" in
        $p) deny "'$w' in '$what' writes — drop it or run the writing step yourself" ;;
      esac
    done
  done
}

vet_git() { # vet_git SEGMENT-WORDS...
  shift     # "git"
  # skip git's pre-subcommand globals; -C and -c take a value
  while (($#)); do
    case "$1" in
      -C | -c)
        shift
        shift || true
        ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  local sub="${1:-}"
  case "$sub" in
    status | diff | log | show | blame | annotate | grep | rev-parse | rev-list | \
      ls-files | ls-tree | ls-remote | cat-file | describe | shortlog | name-rev | \
      merge-base | reflog | var | version | help | check-ignore | count-objects)
      return 0
      ;;
    branch)
      shift || true
      vet_flags "$*" '-d|-D|-m|-M|-c|-C|-f|--force|--delete|--move|--copy|-u|--set-upstream*|--edit-description|--unset-upstream' "git branch"
      return 0
      ;;
    worktree | remote | stash | config | notes | submodule)
      shift || true
      case "${1:-}" in
        list | show | -v | get-url) return 0 ;;
        *) deny "'git $sub ${1:-}' can mutate — only 'list', 'show', '-v', 'get-url' pass" ;;
      esac
      ;;
    *)
      deny "'git ${sub:-<none>}' is not a read-only subcommand"
      ;;
  esac
}

vet_word() { # vet_word FIRST-WORD SEGMENT — the per-command allowlist
  local first="$1" seg="$2"
  case "$first" in
    git)
      # word-split is safe here: only command/flag positions are inspected
      # shellcheck disable=SC2086
      vet_git $seg
      ;;
    sed)
      # -[!-]*i* catches -i buried in a cluster (-ni, -Ei)
      vet_flags "$seg" '-i|-i?*|-[!-]*i*|--in-place*' "sed"
      ;;
    sort)
      vet_flags "$seg" '-o|--output*' "sort"
      ;;
    shfmt)
      vet_flags "$seg" '-w|-s|--write*|--simplify*' "shfmt"
      ;;
    find)
      vet_flags "$seg" '-delete|-exec*|-ok*|-fprint*' "find"
      ;;
    awk)
      case "$seg" in
        *system\(* | *print*\>*) deny "this awk program writes (system() or a '>' redirect inside the script)" ;;
      esac
      ;;
    xargs)
      # the real command is xargs' first non-flag argument; hold it to the
      # same list (flag values like '-n 2' are digits and skipped)
      local w skip_next=0 found=""
      # shellcheck disable=SC2086
      set -- $seg
      shift
      for w in "$@"; do
        if ((skip_next)); then
          skip_next=0
          continue
        fi
        case "$w" in
          -n | -P | -L | -s | -I | -d) skip_next=1 ;;
          -*) ;;
          *)
            found="$w"
            break
            ;;
        esac
      done
      [[ -n "$found" ]] || deny "bare xargs — say which command it should run"
      vet_word "$found" "$found"
      ;;
    tee)
      # tee exists to write; it sneaks into pipelines as a pseudo-pager
      deny "'tee' writes files — pipe to head or read the output directly"
      ;;
    rg | grep | egrep | fgrep | zgrep | ls | cat | head | tail | wc | uniq | \
      cut | tr | diff | comm | file | stat | du | basename | dirname | realpath | \
      pwd | printf | echo | true | false | : | test | \[ | which | type | \
      command | jq | nl | od | strings | column | tput | date | hostname | uname | \
      shellcheck | bats | env | readlink | cd | cmp) ;;
    *) deny "'$first' is not on the read-only allowlist" ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Judge each segment
# ---------------------------------------------------------------------------
while IFS= read -r seg; do
  # substitution first: its payload is invisible to every later check
  [[ "$seg" == *"$S"* ]] && deny 'command substitution — run the inner command as its own Bash call'

  # redirection: walk to each unquoted '>' and judge what follows. Only fd
  # duplication (2>&1) and /dev/null targets pass. Glob matching and prefix
  # stripping only — bash 3.2 on macOS mis-handles the =~ form this used.
  probe="$seg"
  while [[ "$probe" == *"$R"* ]]; do
    after="${probe#*"$R"}"
    # a doubled marker is '>>' — same judgement on its target
    [[ "$after" == "$R"* ]] && after="${after#"$R"}"
    if [[ "$after" == "&"[0-9]* ]]; then
      : # fd duplication, harmless
    else
      target="${after#"${after%%[![:space:]]*}"}" # ltrim
      [[ "$target" == /dev/null* ]] ||
        deny "output redirection — only >/dev/null and 2>&1 pass"
    fi
    probe="$after"
  done

  # leading whitespace, then env-style VAR=val prefixes and wrappers
  seg_trim="${seg#"${seg%%[![:space:]]*}"}"
  first="${seg_trim%%[[:space:]]*}"
  while [[ -n "$first" ]]; do
    case "$first" in
      [A-Za-z_]*=*)
        seg_trim="${seg_trim#"$first"}"
        seg_trim="${seg_trim#"${seg_trim%%[![:space:]]*}"}"
        first="${seg_trim%%[[:space:]]*}"
        ;;
      env | command | nohup)
        seg_trim="${seg_trim#"$first"}"
        seg_trim="${seg_trim#"${seg_trim%%[![:space:]]*}"}"
        first="${seg_trim%%[[:space:]]*}"
        ;;
      *) break ;;
    esac
  done
  [[ -n "$first" ]] || continue # empty segment (from '&&', blank line)

  vet_word "$first" "$seg_trim"
done <<EOF
$segments
EOF

exit 0
