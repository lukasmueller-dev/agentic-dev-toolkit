#!/usr/bin/env bash
#
# install.sh — install, verify and remove this toolkit.
#
# Symlink strategy: files stay in the repo, symlinks point at them. `git pull`
# alone updates your installed tools — no re-copying, no drift.
#
# Usage:
#   ./install.sh [TARGET...]        install (default: all)
#   ./install.sh --dry [TARGET...]  show what would happen, change nothing
#   ./install.sh --uninstall [T...] remove only the symlinks this repo owns
#   ./install.sh doctor             check what is installed and report drift
#
# Targets:
#   bin      bin/* -> ~/bin/, plus shell completions
#   skills   skills/<name>/ -> ~/.claude/skills/<name>
#   claude   claude/CLAUDE.md + hooks/ + agents/ -> ~/.claude/ (symlinks),
#            memory/GLOBAL.md -> ~/.claude/global-memory.md, and merges
#            claude/settings.json into your real settings.json
#   codex    codex/* -> ~/.codex/, memory/GLOBAL.md -> ~/.codex/AGENTS.md
#   gemini   gemini/* -> ~/.gemini/, memory/GLOBAL.md -> ~/.gemini/GEMINI.md
#   vscode   merge vscode/*.jsonc into the real VS Code settings.json
#   all      every target above (the default)
#
# Auto-discovery: every target enumerates the repo at run time. Drop a file in
# bin/, a directory in skills/, a script in claude/hooks/ — the next run picks
# it up with no edits here.
#
# memory/GLOBAL.md is the one file with a fixed fan-out rather than a
# discovered one: each agent reads its global instructions from a different
# hard-coded path, so the mapping is spelled out rather than derived from a
# naming convention.
#
# Safety rules this script keeps:
#   - Idempotent. Re-running changes nothing that is already correct.
#   - A real (non-symlink) file is never deleted, only backed up.
#   - --uninstall removes a symlink only after confirming it points into THIS
#     repo, so it can never take out something another tool installed.
#   - Orphans are pruned: a symlink left in a managed directory that points
#     into this repo at something no longer there — what a renamed skill
#     leaves behind — is removed. Both conditions are required, so this stays
#     a strict subset of what --uninstall already removes.
set -euo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY=0
UNINSTALL=0
DOCTOR=0
TARGETS=()

# Backups of displaced real files, grouped per run. Deliberately OUTSIDE the
# install directories: Claude Code scans ~/.claude/skills, so a displaced skill
# left in place would load as a stale duplicate of the one replacing it.
RUN_TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$HOME/.agentic-dev-toolkit-backups"
BACKUP_DST="$BACKUP_ROOT/$RUN_TS"

c_grn=$'\033[32m'
c_yel=$'\033[33m'
c_red=$'\033[31m'
c_dim=$'\033[2m'
c_bld=$'\033[1m'
c_off=$'\033[0m'

say() { printf '%s%s%s\n' "$c_dim" "$*" "$c_off"; }
ok() { printf '%s%s%s\n' "$c_grn" "$*" "$c_off"; }
warn() { printf '%s%s%s\n' "$c_yel" "$*" "$c_off"; }
err() { printf '%s%s%s\n' "$c_red" "$*" "$c_off" >&2; }
hdr() { printf '\n%s%s%s\n' "$c_bld" "$*" "$c_off"; }

usage() {
  # The whole header comment, however long it grows: from line 3 to the first
  # non-comment line. A hard line range here silently truncated the help once.
  awk 'NR < 3 { next } !/^#/ { exit } { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
  exit "${1:-0}"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while (($#)); do
  case "$1" in
    --dry | -n) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    doctor | --doctor) DOCTOR=1 ;;
    -h | --help) usage 0 ;;
    all | bin | skills | claude | codex | gemini | vscode) TARGETS+=("$1") ;;
    *)
      err "unknown argument: $1"
      usage 1
      ;;
  esac
  shift
done

((${#TARGETS[@]})) || TARGETS=(all)

# want TARGET — is TARGET selected?
want() {
  local t
  for t in "${TARGETS[@]}"; do
    [[ "$t" == all || "$t" == "$1" ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Path helpers
#
# No `readlink -f`: macOS shipped BSD readlink without it for years, and this
# script has to behave identically on every machine it installs to.
# ---------------------------------------------------------------------------

# link_target LINK — absolute path a symlink points at (one hop, resolved).
link_target() {
  local l="$1" t
  t="$(readlink "$l")" || return 1
  [[ "$t" == /* ]] || t="$(cd -P "$(dirname "$l")" && pwd)/$t"
  printf '%s' "$t"
}

# owned_by_repo LINK — true when LINK is a symlink resolving inside this repo.
# This is the guard that makes --uninstall safe to run on a shared HOME.
owned_by_repo() {
  local l="$1" t
  [[ -L "$l" ]] || return 1
  t="$(link_target "$l")" || return 1
  [[ "$t" == "$REPO" || "$t" == "$REPO"/* ]]
}

# ---------------------------------------------------------------------------
# The link map
#
# Built fresh on every run from what is actually in the repo — this IS the
# auto-discovery contract. Records are "src<TAB>dst<TAB>kind".
# ---------------------------------------------------------------------------
MAP=()
map_add() { MAP+=("$1	$2	$3"); }

# The portable global memory, and the paths each agent reads its global
# instructions from. Claude Code loads exactly one such file and this repo also
# ships Claude-only response-style rules, so its copy lands beside CLAUDE.md
# under a name CLAUDE.md imports — see memory/README.md.
GLOBAL_MEMORY="$REPO/memory/GLOBAL.md"
GLOBAL_MEMORY_CLAUDE="$HOME/.claude/global-memory.md"

# map_agent_home KIND SRCDIR DSTDIR [SKIP...] — link an agent's config
# directory into that agent's home, leaving the named basenames alone:
# README.md documents the directory rather than configuring anything, and a
# config file the CLI writes to itself must never be a symlink into this repo,
# or every setting it rewrites becomes a git diff here and syncs to every
# other machine. claude/settings.json is the worked example — it is merged.
#
# The skips are compared one at a time rather than as a `case` alternation:
# `case $b in $skip)` does not re-parse `|` out of an expansion, so a
# README.md|config.toml pattern silently matches neither.
map_agent_home() {
  local kind="$1" srcdir="$2" dstdir="$3"
  shift 3
  local f b s skipped
  [[ -d "$srcdir" ]] || return 0
  for f in "$srcdir"/*; do
    [[ -f "$f" ]] || continue
    b="$(basename "$f")"
    skipped=0
    for s in "$@"; do
      [[ "$b" == "$s" ]] && skipped=1
    done
    ((skipped)) && continue
    map_add "$f" "$dstdir/$b" "$kind"
  done
  return 0
}

build_map() {
  MAP=()
  local f d

  if want bin; then
    if [[ -d "$REPO/bin" ]]; then
      for f in "$REPO"/bin/*; do
        [[ -f "$f" ]] || continue
        map_add "$f" "$HOME/bin/$(basename "$f")" bin
      done
    fi
    # Completions belong to the CLI they complete, so they ride with `bin`.
    [[ -f "$REPO/completions/vibe.bash" ]] &&
      map_add "$REPO/completions/vibe.bash" \
        "$HOME/.local/share/bash-completion/completions/vibe" bin
    [[ -f "$REPO/completions/_vibe" ]] &&
      map_add "$REPO/completions/_vibe" "$HOME/.zsh/completions/_vibe" bin
  fi

  if want skills && [[ -d "$REPO/skills" ]]; then
    for d in "$REPO"/skills/*/; do
      d="${d%/}"
      # _template is scaffolding, not a skill. Claude Code does NOT skip
      # underscore-prefixed directories — it would load it as a real skill —
      # so the installer has to be the thing that keeps it out of ~/.claude.
      case "$(basename "$d")" in _*) continue ;; esac
      map_add "$d" "$HOME/.claude/skills/$(basename "$d")" skills
    done
  fi

  if want claude && [[ -d "$REPO/claude" ]]; then
    # Regular files at claude/ root: CLAUDE.md and anything added later.
    # README.md documents the directory rather than configuring anything, and
    # settings.json is merged rather than symlinked — see install_claude_settings.
    for f in "$REPO"/claude/*; do
      [[ -f "$f" ]] || continue
      case "$(basename "$f")" in README.md | settings.json) continue ;; esac
      map_add "$f" "$HOME/.claude/$(basename "$f")" claude
    done
    # Directories: linked once they hold something besides their README, so an
    # empty agents/ does not put a bare README where Claude Code scans for
    # agent definitions.
    for d in "$REPO"/claude/*/; do
      d="${d%/}"
      if [[ -n "$(find "$d" -type f ! -name 'README.md' -print -quit 2>/dev/null)" ]]; then
        map_add "$d" "$HOME/.claude/$(basename "$d")" claude
      else
        say "skipping claude/$(basename "$d")/ — nothing in it but a README"
      fi
    done
    [[ -f "$GLOBAL_MEMORY" ]] &&
      map_add "$GLOBAL_MEMORY" "$GLOBAL_MEMORY_CLAUDE" claude
  fi

  # Codex and Gemini currently take nothing but the shared memory; their
  # directories are still placeholders. Both are mapped anyway so dropping a
  # real config file in either one needs no edit here.
  if want codex; then
    map_agent_home codex "$REPO/codex" "$HOME/.codex" README.md config.toml
    [[ -f "$GLOBAL_MEMORY" ]] &&
      map_add "$GLOBAL_MEMORY" "$HOME/.codex/AGENTS.md" codex
  fi

  if want gemini; then
    map_agent_home gemini "$REPO/gemini" "$HOME/.gemini" README.md settings.json
    [[ -f "$GLOBAL_MEMORY" ]] &&
      map_add "$GLOBAL_MEMORY" "$HOME/.gemini/GEMINI.md" gemini
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Orphans
#
# The link map is rebuilt from the repo on every run, so it describes what
# SHOULD exist and knows nothing about what used to. Rename a skill and the old
# symlink survives in ~/.claude/skills pointing at a directory that is gone —
# invisible to doctor, which only walks the map, and still scanned by Claude
# Code. Until this existed, every rename needed manual cleanup on every machine.
#
# Pruning deletes a symlink the current repo does not know about, which is the
# authority --uninstall's ownership check exists to constrain. Two conditions
# together keep it inside that constraint:
#
#   1. the link resolves back into THIS checkout (owned_by_repo), and
#   2. it resolves to nothing.
#
# That is a strict subset of what --uninstall already removes — those links at
# least still point at real files — so nothing is lost that was not already
# lost, and the never-delete-a-real-file rule is untouched. Run from a worktree,
# links into the main checkout are "not ours" and are left alone, the same way
# doctor reports them.
# ---------------------------------------------------------------------------

# managed_dirs — the directories this run links into, deduped. Derived from the
# map, not hardcoded, so a new destination directory never needs an edit here —
# and a target left out of TARGETS is never scanned.
managed_dirs() {
  local rec rest dst
  for rec in ${MAP[@]+"${MAP[@]}"}; do
    rest="${rec#*	}"
    dst="${rest%%	*}"
    printf '%s\n' "${dst%/*}"
  done | sort -u
}

# in_map DST — true when DST is a destination this run manages. A dangling link
# at a mapped path is a different diagnosis with a different fix — its source
# is missing, and ./install.sh relinks it — so it is not an orphan, and doctor
# must not report the same link under both headings.
in_map() {
  local rec rest
  for rec in ${MAP[@]+"${MAP[@]}"}; do
    rest="${rec#*	}"
    [[ "${rest%%	*}" == "$1" ]] && return 0
  done
  return 1
}

# orphan_links — one path per line: symlinks sitting directly in a managed
# directory that this repo owns, that resolve to nothing, and that no map
# entry claims.
#
# Deliberately not recursive. ~/.claude/agents and ~/.claude/hooks are
# whole-directory symlinks into the repo, so descending would walk repo files
# and judge them by rules meant for install destinations. No managed basename
# begins with a dot, so a plain glob covers everything and avoids . and .. .
orphan_links() {
  local dir l
  while IFS= read -r dir; do
    [[ -d "$dir" ]] || continue
    for l in "$dir"/*; do
      [[ -L "$l" ]] || continue # the unmatched glob lands here too
      if [[ -e "$l" ]]; then continue; fi
      owned_by_repo "$l" || continue
      if in_map "$l"; then continue; fi
      printf '%s\n' "$l"
    done
  done < <(managed_dirs)
}

# prune_orphans — remove them, honouring --dry. Header printed only when there
# is something to report, so a healthy run stays quiet.
prune_orphans() {
  local l n=0
  while IFS= read -r l; do
    n=$((n + 1))
    if ((n == 1)); then hdr "orphans"; fi
    if ((DRY)); then
      say "  prune    $l -> $(link_target "$l" 2>/dev/null || true) (gone from the repo)"
    else
      rm "$l"
      ok "  pruned   $l (gone from the repo)"
    fi
  done < <(orphan_links)
  return 0
}

# ---------------------------------------------------------------------------
# Linking
# ---------------------------------------------------------------------------
backup() { # backup PATH KIND — move a real file out of the way, never delete
  local path="$1" bak="$BACKUP_DST/$2" dst n=1
  mkdir -p "$bak"
  # Two managed paths can share a kind and a basename (~/bin/vibe and the
  # bash completion both back up as bin/vibe), and a second mv to the same
  # destination would silently clobber the first backup — the one thing this
  # function exists to never do. Suffix instead of overwrite.
  dst="$bak/$(basename "$path")"
  while [[ -e "$dst" ]]; do
    dst="$bak/$(basename "$path").$n"
    n=$((n + 1))
  done
  mv "$path" "$dst"
  warn "  backed up $path -> $dst"
}

do_link() {
  local src="$1" dst="$2" kind="$3"

  # Already correct? Say nothing and touch nothing.
  if [[ -L "$dst" ]] && [[ "$(link_target "$dst" 2>/dev/null)" == "$src" ]]; then
    say "  ok       $dst"
    return
  fi

  if ((DRY)); then
    if [[ -L "$dst" ]]; then
      say "  relink   $dst -> $src"
    elif [[ -e "$dst" ]]; then
      warn "  backup+link $dst (real file would be backed up) -> $src"
    else
      say "  link     $dst -> $src"
    fi
    return
  fi

  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm "$dst" # a symlink, ours or not: safe to replace, nothing is lost
  elif [[ -e "$dst" ]]; then
    backup "$dst" "$kind"
  fi
  ln -s "$src" "$dst"
  ok "  linked   $dst"
}

do_unlink() {
  local dst="$1"
  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    say "  absent   $dst"
    return
  fi
  if ! owned_by_repo "$dst"; then
    if [[ -L "$dst" ]]; then
      warn "  skipped  $dst (symlink points outside this repo)"
    else
      warn "  skipped  $dst (a real file, not ours to remove)"
    fi
    return
  fi
  if ((DRY)); then
    say "  remove   $dst"
    return
  fi
  rm "$dst"
  ok "  removed  $dst"
}

# ---------------------------------------------------------------------------
# Claude Code settings — merged, not symlinked
#
# Claude Code writes to ~/.claude/settings.json itself: /model rewrites `model`,
# "yes, don't ask again" appends to permissions.allow, and feature flags appear
# on their own. Symlinking it into the repo would turn every one of those into
# a git diff in the toolkit, and push them to every other machine.
#
# So the repo holds a BASELINE of the settings worth versioning — permissions,
# hooks, statusLine — and this merges it into whatever is already there.
# Runtime state (model, effortLevel, feature flags) is deliberately absent from
# the baseline, which is what keeps it from clobbering the live values.
# ---------------------------------------------------------------------------
CLAUDE_SETTINGS_SRC="$REPO/claude/settings.json"
CLAUDE_SETTINGS_DST="$HOME/.claude/settings.json"

# Deep-merges the baseline over the live file, but UNIONS the permission and
# sandbox arrays: jq's `*` replaces arrays wholesale, which would silently
# discard every rule accumulated through "don't ask again" — and, for the
# sandbox lists, every domain or exclusion the user added by hand. A sandbox
# path is only unioned when the baseline carries it; one that exists only in
# the live file is untouched by `*` already.
#
# `hooks` needs a union too, and a different one. Plain `*` replaced each event
# array wholesale, so a hook the user had configured for an event the baseline
# also defines (Notification, PostToolUse, SessionEnd, SessionStart) was
# dropped on every run, silently. But a plain concat is wrong in the other
# direction: rename a script in claude/hooks/ and the stale entry would live on
# forever, pointing at a file that no longer exists. So: keep the live entries
# that are NOT ours, and let the baseline be authoritative for the ones that
# are. "Ours" is any entry whose command names .claude/hooks/, the directory
# this installer owns and symlinks into place. Events only the user has (say
# PreCompact) survive untouched, and an event left with no entries is dropped
# rather than written as an empty array, so the merge stays idempotent.
claude_settings_merged() {
  jq -s '
    .[0] as $live | .[1] as $repo
    | ($live * $repo)
    | .permissions.allow = ((($live.permissions.allow // []) + ($repo.permissions.allow // [])) | unique)
    | .permissions.deny  = ((($live.permissions.deny  // []) + ($repo.permissions.deny  // [])) | unique)
    | reduce (
        [["sandbox", "excludedCommands"],
         ["sandbox", "credentials", "files"],
         ["sandbox", "credentials", "envVars"],
         ["sandbox", "filesystem", "allowRead"],
         ["sandbox", "filesystem", "allowWrite"],
         ["sandbox", "filesystem", "denyRead"],
         ["sandbox", "filesystem", "denyWrite"],
         ["sandbox", "network", "allowedDomains"],
         ["sandbox", "network", "deniedDomains"]][]
      ) as $p (.;
        if ($repo | getpath($p)) != null
        then setpath($p; ((($live | getpath($p)) // []) + ($repo | getpath($p))) | unique)
        else . end)
    | .hooks = (
        reduce ((($live.hooks // {}) + ($repo.hooks // {})) | keys[]) as $e ({};
          .[$e] = (
            (($live.hooks[$e] // [])
              | map(select(
                  ((.hooks // []) | any((.command // "") | contains(".claude/hooks/"))) | not)))
            + ($repo.hooks[$e] // [])))
        | with_entries(select((.value | length) > 0)))
  ' "$1" "$CLAUDE_SETTINGS_SRC"
}

install_claude_settings() {
  hdr "claude settings"
  [[ -f "$CLAUDE_SETTINGS_SRC" ]] || {
    say "  no baseline to merge"
    return
  }
  say "  target   $CLAUDE_SETTINGS_DST"

  if ! command -v jq >/dev/null 2>&1; then
    warn "  jq not installed — cannot merge settings.json."
    warn "  Merge $CLAUDE_SETTINGS_SRC into $CLAUDE_SETTINGS_DST by hand."
    return
  fi

  # A missing file is merged against an empty object rather than copied, so
  # creating and merging produce byte-identical output. Copying instead would
  # leave the permission arrays unsorted while the merge sorts them, and the
  # very next run would "merge" again and drop a pointless backup.
  local live="$CLAUDE_SETTINGS_DST" created=0 empty=""
  if [[ ! -f "$CLAUDE_SETTINGS_DST" ]]; then
    if ((DRY)); then
      say "  would create $CLAUDE_SETTINGS_DST from the baseline"
      return
    fi
    empty="$(mktemp)"
    printf '{}' >"$empty"
    live="$empty"
    created=1
  elif ! jq empty "$CLAUDE_SETTINGS_DST" 2>/dev/null; then
    err "  $CLAUDE_SETTINGS_DST is not valid JSON — leaving it alone."
    return
  fi

  local merged
  merged="$(claude_settings_merged "$live")"
  [[ -n "$empty" ]] && rm -f "$empty"

  if ((created)); then
    mkdir -p "$(dirname "$CLAUDE_SETTINGS_DST")"
    printf '%s\n' "$merged" >"$CLAUDE_SETTINGS_DST"
    ok "  created  $CLAUDE_SETTINGS_DST"
    return
  fi

  if [[ "$(jq -S '.' "$CLAUDE_SETTINGS_DST")" == "$(printf '%s' "$merged" | jq -S '.')" ]]; then
    say "  ok       already applied"
    return
  fi

  if ((DRY)); then
    say "  would merge the baseline into your existing settings (backing it up first)"
    return
  fi

  cp "$CLAUDE_SETTINGS_DST" "$CLAUDE_SETTINGS_DST.bak.$RUN_TS"
  printf '%s\n' "$merged" >"$CLAUDE_SETTINGS_DST"
  warn "  backed up $CLAUDE_SETTINGS_DST.bak.$RUN_TS"
  ok "  merged   $CLAUDE_SETTINGS_DST"
}

# ---------------------------------------------------------------------------
# VS Code settings — merged, not symlinked
#
# These snippets are fragments meant to be combined with settings you already
# have. Symlinking the file would replace every unrelated setting in it.
# ---------------------------------------------------------------------------
vscode_target_file() {
  # A remote VS Code session keeps machine settings under ~/.vscode-server.
  if [[ -d "$HOME/.vscode-server" ]]; then
    printf '%s' "$HOME/.vscode-server/data/Machine/settings.json"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    printf '%s' "$HOME/Library/Application Support/Code/User/settings.json"
  else
    printf '%s' "$HOME/.config/Code/User/settings.json"
  fi
}

# Which snippet, unlike which target file, follows the OS and nothing else:
# VS Code keys terminal profiles by platform (`profiles.osx` vs
# `profiles.linux`). Picking by "is this a remote session" got that wrong for a
# macOS machine reached over SSH, which is a server *and* needs the osx keys.
vscode_snippet() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    printf '%s' "$REPO/vscode/vscode-darwin.jsonc"
  else
    printf '%s' "$REPO/vscode/vscode-linux.jsonc"
  fi
}

# Strips whole-line // comments only. That is all these snippets use, and it
# avoids mangling a URL like https://… inside a string value.
strip_jsonc() { sed 's|^[[:space:]]*//.*$||' "$1"; }

install_vscode() {
  hdr "vscode"
  local snippet target
  snippet="$(vscode_snippet)"
  target="$(vscode_target_file)"

  if [[ ! -f "$snippet" ]]; then
    say "  no snippet for this platform"
    return
  fi
  say "  snippet  $snippet"
  say "  target   $target"

  if ! command -v jq >/dev/null 2>&1; then
    warn "  jq not installed — cannot merge automatically."
    warn "  Add these keys to $target by hand:"
    strip_jsonc "$snippet" | sed '/^[[:space:]]*$/d; s/^/    /'
    return
  fi

  if ((DRY)); then
    if [[ -f "$target" ]]; then
      say "  would merge into existing settings (backing it up first)"
    else
      say "  would create $target from the snippet"
    fi
    return
  fi

  mkdir -p "$(dirname "$target")"
  if [[ ! -f "$target" ]]; then
    strip_jsonc "$snippet" | jq '.' >"$target"
    ok "  created  $target"
    return
  fi

  if ! strip_jsonc "$target" | jq empty 2>/dev/null; then
    err "  $target is not valid JSON once comments are stripped — leaving it alone."
    err "  Merge the snippet by hand."
    return
  fi

  local merged bak
  merged="$(jq -s '.[0] * .[1]' <(strip_jsonc "$target") <(strip_jsonc "$snippet"))"

  # Already applied? Then do not touch the file, and do not leave a backup.
  if [[ "$(strip_jsonc "$target" | jq -S '.')" == "$(printf '%s' "$merged" | jq -S '.')" ]]; then
    say "  ok       already applied"
    return
  fi

  bak="$target.bak.$RUN_TS"
  cp "$target" "$bak"
  printf '%s\n' "$merged" >"$target"
  warn "  backed up $bak"
  ok "  merged   $target"
}

# ---------------------------------------------------------------------------
# doctor
# ---------------------------------------------------------------------------
run_doctor() {
  local n_warn=0 n_fail=0
  local pass="  ${c_grn}ok${c_off}  " bad="  ${c_red}FAIL${c_off}" wrn="  ${c_yel}warn${c_off}"

  # d_ok/d_wn/d_no FORMAT [ARG]... — one report line: severity prefix, the
  # message, a newline, and the tally. Same shape as bin/vibe's cmd_doctor.
  # Written out longhand, every one of the eighteen lines below repeated the
  # prefix argument and the '\n', and each non-ok one carried its own flag
  # assignment on the next line — which is exactly the line that gets forgotten
  # when a check is added.
  d_ok() {
    local fmt="$1"
    shift
    # shellcheck disable=SC2059  # FORMAT is ours, never user-supplied
    printf "%s $fmt\n" "$pass" "$@"
  }
  d_wn() {
    local fmt="$1"
    shift
    # shellcheck disable=SC2059  # FORMAT is ours, never user-supplied
    printf "%s $fmt\n" "$wrn" "$@"
    n_warn=$((n_warn + 1))
  }
  d_no() {
    local fmt="$1"
    shift
    # shellcheck disable=SC2059  # FORMAT is ours, never user-supplied
    printf "%s $fmt\n" "$bad" "$@"
    n_fail=$((n_fail + 1))
  }

  hdr "Symlinks"
  build_map
  local rec rest src dst target
  ((${#MAP[@]})) || say "  nothing mapped for the selected targets"
  for rec in ${MAP[@]+"${MAP[@]}"}; do
    src="${rec%%	*}"
    rest="${rec#*	}"
    dst="${rest%%	*}"
    if [[ -L "$dst" ]]; then
      target="$(link_target "$dst" 2>/dev/null || true)"
      # A broken link is broken no matter what it points at, so this is
      # checked before comparing targets.
      if [[ ! -e "$dst" ]]; then
        d_no '%s -> %s (dangling)' "$dst" "$target"
      elif [[ "$target" == "$src" ]]; then
        d_ok '%s' "$dst"
      elif [[ "$target" == "$REPO"/* ]]; then
        d_wn '%s -> %s (points elsewhere in this repo)' "$dst" "$target"
      else
        d_wn '%s -> %s (not ours)' "$dst" "$target"
      fi
    elif [[ -e "$dst" ]]; then
      d_wn '%s is a real file, not a link — run ./install.sh' "$dst"
    else
      # A managed link that is simply gone is unambiguous breakage — unlike
      # "not ours" / "points elsewhere", which are checkout-relative and stay
      # warnings — so it fails the run. Otherwise 'install.sh doctor', whose
      # job in the verification gate is "the live machine still resolves",
      # reports a broken install as healthy and exits 0.
      d_no '%s missing — run ./install.sh' "$dst"
    fi
  done

  # Orphans are invisible to the loop above, which only walks the map. A
  # warning rather than a failure: ./install.sh clears them on its own, and
  # doctor's job here is to name the thing that needs running, not to declare
  # the install broken.
  local orph
  while IFS= read -r orph; do
    d_wn '%s -> %s (orphaned: gone from the repo — run ./install.sh to prune)' \
      "$orph" "$(link_target "$orph" 2>/dev/null || true)"
  done < <(orphan_links)

  hdr "PATH"
  case ":$PATH:" in
    *":$HOME/bin:"*) d_ok '%s is on PATH' "$HOME/bin" ;;
    *)
      # SC2016: the single quotes are the point — this is literal text for the
      # user to paste into a shell rc, not something to expand here.
      # shellcheck disable=SC2016
      d_wn '%s is NOT on PATH — add: export PATH="%s"' "$HOME/bin" '$HOME/bin:$PATH'
      ;;
  esac

  hdr "Tools"
  local t
  for t in git jq; do
    if command -v "$t" >/dev/null 2>&1; then
      d_ok '%s' "$t"
    else
      d_wn '%s missing (needed to merge VS Code settings and by the Claude Code hooks)' "$t"
    fi
  done
  for t in tmux gh; do
    if command -v "$t" >/dev/null 2>&1; then
      d_ok '%s' "$t"
    else
      d_wn '%s missing (optional)' "$t"
    fi
  done

  # Without the import, Claude Code loads the response-style rules and silently
  # drops the workflow memory — every symlink still looks correct, so nothing
  # else in this report would catch it.
  if want claude && [[ -f "$GLOBAL_MEMORY" ]]; then
    hdr "Global memory"
    if [[ ! -e "$HOME/.claude/CLAUDE.md" ]]; then
      d_wn '%s missing — run ./install.sh claude' "$HOME/.claude/CLAUDE.md"
    elif grep -q '^@.*global-memory\.md' "$HOME/.claude/CLAUDE.md"; then
      d_ok '%s imports %s' "$HOME/.claude/CLAUDE.md" "$(basename "$GLOBAL_MEMORY_CLAUDE")"
    else
      d_no '%s does not import %s — Claude Code will not load the shared memory' \
        "$HOME/.claude/CLAUDE.md" "$GLOBAL_MEMORY_CLAUDE"
    fi
  fi

  hdr "Claude settings"
  if [[ ! -f "$CLAUDE_SETTINGS_DST" ]]; then
    d_wn '%s does not exist — run ./install.sh claude' "$CLAUDE_SETTINGS_DST"
  elif ! command -v jq >/dev/null 2>&1; then
    d_wn 'cannot verify without jq'
  elif ! jq empty "$CLAUDE_SETTINGS_DST" 2>/dev/null; then
    d_no '%s is not valid JSON' "$CLAUDE_SETTINGS_DST"
  elif [[ "$(jq -S '.' "$CLAUDE_SETTINGS_DST")" == "$(claude_settings_merged "$CLAUDE_SETTINGS_DST" | jq -S '.')" ]]; then
    d_ok 'baseline applied in %s' "$CLAUDE_SETTINGS_DST"
  else
    d_wn '%s is missing part of the baseline — run ./install.sh claude' "$CLAUDE_SETTINGS_DST"
  fi

  hdr "VS Code"
  local vtarget vsnippet
  vtarget="$(vscode_target_file)"
  vsnippet="$(vscode_snippet)"
  if [[ ! -f "$vtarget" ]]; then
    d_wn '%s does not exist — run ./install.sh vscode' "$vtarget"
  elif ! command -v jq >/dev/null 2>&1; then
    d_wn 'cannot verify without jq'
  elif [[ "$(strip_jsonc "$vtarget" | jq -S '.' 2>/dev/null)" == "$(jq -s -S '.[0] * .[1]' <(strip_jsonc "$vtarget") <(strip_jsonc "$vsnippet") 2>/dev/null)" ]]; then
    d_ok 'settings applied in %s' "$vtarget"
  else
    d_wn '%s is missing keys from %s — run ./install.sh vscode' \
      "$vtarget" "$(basename "$vsnippet")"
  fi

  hdr "Backups"
  if [[ -d "$BACKUP_ROOT" ]]; then
    local n
    n="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    if [[ "$n" -gt 0 ]]; then
      d_wn '%s backup set(s) in %s — remove them once you are sure' "$n" "$BACKUP_ROOT"
      find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sed 's|^|         |'
    else
      d_ok 'no stale backups'
    fi
  else
    d_ok 'no stale backups'
  fi

  printf '\n'
  if ((n_fail > 0)); then
    err "install doctor: problems found"
    return 1
  elif ((n_warn > 0)); then
    warn "install doctor: installed, with warnings"
  else
    ok "install doctor: healthy"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if ((DOCTOR)); then
  run_doctor
  exit $?
fi

((DRY)) && say "dry run — nothing will be changed"

build_map

if ((UNINSTALL)); then
  hdr "Removing symlinks owned by $REPO"
  ((${#MAP[@]})) || say "  nothing mapped for the selected targets"
  for rec in ${MAP[@]+"${MAP[@]}"}; do
    rest="${rec#*	}"
    do_unlink "${rest%%	*}"
  done
  # Mapped links are gone by now, so whatever is still owned and dangling is
  # something an earlier version of this repo left behind. Leaving it would
  # make "removes only what this repo owns" false in the direction that
  # matters: it would be OUR litter surviving our own uninstall.
  prune_orphans
  if want claude; then
    hdr "claude settings"
    say "  not removed: the baseline was merged into your own settings.json."
    say "  Undo by restoring a backup: $CLAUDE_SETTINGS_DST.bak.*"
  fi
  if want vscode; then
    hdr "vscode"
    say "  not removed: settings were merged into your own file, not symlinked."
    say "  Undo by restoring a backup: $(vscode_target_file).bak.*"
  fi
  printf '\n'
  ok "uninstall complete."
  exit 0
fi

# --- install ---------------------------------------------------------------
last_kind=""
for rec in ${MAP[@]+"${MAP[@]}"}; do
  src="${rec%%	*}"
  rest="${rec#*	}"
  dst="${rest%%	*}"
  kind="${rest#*	}"
  if [[ "$kind" != "$last_kind" ]]; then
    hdr "$kind"
    last_kind="$kind"
  fi
  # CLIs in bin/ must be executable, but the checkout is not the installer's
  # to mutate: the exec bit is tracked by git, and a chmod here rewrites the
  # developer's working tree (the test suite runs this installer ~25×, so a
  # deliberately non-executable file would have its mode flipped by running
  # the tests). Warn and let the fix happen in git. Skill scripts need no
  # bit at all — every SKILL.md invokes them as `bash script.sh`.
  if [[ -f "$src" && "$src" == "$REPO/bin/"* && ! -x "$src" ]]; then
    warn "  not executable: $src — fix with chmod +x and commit"
  fi
  do_link "$src" "$dst" "$kind"
done

# After linking, so a path that is both orphaned and re-linked this run (a
# skill renamed back to its old name) is treated as a link, not litter.
prune_orphans

want claude && install_claude_settings
want vscode && install_vscode

# --- tmux: a snippet, sourced by hand ---------------------------------------
if want all && [[ -f "$REPO/tmux/tmux.conf" ]]; then
  hdr "tmux"
  if [[ -f "$HOME/.tmux.conf" ]] && grep -q 'tmux/tmux.conf' "$HOME/.tmux.conf" 2>/dev/null; then
    say "  ok       already sourced from ~/.tmux.conf"
  else
    say "  not linked — it is a snippet. Add to ~/.tmux.conf:"
    say "    source-file $REPO/tmux/tmux.conf"
  fi
fi

# --- PATH check -------------------------------------------------------------
if ((DRY == 0)); then
  case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *)
      hdr "PATH"
      warn "  $HOME/bin is not on your PATH. Add to ~/.zshrc (zsh) or ~/.bashrc (bash):"
      warn "    export PATH=\"\$HOME/bin:\$PATH\""
      ;;
  esac
fi

printf '\n'
if ((DRY)); then
  ok "dry run complete — nothing changed."
else
  ok "done. Run ./install.sh doctor to verify."
fi
