# shellcheck shell=bash
#
# vibe.bash — bash completion for bin/vibe. install.sh links it to
# ~/.local/share/bash-completion/completions/vibe; without bash-completion,
# source it from ~/.bashrc. bash 3.2 safe: no mapfile.

# _vibe_tasks — branch names of the current repo, local and on origin.
_vibe_tasks() {
  git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin 2>/dev/null |
    sed -e 's#^origin/##' -e '/^HEAD$/d' -e '/^origin$/d' -e '/^worktree-/d' -e '/^main$/d' -e '/^master$/d' |
    sort -u
}

# _vibe_agents — --<agent> for each <agent>/vibe-status.sh in the toolkit.
_vibe_agents() {
  local src dir f
  src="$(type -P vibe 2>/dev/null)" || return 0
  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" == /* ]] || src="$dir/$src"
  done
  for f in "$(cd -P "$(dirname "$src")/.." && pwd)"/*/vibe-status.sh; do
    [[ -f "$f" ]] && basename "$(dirname "$f")" | sed 's/^/--/'
  done
}

# _vibe_reply WORDS CUR — fill COMPREPLY without mapfile.
_vibe_reply() {
  local line
  COMPREPLY=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && COMPREPLY+=("$line")
  done < <(compgen -W "$1" -- "$2")
}

_vibe() {
  local cur="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD - 1]}" line
  if [[ "$COMP_CWORD" -eq 1 ]]; then
    _vibe_reply "start sync status night update-toolkit help" "$cur"
    return
  fi
  case "${COMP_WORDS[1]}" in
    start)
      if [[ "$prev" == -C ]]; then
        COMPREPLY=()
        while IFS= read -r line; do COMPREPLY+=("$line"); done < <(compgen -d -- "$cur")
      elif [[ "$cur" == -* ]]; then
        _vibe_reply "-C" "$cur"
      else
        _vibe_reply "$(_vibe_tasks)" "$cur"
      fi
      ;;
    sync) _vibe_reply "--all --wip" "$cur" ;;
    status) _vibe_reply "$(_vibe_agents)" "$cur" ;;
    night)
      if [[ "$COMP_CWORD" -eq 2 ]]; then
        _vibe_reply "start status report" "$cur"
      elif [[ "$cur" == -* ]]; then
        _vibe_reply "$(_vibe_agents) --jobs --until --timeout --new --day" "$cur"
      else
        COMPREPLY=()
        while IFS= read -r line; do COMPREPLY+=("$line"); done < <(compgen -d -- "$cur")
      fi
      ;;
    *) COMPREPLY=() ;;
  esac
}

complete -F _vibe vibe
