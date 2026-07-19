#!/usr/bin/env bash
#
# SessionEnd hook — remind me to refresh HANDOFF.md / PROJECT_STATUS.md when
# they exist and have gone stale.
#
# Wired to SessionEnd rather than Stop deliberately. Stop fires every time the
# agent finishes a response — many times per session — so a reminder there
# would be noise. SessionEnd fires once, when the session actually terminates.
#
# The tradeoff, which is worth knowing: SessionEnd is observational. It cannot
# block and cannot inject context, so it can *tell you* the handoff is stale
# but cannot make the agent go update it. Surfacing text to the user from a
# non-blockable event is done by writing to stderr and exiting 2 — for these
# events that is documented to print stderr and continue, not to fail anything.
#
# "Stale" means: the repo changed after the file was last written. Concretely,
# a tracked file was modified, or a commit landed, more recently than the
# handoff file's own mtime.
#
# stdin: {"session_id","cwd","hook_event_name","reason"}
# exit 0: nothing to say.   exit 2: print the reminder.
set -uo pipefail

# Never let this hook take the session down with it.
command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[[ -n "$cwd" && -d "$cwd" ]] || exit 0

git -C "$cwd" rev-parse --show-toplevel >/dev/null 2>&1 || exit 0
root="$(git -C "$cwd" rev-parse --show-toplevel)"

# mtime in epoch seconds — GNU and BSD stat disagree on flags.
mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# Newest mtime among tracked files that differ from HEAD, ignoring the status
# files themselves — editing the handoff must not make the handoff look stale.
newest_work_mtime() {
  local newest=0 f t
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    case "$f" in HANDOFF.md | PROJECT_STATUS.md) continue ;; esac
    [[ -f "$root/$f" ]] || continue
    t="$(mtime "$root/$f")"
    ((t > newest)) && newest="$t"
  done < <(git -C "$root" status --porcelain --untracked-files=no 2>/dev/null | cut -c4-)

  # A commit is work too: it may be newer than any file left in the tree.
  local commit_t
  commit_t="$(git -C "$root" log -1 --format=%ct 2>/dev/null || echo 0)"
  ((commit_t > newest)) && newest="$commit_t"

  echo "$newest"
}

work_t="$(newest_work_mtime)"
[[ "$work_t" -gt 0 ]] || exit 0

stale=()
for f in HANDOFF.md PROJECT_STATUS.md; do
  [[ -f "$root/$f" ]] || continue # only nag about files that exist
  file_t="$(mtime "$root/$f")"
  ((work_t > file_t)) && stale+=("$f")
done

((${#stale[@]})) || exit 0

{
  printf 'Session ending with a stale handoff in %s:\n' "$(basename "$root")"
  for f in "${stale[@]}"; do
    printf '  - %s (repo changed after it was last written)\n' "$f"
  done
  printf 'Next session starts from these files — worth a minute now.\n'
} >&2
exit 2
