#!/usr/bin/env bash
#
# vibe-status.sh — `vibe status --claude`: the claude-rc@ servers on this machine.
set -euo pipefail

role_file="$HOME/.config/vibe/role"
role=client
if [[ -f "$role_file" ]]; then
  read -r role <"$role_file" || true
fi
echo "role: ${role:-client}  ($role_file)"

if ! command -v systemctl >/dev/null 2>&1; then
  echo "no systemd on this machine"
  exit 0
fi
units="$(systemctl --user list-units 'claude-rc@*' --all --no-legend --plain 2>/dev/null | awk '{ print $1 }' || true)"
if [[ -z "$units" ]]; then
  echo "no claude-rc@ servers on this machine"
  exit 0
fi

printf '%-28s %-18s %-9s %s\n' REPO STATE RESTARTS SINCE
for u in $units; do
  state="" sub="" restarts="" since=""
  while IFS='=' read -r k v; do
    case "$k" in
      ActiveState) state="$v" ;;
      SubState) sub="$v" ;;
      NRestarts) restarts="$v" ;;
      ActiveEnterTimestamp) since="$v" ;;
    esac
  done < <(systemctl --user show -p ActiveState -p SubState -p NRestarts -p ActiveEnterTimestamp "$u")
  repo="${u#claude-rc@}"
  printf '%-28s %-18s %-9s %s\n' "${repo%.service}" "$state/$sub" "${restarts:-?}" "${since:--}"
done
if [[ "$role" != server ]]; then
  echo "warning: servers are loaded, but the role is not 'server'; they will not start again"
fi
