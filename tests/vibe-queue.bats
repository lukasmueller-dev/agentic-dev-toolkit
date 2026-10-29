#!/usr/bin/env bats
#
# vibe queue — the vibe queue in throwaway repos with a bare origin. A stub
# `claude` acts on the MODE line of its prompt; a stub `gh` records its calls
# under $STUBS. The stub prints a system/init event (session id sess-<job id>)
# unless $STUBS/no-init exists. The runner runs with --drain, so each test ends.

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
case "\$prompt" in
  "Run /code-review"*)
    echo "\$prompt" >>"$STUBS/claude.log"
    k=\$((\$(cat "$STUBS/review-count" 2>/dev/null || echo 0) + 1))
    echo "\$k" >"$STUBS/review-count"
    [ ! -f "$STUBS/review-sleep" ] || sleep 30
    if [ -f "$STUBS/review-\$k.json" ]; then cat "$STUBS/review-\$k.json"; else echo '{"type":"result","result":"no schema"}'; fi
    exit 0
    ;;
esac
[ -f "$STUBS/no-init" ] || echo '{"type":"system","subtype":"init","session_id":"sess-'"\${VIBE_JOB_DIR##*/}"'"}'
mode="\$(printf '%s\n' "\$prompt" | sed -n 's/^MODE=//p')"
case "\$prompt" in *"## GPU run finished"*) mode=ok ;; *"The time limit stopped"*) mode=handoff ;; *"A reviewer found problems"*) mode=fix ;; esac
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
  item)
    n="\$(sed -n 's/^item=//p' "\$VIBE_JOB_DIR/job")"
    cp "\$VIBE_JOB_DIR/lane-pr.md" "\$VIBE_JOB_DIR/seen-lane-pr.md" 2>/dev/null || true
    echo "\$n" >"\$n.txt" && git add "\$n.txt" && git commit -q -m "feat: \$n"
    printf 'feat: %s\n\n**Context:** ctx %s.\n**Changed:** %s.txt added.\n**Verify:** cat *.txt\n**Decisions/risks:** none\n\n<details>\n<summary>Details</summary>\n\nmore %s\n\n</details>\n' "\$n" "\$n" "\$n" "\$n" >"\$VIBE_JOB_DIR/pr.md"
    echo "done: \$n.txt added" >"\$VIBE_JOB_DIR/result"
    ;;
  itemwip)
    n="\$(sed -n 's/^item=//p' "\$VIBE_JOB_DIR/job")"
    echo "\$n" >"\$n.txt" && git add "\$n.txt" && git commit -q -m "feat: \$n"
    echo half >"\$n.wip"
    echo "blocked: \$n needs a decision" >"\$VIBE_JOB_DIR/result"
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
  gate)
    mkdir -p .vibe-jobs && echo 'touch hacked.txt' >.vibe-jobs/gate
    git add .vibe-jobs && git commit -q -m "feat: my own gate"
    git update-ref refs/remotes/origin/main HEAD
    echo "done: gate on the branch" >"\$VIBE_JOB_DIR/result"
    ;;
  cost)
    echo work >work.txt && git add work.txt && git commit -q -m "feat: work"
    echo '{"type":"rate_limit_event","rate_limit_info":{"unifiedWindows":{"five_hour":{"utilization":0.46,"resetsAt":1793269800,"status":"allowed"}}}}'
    echo '{"type":"result","subtype":"success","duration_ms":647191,"num_turns":40,"total_cost_usd":1.04}'
    echo "done: costed" >"\$VIBE_JOB_DIR/result"
    ;;
  blocked) echo "blocked: needs a decision" >"\$VIBE_JOB_DIR/result" ;;
  crash) exit 3 ;;
  oom) echo half >wip.txt && kill -9 \$\$ ;;
  silent) ;;
  sleep) sleep 30 ;;
  slow) echo half >wip.txt && sleep 30 ;;
  fix)
    if [ -f "$STUBS/fix-big" ]; then echo fixed >fix.txt && git add fix.txt && git commit -q -m "fix: review"; fi
    if [ -f "$STUBS/fix-md" ]; then echo note >>NOTES.md && git add NOTES.md && git commit -q -m "docs: review"; fi
    sed "s/@SHA@/\$(git rev-parse --short HEAD)/" "$STUBS/verdicts" >"\$VIBE_JOB_DIR/verdicts"
    ;;
  handoff)
    printf '## State\n\nwip.txt is half done.\n' >HANDOFF.md
    git add HANDOFF.md wip.txt && git commit -q -m "wip: handoff"
    echo "failed: out of time — wip.txt" >"\$VIBE_JOB_DIR/result"
    ;;
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
  stub_systemd_run "$STUBS"
  PATH="$STUBS:$PATH"
  export VIBE_TOOLKIT="$BATS_TEST_TMPDIR/no-toolkit" VIBE_QUEUE_POLL=0.2
  export GPU_QUEUE_DIR="$BATS_TEST_TMPDIR/gpu-queue" GPUQ_POLL=0.1
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  mkdir -p "$HOME/.config/vibe" && echo server >"$HOME/.config/vibe/role"
  Q="$XDG_STATE_HOME/vibe/queue"
  CONF="$XDG_CONFIG_HOME/vibe/queue.conf"
  mkdir -p "$Q" "${CONF%/*}"
  echo after= >"$CONF"
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
# slots N — the queue runs N agents at once; the review step stays off.
slots() { printf 'after=\nslots=%s\n' "$1" >"$CONF"; }
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

@test "session: the runner keeps the init event's session id; vibe-job.sh resumes a given one" {
  local r wt
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  drain
  [ "$(cat "$Q/01-a/session")" = sess-01-a ]
  wt="$(cat "$Q/01-a/worktree")"
  echo MODE=silent >"$BATS_TEST_TMPDIR/prompt.md"
  run bash "$REPO_ROOT/claude/vibe-job.sh" "$wt" proj-task-a sonnet "$BATS_TEST_TMPDIR/prompt.md" "" "$(cat "$Q/01-a/session")"
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$STUBS/claude.log" | grep -c -- '-p --model sonnet --resume sess-01-a --name proj-task-a')" = 1 ]
  [ "$(grep -c -- '--resume' "$STUBS/claude.log")" = 1 ]
}

@test "session: a log without an init event leaves no session file" {
  local r
  r="$(make_repo proj)"
  touch "$STUBS/no-init"
  mkjob 01-a "$r" task-a ok
  drain
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ ! -e "$Q/01-a/session" ]
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

@test "lane: 2 done jobs on one branch give one PR with the title and TL;DR of the latest item" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" lane-x item "lane=Fix two health items" item=alpha
  mkjob 02-b "$r" lane-x item "lane=Fix two health items" item=beta
  drain
  [ "$status" -eq 0 ]
  grep -q -- 'pr create --draft --base main --head lane-x --title feat: beta' "$STUBS/gh.log"
  [ "$(grep -c '^\*\*Context:\*\* Fix two health items$' "$Q/02-b/pr-body.md")" = 1 ]
  grep -q '^\*\*Changed:\*\* beta.txt added.$' "$Q/02-b/pr-body.md"
  run grep -c 'alpha.txt added' "$Q/02-b/pr-body.md"
  [ "$output" = 0 ]
  grep -q '^\*\*Verify:\*\* cat \*.txt$' "$Q/02-b/pr-body.md"
  grep -q '^\*\*Decisions/risks:\*\* none$' "$Q/02-b/pr-body.md"
  [ "$(grep -c '^<details>$' "$Q/02-b/pr-body.md")" = 2 ]
  grep -q '^more alpha$' "$Q/02-b/pr-body.md"
  grep -q '^_agent lane: 2/2 done_$' "$Q/02-b/pr-body.md"
}

@test "lane: a 3-item lane body has the TL;DR of the last done item, one <details> per item, 12 lines above the first" {
  local r
  r="$(make_repo proj)"
  slots 1
  touch "$STUBS/pr-exists"
  mkjob 01-a "$r" lane-x item "lane=Fix health" item=alpha
  mkjob 02-b "$r" lane-x blocked "lane=Fix health" item=beta
  mkjob 03-c "$r" lane-x item "lane=Fix health" item=gamma
  drain
  [ "$status" -eq 0 ]
  # the third item was handed the lane so far: alpha's TL;DR and beta out of the lane
  grep -q '^\*\*Changed:\*\* alpha.txt added.$' "$Q/03-c/seen-lane-pr.md"
  grep -q '^- beta → lane-x-beta$' "$Q/03-c/seen-lane-pr.md"
  grep -q '^\*\*Changed:\*\* gamma.txt added.$' "$Q/03-c/pr-body.md"
  grep -q '^- beta → lane-x-beta$' "$Q/03-c/pr-body.md"
  run grep -c 'alpha.txt added' "$Q/03-c/pr-body.md"
  [ "$output" = 0 ]
  [ "$(grep -c '^<details>$' "$Q/03-c/pr-body.md")" = 3 ]
  [ "$(awk '/^<details>$/ { exit } { n++ } END { print n }' "$Q/03-c/pr-body.md")" -le 12 ]
  grep -q '^_agent lane: 2/3 done_$' "$Q/03-c/pr-body.md"
  grep -qF -- "-F body=@$Q/03-c/pr-body.md -f title=feat: gamma" "$STUBS/gh.log"
}

@test "lane: a blocked item with work leaves the lane on <branch>-<item>; the lane branch stays at its start and the next item runs" {
  local r o="$BATS_TEST_TMPDIR/proj.git" start
  r="$(make_repo proj)"
  touch "$STUBS/pr-exists"
  mkjob 01-a "$r" lane-x item "lane=Fix health" item=alpha
  mkjob 02-b "$r" lane-x itemwip "lane=Fix health" item=beta
  mkjob 03-c "$r" lane-x item "lane=Fix health" item=gamma
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/02-b/status")" = blocked ]
  [ "$(cat "$Q/03-c/status")" = "done" ]
  start="$(git -C "$o" rev-parse lane-x~1)"
  [ "$(cat "$Q/02-b/start")" = "$start" ]
  [ "$(cat "$Q/02-b/side")" = lane-x-beta ]
  # the lane branch holds alpha and gamma, in a straight line
  [ "$(git -C "$o" log --format=%s lane-x | head -n 2 | tr '\n' ' ')" = "feat: gamma feat: alpha " ]
  run git -C "$o" cat-file -e lane-x:beta.txt
  [ "$status" -ne 0 ]
  # beta's work, with the WIP commit, sits on the side branch at the lane tip it started from
  [ "$(git -C "$o" rev-parse lane-x-beta~2)" = "$start" ]
  [ "$(git -C "$o" log -n 1 --format=%s lane-x-beta)" = "wip: beta (blocked)" ]
  git -C "$o" cat-file -e lane-x-beta:beta.txt
  git -C "$o" cat-file -e lane-x-beta:beta.wip
  run grep -c -- '--head lane-x-beta' "$STUBS/gh.log"
  [ "$output" = 0 ]
  grep -q '^- beta → lane-x-beta$' "$Q/03-c/pr-body.md"
}

@test "lane: an item that is blocked shows as <item> → <branch>-<item>; a job without lane= keeps its own body" {
  local r
  r="$(make_repo proj)"
  slots 1
  mkjob 01-a "$r" lane-x item "lane=Fix health" item=alpha
  mkjob 02-b "$r" lane-x blocked "lane=Fix health" item=beta
  mkjob 03-c "$r" solo ok
  drain
  [ "$status" -eq 0 ]
  grep -q '^\*\*Changed:\*\* alpha.txt added.$' "$Q/02-b/pr-body.md"
  grep -q '^- beta → lane-x-beta$' "$Q/02-b/pr-body.md"
  grep -q '^_agent lane: 1/2 done_$' "$Q/02-b/pr-body.md"
  grep -q '^\*\*Changed:\*\* work.txt added.$' "$Q/03-c/pr-body.md"
}

@test "lane: status prints one row per lane with its progress, and a row only for the item out of the lane" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" lane-x item "lane=Fix health" item=alpha
  mkjob 02-b "$r" lane-x itemwip "lane=Fix health" item=beta
  drain
  mkjob 03-c "$r" lane-x item "lane=Fix health" item=gamma
  mkjob 04-d "$r" solo ok
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(grep -c 'lane-x · ' <<<"$output")" = 1 ]
  [[ "$output" == *"  lane-x · 1/3 · gamma · https://example.com/pull/1"$'\n'"    Fix health"$'\n'* ]] || false
  [[ "$output" == *"    02-b  blocked  blocked: beta needs a decision → lane-x-beta"* ]] || false
  [ "$(grep -c '01-a\|03-c' <<<"$output")" = 0 ]
  [ "$(grep -c '04-d  queued' <<<"$output")" = 1 ]
}

@test "lane: the report holds the lane in one row, and the item out of the lane under Needs you" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" lane-x item "lane=Fix health" item=alpha
  mkjob 02-b "$r" lane-x itemwip "lane=Fix health" item=beta
  mkjob 03-c "$r" lane-x item "lane=Fix health" item=gamma
  drain
  [ "$status" -eq 0 ]
  run "$VIBE" queue report
  [ "$status" -eq 0 ]
  run cat "$XDG_STATE_HOME"/vibe/briefings/*.md
  [[ "$output" == *"### Needs you"*"| 02-b | blocked |  | blocked: beta needs a decision → lane-x-beta | [PR](https://example.com/pull/1) |"*"### PR ready"*"| lane-x | 2/3 | Fix health | - | [PR](https://example.com/pull/1) |"* ]] || false
  [ "$(grep -c '| 01-a \|| 03-c ' <<<"$output")" = 0 ]
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

@test "run: a job over its own time limit is stopped; without a session there is no handoff turn" {
  command -v timeout >/dev/null 2>&1 || skip "no timeout(1)"
  local r
  r="$(make_repo proj)"
  touch "$STUBS/no-init"
  mkjob 01-a "$r" task-a sleep timeout=1s
  drain
  [ "$(cat "$Q/01-a/status")" = timeout ]
  [ "$(cat "$Q/01-a/note")" = "stopped after 1s" ]
  [ "$(wc -l <"$STUBS/claude.log")" -eq 1 ]
}

@test "run: a job over its time limit gets one more turn that commits HANDOFF.md" {
  command -v timeout >/dev/null 2>&1 || skip "no timeout(1)"
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a slow timeout=1s
  drain
  [ "$(cat "$Q/01-a/status")" = timeout ]
  [ "$(cat "$Q/01-a/note")" = "failed: out of time — wip.txt" ]
  [ "$(git -C "$r/.claude/worktrees/task-a" status --porcelain)" = "" ]
  git -C "$BATS_TEST_TMPDIR/proj.git" show task-a:HANDOFF.md | grep -q 'wip.txt is half done'
  [ "$(tail -n 1 "$STUBS/claude.log" | grep -c -- '--resume sess-01-a .*--max-turns 5')" = 1 ]
  [ "$(grep -c -- '--max-turns' "$STUBS/claude.log")" = 1 ]
}

@test "memory: each agent runs in its own scope, capped at 100% ÷ slots; memory_max= overrides" {
  local r
  r="$(make_repo proj)"
  slots 2
  mkjob 01-a "$r" task-a ok
  drain
  [ "$status" -eq 0 ]
  [[ "$output" == *"memory cap per job: 50%"* ]] || false
  grep -q -- "^--user --scope --quiet --collect -p MemoryMax=50% -p MemorySwapMax=0 .*vibe-job.sh .*proj-task-a" "$STUBS/systemd-run.log"
  echo memory_max=6G >>"$CONF"
  mkjob 02-b "$r" task-b ok
  drain
  grep -q -- "-p MemoryMax=6G .*proj-task-b" "$STUBS/systemd-run.log"
}

@test "memory: a job killed before its time limit ends alone as failed; the other job runs on" {
  local r
  r="$(make_repo proj)"
  slots 2
  mkjob 01-a "$r" task-a oom
  mkjob 02-b "$r" task-b seq
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/01-a/note")" = "agent killed (SIGKILL): past its memory cap (50%), or oomd" ]
  [ "$(cat "$Q/02-b/status")" = "done" ]
  [ "$(cat "$STUBS/seq")" = "$(printf 'begin\nend')" ]
  [ "$(grep -c -- '--resume' "$STUBS/claude.log")" = 0 ]
}

@test "memory: without a systemd user manager the runner warns and runs jobs uncapped" {
  local r
  r="$(make_repo proj)"
  touch "$STUBS/no-systemd"
  mkjob 01-a "$r" task-a ok
  drain
  [ "$status" -eq 0 ]
  [[ "$output" == *"no systemd user manager — jobs run without a memory cap"* ]] || false
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ ! -e "$STUBS/systemd-run.log" ]
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

@test "gate: origin's default branch declares it; it runs in the worktree, exit code in the PR body and briefing" {
  local r f
  r="$(make_repo proj)"
  mkdir -p "$r/.vibe-jobs"
  # shellcheck disable=SC2016  # the gate expands $PWD, not the test
  printf 'echo "docker stage red in ${PWD##*/}"\ntest -f work.txt && exit 3\n' >"$r/.vibe-jobs/gate"
  git -C "$r" add .vibe-jobs && git -C "$r" commit -q -m "chore: gate" && git -C "$r" push -q origin main
  mkjob 01-a "$r" task-a ok
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(cat "$Q/01-a/gate")" = 3 ]
  grep -q '^docker stage red in task-a$' "$Q/01-a/gate.log"
  grep -qF '**Gate:** exit 3' "$Q/01-a/pr-body.md"
  grep -q '^docker stage red in task-a$' "$Q/01-a/pr-body.md"
  run "$VIBE" queue report
  f="$(ls "$XDG_STATE_HOME"/vibe/briefings/*.md)"
  run cat "$f"
  [[ "$output" == *"### Needs you"*"| 01-a | done | The repo lacks work.txt. | **gate exit 3** · work.txt added. |"*"[gate](file://$Q/01-a/gate.log) |"* ]] || false
  [[ "$output" != *"### PR ready"* ]] || false
  [[ "$output" == *"## 01-a — done · gate exit 3"*"docker stage red in task-a"* ]] || false
}

@test "gate: a gate on the job branch alone is ignored; no gate on origin runs as today" {
  local r f
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a gate
  mkjob 02-b "$r" task-b ok
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ ! -e "$r/.claude/worktrees/task-a/hacked.txt" ]
  [ ! -e "$Q/01-a/gate" ]
  [ ! -e "$Q/02-b/gate" ]
  run grep -c 'Gate' "$Q/01-a/pr-body.md" "$Q/02-b/pr-body.md"
  [ "$output" = "$(printf '%s:0\n%s:0' "$Q/01-a/pr-body.md" "$Q/02-b/pr-body.md")" ]
  run "$VIBE" queue report
  f="$(ls "$XDG_STATE_HOME"/vibe/briefings/*.md)"
  run cat "$f"
  [[ "$output" == *"### PR ready"*"| 02-b | done | The repo lacks work.txt. | work.txt added. | [PR](https://example.com/pull/1) |"* ]] || false
  [[ "$output" != *"gate exit"* && "$output" != *"gate.log"* ]] || false
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
  [ "$(grep -c -- '--resume' "$STUBS/claude.log")" = 0 ]
  date +%s >"$XDG_STATE_HOME/vibe/limit"
  touch "$STUBS/limit-reset"
  drain
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(cat "$Q/02-b/status")" = "done" ]
  [ "$(git -C "$BATS_TEST_TMPDIR/proj.git" show task-a:wip.txt)" = "half more" ]
  [ "$(grep -c -- '--resume' "$STUBS/claude.log")" = 1 ]
  [ "$(grep -- '--resume sess-01-a ' "$STUBS/claude.log" | grep -c proj-task-a)" = 1 ]
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

@test "status: short names, two lines per job, no text line without text" {
  local r
  r="$(make_repo proj)"
  mkjob 20261029-081414-proj-task-a "$r" task-a ok "context=Do task a."
  mkjob 02-b "$r" task-b ok
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 2 queued · 0 to review · 4 slots" ]
  grep -qx '  task-a  queued' <<<"$output"
  grep -qx '    Do task a.' <<<"$output"
  grep -qx '  02-b  queued' <<<"$output"
  [ "$(wc -l <<<"$output")" -eq 6 ]
}

# pandoc_stub OK|FAIL — a pandoc that prints a marker, or one that fails.
pandoc_stub() {
  if [ "$1" = OK ]; then
    printf '#!/bin/sh\ncat >/dev/null\necho "<p>PANDOC</p>"\n' >"$STUBS/pandoc"
  else
    printf '#!/bin/sh\nexit 1\n' >"$STUBS/pandoc"
  fi
  chmod +x "$STUBS/pandoc"
}

@test "page: the runner writes job cards with escaped text and the briefing through pandoc" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  pandoc_stub OK
  mkjob 20261029-081414-proj-task-a "$r" task-a blocked
  drain
  mkjob 20261029-081415-proj-task-b "$r" task-b ok 'context=<b>A & B</b>'
  "$VIBE" queue pause >/dev/null
  drain
  [ "$status" -eq 0 ]
  grep -qF '<div class="job s-blocked"><div class="top"><b>task-a</b><span class="pill">blocked</span>' "$f"
  grep -qx '<div class="repo"><h2>proj</h2>' "$f"
  [ "$(grep -A1 '<b>task-b</b>' "$f" | tail -n 1)" = '</div>' ]
  grep -qF '<b>task-b</b><span class="pill">queued</span></div><p>&lt;b&gt;A &amp; B&lt;/b&gt;</p>' "$f"
  grep -qF '<span class="chip"><b>1</b> queued</span>' "$f"
  grep -qF '<p>PANDOC</p>' "$f"
  run grep -c '<b>A &' "$f"
  [ "$output" = 0 ]
  [ ! -e "$f.tmp" ]
}

@test "page: with no working pandoc briefing and config are escaped Markdown in <pre>, file links as text" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  pandoc_stub FAIL
  export VIBE_ROOT="$BATS_TEST_TMPDIR"
  mkdir -p "$r/.vibe-jobs"
  printf -- '---\nschedule: weekly\nday: sun\noutput: pr\n---\n\nCheck.\n' >"$r/.vibe-jobs/health.md"
  echo proj >"${CONF%/*}/repos"
  mkjob 01-a "$r" task-a blocked
  mkdir -p "$Q/01-a" && echo report >"$Q/01-a/report.md"
  drain
  [ "$status" -eq 0 ]
  grep -q '^<pre># Vibe queue' "$f"
  grep -qF '| 01-a | blocked |' "$f"
  grep -q '^<pre>## Queue' "$f"
  grep -qF '| Slots | 4 |' "$f"
  grep -q '^| proj | health | weekly | sun | never | ' "$f"
  grep -qF 'fill-queue sweep (' "$f"
  run grep -c 'file:' "$f"
  [ "$output" = 0 ]
}

@test "page: a running card shows its last step and the last 10 from the log, escaped" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" pid runner i
  command -v jq >/dev/null || skip "no jq"
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a sleep
  {
    for i in 1 2 3 4 5 6 7 8 9 10 11; do
      printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"description":"step %s"}}]}}\n' "$i"
    done
    printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git status"}}]}}\n'
    printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/<y>.md"}}]}}\n'
    printf '{"type":"assistant","message":'
  } >"$Q/01-a/log"
  sleep 30 &
  pid=$!
  echo running >"$Q/01-a/status"
  echo "$pid" >"$Q/01-a/pid"
  "$VIBE" queue run --claude --drain >/dev/null 2>&1 &
  runner=$!
  for i in $(seq 100); do
    if grep -q '<details>' "$f" 2>/dev/null; then break; fi
    sleep 0.1
  done
  kill "$pid"
  wait "$runner" || true
  grep -q '<details><summary>[0-9][0-9]:[0-9][0-9] · Read /x/&lt;y&gt;.md</summary><ol><li>step 4</li>' "$f"
  grep -qF '<li>Bash git status</li>' "$f"
  [ "$(grep -o '<li>' "$f" | wc -l)" -eq 10 ]
}

@test "page: a lane is one card with its progress, next item and the item out of the lane; a done job shows its cost" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  pandoc_stub OK
  mkjob 01-a "$r" lane-x item "lane=Fix health" item=alpha
  mkjob 02-b "$r" lane-x itemwip "lane=Fix health" item=beta
  mkjob 05-e "$r" solo ok
  drain
  mkjob 03-c "$r" lane-x item "lane=Fix health" item=gamma
  printf '{"type":"result","total_cost_usd":1.5,"num_turns":7,"duration_ms":120000}\n' >"$Q/05-e/log"
  "$VIBE" queue pause >/dev/null
  drain
  [ "$status" -eq 0 ]
  grep -qF '<div class="job s-blocked"><div class="top"><b>lane-x</b><span class="pill">1/3</span></div><p>Fix health' "$f"
  grep -qF '<p>next: gamma</p><p>02-b  blocked  blocked: beta needs a decision → lane-x-beta</p>' "$f"
  run grep -c '<b>01-a</b>\|<b>03-c</b>' "$f"
  [ "$output" = 0 ]
  grep -qF '<details><summary>3 jobs</summary><ul><li><b>alpha</b> done · done: alpha.txt added</li><li><b>beta</b> blocked · blocked: beta needs a decision → lane-x-beta</li><li><b>gamma</b> queued</li></ul></details>' "$f"
  # shellcheck disable=SC2016  # a literal $ in the expected text
  grep -qF '<p class="stats">≈$1.50 API · 7 turns · 2m</p>' "$f"
}

@test "page: a failed write warns and the runner goes on" {
  local r
  r="$(make_repo proj)"
  mkdir -p "$XDG_STATE_HOME/vibe"
  echo file >"$XDG_STATE_HOME/vibe/web"
  mkjob 01-a "$r" task-a ok
  drain
  [ "$status" -eq 0 ]
  [[ "$output" == *"queue page not written"* ]] || false
  [ "$(cat "$Q/01-a/status")" = "done" ]
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

# two_findings — the stub reviewer's first answer: two findings.
two_findings() {
  printf '%s' '{"type":"result","structured_output":{"findings":[{"file":"work.txt","line":1,"summary":"empty file","failure_scenario":"reads nothing"},{"file":"x.sh","summary":"quote it","failure_scenario":"word split"}]}}' >"$STUBS/review-1.json"
}

@test "review: findings → the job's session fixes them, a second round, one PR body with both rounds" {
  local r b
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok after=review
  two_findings
  printf '%s' '{"type":"result","structured_output":{"findings":[]}}' >"$STUBS/review-2.json"
  printf '1=fixed @SHA@\n2=rejected not reachable\n' >"$STUBS/verdicts"
  touch "$STUBS/fix-big"
  drain
  [ "$status" -eq 0 ]
  for d in 01-a 01-a-review1 01-a-review2; do [ "$(cat "$Q/$d/status")" = "done" ]; done
  [ ! -e "$Q/01-a/pr" ]
  [ "$(grep -c 'pr create' "$STUBS/gh.log")" = 1 ]
  [ "$(cat "$Q/01-a-review2/pr")" = "https://example.com/pull/1" ]
  [ "$(grep -c '^-p ' "$STUBS/claude.log")" = 4 ]
  [ "$(grep -c '^Run /code-review high origin/main\.\.\.HEAD\. ' "$STUBS/claude.log")" = 2 ]
  grep -q -- '--disallowedTools Edit,Write,NotebookEdit' "$STUBS/claude.log"
  grep -q -- '--output-format json --json-schema' "$STUBS/claude.log"
  [ "$(grep -c -- '--resume sess-01-a ' "$STUBS/claude.log")" = 1 ]
  [ "$(git -C "$BATS_TEST_TMPDIR/proj.git" show task-a:fix.txt)" = fixed ]
  grep -q '^follow=1$' "$Q/01-a-review1/job"
  grep -q '^review=2$' "$Q/01-a-review2/job"
  b="$(cat "$Q/01-a-review2/pr-body.md")"
  grep -q '^\*\*Review:\*\* R1: 2 findings → 1 fixed, 1 rejected · R2: 0 findings$' "$Q/01-a-review2/pr-body.md"
  # shellcheck disable=SC2016 # the backticks are literal
  [[ "$b" == *"**Review:**"*"<details>"*'1. `work.txt:1` — empty file Failure: reads nothing → fixed '*'2. `x.sh:?` — quote it Failure: word split → rejected not reachable'*"**R2** — 0 findings"*"</details>"* ]] || false
  [[ "$b" == *"**Changed:** work.txt added."* ]] || false
}

@test "review: a trivial fix ends the review; open findings stay; review_model and review_level reach the reviewer" {
  local r
  r="$(make_repo proj)"
  echo review_level=low >>"$CONF"
  mkjob 01-a "$r" task-a ok after=review review_model=opus
  two_findings
  printf '1=fixed @SHA@\n2=open\n' >"$STUBS/verdicts"
  touch "$STUBS/fix-md"
  drain
  [ ! -e "$Q/01-a-review2" ]
  [ "$(cat "$Q/01-a-review1/note")" = "R1: 2 findings → 1 fixed, 1 open" ]
  grep -q '^\*\*Review:\*\* R1: 2 findings → 1 fixed, 1 open$' "$Q/01-a-review1/pr-body.md"
  grep -q -- '-p --model opus --name proj-task-a-review1 ' "$STUBS/claude.log"
  grep -q '^Run /code-review low origin/main\.\.\.HEAD\. ' "$STUBS/claude.log"
}

@test "review: review_rounds caps the rounds; review_trivial sets the bar" {
  local r
  r="$(make_repo proj)"
  printf 'review_rounds=1\n' >>"$CONF"
  mkjob 01-a "$r" task-a ok after=review
  two_findings
  printf '1=fixed @SHA@\n2=fixed @SHA@\n' >"$STUBS/verdicts"
  touch "$STUBS/fix-big"
  drain
  [ ! -e "$Q/01-a-review2" ]
  grep -q '^\*\*Review:\*\* R1: 2 findings → 2 fixed$' "$Q/01-a-review1/pr-body.md"
  rm -f "$STUBS/review-count" "$STUBS/fix-big"
  printf 'after=\nreview_trivial=0\n' >"$CONF"
  touch "$STUBS/fix-md"
  mkjob 02-b "$r" task-b ok after=review
  drain
  [ -d "$Q/02-b-review2" ]
}

@test "review: on by default; no structured_output → the PR opens with 'R1: review failed'" {
  local r b
  r="$(make_repo proj)"
  : >"$CONF"
  mkjob 01-a "$r" task-a ok
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a-review1/note")" = "R1: review failed" ]
  [ "$(grep -c '^-p ' "$STUBS/claude.log")" = 2 ]
  [ "$(cat "$Q/01-a-review1/pr")" = "https://example.com/pull/1" ]
  grep -q -- 'pr create --draft --base main --head task-a --title feat: queue work' "$STUBS/gh.log"
  b="$(cat "$Q/01-a-review1/pr-body.md")"
  [[ "$b" == *"**Review:** R1: review failed"*"<details>"*"**R1** — review failed"*"</details>"* ]] || false
  git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/task-a
}

@test "review: a reviewer past review_timeout → 'R1: timeout', the PR opens" {
  command -v timeout >/dev/null 2>&1 || skip "no timeout(1)"
  local r
  r="$(make_repo proj)"
  printf 'review_timeout=1s\n' >>"$CONF"
  touch "$STUBS/review-sleep"
  mkjob 01-a "$r" task-a ok after=review
  drain
  [ "$(cat "$Q/01-a-review1/status")" = "done" ]
  [ "$(cat "$Q/01-a-review1/note")" = "R1: timeout" ]
  [ "$(cat "$Q/01-a-review1/pr")" = "https://example.com/pull/1" ]
}

@test "review: none with after= empty (job over queue.conf), without commits, or for a report-only job" {
  local r
  r="$(make_repo proj)"
  echo after=review >"$CONF"
  mkjob 01-a "$r" task-a ok after=
  mkjob 02-b "$r" task-b seq after=review
  mkjob 03-c "$r" task-c ok after=review output=report
  drain
  [ "$(find "$Q" -mindepth 1 -maxdepth 1 | wc -l)" -eq 3 ]
  [ "$(cat "$Q/01-a/pr")" = "https://example.com/pull/1" ]
  [ "$(cat "$Q/03-c/pr")" = "https://example.com/pull/1" ]
  [ "$(grep -c '^Run /code-review' "$STUBS/claude.log" || true)" = 0 ]
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
