# bash completion for vibe
#
# Installed by install.sh to:
#   ~/.local/share/bash-completion/completions/vibe
# which bash-completion picks up automatically. Without bash-completion
# installed, source it directly from ~/.bashrc:
#   source ~/git/agentic-dev-toolkit/completions/vibe.bash
#
# Avoids `mapfile`, which is bash 4+: macOS still ships bash 3.2, and this
# file should behave the same on both machines.

_vibe_tasks() {
  # Task names are the directory names under <worktree root>/<repo>/. Derived
  # here rather than shelling out to `vibe list` so completion stays fast and
  # works from anywhere inside the repo, including inside a worktree.
  local root repo common cfg d
  cfg="${VIBE_CONFIG_FILE:-$HOME/.config/vibe/config}"
  root="${VIBE_WORKTREE_ROOT:-}"
  if [[ -z "$root" && -r "$cfg" ]]; then
    root="$(sed -n 's/^[[:space:]]*VIBE_WORKTREE_ROOT[[:space:]]*=[[:space:]]*//p' \
      "$cfg" | tail -1 | tr -d '"'\''')"
  fi
  root="${root:-$HOME/git/worktrees}"

  common="$(git rev-parse --git-common-dir 2>/dev/null)" || return 0
  [[ "$common" == /* ]] || common="$PWD/$common"
  repo="$(basename "$(dirname "$common")")"

  [[ -d "$root/$repo" ]] || return 0
  for d in "$root/$repo"/*/; do
    [[ -d "$d" ]] && basename "$d"
  done
}

# _vibe_reply WORDS CUR — fill COMPREPLY without mapfile (bash 3.2 safe)
_vibe_reply() {
  local line
  COMPREPLY=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && COMPREPLY+=("$line")
  done < <(compgen -W "$1" -- "$2")
}

_vibe() {
  local cur cmd
  cur="${COMP_WORDS[COMP_CWORD]}"
  cmd="${COMP_WORDS[1]:-}"

  # completing the subcommand itself
  if [[ "$COMP_CWORD" -eq 1 ]]; then
    _vibe_reply "start attach park rc status list done sync resume where doctor help" "$cur"
    return
  fi

  case "$cmd" in
    done)
      if [[ "$cur" == -* ]]; then
        _vibe_reply "--force" "$cur"
      else
        _vibe_reply "$(_vibe_tasks)" "$cur"
      fi
      ;;
    resume)
      if [[ "$cur" == -* ]]; then
        _vibe_reply "--rebase" "$cur"
      else
        _vibe_reply "$(_vibe_tasks)" "$cur"
      fi
      ;;
    status)
      [[ "$cur" == -* ]] && _vibe_reply "--all" "$cur"
      ;;
    attach | park | rc | sync)
      _vibe_reply "$(_vibe_tasks)" "$cur"
      ;;
    *)
      # `start` takes a new task name: free text, nothing useful to suggest
      COMPREPLY=()
      ;;
  esac
}

complete -F _vibe vibe
