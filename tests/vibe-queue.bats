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
case "\$prompt" in *"## GPU run finished"*) mode=ok && { [ -e "\${VIBE_JOB_DIR%-gpu}/ended" ] && echo ended || echo open; } >"$STUBS/parent-at-follow" ;; *"The time limit stopped"*) mode=handoff ;; *"A reviewer found problems"*) mode=fix ;; esac
case "\$mode" in
  gpu)
    echo code >code.txt && git add code.txt && git commit -q -m "feat: train script"
    "$VIBE" queue gpu -- sh -c '[ ! -f $STUBS/gpu-sleep ] || sleep 30; echo trained >out.txt'
    echo "queued: training" >"\$VIBE_JOB_DIR/result"
    ;;
  gpurace)
    echo code >code.txt && git add code.txt && git commit -q -m "feat: train script"
    "$VIBE" queue gpu -- true
    GPUQ_EXIT=0 "$VIBE" queue follow "\$VIBE_JOB_DIR"
    sleep 1
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
  "pr list")
    case "\$*" in
      *headRefName*) cat "$STUBS/prs" 2>/dev/null ;;
      *) [ ! -f "$STUBS/pr-exists" ] || echo "https://example.com/pull/9" ;;
    esac
    ;;
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

# mkfeature NAME MEMBER... — the feature file $BATS_TEST_TMPDIR/NAME.md; MEMBER: "<repo> <branch> [<pr>]".
mkfeature() {
  local name="$1" m
  shift
  {
    printf '# Feature — %s\n\n**Context:** The gamepad drives the robot.\n**Human test:** drive it on the gantry\n\n## Members\n\n_One line per member._\n\n' "$name"
    for m in "$@"; do echo "- $m"; done
    printf '\n## Decisions\n\n- Sticks as [lx, ly, rx, ry]: one order in every repo.\n\n'
    printf '## Contract\n\n| Interface | Owner | Copies |\n| --- | --- | --- |\n| /robot_sim/sticks | bridge | bridge:node.py, cmdr:ros.py |\n'
  } >"$BATS_TEST_TMPDIR/$name.md"
  echo "$BATS_TEST_TMPDIR/$name.md"
}
# addfeature NAME MEMBER... — mkfeature, then `vibe feature add`.
addfeature() { "$VIBE" feature add "$(mkfeature "$@")" >/dev/null; }
# putfeature NAME MEMBER... — mkfeature, straight into the features dir: no branch checks.
putfeature() {
  mkdir -p "$XDG_STATE_HOME/vibe/features"
  cp "$(mkfeature "$@")" "$XDG_STATE_HOME/vibe/features/$1.md"
}

@test "feature: a member job's prompt ends with the feature block, once along a SPEC chain; another branch gets none" {
  local r w
  r="$(make_repo bridge)"
  "$VIBE" start -C "$r" sticks >/dev/null 2>&1
  w="$r/.claude/worktrees/sticks"
  printf '# Spec\n\n- [ ] one\n- [ ] two\n' >"$w/SPEC.md"
  git -C "$w" add SPEC.md
  git -C "$w" commit -q -m "docs(spec): x"
  putfeature teleop "$r sticks" "$BATS_TEST_TMPDIR/cmdr gamepad"
  mkjob 01-a "$r" sticks milestone
  mkjob 02-b "$r" solo ok
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  grep -qx '## Feature' "$Q/01-a/prompt.md"
  # shellcheck disable=SC2016  # literal backticks in the expected text
  grep -qF 'member of the feature `teleop`: The gamepad drives the robot.' "$Q/01-a/prompt.md"
  grep -qF "Read the feature file first: $XDG_STATE_HOME/vibe/features/teleop.md." "$Q/01-a/prompt.md"
  grep -qF 'blocked: contract <interface>: <the change you propose>' "$Q/01-a/prompt.md"
  local next
  next="$(find "$Q" -mindepth 1 -maxdepth 1 -name '*-bridge-sticks')"
  [ -n "$next" ]
  [ "$(grep -c '^## Feature$' "$next/prompt.md")" = 1 ]
  run grep -c '^## Feature$' "$Q/02-b/prompt.md"
  [ "$output" = 0 ]
}

@test "feature: a member PR body has the Feature line below its TL;DR and the decisions and contract above its footer; the file gets the PR" {
  local r F="$XDG_STATE_HOME/vibe/features"
  r="$(make_repo bridge)"
  putfeature teleop "$r sticks" "$BATS_TEST_TMPDIR/cmdr gamepad https://example.com/pull/24" "$BATS_TEST_TMPDIR/vla node"
  mkjob 01-a "$r" sticks item "lane=Sticks in the sim" item=alpha
  mkjob 02-b "$r" solo ok
  drain
  [ "$status" -eq 0 ]
  run cat "$Q/01-a/pr-body.md"
  [[ "$output" == *$'**Decisions/risks:** none\n**Feature:** teleop — merges together with [cmdr#24](https://example.com/pull/24), vla:node\n'* ]] || false
  [[ "$output" == *$'<summary>Feature teleop: decisions and contract</summary>\n\n- Sticks as [lx, ly, rx, ry]: one order in every repo.\n\n| Interface | Owner | Copies |'* ]] || false
  [[ "$output" == *$'| /robot_sim/sticks | bridge | bridge:node.py, cmdr:ros.py |\n\n</details>\n\n---\n_agent lane: 1/1 done_'* ]] || false
  [ "$(awk '/^<details>$/ { exit } { n++ } END { print n }' "$Q/01-a/pr-body.md")" -le 12 ]
  grep -qx -- "- $r sticks https://example.com/pull/1" "$F/teleop.md"
  grep -qx -- "- $BATS_TEST_TMPDIR/vla node" "$F/teleop.md"
  run grep -c 'Feature' "$Q/02-b/pr-body.md"
  [ "$output" = 0 ]
}

@test "feature: a body without a Decisions/risks line gets the Feature line on top" {
  local r
  r="$(make_repo bridge)"
  putfeature teleop "$r sticks" "$BATS_TEST_TMPDIR/cmdr gamepad"
  mkjob 01-a "$r" sticks ok
  drain
  [ "$status" -eq 0 ]
  [ "$(grep -m 1 . "$Q/01-a/pr-body.md")" = "**Feature:** teleop — merges together with cmdr:gamepad" ]
  [ "$(grep -A 2 '^\*\*Feature:\*\*' "$Q/01-a/pr-body.md" | sed -n 3p)" = "**Context:** The repo lacks work.txt." ]
  grep -qx '</details>' "$Q/01-a/pr-body.md"
}

@test "feature: status shows the Features group first, a line per member; member jobs leave their repo groups" {
  local r1 r2
  r1="$(make_repo bridge)" r2="$(make_repo cmdr)"
  putfeature teleop "$r1 sticks" "$r2 gamepad https://example.com/pull/24" "$BATS_TEST_TMPDIR/vla node"
  mkjob 01-a "$r1" sticks ok
  mkjob 02-b "$r2" gamepad blocked
  mkjob 03-c "$r1" solo ok
  drain
  [ "$status" -eq 0 ]
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\nFeatures\n  teleop · 1/3 · needs you\n    The gamepad drives the robot.\n    bridge · sticks  done  https://example.com/pull/1\n    cmdr · gamepad  blocked  blocked: needs a decision\n    vla · node  no PR\n\nbridge\n  03-c  done\n'* ]] || false
  [ "$(grep -c '01-a\|02-b\|^cmdr$' <<<"$output")" = 0 ]
}

@test "feature: the pill is needs you, then running, queued, your test, merge" {
  local F="$XDG_STATE_HOME/vibe/features"
  putfeature teleop "$BATS_TEST_TMPDIR/bridge sticks" "$BATS_TEST_TMPDIR/cmdr gamepad"
  mkjob 01-a "$BATS_TEST_TMPDIR/bridge" sticks ok
  mkjob 02-b "$BATS_TEST_TMPDIR/cmdr" gamepad ok
  echo running >"$Q/01-a/status"
  echo failed >"$Q/02-b/status"
  [ "$("$VIBE" queue status | grep -c '^  teleop · 0/2 · needs you$')" = 1 ]
  echo "done" >"$Q/02-b/status"
  echo https://example.com/pull/2 >"$Q/02-b/pr"
  [ "$("$VIBE" queue status | grep -c '^  teleop · 1/2 · running$')" = 1 ]
  echo queued >"$Q/01-a/status"
  [ "$("$VIBE" queue status | grep -c '^  teleop · 1/2 · queued$')" = 1 ]
  echo "done" >"$Q/01-a/status"
  [ "$("$VIBE" queue status | grep -c '^  teleop · 1/2 · needs you$')" = 1 ]
  echo https://example.com/pull/1 >"$Q/01-a/pr"
  [ "$("$VIBE" queue status | grep -c '^  teleop · 2/2 · your test$')" = 1 ]
  "$VIBE" feature ready teleop >/dev/null
  [ "$("$VIBE" queue status | grep -c '^  teleop · 2/2 · merge$')" = 1 ]
  "$VIBE" queue hold 01-a test it on the gantry >/dev/null
  [ "$("$VIBE" queue status | grep -c '^    bridge · sticks  held  test it on the gantry$')" = 1 ]
  [ -f "$F/teleop.ready" ]
}

@test "feature: a done member job with a failed gate needs you" {
  putfeature teleop "$BATS_TEST_TMPDIR/bridge sticks" "$BATS_TEST_TMPDIR/cmdr gamepad"
  mkjob 01-a "$BATS_TEST_TMPDIR/bridge" sticks ok
  mkjob 02-b "$BATS_TEST_TMPDIR/cmdr" gamepad ok
  echo "done" >"$Q/01-a/status"
  echo "done" >"$Q/02-b/status"
  echo https://example.com/pull/1 >"$Q/01-a/pr"
  echo https://example.com/pull/2 >"$Q/02-b/pr"
  echo 3 >"$Q/01-a/gate"
  run "$VIBE" queue status
  [[ "$output" == *$'\n  teleop · 1/2 · needs you\n'*$'\n    bridge · sticks  gate  gate exit 3\n'* ]] || false
  echo 0 >"$Q/01-a/gate"
  [ "$("$VIBE" queue status | grep -c '^  teleop · 2/2 · your test$')" = 1 ]
}

@test "page: a feature is one card on top; one click unpacks a lane card, a job card and a card with no job" {
  local r1 r2 f="$XDG_STATE_HOME/vibe/web/index.html"
  r1="$(make_repo bridge)" r2="$(make_repo cmdr)"
  pandoc_stub OK
  putfeature teleop "$r1 lane-x" "$r2 gamepad" "$BATS_TEST_TMPDIR/vla node https://example.com/pull/7"
  mkjob 01-a "$r1" lane-x item "lane=Sticks" item=alpha
  mkjob 02-b "$r1" lane-x item "lane=Sticks" item=beta
  mkjob 03-c "$r2" gamepad ok
  drain
  "$VIBE" queue pause >/dev/null
  drain
  [ "$status" -eq 0 ]
  grep -qF '<div class="repo"><h2>Features</h2>' "$f"
  grep -qF '<div class="job lane feature s-held"><div class="top"><b>teleop · 3/3</b><span class="pill">your test</span></div><p>The gamepad drives the robot.</p><div class="jacts" data-feature="teleop"><button data-act="feature-ready" data-confirm title="Your human test passed: mark every member PR ready">Test passed: ready</button></div><details class="stack"><summary>3 branches</summary>' "$f"
  grep -qF '<div class="job lane s-done"><div class="top"><b>bridge · lane-x</b><span class="pill">2/2</span></div><p>Sticks <a href="https://example.com/pull/1">PR</a></p>' "$f"
  grep -qF '<div class="job s-done"><div class="top"><b>cmdr · gamepad</b><span class="pill">done</span></div><p>done: work.txt added <a href="https://example.com/pull/1">PR</a></p>' "$f"
  grep -qF '<div class="job s-done"><div class="top"><b>vla · node</b><span class="pill">no job</span></div><p> <a href="https://example.com/pull/7">PR</a></p></div></details></div>' "$f"
  run grep -c '<h2>bridge</h2>\|<h2>cmdr</h2>' "$f"
  [ "$output" = 0 ]
}

@test "report: a Features table before the repos; a done member job leaves the repo tables, a blocked one stays" {
  local r1 r2 F="$XDG_STATE_HOME/vibe/features"
  r1="$(make_repo bridge)" r2="$(make_repo cmdr)"
  putfeature teleop "$r1 sticks" "$r2 gamepad https://example.com/pull/24" "$BATS_TEST_TMPDIR/vla node"
  mkjob 01-a "$r1" sticks ok
  mkjob 02-b "$r2" gamepad blocked
  mkjob 03-c "$r1" solo ok
  drain
  [ "$status" -eq 0 ]
  run "$VIBE" queue report
  [ "$status" -eq 0 ]
  run cat "$XDG_STATE_HOME"/vibe/briefings/*.md
  [[ "$output" == *"## Features"*"| teleop | needs you | 1/3 | The gamepad drives the robot. | [bridge#1](https://example.com/pull/1) done · [cmdr#24](https://example.com/pull/24) blocked · vla:node no PR | [file](file://$F/teleop.md) |"*"## bridge"* ]] || false
  [[ "$output" == *"## cmdr"*"### Needs you"*"| 02-b | blocked |"* ]] || false
  [ "$(grep -c '| 01-a ' <<<"$output")" = 0 ]
  [ "$(grep -c '| 03-c ' <<<"$output")" = 1 ]
}

@test "feature add: copies the file, fills in the open PRs, refuses a second add" {
  local r1 r2 f F="$XDG_STATE_HOME/vibe/features"
  r1="$(make_repo bridge)" r2="$(make_repo cmdr)"
  git -C "$r1" branch sticks
  git -C "$r2" push -q origin main:gamepad
  git -C "$r2" fetch -q origin
  printf 'gamepad\thttps://example.com/pull/24\n' >"$STUBS/prs"
  f="$(mkfeature teleop "$r1 sticks" "$r2 gamepad")"
  run "$VIBE" feature add "$f"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmdr · gamepad · https://example.com/pull/24"* ]] || false
  [[ "$output" == *"feature teleop: 2 members → $F/teleop.md" ]] || false
  grep -qx -- "- $r1 sticks" "$F/teleop.md"
  grep -qx -- "- $r2 gamepad https://example.com/pull/24" "$F/teleop.md"
  grep -qx '| /robot_sim/sticks | bridge | bridge:node.py, cmdr:ros.py |' "$F/teleop.md"
  [ -f "$f" ]
  run "$VIBE" feature add "$f"
  [ "$status" -ne 0 ]
  [[ "$output" == *"feature 'teleop' exists"* ]] || false
}

@test "feature add: refuses a missing branch, one member, a member of another feature, a twice-listed member, a name that is no slug" {
  local r1 r2 F="$XDG_STATE_HOME/vibe/features"
  r1="$(make_repo bridge)" r2="$(make_repo cmdr)"
  git -C "$r1" branch sticks
  git -C "$r2" branch gamepad
  run "$VIBE" feature add "$(mkfeature nope "$r1 sticks" "$r2 missing")"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no branch 'missing' in $r2"* ]] || false
  run "$VIBE" feature add "$(mkfeature solo "$r1 sticks")"
  [ "$status" -ne 0 ]
  [[ "$output" == *"2 or more"* ]] || false
  run "$VIBE" feature add "$(mkfeature twice "$r1 sticks" "$r1/ sticks")"
  [ "$status" -ne 0 ]
  [[ "$output" == *"listed twice"* ]] || false
  addfeature teleop "$r1 sticks" "$r2 gamepad"
  run "$VIBE" feature add "$(mkfeature other "$r1 main" "$r2/ gamepad")"
  [ "$status" -ne 0 ]
  [[ "$output" == *"cmdr gamepad is a member of feature 'teleop'"* ]] || false
  cp "$(mkfeature x "$r1 main" "$r2 main")" "$BATS_TEST_TMPDIR/Tele Op.md"
  run "$VIBE" feature add "$BATS_TEST_TMPDIR/Tele Op.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"is not a slug"* ]] || false
  [ "$(find "$F" -type f | wc -l | tr -d ' ')" = 1 ]
}

@test "feature ready and archive: the marker, then both files under archive/<YYYY-MM>/features; a client refuses both" {
  local r1 r2 F="$XDG_STATE_HOME/vibe/features" A
  A="$XDG_STATE_HOME/vibe/archive/$(date +%Y-%m)/features"
  r1="$(make_repo bridge)" r2="$(make_repo cmdr)"
  git -C "$r1" branch sticks
  git -C "$r2" branch gamepad
  addfeature teleop "$r1 sticks" "$r2 gamepad"
  run "$VIBE" feature ready nope
  [ "$status" -ne 0 ]
  run "$VIBE" feature ready teleop
  [ "$status" -eq 0 ]
  [ -s "$F/teleop.ready" ]
  run "$VIBE" feature archive teleop
  [ "$status" -eq 0 ]
  [ -f "$A/teleop.md" ]
  [ -f "$A/teleop.ready" ]
  [ ! -e "$F/teleop.md" ]
  echo 'client nohost' >"$HOME/.config/vibe/role"
  run "$VIBE" feature ready teleop
  [ "$status" -ne 0 ]
  [[ "$output" == *"the queue runs on the server"* ]] || false
}

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

@test "run: both runners pass --add-dir \"\$VIBE_JOB_DIR\"; the job settings fence the file tools" {
  local r wt
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  drain
  [ "$status" -eq 0 ]
  grep -q -- "--add-dir $Q/01-a " "$STUBS/claude.log"
  wt="$(cat "$Q/01-a/worktree")"
  : >"$STUBS/claude.log"
  VIBE_JOB_DIR="$Q/01-a-review1" run bash "$REPO_ROOT/claude/vibe-review.sh" "$wt" proj-task-a-review1 sonnet high main
  [ "$status" -eq 0 ]
  grep -q -- "--add-dir $Q/01-a-review1 " "$STUBS/claude.log"
  echo MODE=silent >"$BATS_TEST_TMPDIR/prompt.md"
  run env -u VIBE_JOB_DIR bash "$REPO_ROOT/claude/vibe-job.sh" "$wt" proj-task-a sonnet "$BATS_TEST_TMPDIR/prompt.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"VIBE_JOB_DIR"* ]] || false
  jq -e '.permissions.blockWritesOutsideWorkingDirectories == true' "$REPO_ROOT/claude/vibe-job-settings.json"
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
  VIBE_JOB_DIR="$Q/01-a" run bash "$REPO_ROOT/claude/vibe-job.sh" "$wt" proj-task-a sonnet "$BATS_TEST_TMPDIR/prompt.md" "" "$(cat "$Q/01-a/session")"
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

@test "run: a relative core.hooksPath runs no hook of the job's tree on the runner's push" {
  local r m="$BATS_TEST_TMPDIR/hooked"
  r="$(make_repo proj)"
  hook_files "$r" "$m" pre-push
  git -C "$r" config core.hooksPath .githooks
  mkjob 01-a "$r" task-a ok
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ -n "$(git -C "$r" ls-remote origin refs/heads/task-a)" ]
  [ ! -e "$m" ]
}

@test "run: the runner does not push a git-lfs tree with hooks off" {
  local r lfs="$BATS_TEST_TMPDIR/lfs"
  r="$(make_repo proj)"
  echo '*.bin filter=lfs diff=lfs merge=lfs -text' >"$r/.gitattributes"
  git -C "$r" add .gitattributes && git -C "$r" commit -q -m "chore: lfs" && git -C "$r" push -q origin main
  mkdir -p "$lfs" && printf '#!/bin/sh\n' >"$lfs/git-lfs" && chmod +x "$lfs/git-lfs"
  mkjob 01-a "$r" task-a ok
  PATH="$lfs:$PATH" drain
  [ "$(cat "$Q/01-a/pr")" = "push failed (git-lfs: push by hand)" ]
  [ -z "$(git -C "$r" ls-remote origin refs/heads/task-a)" ]
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

@test "run: a relative core.hooksPath runs no post-checkout hook when a job resumes a branch whose worktree is gone" {
  local r m="$BATS_TEST_TMPDIR/hooked"
  r="$(make_repo proj)"
  hook_files "$r" "$m" post-checkout
  git -C "$r" push -q origin main:refs/heads/task-a
  git -C "$r" branch task-b main
  git -C "$r" config core.hooksPath .githooks
  mkjob 01-a "$r" task-a ok
  mkjob 02-b "$r" task-b ok
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(cat "$Q/02-b/status")" = "done" ]
  [ ! -e "$m" ]
}

@test "lane: a relative core.hooksPath runs no hook of the job's tree when a blocked item leaves the lane" {
  local r m="$BATS_TEST_TMPDIR/hooked"
  r="$(make_repo proj)"
  hook_files "$r" "$m" pre-push
  git -C "$r" config core.hooksPath .githooks
  mkjob 01-a "$r" lane-x itemwip "lane=Fix health" item=beta
  drain
  [ "$(cat "$Q/01-a/status")" = blocked ]
  [ -n "$(git -C "$r" ls-remote origin refs/heads/lane-x-beta)" ]
  [ ! -e "$m" ]
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

@test "run: skips a dirty worktree, fails a bad branch and a missing repo" {
  local r
  r="$(make_repo proj)"
  "$VIBE" start -C "$r" busy >/dev/null 2>&1
  echo wip >"$r/.claude/worktrees/busy/wip.txt"
  mkjob 01-a "$r" busy ok
  mkjob 02-b "$r" main ok
  mkjob 03-c "$BATS_TEST_TMPDIR/nowhere" task-c ok
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = skipped ]
  [[ "$(cat "$Q/01-a/note")" == *"uncommitted changes"* ]] || false
  [ "$(cat "$Q/02-b/status")" = failed ]
  [ "$(cat "$Q/03-c/status")" = failed ]
  [ ! -e "$STUBS/claude.log" ]
}

# died_job ID REPO BRANCH — a job whose process died mid-run: running, a dead pid, a dirty worktree.
died_job() {
  mkjob "$1" "$2" "$3" ok
  "$VIBE" start -C "$2" "$3" >/dev/null 2>&1
  echo half >"$2/.claude/worktrees/$3/wip.txt"
  echo "$2/.claude/worktrees/$3" >"$Q/$1/worktree"
  echo running >"$Q/$1/status"
  echo 999999 >"$Q/$1/pid"
}

@test "died: a job whose process died is queued again and runs in its own dirty worktree" {
  local r
  r="$(make_repo proj)"
  died_job 01-a "$r" task-a
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ -s "$Q/01-a/requeued" ]
  [ "$(grep -c proj-task-a "$STUBS/claude.log")" = 1 ]
  [ "$(cat "$r/.claude/worktrees/task-a/wip.txt")" = half ]
}

@test "died: a job that dies a second time ends as failed and does not run" {
  local r
  r="$(make_repo proj)"
  died_job 01-a "$r" task-a
  date '+%F %T' >"$Q/01-a/requeued"
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/01-a/note")" = "job process died twice" ]
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

@test "conf: sets one key in queue.conf; refuses an unknown key and a bad value" {
  run "$VIBE" queue conf slots=2
  [ "$status" -eq 0 ]
  run "$VIBE" queue conf slots=3
  [ "$status" -eq 0 ]
  [ "$(grep -c '^slots=' "$CONF")" = 1 ]
  grep -qx slots=3 "$CONF"
  grep -qx after= "$CONF"
  run "$VIBE" queue conf web_login=evil@example.com
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown key 'web_login'"* ]] || false
  for v in slots=0 slots=x after=maybe review_level=huge memory_max=-1 slots; do
    run "$VIBE" queue conf "$v"
    [ "$status" -ne 0 ]
  done
  run "$VIBE" queue conf review_level=max
  [ "$status" -eq 0 ]
  [ "$(cat "$CONF")" = "$(printf 'after=\nslots=3\nreview_level=max')" ]
}

@test "unlimit: the usage limit goes and a queued job starts" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  echo $(($(date +%s) + 3600)) >"$XDG_STATE_HOME/vibe/limit"
  drain
  [ ! -e "$Q/01-a/status" ]
  run "$VIBE" queue unlimit
  [ "$status" -eq 0 ]
  [ ! -e "$XDG_STATE_HOME/vibe/limit" ]
  drain
  [ "$(cat "$Q/01-a/status")" = "done" ]
}

@test "set: now=1 starts a queued job first, after= turns its review off; a started job refuses both" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  mkjob 02-b "$r" task-b ok
  run "$VIBE" queue set 02-b now=1
  [ "$status" -eq 0 ]
  "$VIBE" queue set 02-b now=1 >/dev/null
  [ "$(grep -c '^now=1$' "$Q/02-b/job")" = 1 ]
  run "$VIBE" queue set 01-a after=
  [ "$status" -eq 0 ]
  grep -qx after= "$Q/01-a/job"
  grep -qx branch=task-a "$Q/01-a/job"
  for v in slots=3 now=0 after=review; do
    run "$VIBE" queue set 01-a "$v"
    [ "$status" -ne 0 ]
  done
  slots 1
  drain
  [ "$(grep -o 'proj-task-[ab]' "$STUBS/claude.log" | tr '\n' ' ')" = "proj-task-b proj-task-a " ]
  run "$VIBE" queue set 01-a now=1
  [ "$status" -ne 0 ]
  [[ "$output" == *"01-a is done, not queued"* ]] || false
}

@test "retry: a failed job comes back as a new job with its own worktree; the old one is archived; a done job refuses" {
  local r n a
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a crash now=1
  mkjob 02-b "$r" task-b ok
  drain
  [ "$(cat "$Q/01-a/status")" = failed ]
  run "$VIBE" queue retry 02-b
  [ "$status" -ne 0 ]
  run "$VIBE" queue retry 01-a
  [ "$status" -eq 0 ]
  a="$XDG_STATE_HOME/vibe/archive/$(date +%Y-%m)/01-a"
  [ -d "$a" ]
  [ ! -e "$Q/01-a" ]
  n="$(find "$Q" -mindepth 1 -maxdepth 1 -name '*-proj-task-a')"
  [ -n "$n" ]
  [ ! -e "$n/status" ]
  [ "$(cat "$n/worktree")" = "$(cat "$a/worktree")" ]
  cmp -s "$a/prompt.md" "$n/prompt.md"
  run grep -q '^now=' "$n/job"
  [ "$status" -ne 0 ]
  mkjob 03-c "$r" task-c ok
  echo failed >"$Q/03-c/status"
  rm "$Q/03-c/prompt.md"
  mkdir -p "$BATS_TEST_TMPDIR/tmp"
  TMPDIR="$BATS_TEST_TMPDIR/tmp" run "$VIBE" queue retry 03-c
  [ "$status" -ne 0 ]
  printf 'repo=%s\nbranch=Bad Branch\n' "$r" >"$Q/03-c/job"
  echo task >"$Q/03-c/prompt.md"
  TMPDIR="$BATS_TEST_TMPDIR/tmp" run "$VIBE" queue retry 03-c
  [ "$status" -ne 0 ]
  [ -z "$(ls -A "$BATS_TEST_TMPDIR/tmp")" ]
}

@test "cancel: a queued job ends skipped, note cancelled, and never runs; an ended job refuses" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  run "$VIBE" queue cancel 01-a
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = skipped ]
  [ "$(cat "$Q/01-a/note")" = cancelled ]
  drain
  [ ! -e "$STUBS/claude.log" ]
  run "$VIBE" queue cancel 01-a
  [ "$status" -ne 0 ]
}

@test "stop: the runner ends a running job failed, note stopped; no requeue, no push, no WIP commit" {
  local r i runner
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a slow
  mkjob 02-b "$r" task-b ok
  run "$VIBE" queue stop 01-a
  [ "$status" -ne 0 ]
  [[ "$output" == *"not running"* ]] || false
  slots 1
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/runner.log" 2>&1 3>&- &
  runner=$!
  for i in $(seq 100); do
    if [ -s "$Q/01-a/agent-pid" ] && [ -e "$r/.claude/worktrees/task-a/wip.txt" ]; then break; fi
    sleep 0.1
  done
  run "$VIBE" queue stop 01-a
  [ "$status" -eq 0 ]
  SECONDS=0
  wait "$runner"
  [ "$SECONDS" -lt 15 ] # the slow agent sleeps 30 s: the runner killed it
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/01-a/note")" = stopped ]
  [ ! -e "$Q/01-a/requeued" ]
  [ "$(cat "$Q/02-b/status")" = "done" ]
  [ "$(cat "$r/.claude/worktrees/task-a/wip.txt")" = half ]
  [ -n "$(git -C "$r/.claude/worktrees/task-a" status --porcelain)" ]
  run git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/task-a
  [ "$status" -ne 0 ]
}

@test "stop: a stop asked during the gate ends the job failed and pushes nothing" {
  local r
  r="$(make_repo proj)"
  mkdir -p "$r/.vibe-jobs"
  echo "touch '$Q/01-a/stop'" >"$r/.vibe-jobs/gate"
  git -C "$r" add .vibe-jobs && git -C "$r" commit -q -m "chore: gate" && git -C "$r" push -q origin main
  mkjob 01-a "$r" task-a ok
  drain
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/01-a/note")" = stopped ]
  [ "$(cat "$Q/01-a/gate")" = 0 ]
  run git -C "$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify refs/heads/task-a
  [ "$status" -ne 0 ]
  run grep -c 'pr create' "$STUBS/gh.log"
  [ "$output" = 0 ] || [ "$status" -eq 2 ]
}

@test "stop: a stopped lane item leaves the lane on <branch>-<item>; the next item runs from a clean worktree" {
  local r o="$BATS_TEST_TMPDIR/proj.git" i runner
  r="$(make_repo proj)"
  mkjob 01-a "$r" lane-x slow "lane=Fix health" item=beta
  mkjob 02-b "$r" lane-x item "lane=Fix health" item=gamma
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/runner.log" 2>&1 3>&- &
  runner=$!
  for i in $(seq 100); do
    if [ -s "$Q/01-a/agent-pid" ] && [ -e "$r/.claude/worktrees/lane-x/wip.txt" ]; then break; fi
    sleep 0.1
  done
  "$VIBE" queue stop 01-a >/dev/null
  wait "$runner"
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/01-a/note")" = stopped ]
  [ "$(cat "$Q/01-a/side")" = lane-x-beta ]
  [ "$(git -C "$o" log -n 1 --format=%s lane-x-beta)" = "wip: beta (stopped)" ]
  [ "$(cat "$Q/02-b/status")" = "done" ]
  [ "$(git -C "$o" log -n 1 --format=%s lane-x)" = "feat: gamma" ]
  run git -C "$o" cat-file -e lane-x:wip.txt
  [ "$status" -ne 0 ]
}

@test "stop: a stopped recurring job does not count as a fail" {
  local r
  r="$(make_repo proj)"
  died_job 01-a "$r" task-a
  echo recurring=health >>"$Q/01-a/job"
  touch "$Q/01-a/stop"
  drain
  [ "$(cat "$Q/01-a/note")" = stopped ]
  [ ! -e "$XDG_STATE_HOME/vibe/jobs/proj/health/fails" ]
}

@test "stop: a stopped job whose process died is not queued again" {
  local r
  r="$(make_repo proj)"
  died_job 01-a "$r" task-a
  touch "$Q/01-a/stop"
  drain
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/01-a/note")" = stopped ]
  [ ! -e "$STUBS/claude.log" ]
}

@test "stop: an agent-pid of 0 does not TERM the runner's own process group" {
  local r rc=0
  r="$(make_repo proj)"
  died_job 01-a "$r" task-a
  sleep 2 &
  echo "$!" >"$Q/01-a/pid"
  echo 0 >"$Q/01-a/agent-pid"
  touch "$Q/01-a/stop"
  # Its own process group (set -m): a kill 0 there must not reach bats.
  (
    set -m
    "$VIBE" queue run --claude --drain >/dev/null 2>&1 &
    wait "$!"
  ) || rc=$?
  [ "$rc" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/01-a/note")" = stopped ]
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
  [[ "$output" == "queue: 0 running · 0 on the GPU · 1 queued · 0 to review · 1 no PR"* ]] || false
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
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 2 queued · 0 to review · 0 no PR · 4 slots" ]
  grep -qx '  task-a  queued' <<<"$output"
  grep -qx '    Do task a.' <<<"$output"
  grep -qx '  02-b  queued' <<<"$output"
  [ "$(wc -l <<<"$output")" -eq 6 ]
}

# endjob ID REPO BRANCH [PR] [KEY=value...] — a job that ended `done`; PR is the text of its `pr` file.
endjob() {
  local id="$1" repo="$2" branch="$3" pr="${4:-}"
  shift $(($# < 4 ? $# : 4))
  mkjob "$id" "$repo" "$branch" ok "$@"
  echo "done" >"$Q/$id/status"
  if [ -n "$pr" ]; then echo "$pr" >"$Q/$id/pr"; fi
}

@test "counts: one PR with 3 jobs counts 1, and its jobs without a pr file do not count as no PR" {
  local r
  r="$(make_repo proj)"
  endjob 01-a "$r" task-a
  endjob 01-a-review1 "$r" task-a
  endjob 01-a-review2 "$r" task-a https://example.com/pull/7
  endjob 02-b "$r" task-b https://example.com/pull/8
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 0 queued · 2 to review · 0 no PR · 4 slots" ]
}

@test "counts: review jobs that each write the PR URL count the PR once" {
  local r
  r="$(make_repo proj)"
  endjob 01-a "$r" task-a https://example.com/pull/7
  endjob 01-a-review1 "$r" task-a https://example.com/pull/7
  endjob 01-a-review2 "$r" task-a https://example.com/pull/7
  run "$VIBE" queue status
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 0 queued · 1 to review · 0 no PR · 4 slots" ]
}

@test "counts: an ended job with no PR counts in no PR" {
  local r
  r="$(make_repo proj)"
  endjob 01-a "$r" task-a "PR not created"
  endjob 02-b "$r" task-b "push failed"
  endjob 03-c "$r" task-c
  endjob 04-d "$r" task-d https://example.com/pull/4
  run "$VIBE" queue status
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 0 queued · 1 to review · 3 no PR · 4 slots" ]
}

@test "counts: a done job whose review round is queued or running is not no PR; its PR counts when it opens" {
  local r
  r="$(make_repo proj)"
  endjob 01-a "$r" task-a
  mkjob 01-a-review1 "$r" task-a ok review=1
  run "$VIBE" queue status
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 1 queued · 0 to review · 0 no PR · 4 slots" ]
  echo running >"$Q/01-a-review1/status"
  run "$VIBE" queue status
  [ "$(sed -n 1p <<<"$output")" = "queue: 1 running · 0 on the GPU · 0 queued · 0 to review · 0 no PR · 4 slots" ]
  echo "done" >"$Q/01-a-review1/status"
  echo https://example.com/pull/7 >"$Q/01-a-review1/pr"
  run "$VIBE" queue status
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 0 queued · 1 to review · 0 no PR · 4 slots" ]
}

@test "counts: a live job on another branch does not hide a no PR job" {
  local r
  r="$(make_repo proj)"
  endjob 01-a "$r" task-a
  mkjob 02-b "$r" task-b ok
  run "$VIBE" queue status
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 1 queued · 0 to review · 1 no PR · 4 slots" ]
}

@test "counts: a failed or blocked job counts in no PR although a job on its branch has a PR; a live job does not hide it" {
  local r
  r="$(make_repo proj)"
  endjob 01-a "$r" lane-x https://example.com/pull/3 lane=x
  endjob 02-b "$r" lane-x "" lane=x
  echo failed >"$Q/02-b/status"
  endjob 03-c "$r" lane-x "" lane=x
  echo blocked >"$Q/03-c/status"
  run "$VIBE" queue status
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 0 queued · 1 to review · 2 no PR · 4 slots" ]
  mkjob 04-d "$r" lane-x ok lane=x
  run "$VIBE" queue status
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 1 queued · 1 to review · 2 no PR · 4 slots" ]
}

@test "counts: a lane counts 1; running and queued jobs are not in the PR numbers" {
  local r
  r="$(make_repo proj)"
  endjob 01-a "$r" lane-x https://example.com/pull/3 lane=x
  endjob 02-b "$r" lane-x https://example.com/pull/3 lane=x
  endjob 03-c "$r" lane-x https://example.com/pull/3 lane=x
  mkjob 04-d "$r" task-d ok
  mkjob 05-e "$r" task-e ok
  echo running >"$Q/05-e/status"
  run "$VIBE" queue status
  [ "$(sed -n 1p <<<"$output")" = "queue: 1 running · 0 on the GPU · 1 queued · 1 to review · 0 no PR · 4 slots" ]
}

@test "page: two chips, to review (PRs) with a GitHub link and no PR" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  endjob 01-a "$r" task-a https://example.com/pull/7
  endjob 01-a-review1 "$r" task-a https://example.com/pull/7
  endjob 02-b "$r" task-b "push failed"
  drain
  [ "$status" -eq 0 ]
  grep -qF '<span class="chip"><b>1</b> to review<a href="https://github.com/pulls?q=is%3Apr+is%3Aopen+label%3Aagent+author%3A%40me">agent PRs on GitHub</a></span><span class="chip"><b>1</b> no PR</span>' "$f"
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
  grep -qF '<div class="repo"><div class="rh"><h2>proj</h2>' "$f"
  [ "$(grep -A1 '<b>task-b</b>' "$f" | tail -n 1)" = '</div>' ]
  grep -qF '<b>task-b</b><span class="pill">queued</span></div><p>&lt;b&gt;A &amp; B&lt;/b&gt;</p>' "$f"
  grep -qF '<span class="chip"><b>1</b> queued</span>' "$f"
  grep -qF '<p>PANDOC</p>' "$f"
  run grep -c '<b>A &' "$f"
  [ "$output" = 0 ]
  [ ! -e "$f.tmp" ]
}

@test "page: raw HTML in a job's text shows as code in the briefing" {
  command -v pandoc >/dev/null || skip "pandoc not installed"
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  mkjob 20261029-081414-proj-task-a "$r" task-a blocked 'context=<img src=x onerror=alert(1)> and <script>alert(2)</script>'
  drain
  [ "$status" -eq 0 ]
  grep -qF '<code>&lt;img src=x onerror=alert(1)&gt;</code>' "$f"
  run grep -c '<img\|<script>alert' "$f"
  [ "$output" = 0 ]
}

@test "page: a link or image with a javascript: or data: target shows as text in the briefing" {
  command -v pandoc >/dev/null || skip "pandoc not installed"
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  mkjob 20261029-081414-proj-task-a "$r" task-a blocked 'context=[bad](javascript:alert(1)) ![pic](data:text/html,x) <javascript:alert(2)> [ok](https://example.com/ok)'
  drain
  [ "$status" -eq 0 ]
  grep -qF 'href="https://example.com/ok"' "$f"
  grep -qF 'bad pic javascript:alert(2)' "$f"
  run grep -c 'href="javascript\|src="data' "$f"
  [ "$output" = 0 ]
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
  touch "$Q/01-a/requeued" # the kill below ends the job, so the runner drains
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

@test "page: a lane is one card with its progress, next item and the item out of the lane; one click anywhere on it unpacks it into a job card per job; a done job shows its cost" {
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
  grep -qF '<div class="job lane s-blocked"><div class="top"><b>lane-x</b><span class="pill">1/3</span></div><p>Fix health' "$f"
  grep -qF '<p>next: gamma</p><p>02-b  blocked  blocked: beta needs a decision → lane-x-beta</p>' "$f"
  run grep -c '<b>01-a</b>\|<b>03-c</b>' "$f"
  [ "$output" = 0 ]
  grep -qF '<details class="stack"><summary>3 jobs</summary><div class="job s-done"><div class="top"><b>alpha</b><span class="pill">done</span></div><p>done: alpha.txt added' "$f"
  grep -qF '<div class="job s-blocked"><div class="top"><b>beta</b><span class="pill">blocked</span></div><p>blocked: beta needs a decision → lane-x-beta' "$f"
  grep -qF '<div class="job s-queued"><div class="top"><b>gamma</b><span class="pill">queued</span></div><p></p><div class="jacts" data-id="03-c"><button data-act="now">Start next</button><hr><button data-act="cancel" data-confirm>Cancel</button></div></div></details></div>' "$f"
  # shellcheck disable=SC2016  # a literal $ in the expected text
  grep -qF '<p class="stats">≈$1.50 API · 7 turns · 2m</p>' "$f"
  # The summary covers the whole lane card and has no arrow; link, steps and job cards sit above it.
  grep -qE '^\.job\.lane > \.stack > summary \{[^}]*position: absolute; inset: 0;[^}]*list-style: none;' "$f"
  grep -qE '^\.job\.lane > \.stack > summary::-webkit-details-marker \{ display: none; \}' "$f"
  grep -qE '^\.job\.lane > p a, [^{]*\.stack > \.job[^{]*\{ position: relative; z-index: 1; \}' "$f"
  # Nothing in a lane may reach the sticky bar's z-index, or it scrolls over the bar.
  grep -qE '^\.bar \{[^}]*position: sticky;[^}]*z-index: 2;' "$f"
  run grep -E '^\.(job|stack)[^{]*\{[^}]*z-index: ([2-9]|[1-9][0-9])' "$f"
  [ "$status" -eq 1 ]
}

# acts_of LINE — the buttons, empty rows, labels and file lines of one button group, in page order.
acts_of() { printf '%s' "$1" | grep -o '<hr>\|data-act="[a-z-]*"\|class="lbl"\|class="files"' | sed 's/data-act=//; s/"//g; s/class=//' | paste -sd' ' -; }

@test "page: each button group is read-only first, write next, then an empty row and the data-confirm buttons; file links last" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" top card new
  r="$(make_repo proj)"
  mkdir -p "$r/.vibe-jobs" "$XDG_STATE_HOME/vibe/jobs/proj/codebase-health"
  printf -- '---\n---\n\nCheck it.\n' >"$r/.vibe-jobs/codebase-health.md"
  echo 2 >"$XDG_STATE_HOME/vibe/jobs/proj/codebase-health/fails"
  mkjob 01-a "$r" task-a ok
  mkjob 02-b "$r" task-b ok
  echo failed >"$Q/02-b/status"
  echo report >"$Q/02-b/report.md"
  echo log >"$Q/02-b/log"
  VIBE_ROOT="$BATS_TEST_TMPDIR" run "$VIBE" queue page
  [ "$status" -eq 0 ]
  top="$(grep '^<div class="acts">' "$f")"
  [ "$(acts_of "$top")" = 'servers pause conf triage sync <hr> restart server-restart update-toolkit' ]
  # Merge order: in the repo heading row.
  grep -qF "<div class=\"repo\"><div class=\"rh\"><h2>proj</h2><div class=\"jacts\" data-repo=\"$r\"><button data-act=\"merge-order\">" "$f"
  card="$(grep 'data-id="01-a"' "$f")"
  [ "$(acts_of "${card#*data-id=\"01-a\"}")" = 'now <hr> cancel' ]
  card="$(grep 'data-id="02-b"' "$f")"
  [ "$(acts_of "${card#*data-id=\"02-b\"}")" = 'retry hold <hr> answer archive files' ]
  grep -qF '<div class="files"><a href="/queue/api/job/02-b/report.md">report.md</a><a href="/queue/api/job/02-b/log">log</a></div></div>' "$f"
  new="$(grep "<b>proj</b><span class=\"pill\"></span></div><div class=\"jacts\" data-repo=\"$r\">" "$f")"
  [ "$(acts_of "${new#*"data-repo=\"$r\""}")" = 'roadmap worktrees new opt-in lbl run reset' ]
  # The recurring job keeps its own .jacts: page.js sends data-repo and data-job from the nearest one.
  grep -qF "<span class=\"lbl\">Run recurring</span><div class=\"jacts\" data-repo=\"$r\" data-job=\"codebase-health\"><button data-act=\"run\">codebase-health</button><button data-act=\"reset\">Reset codebase-health</button></div></div>" "$f"
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
  [[ "$output" == *"queue: 0 running"*"1 to review · 3 no PR"* ]] || false
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

@test "cost: the limit share reads no job that ended before the job started" {
  local r f n0 n1 i
  r="$(make_repo proj)"
  printf '#!/bin/sh\necho x >>"%s/date.calls"\nexec /bin/date "$@"\n' "$STUBS" >"$STUBS/date"
  chmod +x "$STUBS/date"
  endedjob 01-a "$r" 10:00:00 10:09:59 1 0.40 0.48
  endedjob 02-b "$r" 10:00:00 10:09:59 3 0.40 0.48
  : >"$STUBS/date.calls"
  "$VIBE" queue report >/dev/null
  n0="$(wc -l <"$STUBS/date.calls")"
  for i in $(seq 300); do
    mkdir -p "$XDG_STATE_HOME/vibe/archive/2020-01/old-$i"
    echo "2020-01-01 10:00:00" >"$XDG_STATE_HOME/vibe/archive/2020-01/old-$i/started"
    echo "2020-01-01 10:09:59" >"$XDG_STATE_HOME/vibe/archive/2020-01/old-$i/ended"
    cp "$Q/01-a/log" "$XDG_STATE_HOME/vibe/archive/2020-01/old-$i/log"
  done
  : >"$STUBS/date.calls"
  "$VIBE" queue report >/dev/null
  n1="$(wc -l <"$STUBS/date.calls")"
  [ "$n1" -eq "$n0" ]
  for f in "$XDG_STATE_HOME"/vibe/briefings/*.md; do :; done
  grep -F '| 01-a |' "$f" | grep -qF '≈2% 5h est.'
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

# gpurace — a job whose GPU run ends while the job still runs: `queue follow` ends the job first.
gpurace() {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a gpurace
  timeout 60 "$VIBE" queue run --claude --drain >/dev/null 2>&1
}

@test "gpu: a follow-up that ended its parent first leaves the parent done" {
  gpurace
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(cat "$Q/01-a/note")" = "GPU run exit 0 → 01-a-gpu" ]
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
}

@test "gpu: the follow-up starts after its parent has an ended file" {
  gpurace
  [ "$(cat "$STUBS/parent-at-follow")" = ended ]
}

@test "gpu: a parent that died after its follow-up marked it done gets an ended file, and the follow-up runs" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  mkdir -p "$Q/01-a" && echo "queued: training" >"$Q/01-a/result"
  echo running >"$Q/01-a/status"
  GPUQ_EXIT=0 "$VIBE" queue follow "$Q/01-a" >/dev/null
  echo 999999 >"$Q/01-a/pid"
  [ ! -e "$Q/01-a/ended" ]
  run timeout 60 "$VIBE" queue run --claude --drain
  [ "$status" -eq 0 ]
  [ -s "$Q/01-a/ended" ]
  [ ! -e "$Q/01-a/pid" ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
}

@test "gpu: a requeued parent (usage limit) gets an ended file from queue follow, and the follow-up runs" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  echo queued >"$Q/01-a/status"
  GPUQ_EXIT=0 "$VIBE" queue follow "$Q/01-a" >/dev/null
  [ -s "$Q/01-a/ended" ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  run timeout 60 "$VIBE" queue run --claude --drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
}

@test "gpu: a parent that queue follow marked done while its process still runs is not archived or briefed" {
  local r f
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  echo running >"$Q/01-a/status"
  GPUQ_EXIT=0 "$VIBE" queue follow "$Q/01-a" >/dev/null
  echo $$ >"$Q/01-a/pid"
  [ "$(cat "$Q/01-a/status")" = "done" ]
  run "$VIBE" queue archive 01-a
  [ "$status" -ne 0 ]
  [[ "$output" == *"has not ended"* ]] || false
  [ -d "$Q/01-a" ]
  run "$VIBE" queue report
  f="$(ls "$XDG_STATE_HOME"/vibe/briefings/*.md)"
  run cat "$f"
  [[ "$output" != *"task-a"* ]] || false
  rm -f "$Q/01-a/pid"
  date '+%F %T' >"$Q/01-a/ended"
  run "$VIBE" queue archive 01-a
  [ "$status" -eq 0 ]
  [ -d "$XDG_STATE_HOME/vibe/archive/$(date +%Y-%m)/01-a" ]
}

@test "gpu cancel: a queued or a running run ends the job failed, with no follow-up" {
  local r pid g
  r="$(make_repo proj)"
  touch "$STUBS/gpu-sleep"
  mkjob 01-a "$r" task-a gpu
  mkjob 02-b "$r" task-b gpu
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/run.out" 2>&1 &
  pid=$!
  for _ in $(seq 1 100); do
    [ "$(cat "$Q/01-a/status" "$Q/02-b/status" 2>/dev/null)" != "$(printf 'gpu\ngpu')" ] || break
    sleep 0.1
  done
  run "$REPO_ROOT/bin/gpu-queue" cancel "$(cat "$Q/01-a/gpu-job")"
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = failed ]
  [ "$(cat "$Q/01-a/note")" = "GPU run cancelled" ]
  g="$GPU_QUEUE_DIR/running/$(cat "$Q/02-b/gpu-job")"
  "$REPO_ROOT/bin/gpu-queue" run --once 2>/dev/null &
  for _ in $(seq 1 50); do
    [ ! -s "$g/pid" ] || break
    sleep 0.1
  done
  run "$REPO_ROOT/bin/gpu-queue" cancel "${g##*/}"
  [ "$status" -eq 0 ]
  wait "$pid"
  [ "$(cat "$Q/02-b/status")" = failed ]
  [ ! -e "$Q/01-a-gpu" ]
  [ ! -e "$Q/02-b-gpu" ]
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
  run "$VIBE" queue status
  [[ "$output" == "queue: 0 running · 0 on the GPU · 0 queued · 1 to review · 0 no PR"* ]] || false
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
