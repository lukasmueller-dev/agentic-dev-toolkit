#!/usr/bin/env bats
#
# vibe queue — the vibe queue in throwaway repos with a bare origin. A stub
# `claude` acts on the MODE line of its prompt; a stub `gh` records its calls
# under $STUBS. The runner runs with --drain, so each test ends.

load helper

VIBE="$REPO_ROOT/bin/vibe"
SWEEP="$REPO_ROOT/skills/fill-queue/sweep.sh"

setup() {
  git_env
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"
  cat >"$STUBS/claude" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$STUBS/claude.log"
prompt="\$(cat)"
mode="\$(printf '%s\n' "\$prompt" | sed -n 's/^MODE=//p')"
case "\$prompt" in *"## GPU run finished"*) mode=ok ;; esac
case "\$mode" in
  gpu)
    echo code >code.txt && git add code.txt && git commit -q -m "feat: train script"
    "$VIBE" queue gpu -- sh -c 'echo trained >out.txt'
    echo "queued: training" >"\$VIBE_JOB_DIR/result"
    ;;
  ok)
    echo work >work.txt && git add work.txt && git commit -q -m "feat: work"
    printf 'feat: queue work\n\n**Context:** The repo lacks work.txt.\n**Changed:** work.txt added.\n**Verify:** cat work.txt\n' >"\$VIBE_JOB_DIR/pr.md"
    echo "done: work.txt added" >"\$VIBE_JOB_DIR/result"
    ;;
  lock)
    echo work >work.txt && git add work.txt && git commit -q -m "feat: work"
    l="\$(cd "\$(git rev-parse --git-common-dir)" && pwd)/config.lock"
    rm -f "\$l" && : >"\$l" && chmod 444 "\$l"
    echo "done: work.txt added" >"\$VIBE_JOB_DIR/result"
    ;;
  nopr)
    echo work >work.txt && git add work.txt && git commit -q -m "feat: work"
    echo "done: work.txt added, no pr.md" >"\$VIBE_JOB_DIR/result"
    ;;
  seq)
    echo begin >>"$STUBS/seq" && sleep 0.5 && echo end >>"$STUBS/seq"
    echo "done: nothing" >"\$VIBE_JOB_DIR/result"
    ;;
  milestone)
    awk '!t && /^- \[ \]/ { sub(/\[ \]/, "[x]"); t = 1 } { print }' SPEC.md >SPEC.tmp && mv SPEC.tmp SPEC.md
    git commit -q -am "feat: a milestone"
    echo "done: one milestone" >"\$VIBE_JOB_DIR/result"
    ;;
  limit)
    if [ -f "$STUBS/limit-reset" ]; then
      echo "\$(cat wip.txt) more" >wip.txt && git add wip.txt && git commit -q -m "feat: wip"
      echo "done: wip finished" >"\$VIBE_JOB_DIR/result"
    else
      echo half >wip.txt
      echo '{"type":"rate_limit_event","rate_limit_info":{"status":"rejected","resetsAt":'"\$((\$(date +%s) + 3600))"',"rateLimitType":"five_hour"}}'
      exit 1
    fi
    ;;
  cost)
    echo work >work.txt && git add work.txt && git commit -q -m "feat: work"
    echo '{"type":"rate_limit_event","rate_limit_info":{"unifiedWindows":{"five_hour":{"utilization":0.46,"resetsAt":1793269800,"status":"allowed"}}}}'
    echo '{"type":"result","subtype":"success","duration_ms":647191,"num_turns":40,"total_cost_usd":1.04}'
    echo "done: costed" >"\$VIBE_JOB_DIR/result"
    ;;
  blocked) echo "blocked: needs a decision" >"\$VIBE_JOB_DIR/result" ;;
  crash) exit 3 ;;
  silent) ;;
  sleep) sleep 30 ;;
esac
EOF
  cat >"$STUBS/gh" <<EOF
#!/bin/sh
echo "\$*" >>"$STUBS/gh.log"
case "\$1 \$2" in
  "pr create") echo "https://example.com/pull/1" ;;
  "pr list") [ ! -f "$STUBS/pr-exists" ] || echo "https://example.com/pull/9" ;;
esac
EOF
  printf '#!/bin/sh\n' >"$STUBS/code"
  chmod +x "$STUBS/claude" "$STUBS/gh" "$STUBS/code"
  PATH="$STUBS:$PATH"
  export VIBE_TOOLKIT="$BATS_TEST_TMPDIR/no-toolkit" VIBE_QUEUE_POLL=0.2
  export GPU_QUEUE_DIR="$BATS_TEST_TMPDIR/gpu-queue" GPUQ_POLL=0.1
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  mkdir -p "$HOME/.config/vibe" && echo server >"$HOME/.config/vibe/role"
  Q="$XDG_STATE_HOME/vibe/queue"
  CONF="$XDG_CONFIG_HOME/vibe/queue.conf"
  mkdir -p "$Q" "${CONF%/*}"
}

# mkjob ID REPO BRANCH MODE [JOB-LINE...] — one job dir in the queue.
mkjob() {
  local id="$1" repo="$2" branch="$3" mode="$4"
  shift 4
  mkdir -p "$Q/$id"
  printf 'Do the task.\nMODE=%s\n' "$mode" >"$Q/$id/prompt.md"
  {
    printf 'repo=%s\nbranch=%s\nmodel=sonnet\n' "$repo" "$branch"
    for l in "$@"; do echo "$l"; done
  } >"$Q/$id/job"
}
# slots N — the queue runs N agents at once.
slots() { echo "slots=$1" >"$CONF"; }
drain() { run "$VIBE" queue run --claude --drain; }

@test "run: jobs in id order, commits pushed, draft PR from pr.md" {
  local r
  r="$(make_repo proj)"
  slots 1
  mkjob 01-a "$r" task-a ok
  mkjob 02-b "$r" task-b ok
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(cat "$Q/02-b/status")" = "done" ]
  [ "$(sed -n 1p "$STUBS/claude.log" | grep -c proj-task-a)" = 1 ]
  git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/task-a
  git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/task-b
  [ "$(cat "$Q/01-a/pr")" = "https://example.com/pull/1" ]
  grep -q -- 'pr create --draft --base main --head task-a --title feat: queue work' "$STUBS/gh.log"
  grep -q '^\*\*Changed:\*\* work.txt added.' "$Q/01-a/pr-body.md"
  grep -qF -- 'api --method POST repos/{owner}/{repo}/issues/1/labels -f labels[]=agent' "$STUBS/gh.log"
  [ "$(cat "$Q/01-a/note")" = "done: work.txt added" ]
}

@test "run: the agent is headless, sandboxed by the job settings, named <repo>-<branch>" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  drain
  [ "$status" -eq 0 ]
  grep -q -- '-p --model sonnet --name proj-task-a' "$STUBS/claude.log"
  grep -q -- '--permission-prompts none' "$STUBS/claude.log"
  grep -q -- "--settings $REPO_ROOT/claude/vibe-job-settings.json" "$STUBS/claude.log"
}

@test "run: effort= in the job file reaches the agent as --effort" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok effort=xhigh
  drain
  [ "$status" -eq 0 ]
  grep -q -- '-p --model sonnet --effort xhigh --name proj-task-a' "$STUBS/claude.log"
}

@test "run: an empty read-only .git/config.lock does not stop a job from starting" {
  local r
  r="$(make_repo proj)"
  git -C "$r" push -q origin main:refs/heads/task-a
  : >"$r/.git/config.lock" && chmod 444 "$r/.git/config.lock"
  mkjob 01-a "$r" task-a ok
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(git -C "$r" config branch.task-a.remote)" = origin ]
  [ ! -e "$r/.git/config.lock" ]
}

@test "run: a config.lock the job's own sandbox leaves does not stop the push -u" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a lock
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(git -C "$r" config branch.task-a.remote)" = origin ]
  [ ! -e "$r/.git/config.lock" ]
}

@test "run: a config.lock with content, or a writable one, stays" {
  local r
  r="$(make_repo proj)"
  git -C "$r" push -q origin main:refs/heads/task-a main:refs/heads/task-b
  echo pid >"$r/.git/config.lock" && chmod 444 "$r/.git/config.lock"
  mkjob 01-a "$r" task-a ok
  drain
  [ "$(cat "$r/.git/config.lock")" = pid ]
  [ "$(cat "$Q/01-a/status")" != "done" ]
  rm -f "$r/.git/config.lock" && : >"$r/.git/config.lock"
  mkjob 02-b "$r" task-b ok
  drain
  [ -e "$r/.git/config.lock" ]
  [ "$(cat "$Q/02-b/status")" != "done" ]
}

@test "run: no pr.md titles the PR from the result; an open PR gets its body replaced" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a nopr
  drain
  grep -q -- '--title agent(task-a): work.txt added, no pr.md --body-file' "$STUBS/gh.log"
  touch "$STUBS/pr-exists"
  mkjob 02-b "$r" task-b ok
  drain
  [ "$(cat "$Q/02-b/pr")" = "https://example.com/pull/9" ]
  grep -qF -- "api --method PATCH repos/{owner}/{repo}/pulls/9 -F body=@$Q/02-b/pr-body.md" "$STUBS/gh.log"
  run grep -c -- 'pr create --draft --base main --head task-b' "$STUBS/gh.log"
  [ "$output" = 0 ]
}

@test "run: blocked without commits pushes nothing; crash and silence fail" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a blocked
  mkjob 02-b "$r" task-b crash
  mkjob 03-c "$r" task-c silent
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = blocked ]
  [ "$(cat "$Q/01-a/note")" = "blocked: needs a decision" ]
  [ ! -e "$Q/01-a/pr" ]
  run git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/task-a
  [ "$status" -ne 0 ]
  [ "$(cat "$Q/02-b/status")" = failed ]
  [[ "$(cat "$Q/02-b/note")" == "agent exit 3: "* ]] || false
  [ "$(cat "$Q/03-c/status")" = failed ]
  [ "$(cat "$Q/03-c/note")" = "no result line" ]
}

@test "run: a job over its own time limit is stopped" {
  command -v timeout >/dev/null 2>&1 || skip "no timeout(1)"
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a sleep timeout=1s
  drain
  [ "$(cat "$Q/01-a/status")" = timeout ]
  [ "$(cat "$Q/01-a/note")" = "stopped after 1s" ]
}

@test "run: skips a dirty worktree, fails a bad branch, a missing repo and a dead job" {
  local r
  r="$(make_repo proj)"
  "$VIBE" start -C "$r" busy >/dev/null 2>&1
  echo wip >"$r/.claude/worktrees/busy/wip.txt"
  mkjob 01-a "$r" busy ok
  mkjob 02-b "$r" main ok
  mkjob 03-c "$BATS_TEST_TMPDIR/nowhere" task-c ok
  mkjob 04-d "$r" task-d ok
  echo running >"$Q/04-d/status"
  echo 999999 >"$Q/04-d/pid"
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = skipped ]
  [[ "$(cat "$Q/01-a/note")" == *"uncommitted changes"* ]] || false
  [ "$(cat "$Q/02-b/status")" = failed ]
  [ "$(cat "$Q/03-c/status")" = failed ]
  [ "$(cat "$Q/04-d/status")" = failed ]
  [ "$(cat "$Q/04-d/note")" = "job process died" ]
  [ ! -e "$STUBS/claude.log" ]
}

@test "run: --now jobs start first; a long timeout starts at once" {
  local r
  r="$(make_repo proj)"
  slots 1
  mkjob 01-a "$r" task-a ok timeout=9h
  mkjob 02-b "$r" task-b ok now=1
  drain
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$STUBS/claude.log" | grep -c proj-task-b)" = 1 ]
  [ "$(sed -n 2p "$STUBS/claude.log" | grep -c proj-task-a)" = 1 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
}

@test "run: one job per branch at a time" {
  local r
  r="$(make_repo proj)"
  slots 2
  mkjob 01-a "$r" task-a seq
  mkjob 02-a "$r" task-a seq
  drain
  [ "$(cat "$Q/02-a/status")" = "done" ]
  [ "$(tr '\n' ' ' <"$STUBS/seq")" = "begin end begin end " ]
}

@test "pause: nothing starts until resume" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  run "$VIBE" queue pause
  [ "$status" -eq 0 ]
  drain
  [ ! -e "$Q/01-a/status" ]
  run "$VIBE" queue status
  [[ "$output" == *"PAUSED"* ]] || false
  "$VIBE" queue resume >/dev/null
  drain
  [ "$(cat "$Q/01-a/status")" = "done" ]
}

@test "limit: the job requeues with its worktree kept, nothing starts until the reset" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a limit
  mkjob 02-b "$r" task-b ok
  slots 1
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = queued ]
  [[ "$(cat "$Q/01-a/note")" == "usage limit — retry after "* ]] || false
  [ ! -e "$Q/02-b/status" ]
  [ "$(cat "$r/.claude/worktrees/task-a/wip.txt")" = half ]
  run git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/task-a
  [ "$status" -ne 0 ]
  run "$VIBE" queue status
  [[ "$output" == *"USAGE LIMIT until"* ]] || false
  date +%s >"$XDG_STATE_HOME/vibe/limit"
  touch "$STUBS/limit-reset"
  drain
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(cat "$Q/02-b/status")" = "done" ]
  [ "$(git -C "$BATS_TEST_TMPDIR/proj.git" show task-a:wip.txt)" = "half more" ]
}

@test "add: moves a prepared dir in as <time>-<repo>-<branch>, in order; --now; refuses bad input" {
  local r a b
  r="$(make_repo proj)"
  a="$BATS_TEST_TMPDIR/a" b="$BATS_TEST_TMPDIR/b"
  mkdir -p "$a" "$b"
  printf 'repo=%s\nbranch=x\n' "$r" >"$a/job"
  printf 'repo=%s\nbranch=y\n' "$r" >"$b/job"
  echo task >"$a/prompt.md"
  echo task >"$b/prompt.md"
  run "$VIBE" queue add "$a" --now "$b"
  [ "$status" -eq 0 ]
  [ ! -e "$a" ]
  [ "$(for d in "$Q"/*; do echo "${d##*/}"; done | sed -E 's/^[0-9]{8}-[0-9]{6}-//' | tr '\n' ' ')" = "proj-x proj-y " ]
  grep -qx now=1 "$Q"/*-proj-y/job
  mkdir -p "$a"
  run "$VIBE" queue add "$a"
  [ "$status" -ne 0 ]
  printf 'repo=%s\nbranch=Bad Branch\n' "$r" >"$a/job"
  run "$VIBE" queue add "$a"
  [ "$status" -ne 0 ]
}

@test "milestones: a SPEC.md job that ticks one queues the next; the last one ends the chain" {
  local r
  r="$(make_repo proj)"
  "$VIBE" start -C "$r" spec >/dev/null 2>&1
  printf '# Spec\n\n- [ ] one\n- [ ] two\n' >"$r/.claude/worktrees/spec/SPEC.md"
  git -C "$r/.claude/worktrees/spec" add SPEC.md
  git -C "$r/.claude/worktrees/spec" commit -q -m "docs(spec): x"
  mkjob 01-a "$r" spec milestone timeout=1h
  drain
  [ "$(find "$Q" -mindepth 1 -maxdepth 1 | wc -l)" -eq 2 ]
  for d in "$Q"/*/; do [ "$(cat "$d/status")" = "done" ]; done
  [ "$(grep -c '^- \[x\]' "$r/.claude/worktrees/spec/SPEC.md")" -eq 2 ]
  mkjob 09-z "$r" spec ok
  printf '# Spec\n\n- [ ] three\n' >"$r/.claude/worktrees/spec/SPEC.md"
  git -C "$r/.claude/worktrees/spec" commit -q -am "docs(spec): three"
  drain
  [ "$(find "$Q" -mindepth 1 -maxdepth 1 | wc -l)" -eq 3 ]
}

@test "hold and archive: a held job stays; archive moves only ended jobs" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  mkjob 02-b "$r" task-b blocked
  mkjob 03-c "$r" task-c ok
  drain
  mkjob 04-d "$r" task-d ok
  run "$VIBE" queue archive 04-d
  [ "$status" -ne 0 ]
  [[ "$output" == *"has not ended"* ]] || false
  run "$VIBE" queue hold 02-b test it on the robot
  [ "$status" -eq 0 ]
  run "$VIBE" queue archive 01-a 03-c
  [ "$status" -eq 0 ]
  [ -d "$XDG_STATE_HOME/vibe/archive/$(date +%Y-%m)/01-a" ]
  [ ! -e "$Q/01-a" ]
  run "$VIBE" queue status
  [[ "$output" == "queue: 0 running · 0 on the GPU · 1 queued · 1 to review"* ]] || false
  [[ "$output" == *"proj"*"02-b"*"held"*"04-d"*"queued"* ]] || false
  run "$VIBE" queue archive nosuch
  [ "$status" -ne 0 ]
}

@test "status: the columns line up for ids of any length" {
  local r a b
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  mkjob 02-a-much-longer-id-than-the-other "$r" task-b ok
  run "$VIBE" queue status
  a="$(grep ' 01-a ' <<<"$output")" b="$(grep ' 02-a-much' <<<"$output")"
  a="${a%%queued*}" b="${b%%queued*}"
  [ "${#a}" -gt 6 ]
  [ "${#a}" -eq "${#b}" ]
}

@test "report: header, held jobs under Yours, per repo tables, next actions; copied to the briefing dir" {
  local r f
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  mkjob 02-b "$r" task-b blocked
  mkjob 03-c "$r" task-c crash 'context=Task c needs a | fix.'
  mkjob 04-d "$r" task-d blocked
  drain
  "$VIBE" queue hold 04-d test it on the robot >/dev/null
  printf '## Next action\n\nAsk the supervisor.\n\n## Blockers\n\nNeeds a | decision.\n' \
    >"$r/.claude/worktrees/task-b/HANDOFF.md"
  echo findings >"$Q/03-c/report.md"
  echo "$BATS_TEST_TMPDIR/vault/inbox" >"$XDG_CONFIG_HOME/vibe/briefing-dir"
  run "$VIBE" queue report
  [ "$status" -eq 0 ]
  f="$(ls "$XDG_STATE_HOME"/vibe/briefings/*.md)"
  [[ "${f##*/}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\.md$ ]] || false
  [[ "$output" == *"copied: $BATS_TEST_TMPDIR/vault/inbox/briefing-${f##*/}"* ]] || false
  [ "$(head -n 2 "$BATS_TEST_TMPDIR/vault/inbox/briefing-${f##*/}")" = "$(printf -- '---\ncreated: %s' "$(date +%F)")" ]
  run cat "$f"
  [[ "$output" == *"queue: 0 running"*"4 to review"* ]] || false
  [[ "$output" == *"## Yours"*"| 04-d | blocked |  | test it on the robot |  |"*"## proj"* ]] || false
  [[ "$output" == *"## proj"*"### Needs you"*"| 02-b | blocked |  | blocked: needs a decision |  |"*"| 03-c | failed | Task c needs a / fix. |"*"| [report](file://$Q/03-c/report.md) |"*"### PR ready"* ]] || false
  [[ "$output" == *"### PR ready"*"| 01-a | done | The repo lacks work.txt. | work.txt added. | [PR](https://example.com/pull/1) |"* ]] || false
  [[ "$output" == *"## 02-b — blocked"*"Ask the supervisor."*"Needs a | decision."* ]] || false
  [[ "$output" == *"## 03-c — failed"*"- Report: $Q/03-c/report.md"*"- Log: $Q/03-c/log"* ]] || false
  [[ "$output" != *"## 04-d — "* ]] || false
}

# endedjob ID REPO START END COST UTIL0 UTIL1 [RESET] — an ended job with a log of two
# rate_limit_events and a result event; START and END are HH:MM:SS today.
endedjob() {
  local id="$1" r="${8:-1793269800}"
  mkjob "$id" "$2" "b-$id" ok
  echo "done" >"$Q/$id/status"
  echo "done: $id" >"$Q/$id/note"
  echo "$(date +%F) $3" >"$Q/$id/started"
  echo "$(date +%F) $4" >"$Q/$id/ended"
  {
    echo '{"type":"rate_limit_event","rate_limit_info":{"unifiedWindows":{"five_hour":{"utilization":'"$6"',"resetsAt":1793269800}}}}'
    echo '{"type":"rate_limit_event","rate_limit_info":{"unifiedWindows":{"five_hour":{"utilization":'"$7"',"resetsAt":'"$r"'}}}}'
    echo '{"type":"result","duration_ms":60000,"num_turns":3,"total_cost_usd":'"$5"'}'
  } >"$Q/$id/log"
}

@test "cost: the PR footer and the briefing row show the API price, turns and minutes" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a cost
  drain
  [ "$status" -eq 0 ]
  grep -qF -- "_agent job 01-a: done: costed · ≈\$1.04 API · 40 turns · 11m_" "$Q/01-a/pr-body.md"
  run "$VIBE" queue report
  [ "$status" -eq 0 ]
  run cat "$XDG_STATE_HOME"/vibe/briefings/*.md
  [[ "$output" == *"| 01-a | done |"*"≈\$1.04 API · 40 turns · 11m |"* ]] || false
  [[ "$output" != *"5h est."* ]] || false
}

@test "cost: the limit share is the job cost over the cost of the jobs it overlaps, scaled by overlap time" {
  local r f files
  r="$(make_repo proj)"
  endedjob 01-a "$r" 10:00:00 10:09:59 1 0.40 0.48
  endedjob 02-b "$r" 10:00:00 10:09:59 3 0.40 0.48
  "$VIBE" queue report >/dev/null
  f="$(ls "$XDG_STATE_HOME"/vibe/briefings/*.md)"
  grep -F '| 01-a |' "$f" | grep -qF "≈\$1.00 API · ≈2% 5h est. · 3 turns · 1m"
  grep -F '| 02-b |' "$f" | grep -qF "≈\$3.00 API · ≈6% 5h est. · 3 turns · 1m"
  # 03-c runs in the last tenth of 01-a and 02-b: its $20 counts for $2.
  endedjob 03-c "$r" 10:09:00 10:18:59 20 0.48 0.50
  "$VIBE" queue report >/dev/null
  files=("$XDG_STATE_HOME"/vibe/briefings/*.md)
  f="${files[${#files[@]} - 1]}"
  grep -F '| 01-a |' "$f" | grep -qF '≈1% 5h est.'
  grep -F '| 02-b |' "$f" | grep -qF '≈4% 5h est.'
}

@test "cost: no limit share when resetsAt changes, a neighbour has no cost, or the log has one event" {
  local r f
  r="$(make_repo proj)"
  endedjob 01-a "$r" 10:00:00 10:09:59 1 0.40 0.48 1793287800
  endedjob 02-b "$r" 11:00:00 11:09:59 1 0.40 0.48
  endedjob 03-c "$r" 11:00:00 11:09:59 1 0.40 0.48
  : >"$Q/03-c/log"
  endedjob 05-e "$r" 12:00:00 12:09:59 1 0.40 0.48
  sed -i.bak '2d' "$Q/05-e/log" && rm "$Q/05-e/log.bak"
  "$VIBE" queue report >/dev/null
  f="$(ls "$XDG_STATE_HOME"/vibe/briefings/*.md)"
  grep -F '| 01-a |' "$f" | grep -qF "≈\$1.00 API · 3 turns"
  grep -F '| 02-b |' "$f" | grep -qF "≈\$1.00 API · 3 turns"
  grep -F '| 05-e |' "$f" | grep -qF "≈\$1.00 API · 3 turns"
  run grep -c '5h est.' "$f"
  [ "$output" = 0 ]
  run grep -F '| 03-c |' "$f"
  [[ "$output" != *"API"* ]] || false
}

@test "cost: the briefing header shows the 5h limit from the newest rate_limit_event" {
  local r f at
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a cost
  drain
  "$VIBE" queue report >/dev/null
  f="$(ls "$XDG_STATE_HOME"/vibe/briefings/*.md)"
  at="$(date -d @1793269800 +%H:%M 2>/dev/null || date -r 1793269800 +%H:%M)"
  [[ "$(sed -n 3p "$f")" == "queue: "*" · limit 5h: 46%, resets $at" ]] || false
  rm "$Q/01-a/log"
  "$VIBE" queue report >/dev/null
  run cat "$f"
  [[ "$output" != *"limit 5h"* ]] || false
}

@test "docs: the --bare trap is in docs/vibe-queue.md" {
  grep -q -- '--bare' "$REPO_ROOT/docs/vibe-queue.md"
}

@test "report --week: per repo jobs run, PRs merged, blockers open; old jobs count only while open" {
  local r f since
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  mkjob 02-b "$r" task-b blocked
  mkjob 03-c "$r" task-c crash
  drain
  "$VIBE" queue archive 01-a >/dev/null
  mkdir -p "$Q/00-oldblock" "$XDG_STATE_HOME/vibe/archive/2020-01/00-oldarch"
  printf 'repo=%s\nbranch=old\n' "$r" | tee "$Q/00-oldblock/job" >"$XDG_STATE_HOME/vibe/archive/2020-01/00-oldarch/job"
  echo blocked >"$Q/00-oldblock/status"
  echo "blocked: ancient" >"$Q/00-oldblock/note"
  echo "2020-01-01 00:00:00" | tee "$Q/00-oldblock/ended" >"$XDG_STATE_HOME/vibe/archive/2020-01/00-oldarch/ended"
  echo "done" >"$XDG_STATE_HOME/vibe/archive/2020-01/00-oldarch/status"
  cat >"$STUBS/gh" <<EOF
#!/bin/sh
echo "\$*" >>"$STUBS/gh.log"
echo "  - [#5](https://example.com/pull/5) feat: merged work"
EOF
  run "$VIBE" queue report
  f="$(ls "$XDG_STATE_HOME"/vibe/briefings/*.md)"
  [ "$(grep -c '^## Week' "$f")" -eq 0 ]
  rm "$f"
  run "$VIBE" queue report --week
  [ "$status" -eq 0 ]
  f="$(ls "$XDG_STATE_HOME"/vibe/briefings/*.md)"
  since="$(date -d '7 days ago' +%F 2>/dev/null || date -v-7d +%F)"
  grep -qF -- "merged:>=$since" "$STUBS/gh.log"
  run cat "$f"
  [[ "$output" == *"## proj"*"## Week since $since"*"### proj"*"- Jobs run: 3 (1 done, 1 blocked, 1 failed)"*"- PRs merged: 1"*"  - [#5](https://example.com/pull/5) feat: merged work"*"- Blockers open: 3"*"  - 00-oldblock — blocked: ancient"*"  - 02-b — blocked: needs a decision"*"  - 03-c — agent exit 3"* ]] || false
  [[ "$output" != *"00-oldarch"* ]] || false
}

@test "report --week: no merged PRs say none; a failing gh says unknown; other arguments are refused" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a blocked
  drain
  run "$VIBE" queue report --week
  [[ "$(cat "$XDG_STATE_HOME"/vibe/briefings/*.md)" == *"- Jobs run: 1 (1 blocked)"*"- PRs merged: none"* ]] || false
  printf '#!/bin/sh\nexit 1\n' >"$STUBS/gh"
  run "$VIBE" queue report --week
  [[ "$(cat "$XDG_STATE_HOME"/vibe/briefings/*.md)" == *"- PRs merged: unknown (gh failed)"* ]] || false
  run "$VIBE" queue report --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage: vibe queue report [--week]"* ]] || false
}

@test "gpu: the job queues its run, the queue runs it, a follow-up job finishes the task" {
  local r pid
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a gpu
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/run.out" 2>&1 &
  pid=$!
  for _ in $(seq 1 100); do
    [ "$(cat "$Q/01-a/status" 2>/dev/null)" != gpu ] || break
    sleep 0.1
  done
  [ "$(cat "$Q/01-a/status")" = gpu ]
  [ "$(cat "$Q/01-a/pr")" = "https://example.com/pull/1" ]
  "$REPO_ROOT/bin/gpu-queue" run --once
  wait "$pid"
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(cat "$Q/01-a/note")" = "GPU run exit 0 → 01-a-gpu" ]
  [ "$(cat "$r/.claude/worktrees/task-a/out.txt")" = trained ]
  grep -q '^follow=1$' "$Q/01-a-gpu/job"
  grep -q -- '- Exit: 0' "$Q/01-a-gpu/prompt.md"
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
}

@test "gpu: only inside a queue job; --help prints usage and queues nothing" {
  local r
  run env -u VIBE_JOB_DIR "$VIBE" queue gpu -- true
  [ "$status" -ne 0 ]
  [[ "$output" == *"inside a queue job"* ]] || false
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  VIBE_JOB_DIR="$Q/01-a" run "$VIBE" queue gpu --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"vibe queue status"* ]] || false
  [ ! -e "$Q/01-a/gpu-job" ]
}

@test "run: refuses a missing or unknown agent" {
  run "$VIBE" queue run --drain
  [ "$status" -ne 0 ]
  run "$VIBE" queue run --nope --drain
  [ "$status" -ne 0 ]
  [[ "$output" == *"vibe-job.sh is missing"* ]] || false
}

@test "unit: runner and GPU queue run only with role 'server', survive restarts; no report timers" {
  local u
  for u in vibe-queue gpu-queue; do
    grep -q '^ExecCondition=.*grep -qx server %h/.config/vibe/role' "$REPO_ROOT/claude/systemd/$u.service"
    grep -q '^KillMode=process$' "$REPO_ROOT/claude/systemd/$u.service"
    grep -q '^Restart=always$' "$REPO_ROOT/claude/systemd/$u.service"
  done
  grep -q '^ExecStart=%h/bin/vibe queue run --claude$' "$REPO_ROOT/claude/systemd/vibe-queue.service"
  grep -q '^ExecStart=%h/bin/gpu-queue run$' "$REPO_ROOT/claude/systemd/gpu-queue.service"
  [ -z "$(ls "$REPO_ROOT"/claude/systemd/*report* 2>/dev/null)" ]
}

@test "sweep: repos from the config in rank order, items joined, handoff next action, QUEUED" {
  local a b
  a="$(make_repo alpha)" b="$(make_repo beta)"
  printf '# Roadmap\n\n## Items\n\n- [ ] First item\n      done when x.\n- [x] Finished\n- [ ] Second item\n' >"$b/PROJECT_ROADMAP.md"
  git -C "$b" add PROJECT_ROADMAP.md
  git -C "$b" commit -q -m roadmap
  git -C "$b" push -q
  "$VIBE" start -C "$a" task >/dev/null 2>&1
  printf '## Next action\n\n_placeholder_\n\nRun the eval.\n\n## Blockers\n\nNone.\n' >"$a/.claude/worktrees/task/HANDOFF.md"
  printf 'beta   # first\n\n%s\n' "$a" >"$XDG_CONFIG_HOME/vibe/repos"
  mkjob 01-a "$a" task ok
  VIBE_ROOT="$BATS_TEST_TMPDIR" run "$SWEEP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# 1. beta"*"# 2. alpha"* ]] || false
  [[ "$output" == *"L5: - [ ] First item done when x."* ]] || false
  [[ "$output" == *"L8: - [ ] Second item"* ]] || false
  [[ "$output" != *"Finished"* ]] || false
  [[ "$output" == *"[task] DIRTY QUEUED"*"Run the eval."*"None."* ]] || false
  [[ "$output" != *"placeholder"* ]] || false
  echo "done" >"$Q/01-a/status"
  VIBE_ROOT="$BATS_TEST_TMPDIR" run "$SWEEP"
  [[ "$output" != *"QUEUED"* ]] || false
}

@test "sweep: reads the roadmap from origin, so an item a merged PR deleted stays gone" {
  local a o
  a="$(make_repo alpha)"
  printf '# Roadmap\n\n- [ ] Done elsewhere\n- [ ] Still open\n' >"$a/PROJECT_ROADMAP.md"
  git -C "$a" add PROJECT_ROADMAP.md
  git -C "$a" commit -q -m roadmap
  git -C "$a" push -q
  o="$(clone_repo alpha other)"
  printf '# Roadmap\n\n- [ ] Still open\n' >"$o/PROJECT_ROADMAP.md"
  git -C "$o" commit -q -am "feat: done elsewhere"
  git -C "$o" push -q
  run "$SWEEP" "$a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"read from: origin/main"*"L3: - [ ] Still open"* ]] || false
  [[ "$output" != *"Done elsewhere"* ]] || false
  grep -q "Done elsewhere" "$a/PROJECT_ROADMAP.md"
}

@test "sweep: arguments override the config; no repos at all fails" {
  local a
  a="$(make_repo alpha)"
  run "$SWEEP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no repos"* ]] || false
  run "$SWEEP" "$a" "$BATS_TEST_TMPDIR/nowhere"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# 1. alpha"*"no PROJECT_ROADMAP.md"*"# 2. nowhere"*"not a git repo"* ]] || false
}
