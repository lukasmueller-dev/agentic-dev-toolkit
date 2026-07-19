#!/usr/bin/env bash
#
# install.sh — link everything in this toolkit into place.
#
# Symlink strategy: files stay in the repo, symlinks point at them. That means
# `git pull` alone updates your installed tools — no re-copying, no drift.
#
# What it does (idempotent, safe to re-run):
#   - bin/*            -> ~/bin/<name>            (your CLI tools, e.g. vibe)
#   - skills/<name>/   -> ~/.claude/skills/<name> (Claude Code skills)
#
# settings/ is deliberately NOT linked. Those are fragments to merge into an
# existing VS Code settings.json, not whole files — symlinking would clobber
# every other setting in it. The script just points you at them.
#
# New tools/skills are picked up automatically next run — no edits needed here.
#
# Usage:
#   ./install.sh          # link everything
#   ./install.sh --dry    # show what would happen, change nothing
set -euo pipefail

DRY=0
[[ "${1:-}" == "--dry" || "${1:-}" == "-n" ]] && DRY=1

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DST="$HOME/bin"
SKILLS_DST="$HOME/.claude/skills"

# Backups go OUTSIDE the install dirs, grouped per run. Critically, a displaced
# skill must not stay in ~/.claude/skills — Claude Code scans that directory,
# so a leftover copy would load as a stale duplicate of the skill replacing it.
RUN_TS="$(date +%s)"
BACKUP_DST="$HOME/.agentic-dev-toolkit-backups/$RUN_TS"

c_grn=$'\033[32m'; c_yel=$'\033[33m'; c_dim=$'\033[2m'; c_red=$'\033[31m'; c_off=$'\033[0m'
say()  { printf '%s%s%s\n' "$c_dim" "$*" "$c_off"; }
ok()   { printf '%s%s%s\n' "$c_grn" "$*" "$c_off"; }
warn() { printf '%s%s%s\n' "$c_yel" "$*" "$c_off"; }

# link SRC -> DST, backing up an existing non-symlink, replacing an old symlink.
# KIND ("bin"/"skills") namespaces the backup, so bin/foo and skills/foo can
# both be displaced in one run without one landing inside the other.
link() {
  local src="$1" dst="$2" kind="${3:-misc}"
  local bak="$BACKUP_DST/$kind"
  if [[ "$DRY" == 1 ]]; then
    say "would link  $dst -> $src"
    [[ -e "$dst" && ! -L "$dst" ]] && warn "  (would back up existing $dst -> $bak/)"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm "$dst"                                   # stale symlink, replace
  elif [[ -e "$dst" ]]; then
    mkdir -p "$bak"                             # real file/dir, back it up
    mv "$dst" "$bak/$(basename "$dst")"
    warn "backed up existing $dst -> $bak/$(basename "$dst")"
  fi
  ln -s "$src" "$dst"
  ok "linked $dst -> $src"
}

# --- bin/ : individual executable files ------------------------------------
if compgen -G "$REPO/bin/*" >/dev/null; then
  for f in "$REPO"/bin/*; do
    [[ -f "$f" ]] || continue
    [[ "$DRY" == 1 ]] || chmod +x "$f"
    link "$f" "$BIN_DST/$(basename "$f")" bin
  done
else
  say "no bin/ entries"
fi

# --- skills/ : each subdirectory is one skill ------------------------------
if compgen -G "$REPO/skills/*/" >/dev/null; then
  for d in "$REPO"/skills/*/; do
    d="${d%/}"
    # make any bundled scripts executable
    [[ "$DRY" == 1 ]] || find "$d" -name '*.sh' -exec chmod +x {} +
    link "$d" "$SKILLS_DST/$(basename "$d")" skills
  done
else
  say "no skills/ entries"
fi

# --- settings/ : manual, they're fragments not whole files -----------------
if compgen -G "$REPO/settings/*" >/dev/null; then
  say "settings/ is not linked — paste into VS Code settings JSON by hand:"
  for f in "$REPO"/settings/*; do
    [[ -f "$f" ]] && say "  $f"
  done
fi

# --- PATH check ------------------------------------------------------------
if [[ "$DRY" != 1 ]] && ! printf '%s' ":$PATH:" | grep -q ":$BIN_DST:"; then
  warn "note: $BIN_DST is not in your PATH."
  warn "  add to ~/.bashrc (server) or ~/.zshrc (mac):"
  warn "    export PATH=\"\$HOME/bin:\$PATH\""
fi

ok "done."
