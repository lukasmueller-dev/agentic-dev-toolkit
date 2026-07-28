#!/usr/bin/env bash
# sota-weekly.sh — the cron entry point for the weekly SOTA digest.
#
# Starts one unattended `vibe loop` run whose only job is to write
# docs/sota/<YYYY-Www>.md and open a PR with it. Everything about the digest
# itself lives in the sibling SKILL.md; this script exists only to make that
# run survivable from cron: no tty, no login shell PATH, no one watching.
#
# Enable it with the instructions in docs/sota-watch.md.
set -euo pipefail

# Resolve where this script really lives — cron gives no useful $PWD, and the
# script may be reached through a symlink. `readlink -f` is avoided: macOS
# shipped BSD readlink without it for years.
script_dir() {
  local src="${BASH_SOURCE[0]}" dir
  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

SELF_DIR="$(script_dir)"
REPO_DIR="$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null)" ||
  {
    echo "sota-weekly: $SELF_DIR is not inside a git checkout" >&2
    exit 1
  }

# Stand in the checkout before doing anything else. `vibe` resolves the repo
# from the *current directory*, not from an argument, and cron runs the job
# from $HOME — which is not a git repo, so the loop would die "not a git repo."
# the moment it started. Deriving REPO_DIR and never entering it is what made
# that failure silent: the launch is wrapped in `|| rc=$?`, so the script went
# on to log "done" and exit 0 every week without ever running a digest.
cd "$REPO_DIR" || {
  echo "sota-weekly: cannot enter $REPO_DIR" >&2
  exit 1
}

# cron's PATH is famously minimal, and both `vibe` and the agent CLI are
# normally installed into a home-directory bin.
PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export PATH

log() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"; }

# ISO-8601 week: %G/%V, not %Y/%W — in the days around New Year they disagree,
# and %G-W%V is the pair that is internally consistent. Validated before
# anything is created, so a typo leaves no directory and no log behind.
WEEK="${1:-$(date -u +%G-W%V)}"
case "$WEEK" in
  [0-9][0-9][0-9][0-9]-W[0-9][0-9]) ;;
  *)
    echo "sota-weekly: bad week '$WEEK' (want YYYY-Www, e.g. 2026-W30)" >&2
    exit 1
    ;;
esac

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sota-digest"
mkdir -p "$LOG_DIR"
exec >>"$LOG_DIR/$WEEK.log" 2>&1

log "starting SOTA digest run for $WEEK (repo $REPO_DIR)"

command -v vibe >/dev/null 2>&1 || {
  log "FAILED: vibe is not on PATH ($PATH)"
  exit 1
}

BRIEF="$SELF_DIR/loop-brief.md"
[[ -f "$BRIEF" ]] || {
  log "FAILED: no loop brief at $BRIEF"
  exit 1
}

# The task string becomes both the branch slug and the brief's <goal>, so it
# has to carry the week: the agent reads the week out of the goal line.
TASK="sota $WEEK"

# --max 3 rather than 1: a round that dies mid-sweep gets another attempt, and
# --until stops the loop the moment the digest exists, so a clean first round
# costs nothing extra. Re-running for a week whose worktree already exists
# resumes that loop rather than starting a second one — which is exactly the
# behaviour wanted after a crashed run.
set -- --prompt "$BRIEF" --until "test -f docs/sota/$WEEK.md" --max 3 --pr

# --no-attach only where it belongs: on a server the loop detaches into tmux
# and cron has no tty to attach from, so it is required. Locally the flag is
# accepted too (it implies tmux anywhere), but the foreground run is what is
# wanted here — it is the by-hand path from docs/sota-watch.md, where you
# watch the loop rather than go looking for its session, and it needs no tmux
# installed. So ask vibe which environment this is and add the flag only for a
# server. 'vibe where' prints "<env> (reason)"; the first word is env.
env="$(vibe where | awk '{print $1}')"
if [[ "$env" == "server" ]]; then
  set -- "$@" --no-attach
fi

log "launching (env: ${env:-unknown}): vibe loop '$TASK' $*"
rc=0
vibe loop "$TASK" "$@" || rc=$?

# On a server the loop detaches into tmux and this exit status only reports the
# launch, not the run; on a local machine a non-zero status is the loop's own
# outcome code (2 stalled, 3 maxed, 4 time up, 5 diverged). Neither is worth
# failing the cron job over — the PR, or its absence, is the signal.
log "vibe loop returned $rc"

log "done"
