#!/usr/bin/env bash
#
# pr-ready.sh <pr-number> — the stop check for a "drive this PR to mergeable"
# loop. Exits 0 only when both hold for that PR:
#
#   * no failing and no pending checks (`gh pr checks --json bucket`)
#   * zero unresolved review threads (GraphQL `reviewThreads`)
#
# Everything else exits non-zero: a failing check, a pending check, an
# unresolved thread — and equally `gh` or `jq` missing, `gh` unauthenticated,
# the API erroring, or output that does not parse. A broken environment must
# never read as "done", because that would end the loop with the PR unmerged
# and nobody watching.
set -uo pipefail

prog="$(basename "$0")"
not_ready() {
  echo "$prog: $*" >&2
  exit 1
}

pr="${1:-}"
[[ "$pr" =~ ^[0-9]+$ ]] || not_ready "usage: $prog <pr-number>"

command -v gh >/dev/null 2>&1 || not_ready "'gh' is not installed — cannot tell whether PR #$pr is ready."
command -v jq >/dev/null 2>&1 || not_ready "'jq' is not installed — cannot tell whether PR #$pr is ready."

# ---------------------------------------------------------------------------
# Checks. `gh pr checks` exits non-zero both when checks are failing/pending
# and when it fails outright, so the exit status alone cannot separate the two.
# The JSON is what decides: parse it, or treat the call as broken.
# ---------------------------------------------------------------------------
checks="$(gh pr checks "$pr" --json bucket 2>/dev/null)" || true
echo "$checks" | jq -e 'type == "array"' >/dev/null 2>&1 ||
  not_ready "could not read checks for PR #$pr (gh failed, unauthenticated, or reported none)."

bad="$(echo "$checks" | jq '[.[] | select(.bucket != "pass" and .bucket != "skipping")] | length')"
[[ "$bad" == "0" ]] || not_ready "PR #$pr has $bad check(s) failing or pending."

# ---------------------------------------------------------------------------
# Review threads. `gh pr view` cannot report resolution state, so this goes
# through GraphQL.
# ---------------------------------------------------------------------------
nwo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || true
[[ "$nwo" == */* ]] || not_ready "could not resolve the repository from gh."

# shellcheck disable=SC2016  # $owner/$name/$number are GraphQL variables, not shell ones
threads="$(gh api graphql \
  -f owner="${nwo%%/*}" -f name="${nwo#*/}" -F number="$pr" \
  -f query='query($owner:String!,$name:String!,$number:Int!){
    repository(owner:$owner,name:$name){
      pullRequest(number:$number){
        reviewThreads(first:100){ nodes { isResolved } }
      }
    }
  }' 2>/dev/null)" || true

open_threads="$(echo "$threads" |
  jq -e '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)] | length' 2>/dev/null)" ||
  not_ready "could not read review threads for PR #$pr."
[[ "$open_threads" == "0" ]] || not_ready "PR #$pr has $open_threads unresolved review thread(s)."

echo "$prog: PR #$pr is ready — checks green, no unresolved review threads."
