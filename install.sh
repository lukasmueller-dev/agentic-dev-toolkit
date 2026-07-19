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
#   claude   claude/* -> ~/.claude/*  (settings.json, CLAUDE.md, hooks/, agents/)
#   vscode   merge vscode/*.jsonc into the real VS Code settings.json
#   all      every target above (the default)
#
# Auto-discovery: every target enumerates the repo at run time. Drop a file in
# bin/, a directory in skills/, a script in claude/hooks/ — the next run picks
# it up with no edits here.
#
# Safety rules this script keeps:
#   - Idempotent. Re-running changes nothing that is already correct.
#   - A real (non-symlink) file is never deleted, only backed up.
#   - --uninstall removes a symlink only after confirming it points into THIS
#     repo, so it can never take out something another tool installed.
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
  sed -n '3,29p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
    all | bin | skills | claude | vscode) TARGETS+=("$1") ;;
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
# script has to behave identically on both machines.
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
    # Regular files at claude/ root: settings.json, CLAUDE.md, anything added
    # later. README.md is documentation about the directory, not config.
    for f in "$REPO"/claude/*; do
      [[ -f "$f" ]] || continue
      case "$(basename "$f")" in README.md) continue ;; esac
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
  fi
}

# ---------------------------------------------------------------------------
# Linking
# ---------------------------------------------------------------------------
backup() { # backup PATH KIND — move a real file out of the way, never delete
  local path="$1" bak="$BACKUP_DST/$2"
  mkdir -p "$bak"
  mv "$path" "$bak/$(basename "$path")"
  warn "  backed up $path -> $bak/$(basename "$path")"
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

vscode_snippet() {
  if [[ -d "$HOME/.vscode-server" || "$(uname -s)" != "Darwin" ]]; then
    printf '%s' "$REPO/vscode/vscode-server.jsonc"
  else
    printf '%s' "$REPO/vscode/vscode-mac.jsonc"
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
  local fail=0 warned=0
  local pass="  ${c_grn}ok${c_off}  " bad="  ${c_red}FAIL${c_off}" wrn="  ${c_yel}warn${c_off}"

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
      if [[ "$target" == "$src" ]]; then
        if [[ -e "$dst" ]]; then
          printf '%s %s\n' "$pass" "$dst"
        else
          printf '%s %s -> %s (dangling)\n' "$bad" "$dst" "$target"
          fail=1
        fi
      elif [[ "$target" == "$REPO"/* ]]; then
        printf '%s %s -> %s (points elsewhere in this repo)\n' "$wrn" "$dst" "$target"
        warned=1
      else
        printf '%s %s -> %s (not ours)\n' "$wrn" "$dst" "$target"
        warned=1
      fi
    elif [[ -e "$dst" ]]; then
      printf '%s %s is a real file, not a link — run ./install.sh\n' "$wrn" "$dst"
      warned=1
    else
      printf '%s %s missing — run ./install.sh\n' "$wrn" "$dst"
      warned=1
    fi
  done

  hdr "PATH"
  case ":$PATH:" in
    *":$HOME/bin:"*) printf '%s %s\n' "$pass" "$HOME/bin is on PATH" ;;
    *)
      # SC2016: the single quotes are the point — this is literal text for the
      # user to paste into a shell rc, not something to expand here.
      # shellcheck disable=SC2016
      printf '%s %s is NOT on PATH — add: export PATH="%s"\n' \
        "$wrn" "$HOME/bin" '$HOME/bin:$PATH'
      warned=1
      ;;
  esac

  hdr "Tools"
  local t
  for t in git jq; do
    if command -v "$t" >/dev/null 2>&1; then
      printf '%s %s\n' "$pass" "$t"
    else
      printf '%s %s missing (needed to merge VS Code settings and by the Claude Code hooks)\n' "$wrn" "$t"
      warned=1
    fi
  done
  for t in tmux gh; do
    if command -v "$t" >/dev/null 2>&1; then
      printf '%s %s\n' "$pass" "$t"
    else
      printf '%s %s missing (optional)\n' "$wrn" "$t"
      warned=1
    fi
  done

  hdr "VS Code"
  local vtarget vsnippet
  vtarget="$(vscode_target_file)"
  vsnippet="$(vscode_snippet)"
  if [[ ! -f "$vtarget" ]]; then
    printf '%s %s does not exist — run ./install.sh vscode\n' "$wrn" "$vtarget"
    warned=1
  elif ! command -v jq >/dev/null 2>&1; then
    printf '%s cannot verify without jq\n' "$wrn"
    warned=1
  elif [[ "$(strip_jsonc "$vtarget" | jq -S '.' 2>/dev/null)" == "$(jq -s -S '.[0] * .[1]' <(strip_jsonc "$vtarget") <(strip_jsonc "$vsnippet") 2>/dev/null)" ]]; then
    printf '%s settings applied in %s\n' "$pass" "$vtarget"
  else
    printf '%s %s is missing keys from %s — run ./install.sh vscode\n' \
      "$wrn" "$vtarget" "$(basename "$vsnippet")"
    warned=1
  fi

  hdr "Backups"
  if [[ -d "$BACKUP_ROOT" ]]; then
    local n
    n="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    if [[ "$n" -gt 0 ]]; then
      printf '%s %s backup set(s) in %s — remove them once you are sure\n' "$wrn" "$n" "$BACKUP_ROOT"
      find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sed 's|^|         |'
      warned=1
    else
      printf '%s no stale backups\n' "$pass"
    fi
  else
    printf '%s no stale backups\n' "$pass"
  fi

  printf '\n'
  if ((fail)); then
    err "install doctor: problems found"
    return 1
  elif ((warned)); then
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
  # Bundled scripts must be executable wherever they came from.
  if ((DRY == 0)); then
    [[ -f "$src" && "$src" == "$REPO/bin/"* ]] && chmod +x "$src"
    [[ -d "$src" ]] && find "$src" -name '*.sh' -exec chmod +x {} +
  fi
  do_link "$src" "$dst" "$kind"
done

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
      warn "  $HOME/bin is not on your PATH. Add to ~/.zshrc (mac) or ~/.bashrc (server):"
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
