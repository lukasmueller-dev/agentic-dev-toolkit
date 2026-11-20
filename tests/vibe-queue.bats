#!/usr/bin/env bats
#
# vibe queue — the queue in throwaway repos; the stubs and the setup: tests/queue.bash.

load helper
load queue

SWEEP="$REPO_ROOT/skills/fill-queue/sweep.sh"

setup() { queue_setup; }

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

# par_set_pr DIR — DIR/f.md has 8 members; 8 parallel feature_set_pr calls each give one a PR URL.
par_set_pr() {
  local i pid pids=()
  eval "$(sed -n '/^mkdir_lock() {/,/^}/p; /^feature_set_pr() {/,/^}/p' "$VIBE")"
  {
    printf '## Members\n\n'
    for i in 1 2 3 4 5 6 7 8; do echo "- r$i b$i"; done
  } >"$1/f.md"
  [ ! -e "$1/f.md.lock" ] || touch -t 200001010000 "$1/f.md.lock"
  for i in 1 2 3 4 5 6 7 8; do
    feature_set_pr "$1/f.md" "r$i" "b$i" "https://example.com/pull/$i" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do wait "$pid"; done
  [ "$(ls "$1")" = f.md ]
  for i in 1 2 3 4 5 6 7 8; do grep -qxF -- "- r$i b$i https://example.com/pull/$i" "$1/f.md"; done
}

@test "feature: parallel feature_set_pr calls all succeed, keep every PR and leave no temp file or lock" {
  mkdir "$BATS_TEST_TMPDIR/par"
  par_set_pr "$BATS_TEST_TMPDIR/par"
}

# locked_out ARGS — feature_set_pr where mkdir always fails (a read-only directory, a stuck FILE.reap), in a subshell.
# shellcheck disable=SC2317  # the stubs run inside the eval'd feature_set_pr
locked_out() (
  eval "$(sed -n '/^mkdir_lock() {/,/^}/p; /^feature_set_pr() {/,/^}/p' "$VIBE")"
  mkdir() { return 1; }
  find() { :; }
  sleep() { :; }
  feature_set_pr "$@"
)

@test "feature: feature_set_pr gives up with a message when it cannot take the lock" {
  run locked_out "$BATS_TEST_TMPDIR/f.md" r b https://example.com/pull/1
  [ "$status" -eq 1 ]
  [[ "$output" == *"no lock on $BATS_TEST_TMPDIR/f.md after 3 min"* ]] || false
}

@test "feature: a stale lock from a killed job is removed once; parallel feature_set_pr calls still keep every PR" {
  mkdir -p "$BATS_TEST_TMPDIR/par/f.md.lock"
  par_set_pr "$BATS_TEST_TMPDIR/par"
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

@test "page: a feature is one row in Needs you; its block unpacks a lane card, a job card and a card with no job" {
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
  grep -qF '<div class="row" data-k="feature/teleop"><i class="lamp l-you"></i><a class="t" href="#job-feature/teleop"><b>teleop <span class="n">3 of 3 items</span></b><span class="why">Test it yourself · The gamepad drives the robot. · Feature</span></a><span class="jacts p" data-feature="teleop"><button data-act="feature-ready" data-confirm title="Your human test passed: mark every member PR ready">Test passed</button></span></div>' "$f"
  [ "$(grep -o '<div class="row"' "$f" | wc -l)" -eq 1 ]
  grep -qF '<div class="blk" id="job-feature/teleop" hidden><div class="bh"><i class="lamp l-you"></i><span class="st" title="Every member PR passed its checks: test the feature, then Test passed.">Test it yourself</span><h2>teleop <span class="n">3 of 3 items</span></h2><code class="meta">Feature</code></div><div class="job lane feature s-held">' "$f"
  grep -qF '<div class="job lane feature s-held"><div class="top"><b>teleop · 3 of 3 items</b><span class="pill">Test it yourself</span></div><p>The gamepad drives the robot.</p><div class="jacts" data-feature="teleop"><button data-act="feature-ready" data-confirm title="Your human test passed: mark every member PR ready">Test passed</button></div><details class="stack"><summary>3 branches</summary>' "$f"
  grep -qF '<div class="job lane s-done"><div class="top"><b>bridge · lane-x</b><span class="pill">2 of 2 items</span></div><p class="steps">' "$f"
  grep -qF '<p>Sticks <a href="https://example.com/pull/1">PR</a></p>' "$f"
  grep -qF '<div class="job s-done"><div class="top"><b>cmdr · gamepad</b><span class="pill">Done</span></div><p class="steps">' "$f"
  grep -qF '<p>work.txt added <a href="https://example.com/pull/1">PR</a></p>' "$f"
  grep -qF '<div class="job s-done"><div class="top"><b>vla · node</b><span class="pill">No job</span></div><p> <a href="https://example.com/pull/7">PR</a></p></div></details></div>' "$f"
  run grep -c '<h2>bridge</h2>\|<h2>cmdr</h2>' "$f"
  [ "$output" = 0 ]
}

@test "run: a bin/vibe edited in place while the runner runs does not change its exit status" {
  local r tk="$BATS_TEST_TMPDIR/toolkit" pid i
  r="$(make_repo proj)"
  mkdir "$tk" && cp -R "$REPO_ROOT/bin" "$REPO_ROOT/skills" "$REPO_ROOT/claude" "$REPO_ROOT/templates" "$tk"
  mkjob 01-a "$r" task-a seq
  "$tk/bin/vibe" queue run --claude --drain >"$BATS_TEST_TMPDIR/run.out" 2>&1 &
  pid=$!
  for i in $(seq 1 100); do
    [ ! -s "$Q/01-a/pid" ] || break
    sleep 0.1
  done
  [ -s "$Q/01-a/pid" ]
  { head -n 1 "$tk/bin/vibe" && echo '# a line the running vibe never reads, long enough to move its end offset' && tail -n +2 "$tk/bin/vibe"; } >"$BATS_TEST_TMPDIR/vibe.new"
  cat "$BATS_TEST_TMPDIR/vibe.new" >"$tk/bin/vibe"
  wait "$pid" || { cat "$BATS_TEST_TMPDIR/run.out" && false; }
  [ "$(cat "$Q/01-a/status")" = "done" ]
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

@test "feature add: refuses a relative member path and names it" {
  local r1 r2 F="$XDG_STATE_HOME/vibe/features"
  r1="$(make_repo bridge)" r2="$(make_repo cmdr)"
  git -C "$r1" branch sticks
  git -C "$r2" branch gamepad
  cd "$BATS_TEST_TMPDIR"
  run "$VIBE" feature add "$(mkfeature rel "./bridge sticks" "$r2 gamepad")"
  [ "$status" -ne 0 ]
  [[ "$output" == *"./bridge is not an absolute path"* ]] || false
  [ ! -e "$F/rel.md" ]
}

@test "feature add: refuses a member path that is not canonical and names the one to write" {
  local r1 r2 p
  r1="$(make_repo bridge)" r2="$(make_repo cmdr)"
  git -C "$r1" branch sticks
  git -C "$r2" branch gamepad
  for p in "$r1/../bridge" "$(dirname "$r1")//bridge"; do
    run "$VIBE" feature add "$(mkfeature dots "$p sticks" "$r2 gamepad")"
    [ "$status" -ne 0 ]
    [[ "$output" == *"$p is not the path jobs store as their repo — write $r1"* ]] || false
    [ ! -e "$XDG_STATE_HOME/vibe/features/dots.md" ]
  done
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
  grep -q -- "--add-dir $Q/01-a/agent " "$STUBS/claude.log"
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

@test "run: the runner does not push a job that adds an LFS-tracked file, with hooks off" {
  local r lfs="$BATS_TEST_TMPDIR/lfs"
  r="$(make_repo proj)"
  echo '*.txt filter=lfs diff=lfs merge=lfs -text' >"$r/.gitattributes"
  git -C "$r" add .gitattributes && git -C "$r" commit -q -m "chore: lfs" && git -C "$r" push -q origin main
  mkdir -p "$lfs" && printf '#!/bin/sh\n' >"$lfs/git-lfs" && chmod +x "$lfs/git-lfs"
  mkjob 01-a "$r" task-a ok
  PATH="$lfs:$PATH" drain
  [ "$(cat "$Q/01-a/pr")" = "push failed (git-lfs: push by hand)" ]
  [ -z "$(git -C "$r" ls-remote origin refs/heads/task-a)" ]
}

@test "run: the runner pushes a job in a git-lfs repo when no changed path is LFS-tracked" {
  local r lfs="$BATS_TEST_TMPDIR/lfs"
  r="$(make_repo proj)"
  echo '*.bin filter=lfs diff=lfs merge=lfs -text' >"$r/.gitattributes"
  git -C "$r" add .gitattributes && git -C "$r" commit -q -m "chore: lfs" && git -C "$r" push -q origin main
  mkdir -p "$lfs" && printf '#!/bin/sh\n' >"$lfs/git-lfs" && chmod +x "$lfs/git-lfs"
  mkjob 01-a "$r" task-a ok
  PATH="$lfs:$PATH" drain
  [ "$(cat "$Q/01-a/pr")" != "push failed (git-lfs: push by hand)" ]
  [ -n "$(git -C "$r" ls-remote origin refs/heads/task-a)" ]
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
  grep -q '^\*\*Changed:\*\* alpha.txt added.$' "$Q/03-c/agent/seen-lane-pr.md"
  grep -q '^- beta → lane-x-beta$' "$Q/03-c/agent/seen-lane-pr.md"
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

@test "gate: origin's default branch declares it; it runs in the worktree, exit code in the PR body and report" {
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

# epoch_at 'YYYY-MM-DD HH:MM' — epoch seconds, GNU or BSD date.
epoch_at() { date -d "$1:00" +%s 2>/dev/null || date -j -f '%Y-%m-%d %H:%M:%S' "$1:00" +%s; }

@test "add --at: writes the next HH:MM as at=; a bad time, a missing time or --now with it queues nothing" {
  local r a now at e t
  r="$(make_repo proj)"
  a="$BATS_TEST_TMPDIR/a"
  mkprep "$a" "$r" x
  for t in 25:00 24:00 23:60 9:5 noon; do
    run "$VIBE" queue add --at "$t" "$a"
    [ "$status" -ne 0 ]
    [[ "$output" == *"bad time '$t'"* ]] || false
  done
  run "$VIBE" queue add --at
  [ "$status" -ne 0 ]
  run "$VIBE" queue add --now --at 03:30 "$a"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--now and --at"* ]] || false
  [ -z "$(ls "$Q")" ]
  # The current minute has passed: the next one is tomorrow.
  now="$(date +%s)"
  run "$VIBE" queue add --at "$(date +%H:%M)" "$a"
  [ "$status" -eq 0 ]
  [ ! -e "$a" ]
  at="$(sed -n 's/^at=//p' "$Q"/*-proj-x/job)"
  [[ "$at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}$ ]] || false
  e="$(epoch_at "$at")"
  [ "$e" -gt $((now + 80000)) ]
  [ "$e" -le $((now + 90000)) ]
  [[ "$output" == *"starts $at"* ]] || false
}

@test "run: a job added with --at does not start before its time, starts after it; status and page show the start" {
  local r a j pid at
  r="$(make_repo proj)"
  a="$BATS_TEST_TMPDIR/a"
  mkprep "$a" "$r" task-a
  "$VIBE" queue add --at 03:30 "$a"
  j="$(echo "$Q"/*-proj-task-a)"
  at="$(sed -n 's/^at=//p' "$j/job")"
  [[ "$at" == *" 03:30" ]] || false
  run "$VIBE" queue status
  [[ "$output" == *"starts $at · night work"* ]] || false
  "$VIBE" queue page >/dev/null
  grep -qF "<span class=\"why\">starts $at · night work · proj</span>" "$XDG_STATE_HOME/vibe/web/index.html"
  grep -qF "<p>Starts $at.</p>" "$XDG_STATE_HOME/vibe/web/index.html"
  # A job with no at= is the clock: once it is done, the runner has scanned the waiting one.
  mkjob 01-ctl "$r" ctl ok
  timeout 60 "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/run.out" 2>&1 3>&- &
  pid=$!
  for _ in $(seq 1 150); do
    [ "$(cat "$Q/01-ctl/status" 2>/dev/null)" != "done" ] || break
    sleep 0.1
  done
  [ "$(cat "$Q/01-ctl/status")" = "done" ]
  sleep 1
  [ ! -e "$j/status" ]
  [ "$(grep -c proj-task-a "$STUBS/claude.log")" = 0 ]
  # The time has come: at= is in the past.
  sed 's/^at=.*/at=2000-01-01 03:30/' "$j/job" >"$j/job.tmp" && mv "$j/job.tmp" "$j/job"
  wait "$pid"
  [ "$(cat "$j/status")" = "done" ]
  [ "$(grep -c proj-task-a "$STUBS/claude.log")" = 1 ]
  run "$VIBE" queue status
  [[ "$output" != *"starts "* ]] || false
}

@test "run: a job with now=1 starts although its at= is ahead" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok "at=2999-01-01 03:30" now=1
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
}

# clockdate DAY NOW — a `date` in $BATS_TEST_TMPDIR/clock that fakes `date +%F` (DAY), `date +%s` (NOW) and tomorrow; the rest is the real date.
clockdate() {
  mkdir -p "$BATS_TEST_TMPDIR/clock"
  cat >"$BATS_TEST_TMPDIR/clock/date" <<EOF
#!/bin/sh
case "\$*" in
  "+%F") echo $1 ;;
  "+%s") echo $2 ;;
  "-d +1 day +%F") echo 2026-03-29 ;;
  *) exec /bin/date "\$@" ;;
esac
EOF
  chmod +x "$BATS_TEST_TMPDIR/clock/date"
}

@test "add --at: refuses a time the spring clock change skips, tonight and today; the next real time passes" {
  local r a
  [ -e /usr/share/zoneinfo/Europe/Berlin ] || skip "no tz database"
  r="$(make_repo proj)"
  a="$BATS_TEST_TMPDIR/a"
  mkprep "$a" "$r" x
  export TZ=Europe/Berlin
  # 2026-03-28 20:00 CET: 02:30 has passed, and 2026-03-29 02:30 does not exist.
  clockdate 2026-03-28 1774724400
  PATH="$BATS_TEST_TMPDIR/clock:$PATH" run "$VIBE" queue add --at 02:30 "$a"
  [ "$status" -ne 0 ]
  [[ "$output" == *"02:30 does not exist on 2026-03-29"* ]] || false
  [ -z "$(ls "$Q")" ]
  # 2026-03-29 01:00 CET: 02:30 today does not exist, and no arithmetic error shows.
  clockdate 2026-03-29 1774742400
  PATH="$BATS_TEST_TMPDIR/clock:$PATH" run "$VIBE" queue add --at 02:30 "$a"
  [ "$status" -ne 0 ]
  [[ "$output" == *"02:30 does not exist on 2026-03-29"* ]] || false
  [[ "$output" != *"syntax error"* ]] || false
  [ -z "$(ls "$Q")" ]
  clockdate 2026-03-28 1774724400
  PATH="$BATS_TEST_TMPDIR/clock:$PATH" run "$VIBE" queue add --at 03:30 "$a"
  [ "$status" -eq 0 ]
  grep -qx 'at=2026-03-29 03:30' "$Q"/*-proj-x/job
}

@test "retry: a cancelled job that waited on at= comes back without it, and starts" {
  local r a j id new
  r="$(make_repo proj)"
  a="$BATS_TEST_TMPDIR/a"
  mkprep "$a" "$r" task-a
  "$VIBE" queue add --at 03:30 "$a"
  j="$(echo "$Q"/*-proj-task-a)"
  id="${j##*/}"
  grep -q '^at=' "$j/job"
  "$VIBE" queue cancel "$id"
  run "$VIBE" queue retry "$id"
  [ "$status" -eq 0 ]
  new="$(echo "$Q"/*-proj-task-a)"
  [ "$new" != "$j" ]
  [ "$(grep -c '^at=' "$new/job")" = 0 ]
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$new/status")" = "done" ]
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

@test "milestones: a job started by now=1 over a future at= queues the next milestone without at=, and it starts" {
  local r d n
  r="$(make_repo proj)"
  "$VIBE" start -C "$r" spec >/dev/null 2>&1
  printf '# Spec\n\n- [ ] one\n- [ ] two\n' >"$r/.claude/worktrees/spec/SPEC.md"
  git -C "$r/.claude/worktrees/spec" add SPEC.md
  git -C "$r/.claude/worktrees/spec" commit -q -m "docs(spec): x"
  mkjob 01-a "$r" spec milestone "at=2999-01-01 03:30" now=1
  run timeout 60 "$VIBE" queue run --claude --drain
  [ "$status" -eq 0 ]
  [ "$(find "$Q" -mindepth 1 -maxdepth 1 | wc -l)" -eq 2 ]
  for d in "$Q"/*/; do [ "$(cat "$d/status")" = "done" ]; done
  n="$(find "$Q" -mindepth 1 -maxdepth 1 -name '*-proj-spec')"
  [ -n "$n" ]
  [ "$(grep -c '^at=' "$n/job")" = 0 ]
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
  for v in slots=0 slots=x after=maybe review_level=huge memory_max=-1 steer=yes slots; do
    run "$VIBE" queue conf "$v"
    [ "$status" -ne 0 ]
  done
  run "$VIBE" queue conf review_level=max
  [ "$status" -eq 0 ]
  run "$VIBE" queue conf after=code
  [ "$status" -eq 0 ]
  [ "$(cat "$CONF")" = "$(printf 'slots=3\nreview_level=max\nafter=code')" ]
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

# The job sandbox may write its worktree and $VIBE_JOB_DIR; the stub writes there what a hostile job would.
@test "trust: a job-written worktree and base are not used by the runner's gate and push" {
  local r e
  r="$(make_repo proj)"
  e="$BATS_TEST_TMPDIR/evil"
  git init -q "$e"
  git -C "$e" remote add origin "$e"
  git -C "$e" config remote.origin.uploadpack "touch '$BATS_TEST_TMPDIR/pwned'; git-upload-pack"
  git -C "$e" config remote.origin.receivepack "touch '$BATS_TEST_TMPDIR/pwned'; git-receive-pack"
  mkdir -p "$STUBS/forge"
  echo "$e" >"$STUBS/forge/worktree"
  echo nope >"$STUBS/forge/base"
  mkjob 01-a "$r" task-a forge
  drain
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(git -C "$BATS_TEST_TMPDIR/proj.git" show task-a:work.txt)" = work ]
  # A copy, not a link: Write and Edit run outside the sandbox and could follow a link.
  [ ! -L "$Q/01-a/agent/job" ]
  cmp "$Q/01-a/job" "$Q/01-a/agent/job"
}

@test "trust: a job-written agent-pid is not what vibe queue stop TERMs" {
  local r victim runner
  r="$(make_repo proj)"
  sleep 60 3>&- &
  victim=$!
  mkdir -p "$STUBS/forge"
  echo "$victim" >"$STUBS/forge/agent-pid"
  touch "$STUBS/forge-sleep"
  mkjob 01-a "$r" task-a forge
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/runner.log" 2>&1 3>&- &
  runner=$!
  for _ in $(seq 100); do
    if [ -e "$STUBS/forged" ]; then break; fi
    sleep 0.1
  done
  "$VIBE" queue stop 01-a >/dev/null
  SECONDS=0
  wait "$runner"
  [ "$SECONDS" -lt 15 ] # the forging agent sleeps 30 s: the runner TERMed it, not the victim
  kill -0 "$victim"
  kill "$victim"
  [ "$(cat "$Q/01-a/note")" = stopped ]
}

@test "trust: the job sandbox may not write the queue or gpu-queue" {
  # An entry that names either, or holds ~/.local/state, lets a job forge the runner's files or a GPU run.
  jq -e '[.sandbox.filesystem.allowWrite[] | rtrimstr("/") as $e
    | select(($e | contains("vibe") or contains("gpu-queue")) or ("~/.local/state/" | startswith($e + "/")))] == []' \
    "$REPO_ROOT/claude/vibe-job-settings.json"
}

@test "trust: a link the job leaves as pr.md is not copied back or published" {
  local r
  r="$(make_repo proj)"
  echo "host secret" >"$STUBS/secret"
  mkjob 01-a "$r" task-a leak
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ ! -e "$Q/01-a/pr.md" ]
  [ -f "$Q/01-a/pr-body.md" ]
  run grep -q "host secret" "$Q/01-a/pr-body.md"
  [ "$status" -eq 1 ]
}

@test "report: a done job whose push failed or whose PR was not created is under Needs you with its note, not under Done" {
  local r
  r="$(make_repo proj)"
  endjob 01-a "$r" task-a "push failed (git-lfs: push by hand)"
  endjob 02-b "$r" task-b "push failed"
  endjob 03-c "$r" task-c
  endjob 04-d "$r" task-d "PR not created"
  endjob 05-e "$r" task-e "push failed"
  echo 1 >"$Q/05-e/gate" && echo red >"$Q/05-e/gate.log"
  run "$VIBE" queue report
  [ "$status" -eq 0 ]
  [[ "$output" == *"### Needs you"*"| 01-a | done |"*"**push failed (git-lfs: push by hand)** · "*"| 02-b | done |"*"**push failed** · "*"| 04-d | done |"*"**PR not created** · "*"| 05-e | done |"*"**gate exit 1** · **push failed** · "*"### Done, nothing to read"*"| 03-c | done |"* ]] || false
  [ "$(grep -cE '^\| 0[1245]-[a-e] ' <<<"$output")" = 4 ]
}

@test "report: a feature member whose last round failed to push needs you although an earlier job holds a PR; a later PR clears it" {
  local r1 r2
  r1="$(make_repo bridge)" r2="$(make_repo cmdr)"
  putfeature teleop "$r1 sticks" "$r2 gamepad"
  endjob 01-a "$r1" sticks https://example.com/pull/1
  endjob 01-a-review1 "$r1" sticks "push failed (git-lfs: push by hand)"
  endjob 02-b "$r2" gamepad "push failed"
  endjob 02-b-review1 "$r2" gamepad https://example.com/pull/2
  run "$VIBE" queue report
  [ "$status" -eq 0 ]
  [[ "$output" == *"| teleop | needs you | 1/2 |"*"| [bridge#1](https://example.com/pull/1) push failed (git-lfs: push by hand) · [cmdr#2](https://example.com/pull/2) done |"* ]] || false
}

@test "report: a lane whose push failed or whose PR was not created is one row under Needs you with the note" {
  local r
  r="$(make_repo proj)"
  endjob 01-a "$r" lane-x "push failed" "lane=Fix health" item=alpha
  endjob 02-b "$r" lane-x "push failed (git-lfs: push by hand)" "lane=Fix health" item=beta
  endjob 03-c "$r" lane-y "PR not created" "lane=Fix wiring" item=gamma
  endjob 04-d "$r" lane-y "PR not created" "lane=Fix wiring" item=delta
  run "$VIBE" queue report
  [ "$status" -eq 0 ]
  [[ "$output" == *"### Needs you"*"| lane-x | 2/2 | Fix health | **push failed (git-lfs: push by hand)** · "*"| lane-y | 2/2 | Fix wiring | **PR not created** · "* ]] || false
  [[ "$output" != *"### Done, nothing to read"* ]] || false
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

@test "status: short names, a line per job, then its text and its phases; no text line without text" {
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
  [ "$(grep -cx '    ○ Agent · ○ Gate · ○ PR' <<<"$output")" = 2 ]
  [ "$(wc -l <<<"$output")" -eq 8 ]
}

# gpuq_end N EXIT — the finished run `2026111N-120000-1-rN` (ids sort by submit time), ended 2026-11-1N 12:0N:30 with EXIT. Prints its id.
gpuq_end() {
  local gq="${GPU_QUEUE_DIR:-$XDG_STATE_HOME/gpu-queue}" id="2026111$1-120000-1-r$1"
  mv "$gq/finished/$(gpuq finished "r$1" "$BATS_TEST_TMPDIR")" "$gq/finished/$id"
  echo "$2" >"$gq/finished/$id/exit"
  echo "2026-11-1$1 12:0$1:30" >"$gq/finished/$id/ended"
  echo "$id"
}

@test "status: a gpu-queue run no vibe job started counts on the GPU, in a GPU block with its id and dir" {
  local id dir="$BATS_TEST_TMPDIR/sc-962d4a2"
  unset GPU_QUEUE_DIR # the default state dir of gpu-queue and of vibe must agree
  mkdir "$dir"
  id="$(gpuq running t43 "$dir")"
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 1 on the GPU · 0 queued · 0 to review · 0 no PR · 4 slots" ]
  [ "$(sed -n 3p <<<"$output")" = "GPU" ]
  [ "$(sed -n 4p <<<"$output")" = "  $id  running" ]
  [ "$(sed -n 5p <<<"$output")" = "    $(cd "$dir" && pwd)" ]
  run "$VIBE" queue page
  [ "$status" -eq 0 ]
  grep -qF "<section class=\"sec\" data-k=\"run\"><h2>Running <span class=\"n\">1</span></h2><div class=\"card\"><div class=\"row\" data-k=\"$id\"><i class=\"lamp l-ok\"></i><a class=\"t\" href=\"#job-$id\"><b>GPU run · t43</b><span class=\"why\">sc-962d4a2</span></a></div>" "$XDG_STATE_HOME/vibe/web/index.html"
  grep -qF "<p>$(cd "$dir" && pwd)</p>" "$XDG_STATE_HOME/vibe/web/index.html"
}

@test "status: a gpu-queue run a vibe job's gpu-job names counts once; an outside queued run is added" {
  local r own other
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  echo gpu >"$Q/01-a/status"
  own="$(gpuq running own "$r")"
  echo "$own" >"$Q/01-a/gpu-job"
  other="$(gpuq queued other "$r")"
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 2 on the GPU · 0 queued · 0 to review · 0 no PR · 4 slots" ]
  grep -qx "  $other  queued" <<<"$output"
  [ "$(grep -c "$own" <<<"$output")" -eq 0 ]
}

@test "status: the <id>.tmp dir of a gpu-queue submit under way is no GPU run" {
  local id
  id="$(gpuq queued t43 "$BATS_TEST_TMPDIR")"
  mkdir "$GPU_QUEUE_DIR/queued/$id.tmp"
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 1 on the GPU · 0 queued · 0 to review · 0 no PR · 4 slots" ]
  [ "$(grep -c '\.tmp' <<<"$output")" -eq 0 ]
}

@test "status: an outside running gpu-queue run shows elapsed time, dir, last log line, command, then hook and wandb link, on the page too" {
  local id dir="$BATS_TEST_TMPDIR/run-dir" t html="$XDG_STATE_HOME/vibe/web/index.html" rd
  mkdir "$dir"
  id="$(gpuq running train "$dir")"
  rd="$GPU_QUEUE_DIR/running/$id"
  t=$(($(date +%s) - 720))
  { date -d "@$t" '+%F %T' 2>/dev/null || date -r "$t" '+%F %T'; } >"$rd/started"
  echo "notify-me" >"$rd/then"
  # An ANSI-coloured link, then a progress bar that redraws itself with \r and an erase code.
  printf 'old line\n\033[34mwandb: run at \033[4mhttps://wandb.ai/me/proj/runs/abc123\033[0m\n  5%%|#  | 5/100\r 10%%|## | 10/100\r\033[2K 15%%|### | 15/100\r' >"$rd/log"
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(sed -n 4,9p <<<"$output")" = "  $id  running 12m
    $(cd "$dir" && pwd)
    log: 15%|### | 15/100
    cmd: true
    then: notify-me
    wandb: https://wandb.ai/me/proj/runs/abc123" ]
  [ "$(grep -c $'\033' <<<"$output")" -eq 0 ]
  [ "$(grep -c $'\r' <<<"$output")" -eq 0 ]
  run "$VIBE" queue page
  [ "$status" -eq 0 ]
  grep -qF '<span class="pill">Running 12m</span>' "$html"
  grep -qF "<p>$(cd "$dir" && pwd)</p>" "$html"
  grep -qF '<p class="stats">log: 15%|### | 15/100</p>' "$html"
  grep -qF '<p class="stats">cmd: true</p>' "$html"
  grep -qF '<p class="stats">then: notify-me</p>' "$html"
  grep -qF '<a href="https://wandb.ai/me/proj/runs/abc123">wandb run</a>' "$html"
}

@test "status: a long log line and a long command are cut to one line; no then or wandb line without data" {
  local id long rd
  long="$(printf '%0200d' 0)"
  id="$(gpuq running long "$BATS_TEST_TMPDIR")"
  rd="$GPU_QUEUE_DIR/running/$id"
  echo "$long" >"$rd/cmd"
  printf 'begin\n%s\n\n  \n' "$long" >"$rd/log"
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  grep -qxF "    log: $(printf '%079d' 0)…" <<<"$output"
  grep -qxF "    cmd: $(printf '%079d' 0)…" <<<"$output"
  [ "$(grep -cE '^ +(then|wandb):' <<<"$output")" -eq 0 ]
}

@test "status: a multi-byte log line is cut to valid UTF-8 under the C locale (the cut falls inside a character)" {
  local id bar
  bar="$(printf '%0100d' 0 | sed 's/0/█/g')"
  id="$(gpuq running bar "$BATS_TEST_TMPDIR")"
  printf '  5%%|%s| 5/100 [00:03<00:17, 4.9it/s]\n' "$bar" >"$GPU_QUEUE_DIR/running/$id/log"
  LC_ALL=C run "$VIBE" queue status
  [ "$status" -eq 0 ]
  grep -qE '^    log: 5%\|█+…$' <<<"$output"
  iconv -f UTF-8 -t UTF-8 <<<"$output" >/dev/null
}

@test "status: queued, held and parked outside runs show state, dir and command; only the queued one counts on the GPU" {
  local q h p dir="$BATS_TEST_TMPDIR/q-dir" html="$XDG_STATE_HOME/vibe/web/index.html"
  mkdir "$dir"
  q="$(gpuq queued a "$dir")" h="$(gpuq held b "$dir")" p="$(gpuq parked c "$dir")"
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 1 on the GPU · 0 queued · 0 to review · 0 no PR · 4 slots" ]
  grep -qxF "  $q  queued" <<<"$output"
  grep -qxF "  $h  held" <<<"$output"
  grep -qxF "  $p  parked" <<<"$output"
  [ "$(grep -cxF "    $(cd "$dir" && pwd)" <<<"$output")" -eq 3 ]
  [ "$(grep -cxF '    cmd: true' <<<"$output")" -eq 3 ]
  [ "$(grep -cE '^ +(log|then|wandb):' <<<"$output")" -eq 0 ]
  run "$VIBE" queue page
  [ "$status" -eq 0 ]
  [[ "$(sec queued)" == *"data-k=\"$q\""* ]] || false
  [[ "$(sec held)" == *"data-k=\"$h\""*"data-k=\"$p\""* ]] || false
  grep -qF '<span class="pill">On hold</span>' "$html"
  grep -qF '<span class="pill">Waits for the GPU</span>' "$html"
  [ "$(grep -o 'class="job s-held"' "$html" | wc -l)" -eq 2 ]
}

@test "status: the 3 latest finished outside runs show exit code and end time and do not count on the GPU; the run of a live or an archived job stays out" {
  local r id1 id2 id3 id4 own arch html="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  id1="$(gpuq_end 1 5)" id2="$(gpuq_end 2 0)" id3="$(gpuq_end 3 1)" id4="$(gpuq_end 4 cancelled)" own="$(gpuq_end 5 0)" arch="$(gpuq_end 6 0)"
  mkjob 01-a "$r" task-a ok
  echo "$own" >"$Q/01-a/gpu-job"
  endjob 02-b "$r" task-b
  echo "$arch" >"$Q/02-b/gpu-job"
  run "$VIBE" queue archive 02-b
  [ "$status" -eq 0 ]
  [ -f "$XDG_STATE_HOME/vibe/archive/$(date +%Y-%m)/02-b/gpu-job" ]
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<<"$output")" = "queue: 0 running · 0 on the GPU · 1 queued · 0 to review · 0 no PR · 4 slots" ]
  [ "$(sed -n 3,6p <<<"$output")" = "GPU
  $id2  exit 0 · 2026-11-12 12:02
  $id3  exit 1 · 2026-11-13 12:03
  $id4  exit cancelled · 2026-11-14 12:04" ]
  [ "$(grep -cE "$id1|$own|$arch" <<<"$output")" -eq 0 ]
  run "$VIBE" queue page
  [ "$status" -eq 0 ]
  [ "$(sec "done" | grep -o '<div class="row"' | wc -l)" -eq 3 ]
  grep -qF "<div class=\"row\" data-k=\"$id3\"><i class=\"lamp l-done\"></i><a class=\"t\" href=\"#job-$id3\"><b>GPU run · ${id3#*-*-*-}</b><span class=\"why\">Failed, exit 1 · 2026-11-13 12:03</span></a></div>" "$html"
  grep -qF '<span class="pill">Failed, exit 1</span></div><p>2026-11-13 12:03</p>' "$html"
  grep -qF '<span class="pill">Finished</span></div><p>2026-11-12 12:02</p>' "$html"
  grep -qF '<span class="pill">Cancelled</span></div><p>2026-11-14 12:04</p>' "$html"
  [ "$(grep -cE "$id1|$own|$arch" "$html")" -eq 0 ]
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

# pandoc_stub OK|FAIL — a pandoc that prints a marker, or one that fails.
pandoc_stub() {
  if [ "$1" = OK ]; then
    printf '#!/bin/sh\ncat >/dev/null\necho "<p>PANDOC</p>"\n' >"$STUBS/pandoc"
  else
    printf '#!/bin/sh\nexit 1\n' >"$STUBS/pandoc"
  fi
  chmod +x "$STUBS/pandoc"
}

@test "page: the runner writes job cards with escaped text" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  pandoc_stub OK
  mkjob 20261029-081414-proj-task-a "$r" task-a blocked
  drain
  mkjob 20261029-081415-proj-task-b "$r" task-b ok 'context=<b>A & B</b>'
  "$VIBE" queue pause >/dev/null
  drain
  [ "$status" -eq 0 ]
  grep -qF '<div class="job s-blocked"><div class="top"><b>task-a</b><span class="pill">Has a question</span>' "$f"
  grep -qF '<b>task-b</b><span class="why">&lt;b&gt;A &amp; B&lt;/b&gt; · proj</span>' "$f"
  grep -qF '<div class="task"><h3>Task</h3><p>&lt;b&gt;A &amp; B&lt;/b&gt;</p></div>' "$f"
  grep -qF '<details class="sec" data-k="queued"><summary>Queued <span class="n">1</span></summary>' "$f"
  run grep -c '<b>A &' "$f"
  [ "$output" = 0 ]
  [ ! -e "$f.tmp" ]
}

@test "page: raw HTML in a held job's note shows as text, in a triage line as code" {
  command -v pandoc >/dev/null || skip "pandoc not installed"
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  mkjob 20261029-081414-proj-task-a "$r" task-a blocked
  drain
  [ "$status" -eq 0 ]
  "$VIBE" queue hold 20261029-081414-proj-task-a '<img src=x onerror=alert(1)> and <script>alert(2)</script>' >/dev/null
  printf -- '- see <img src=y onerror=alert(3)>\n' >"$XDG_STATE_HOME/vibe/triage.md"
  "$VIBE" queue page
  grep -qF '<span class="why">&lt;img src=x onerror=alert(1)&gt; and &lt;script&gt;alert(2)&lt;/script&gt; · proj</span>' "$f"
  grep -qF '<code>&lt;img src=y onerror=alert(3)&gt;</code>' "$f"
  run grep -c '<img\|<script>alert' "$f"
  [ "$output" = 0 ]
}

@test "page: a link or image with a javascript: or data: target in a triage line shows as text" {
  command -v pandoc >/dev/null || skip "pandoc not installed"
  local f="$XDG_STATE_HOME/vibe/web/index.html"
  echo '- [bad](javascript:alert(1)) ![pic](data:text/html,x) <javascript:alert(2)> [ok](https://example.com/ok)' >"$XDG_STATE_HOME/vibe/triage.md"
  "$VIBE" queue page
  grep -qF 'href="https://example.com/ok"' "$f"
  grep -qF 'bad pic javascript:alert(2)' "$f"
  run grep -c 'href="javascript\|src="data' "$f"
  [ "$output" = 0 ]
}

@test "page: triage lines are escaped Markdown in <pre> with no working pandoc, file links as text; a held row shows its note" {
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
  "$VIBE" queue hold 01-a look at it >/dev/null
  printf '## Triage — now\n\n- proj [#1](https://example.com/pull/1): CI red: test\n' >"$XDG_STATE_HOME/vibe/triage.md"
  "$VIBE" queue page
  grep -qF '<span class="why">look at it · proj</span>' "$f"
  grep -qF -- '- proj [#1](https://example.com/pull/1): CI red: test' "$f"
  grep -qF '<tr><td>health</td><td>weekly · sun</td><td>never</td><td>' "$f"
  run grep -c 'file:' "$f"
  [ "$output" = 0 ]
}

@test "page: a job with a log has an Activity part for page.js to fill; the page holds no log text" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  mkjob 02-b "$r" task-b ok
  echo running >"$Q/01-a/status"
  echo running >"$Q/02-b/status"
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/<y>.md"}}]}}\n' >"$Q/01-a/log"
  "$VIBE" queue page >/dev/null
  grep -qF '<div class="act" data-id="01-a"><h3>Activity</h3><ol></ol></div></div>' "$f"
  [ "$(grep -c 'class="act"' "$f")" = 1 ]
  run grep -c '&lt;y&gt;\|<y>' "$f"
  [ "$output" = 0 ]
}

@test "page: a lane is one row with its progress; its block holds the next item, the item out of the lane and a job card per job; a done job shows its cost" {
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
  grep -qF '<div class="job lane s-blocked"><div class="top"><b>lane-x</b><span class="pill">1 of 3 items</span></div><p class="steps">' "$f"
  grep -qF '<p>Fix health <a href="https://example.com/pull/1">PR</a></p><p>next: gamma</p><p>02-b · Has a question: beta needs a decision → lane-x-beta</p>' "$f"
  run grep -c '<b>01-a</b>\|<b>03-c</b>' "$f"
  [ "$output" = 0 ]
  grep -qF '<details class="stack"><summary>3 jobs</summary><div class="job s-done"><div class="top"><b>alpha</b><span class="pill">Done</span></div><p>alpha.txt added' "$f"
  grep -qF '<div class="job s-blocked"><div class="top"><b>beta</b><span class="pill">Has a question</span></div><p>beta needs a decision → lane-x-beta' "$f"
  grep -qF '<div class="job s-queued"><div class="top"><b>gamma</b><span class="pill">Queued</span></div><p>Waits for a free slot.</p><div class="jacts" data-id="03-c"><button data-act="now">Start next</button><hr><button data-act="cancel" data-confirm>Cancel</button></div></div></details></div>' "$f"
  # shellcheck disable=SC2016  # a literal $ in the expected text
  grep -qF '<p class="stats">≈$1.50 API · 7 turns · 2m</p>' "$f"
  grep -qF '<div class="row" data-k="proj/lane-x"><i class="lamp l-bad"></i><a class="t" href="#job-proj/lane-x"><b>lane-x <span class="n">1 of 3 items</span></b><span class="why">02-b · Has a question: beta needs a decision → lane-x-beta · proj</span></a></div>' "$f"
  grep -qF '<div class="blk" id="job-proj/lane-x" hidden><div class="bh"><i class="lamp l-bad"></i><span class="st" title="One of its items needs your answer or your check.">Needs you</span><h2>lane-x <span class="n">1 of 3 items</span></h2><code class="meta">proj</code></div><div class="job lane s-blocked">' "$f"
}

# acts_of LINE — the buttons, empty rows, labels and file lines of one button group, in page order.
acts_of() { printf '%s' "$1" | grep -o '<hr>\|data-act="[a-z-]*"\|class="lbl"\|class="files"' | sed 's/data-act=//; s/"//g; s/class=//' | paste -sd' ' -; }

@test "page: each button group is fields first, then write, an empty row and the data-confirm buttons; the file links after it" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" top card
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
  top="$(grep '^<section class="sec"><h2>Rescue</h2>' "$f")"
  [ "$(acts_of "$top")" = 'restart' ]
  card="$(grep 'data-id="01-a"' "$f")"
  [ "$(acts_of "${card#*<div class=\"jacts\" data-id=\"01-a\"}")" = 'now <hr> cancel' ]
  card="$(grep 'data-id="02-b"' "$f")"
  [ "$(acts_of "${card#*<div class=\"jacts\" data-id=\"02-b\"}")" = 'retry hold archive files' ]
  grep -qF '<button data-act="archive" data-confirm>Archive</button></div><div class="files" data-id="02-b"><h3>Files</h3><p><a href="/queue/api/job/02-b/report.md">Report</a><a href="/queue/api/job/02-b/log">Full log</a></p></div>' "$f"
  # A recurring job's row has its own .jacts: page.js sends data-repo and data-job from the nearest one.
  grep -qF "<td><div class=\"jacts\" data-repo=\"$r\" data-job=\"codebase-health\"><button data-act=\"run\">Run</button><button data-act=\"reset\">Reset</button></div></td></tr></table></div></section>" "$f"
}

@test "page: each row links to a hidden block of its own in the panel, one per line; rows hold no fold" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" k n=0
  r="$(make_repo proj)"
  you_jobs "$r"
  "$VIBE" queue page >/dev/null
  while IFS= read -r k; do
    grep -qF "<div class=\"row\" data-k=\"$k\"><i class=\"lamp l-" "$f"
    grep -qF "<a class=\"t\" href=\"#job-$k\">" "$f"
    [ "$(grep -c "^<div class=\"blk\" id=\"job-$k\" hidden>" "$f")" = 1 ]
    n=$((n + 1))
  done < <(grep -o '<div class="row" data-k="[^"]*">' "$f" | sed 's/.*data-k="//; s/">//')
  [ "$n" -eq 15 ]
  [ "$(grep -c '^<div class="blk" id="job-' "$f")" = 15 ]
  # The blocks sit in the panel, the last part of main.
  [ "$(grep -n '^<div class="blk" id="job-' "$f" | head -1 | cut -d: -f1)" -gt "$(grep -n '^<dialog id="panel"' "$f" | cut -d: -f1)" ]
  [ "$(grep -n '^<div class="blk" id="job-' "$f" | tail -1 | cut -d: -f1)" -lt "$(grep -n '^</main>' "$f" | cut -d: -f1)" ]
  run grep -c '<details class="row"\|<summary><i class="lamp' "$f"
  [ "$output" = 0 ]
  # The head: lamp, state, title, meta line; the reason a done job needs you is its state.
  grep -qF '<div class="blk" id="job-09-rev" hidden><div class="bh"><i class="lamp l-you"></i><span class="st" title="It opened a draft PR: review it on GitHub.">PR #9 to review</span><h2>09-rev</h2><code class="meta">proj · b09</code></div>' "$f"
  grep -qF '<div class="blk" id="job-07-pus" hidden><div class="bh"><i class="lamp l-bad"></i><span class="st" title="The runner could not push the branch or open the PR.">push failed</span>' "$f"
  # Put on hold shares the note field of a failed, timed-out, skipped or blocked job; a done or a held job has none.
  grep -qF '<div class="jacts" data-id="02-fai"><span class="ask note"><label>Note: optional for Run again, needed for Put on hold<textarea name="note" rows="3" data-opt></textarea></label><button data-act="retry">Run again</button><button data-act="hold" data-need>Put on hold</button></span>' "$f"
  grep -qF '<div class="jacts" data-id="01-blk"><span class="ask note"><label>Note: your answer to its question<textarea name="note" rows="3"></textarea></label>' "$f"
  [ "$(grep -o 'data-act="hold"' "$f" | wc -l)" -eq 4 ]
  grep -qF '<div class="jacts" data-id="10-don"><button data-act="archive" data-confirm>Archive</button></div>' "$f"
  run grep -c 'data-ask=' "$f"
  [ "$output" = 0 ]
}

@test "page: Settings holds Slots, the usage limit, any key=value and the restarts; Recurring per repo its jobs with Run, Skip or Undo, and Reset when stopped; no page actions" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" i
  r="$(make_repo proj)"
  pandoc_stub FAIL
  mkdir -p "$r/.vibe-jobs" "$XDG_STATE_HOME/vibe/jobs/proj/health"
  printf -- '---\nschedule: weekly\nday: sun\noutput: pr\n---\n\nCheck.\n' >"$r/.vibe-jobs/health.md"
  printf -- '---\nschedule: monthly\noutput: report\n---\n\nAudit <it>.\n' >"$r/.vibe-jobs/audit.md"
  echo 2 >"$XDG_STATE_HOME/vibe/jobs/proj/health/fails"
  echo proj >"${CONF%/*}/repos"
  VIBE_ROOT="$BATS_TEST_TMPDIR" "$VIBE" queue page >/dev/null
  [ "$(grep -oE '^<section class="sec"><h2>[A-Za-z ]+</h2>' "$f" | sed 's/.*<h2>//; s#</h2>##' | paste -sd, -)" = 'proj,Queue,Rescue,Session servers' ]
  # Slots: page.js sends slots=<n> to route conf.
  grep -qF '<b>Slots</b><p>Jobs that run at the same time.</p></div><div class="jacts"><span class="ask"><input name="set" data-pre="slots=" type="number" min="1" value="4" aria-label="Slots"><button data-act="conf">Set</button></span></div>' "$f"
  grep -qF '<b>Other setting</b><p>A key=value line in ' "$f"
  grep -qF '<input name="set" placeholder="key=value" aria-label="Setting"><button data-act="conf">Set</button>' "$f"
  grep -qF '<button data-act="restart" data-confirm>Restart queue runner</button>' "$f"
  # Per repo a table: job, schedule, last run, state, Run; Skip for a due job, Reset for the stopped job.
  grep -qF "<section class=\"sec\"><h2>proj</h2><div class=\"card\"><table><tr><th>Job</th><th>Schedule</th><th>Last run</th><th>State</th><th></th></tr><tr><td>audit</td><td>monthly</td><td>never</td><td>due</td><td><div class=\"jacts\" data-repo=\"$r\" data-job=\"audit\"><button data-act=\"run\">Run</button><button data-act=\"skip\">Skip</button></div></td></tr><tr><td>health</td><td>weekly · sun</td><td>never</td><td>stopped</td><td><div class=\"jacts\" data-repo=\"$r\" data-job=\"health\"><button data-act=\"run\">Run</button><button data-act=\"reset\">Reset</button></div></td></tr></table></div></section>" "$f"
  for i in $(seq -w 1 25); do printf '2026-11-16 10:00:%s\tme\tvibe queue pause\t0\n' "$i" >>"$XDG_STATE_HOME/vibe/actions.log"; done
  VIBE_ROOT="$BATS_TEST_TMPDIR" "$VIBE" queue page >/dev/null
  run grep -c 'Page actions\|2026-11-16 10:00' "$f"
  [ "$output" = 0 ]
  # Recurring and Settings stay out of the Jobs list and the panel; no button asks with prompt().
  [ "$(grep -n '^<section id="settings" class="page">' "$f" | cut -d: -f1)" -gt "$(grep -n '^<section id="recurring" class="page">' "$f" | cut -d: -f1)" ]
  [ "$(grep -n '^<section id="recurring" class="page">' "$f" | cut -d: -f1)" -gt "$(grep -n '^<div id="jobs" class="page">' "$f" | cut -d: -f1)" ]
  run grep -c 'data-ask=' "$f"
  [ "$output" = 0 ]
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

# you_jobs REPO — one item per Needs-you rule, and one each for Done, Running, Queued and Held.
you_jobs() {
  local r="$1" id
  for id in 01-blk:blocked 02-fai:failed 03-tim:timeout 04-ski:skipped 11-run:running; do
    mkjob "${id%:*}" "$r" "b${id%:*}" ok
    echo "${id#*:}" >"$Q/${id%:*}/status"
  done
  endjob 05-gat "$r" b05 https://example.com/pull/5
  echo 2 >"$Q/05-gat/gate"
  endjob 06-ver "$r" b06
  echo fail >"$Q/06-ver/verify"
  endjob 07-pus "$r" b07 "push failed"
  endjob 08-npr "$r" b08 "PR not created"
  endjob 09-rev "$r" b09 https://example.com/pull/9
  endjob 10-don "$r" b10
  mkjob 12-que "$r" b12 ok
  endjob 13-hel "$r" b13
  "$VIBE" queue hold 13-hel "my note" >/dev/null
  putfeature ft "$BATS_TEST_TMPDIR/vla node https://example.com/pull/7"
  putfeature fm "$BATS_TEST_TMPDIR/vlb node https://example.com/pull/8"
  touch "$XDG_STATE_HOME/vibe/features/fm.ready"
}

# sec SECTION — the page's line of one section: you run queued held triage done.
sec() { grep -E "^<(section|details) class=\"sec\" data-k=\"$1\">" "$XDG_STATE_HOME/vibe/web/index.html" || true; }

# prim KEY — the data-act of the buttons in a row, or the text of its link (Open PR, Answer, Fix); empty for none.
prim() {
  grep -o "<div class=\"row\" data-k=\"$1\">.*" "$XDG_STATE_HOME/vibe/web/index.html" | sed 's#</div>.*##' |
    grep -o 'data-act="[a-z-]*"\|>Open PR\|>Answer<\|>Fix<' | sed 's/data-act=//; s/"//g; s/[<>]//g' | paste -sd' ' - || true
}

@test "page: six sections, no repo groups; each item in one, by the Needs-you rules; tab title and Jobs count" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" id
  r="$(make_repo proj)"
  you_jobs "$r"
  "$VIBE" queue page >/dev/null
  for id in 01-blk 02-fai 03-tim 04-ski 05-gat 06-ver 07-pus 08-npr 09-rev feature/ft feature/fm; do
    [[ "$(sec you)" == *"<div class=\"row\" data-k=\"$id\">"* ]] || false
  done
  [ "$(sec you | grep -o '<div class="row"' | wc -l)" -eq 11 ]
  grep -qF '<section class="sec" data-k="you"><h2>Needs you <span class="n">11</span></h2>' "$f"
  grep -qF '<section class="sec" data-k="run"><h2>Running <span class="n">1</span></h2><div class="card"><div class="row" data-k="11-run">' "$f"
  grep -qF '<details class="sec" data-k="queued"><summary>Queued <span class="n">1</span></summary><div class="row" data-k="12-que">' "$f"
  grep -qF '<details class="sec" data-k="held"><summary>On hold <span class="n">1</span></summary><div class="row" data-k="13-hel"><i class="lamp l-held"></i><a class="t" href="#job-13-hel"><b>13-hel</b><span class="why">my note · proj</span>' "$f"
  grep -qF '<details class="sec" data-k="done"><summary>Done <span class="n">1</span></summary><div class="row" data-k="10-don">' "$f"
  # The reason under the title, then the repo; no repo group.
  grep -qF '<div class="row" data-k="05-gat"><i class="lamp l-bad"></i><a class="t" href="#job-05-gat"><b>05-gat</b><span class="why">Checks failed (exit 2) · proj</span></a>' "$f"
  grep -qF '<span class="why">Verify: fail · proj</span>' "$f"
  grep -qF '<span class="why">push failed · proj</span>' "$f"
  grep -qF '<i class="lamp l-you"></i><a class="t" href="#job-09-rev"><b>09-rev</b><span class="why">PR #9 to review · proj</span>' "$f"
  grep -qF '<b>ft <span class="n">1 of 1 items</span></b><span class="why">Test it yourself · The gamepad drives the robot. · Feature</span></a>' "$f"
  run grep -c '<div class="repo">\|class="chips"\|class="filter"' "$f"
  [ "$output" = 0 ]
  grep -qF '<title>(11) vibe</title>' "$f"
  grep -qF '<a class="tj" href="#jobs">Jobs<span class="n">11</span></a>' "$f"
  # PR problems: folded, only with triage.md.
  [ -z "$(sec triage)" ]
  printf '## Triage — now\n\n- proj #1: CI red\n- proj #2: merged\n' >"$XDG_STATE_HOME/vibe/triage.md"
  "$VIBE" queue page >/dev/null
  [ -n "$(sec triage)" ]
  grep -qF '<details class="sec" data-k="triage"><summary>PR problems <span class="n">2</span></summary><div class="md">' "$f"
  [ "$(grep -oE '^<[a-z]+ class="sec" data-k="[a-z]+"' "$f" | sed 's/.*data-k=//; s/"//g' | paste -sd' ' -)" = 'you run queued held triage done' ]
}

@test "page: with nothing to do, Needs you and Running say so, the folded sections go and the tab title has no count" {
  local f="$XDG_STATE_HOME/vibe/web/index.html"
  "$VIBE" queue page >/dev/null
  grep -qF '<h2>Needs you <span class="n">0</span></h2><div class="card"><p class="none">Nothing needs you.</p></div>' "$f"
  grep -qF '<h2>Running <span class="n">0</span></h2><div class="card"><p class="none">No job runs.</p></div>' "$f"
  [ "$(grep -c '<details class="sec"' "$f")" = 0 ]
  grep -qF '<title>vibe</title>' "$f"
  grep -qF '<a class="tj" href="#jobs">Jobs<span class="n"></span></a>' "$f"
  [ "$(grep -c 'class="folds' "$f")" = 0 ]
}

@test "page: one primary button per row: Answer, Run again, Open PR, Test passed, Archive, else none; Answer opens the block; the rest in the block" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" x
  r="$(make_repo proj)"
  you_jobs "$r"
  "$VIBE" queue page >/dev/null
  [ "$(prim 01-blk)" = Answer ]
  [ "$(prim 02-fai)" = retry ]
  [ "$(prim 03-tim)" = retry ]
  [ "$(prim 04-ski)" = retry ]
  [ "$(prim 05-gat)" = "Open PR" ]
  [ "$(prim 06-ver)" = "" ]
  [ "$(prim 07-pus)" = "" ]
  [ "$(prim 09-rev)" = "Open PR" ]
  [ "$(prim 10-don)" = archive ]
  [ "$(prim 11-run)" = "" ]
  [ "$(prim 12-que)" = "" ]
  [ "$(prim 13-hel)" = "" ]
  [ "$(prim feature/ft)" = feature-ready ]
  [ "$(prim feature/fm)" = feature-archive ]
  # Answer needs text: the row links to the block, whose field holds it. No Fix: a /fix comment on the PR starts one.
  run grep -c 'data-act="fix"\|>Fix<' "$f"
  [ "$output" = 0 ]
  grep -qF '<div class="jacts" data-id="01-blk"><span class="ask note"><label>Note: your answer to its question<textarea name="note" rows="3"></textarea></label><button data-act="retry">Run again</button>' "$f"
  grep -qF '<a class="btn" href="https://example.com/pull/9" target="_blank" rel="noopener">Open PR ↗</a></div>' "$f"
  grep -qF '<span class="jacts p" data-feature="ft"><button data-act="feature-ready" data-confirm' "$f"
  # The block keeps the card's buttons; no Merge order.
  grep -qF '<div class="blk" id="job-12-que" hidden><div class="bh"><i class="lamp l-off"></i><span class="st" title="It waits for a free slot or for its start time.">Queued</span><h2>12-que</h2><code class="meta">proj · b12</code></div><div class="job s-queued"><div class="top"><b>12-que</b><span class="pill">Queued</span></div><p class="steps">' "$f"
  grep -qF '○ PR</span></p><p>Waits for a free slot.</p><div class="jacts" data-id="12-que"><button data-act="now">' "$f"
  run grep -c 'merge-order' "$f"
  [ "$output" = 0 ]
  # A row's button and its block's button share one markup.
  for x in retry archive feature-ready; do
    [ "$(grep -o "<button data-act=\"$x\"[^>]*>[^<]*</button>" "$f" | sort -u | wc -l)" -eq 1 ]
  done
  # A done job and its review round are a lane with no running job.
  endjob 14-lan "$r" b14
  endjob 14-lan-review1 "$r" b14 https://example.com/pull/14
  "$VIBE" queue page >/dev/null
  [ "$(prim proj/b14)" = "Open PR" ]
}

@test "page: a branch of jobs shows the first open milestone of its newest job's SPEC.md, else N of M jobs; a lane counts items" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" w0="$BATS_TEST_TMPDIR/w0" w1="$BATS_TEST_TMPDIR/w1"
  r="$(make_repo proj)"
  mkdir -p "$w0" "$w1"
  printf -- '- [ ] only\n' >"$w0/SPEC.md"
  printf -- '# Spec\n\n- [x] a\n- [ ] b\n- [x] c\n' >"$w1/SPEC.md"
  endjob 01-a "$r" b01
  echo "$w0" >"$Q/01-a/worktree"
  mkjob 01-a-review1 "$r" b01 ok
  echo running >"$Q/01-a-review1/status"
  echo "$w1" >"$Q/01-a-review1/worktree"
  endjob 02-b "$r" b02
  endjob 02-b-review1 "$r" b02
  endjob 03-c "$r" b03 "" "lane=Ports" item=alpha
  mkjob 03-d "$r" b03 ok "lane=Ports" item=beta
  echo "$w1" >"$Q/03-d/worktree"
  "$VIBE" queue page >/dev/null
  grep -qF '<b>b01 <span class="n">Milestone 2 of 3</span></b>' "$f"
  grep -qF '<b>b02 <span class="n">2 of 2 jobs</span></b>' "$f"
  grep -qF '<b>b03 <span class="n">1 of 2 items</span></b>' "$f"
  # Every box ticked: the last one.
  printf -- '- [x] a\n- [x] b\n' >"$w1/SPEC.md"
  "$VIBE" queue page >/dev/null
  grep -qF '<b>b01 <span class="n">Milestone 2 of 2</span></b>' "$f"
}

@test "page: a lane or feature that needs you names the item that blocks it; a done lane job with a failed gate needs you, with Open PR" {
  local r r2 f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)" r2="$(make_repo cmdr)"
  # A done job with a failed gate and a PR, then its done review round: one lane row with no running job.
  endjob 15-gat "$r" b15 https://example.com/pull/15
  echo 2 >"$Q/15-gat/gate"
  endjob 15-gat-review1 "$r" b15
  # A lane item that failed: its id, status and note are the reason, not the lane's context.
  endjob 16-a "$r" b16 "" "lane=Fix health" item=alpha
  endjob 16-b "$r" b16 "" "lane=Fix health" item=beta
  echo failed >"$Q/16-b/status"
  echo "tests red" >"$Q/16-b/note"
  mkjob 17-c "$r2" b17 ok
  echo blocked >"$Q/17-c/status"
  echo "blocked: which port?" >"$Q/17-c/note"
  putfeature fx "$r2 b17"
  "$VIBE" queue page >/dev/null
  grep -qF '<div class="row" data-k="proj/b15"><i class="lamp l-bad"></i><a class="t" href="#job-proj/b15"><b>b15 <span class="n">2 of 2 jobs</span></b><span class="why">15-gat: Checks failed (exit 2) · proj</span></a><a class="btn" href="https://example.com/pull/15" target="_blank" rel="noopener">Open PR ↗</a></div>' "$f"
  grep -qF '<div class="blk" id="job-proj/b15" hidden><div class="bh"><i class="lamp l-bad"></i><span class="st" title="The checks of the repo (.vibe-jobs/gate) failed: read the Checks log.">15-gat: Checks failed (exit 2)</span><h2>b15 <span class="n">2 of 2 jobs</span></h2><code class="meta">proj</code></div><div class="job lane' "$f"
  [[ "$(sec you)" == *'data-k="proj/b15"'* ]] || false
  grep -qF '<div class="row" data-k="proj/b16"><i class="lamp l-bad"></i><a class="t" href="#job-proj/b16"><b>b16 <span class="n">1 of 2 items</span></b><span class="why">16-b · Failed: tests red · proj</span>' "$f"
  grep -qF '<div class="row" data-k="feature/fx"><i class="lamp l-bad"></i><a class="t" href="#job-feature/fx"><b>fx <span class="n">0 of 1 items</span></b><span class="why">cmdr · b17 · Has a question: which port? · Feature</span>' "$f"
}

@test "page: a running lane needs you while an item is blocked or a done item's gate failed; a held item leaves it in Running" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  endjob 18-a "$r" b18 "" "lane=Ports" item=alpha
  echo blocked >"$Q/18-a/status"
  echo "blocked: which port?" >"$Q/18-a/note"
  mkjob 18-b "$r" b18 ok "lane=Ports" item=beta
  echo running >"$Q/18-b/status"
  "$VIBE" queue page >/dev/null
  [[ "$(sec you)" == *'<div class="row" data-k="proj/b18"><i class="lamp l-bad"></i><a class="t" href="#job-proj/b18"><b>b18 <span class="n">'*'</span></b><span class="why">18-a · Has a question: which port? · proj</span></a>'* ]] || false
  [[ "$(sec run)" != *'data-k="proj/b18"'* ]] || false
  grep -qF '<title>(1) vibe</title>' "$f"
  # A done item whose gate failed, while the next item runs.
  echo "done" >"$Q/18-a/status"
  echo 2 >"$Q/18-a/gate"
  "$VIBE" queue page >/dev/null
  [[ "$(sec you)" == *'data-k="proj/b18"'*'<span class="why">18-a: Checks failed (exit 2) · proj</span>'* ]] || false
  # A held item is yours already: the lane stays in Running.
  rm "$Q/18-a/gate"
  echo blocked >"$Q/18-a/status"
  "$VIBE" queue hold 18-a "ask the robot team" >/dev/null
  "$VIBE" queue page >/dev/null
  [[ "$(sec run)" == *'<div class="row" data-k="proj/b18"><i class="lamp l-ok"></i>'* ]] || false
  grep -qF '<h2>Needs you <span class="n">0</span></h2>' "$f"
}

@test "page: a running row names its repo, its running step and its tool, and shows its run time; no row has a phase bar" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" t
  r="$(make_repo proj)"
  phase_jobs "$r"
  t=$(($(date +%s) - 4500))
  { date -d "@$t" '+%F %T' 2>/dev/null || date -r "$t" '+%F %T'; } >"$Q/06-f/started"
  mkjob 08-t "$r" task-t ok tool=kapso place=turing
  echo running >"$Q/08-t/status"
  "$VIBE" queue page >/dev/null
  grep -qF '<b>task-a <span class="n">2 of 3 jobs</span></b><span class="why">proj · Review 2</span></a></div>' "$f"
  grep -qF '<b>06-f</b><span class="why">proj · Checks</span></a><span class="el">1:15</span></div>' "$f"
  grep -qF '<b>08-t</b><span class="why">proj · Work · kapso · turing</span></a></div>' "$f"
  # The block's meta line: repo, branch, tool, run time; the result line: since when it runs.
  grep -qF '<div class="blk" id="job-08-t" hidden><div class="bh"><i class="lamp l-ok"></i><span class="st" title="An agent works on it now.">Running</span><h2>08-t</h2><code class="meta">proj · task-t · kapso · turing</code>' "$f"
  grep -qE '<div class="blk" id="job-06-f" hidden><div class="bh"><i class="lamp l-ok"></i><span class="st" title="An agent works on it now.">Running</span><h2>06-f</h2><code class="meta">proj · [a-z0-9-]+ · 1:15</code>' "$f"
  grep -qF "<p>Runs since $(cut -c 12-16 "$Q/06-f/started").</p>" "$f"
  [ "$(grep -c 'class="pbar"' "$f")" = 0 ]
}

@test "page: Geist fonts copied next to the page and loaded from it; a stale copy is replaced; no zoom; sizes 12 to 24 px; red only in the glider" {
  local f="$XDG_STATE_HOME/vibe/web/index.html" w="$XDG_STATE_HOME/vibe/web/fonts" x
  "$VIBE" queue page >/dev/null
  for x in Geist-Variable.woff2 GeistMono-Variable.woff2 LICENSE.txt; do cmp "$REPO_ROOT/templates/fonts/$x" "$w/$x"; done
  grep -qF '@font-face { font-family: "Geist"; src: url("/queue/fonts/Geist-Variable.woff2") format("woff2");' "$f"
  grep -qF '@font-face { font-family: "Geist Mono"; src: url("/queue/fonts/GeistMono-Variable.woff2") format("woff2");' "$f"
  echo junk >"$w/Geist-Variable.woff2"
  touch -t 200001010000 "$w/Geist-Variable.woff2"
  "$VIBE" queue page >/dev/null
  cmp "$REPO_ROOT/templates/fonts/Geist-Variable.woff2" "$w/Geist-Variable.woff2"
  run grep -c 'zoom\|fonts.googleapis' "$f"
  [ "$output" = 0 ]
  run bash -c "grep -oE 'font(-size)?: ([0-9]+ )?[0-9.]+px' '$f' | grep -oE '[0-9.]+px\$' | grep -vxE '1[2346]px|24px'"
  [ "$output" = "" ]
  grep -qF -- '--bg: #eef1f3;' "$f"
  grep -qF -- '--bg: #0e1317;' "$f"
  [ "$(grep 'var(--red)' "$f" | grep -vc '^\.brand svg ')" = 0 ]
}

@test "page: the header holds the lamp, jobs that run of the slots, the limit and Runner stopped; Pause or Resume; Clear usage limit in Settings only while limited" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html" lim
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  echo running >"$Q/01-a/status"
  "$VIBE" queue page >/dev/null
  grep -qE '<span class="stat"><i class="lamp l-ok"></i><span>1 of 4 jobs run<span class="more"></span></span><span class="updated" data-t="[0-9]+">Runner stopped</span></span><span class="jacts"><button data-act="pause">Pause</button></span></div></header>' "$f"
  grep -qF '<b>Claude usage limit</b><p>None now.</p></div></div>' "$f"
  [ "$(grep -c 'data-act="unlimit"' "$f")" = 0 ]
  "$VIBE" queue pause >/dev/null
  echo $(($(date +%s) + 60)) >"$XDG_STATE_HOME/vibe/limit"
  "$VIBE" queue page >/dev/null
  grep -qE '<i class="lamp l-bad"></i><span>1 of 4 jobs run<span class="more"> · paused · Claude usage limit, resets [0-9]{2}:[0-9]{2}</span></span><span class="updated"' "$f"
  grep -qF '<span class="jacts"><button data-act="resume">Resume</button></span></div></header>' "$f"
  grep -qE '<b>Claude usage limit</b><p>Reached: resets [0-9-]+ [0-9:]+\.</p></div><div class="jacts"><button data-act="unlimit">Clear usage limit</button></div>' "$f"
  # A weekly limit resets days later: the header keeps the date.
  lim=$(($(date +%s) + 3 * 86400))
  echo "$lim" >"$XDG_STATE_HOME/vibe/limit"
  "$VIBE" queue page >/dev/null
  grep -qF "Claude usage limit, resets $(date -d "@$lim" '+%F %H:%M' 2>/dev/null || date -r "$lim" '+%F %H:%M')</span></span><span class=\"updated\"" "$f"
}

@test "report: header, held jobs under Yours, per repo tables, next actions; writes no file" {
  local r before
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
  before="$(find "$XDG_STATE_HOME" "$XDG_CONFIG_HOME" | sort)"
  run "$VIBE" queue report
  [ "$status" -eq 0 ]
  [ "$(find "$XDG_STATE_HOME" "$XDG_CONFIG_HOME" | sort)" = "$before" ]
  [[ "$output" == "# Vibe queue — "* ]] || false
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

@test "cost: the PR footer and the report row show the API price, turns and minutes" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a cost
  drain
  [ "$status" -eq 0 ]
  grep -qF -- "_agent job 01-a: done: costed · ≈\$1.04 API · 40 turns · 11m_" "$Q/01-a/pr-body.md"
  run "$VIBE" queue report
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 01-a | done |"*"≈\$1.04 API · 40 turns · 11m |"* ]] || false
  [[ "$output" != *"5h est."* ]] || false
}

@test "cost: the limit share is the job cost over the cost of the jobs it overlaps, scaled by overlap time" {
  local r f
  r="$(make_repo proj)"
  endedjob 01-a "$r" 10:00:00 10:09:59 1 0.40 0.48
  endedjob 02-b "$r" 10:00:00 10:09:59 3 0.40 0.48
  f="$BATS_TEST_TMPDIR/report.md"
  "$VIBE" queue report >"$f"
  grep -F '| 01-a |' "$f" | grep -qF "≈\$1.00 API · ≈2% 5h est. · 3 turns · 1m"
  grep -F '| 02-b |' "$f" | grep -qF "≈\$3.00 API · ≈6% 5h est. · 3 turns · 1m"
  # 05-e runs in the last tenth of 03-c and 04-d: its $20 counts for $2.
  endedjob 03-c "$r" 12:00:00 12:09:59 1 0.40 0.48
  endedjob 04-d "$r" 12:00:00 12:09:59 3 0.40 0.48
  endedjob 05-e "$r" 12:09:00 12:18:59 20 0.48 0.50
  "$VIBE" queue report >"$f"
  grep -F '| 03-c |' "$f" | grep -qF '≈1% 5h est.'
  grep -F '| 04-d |' "$f" | grep -qF '≈4% 5h est.'
}

@test "cost: a final job's limit share comes from its cache once no job it overlaps can change" {
  local r f
  r="$(make_repo proj)"
  endedjob 01-a "$r" 10:00:00 10:09:59 1 0.40 0.48
  endedjob 02-b "$r" 10:05:00 10:14:59 3 0.40 0.48
  echo gpu >"$Q/02-b/status"
  f="$BATS_TEST_TMPDIR/report.md"
  "$VIBE" queue report >"$f"
  grep -F '| 01-a |' "$f" | grep -qF '≈3% 5h est.'
  [ ! -e "$Q/01-a/limit-pct" ]
  echo "done" >"$Q/02-b/status"
  "$VIBE" queue report >"$f"
  [ "$(cat "$Q/01-a/limit-pct")" = 3 ]
  # 03-c overlaps 01-a: a new scan would give 01-a ≈0%.
  endedjob 03-c "$r" 10:00:00 10:09:59 20 0.40 0.48
  "$VIBE" queue report >"$f"
  grep -F '| 01-a |' "$f" | grep -qF '≈3% 5h est.'
}

@test "cost: no limit share cache while a job it overlaps is done but has no ended file (queue follow, still publishing)" {
  local r
  r="$(make_repo proj)"
  endedjob 01-a "$r" 10:00:00 10:09:59 1 0.40 0.48
  endedjob 02-b "$r" 10:05:00 10:14:59 3 0.40 0.48
  # 2020: a span open until now overlaps 01-a at any time of day.
  printf '2020-01-01 10:00:00\n' >"$Q/01-a/started" && printf '2020-01-01 10:09:59\n' >"$Q/01-a/ended"
  printf '2020-01-01 10:05:00\n' >"$Q/02-b/started" && rm "$Q/02-b/ended"
  "$VIBE" queue report >/dev/null
  [ ! -e "$Q/01-a/limit-pct" ]
  printf '2020-01-01 10:14:59\n' >"$Q/02-b/ended"
  "$VIBE" queue report >/dev/null
  [ "$(cat "$Q/01-a/limit-pct")" = 3 ]
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
  f="$BATS_TEST_TMPDIR/report.md"
  "$VIBE" queue report >"$f"
  grep -F '| 01-a |' "$f" | grep -qF "≈\$1.00 API · 3 turns"
  grep -F '| 02-b |' "$f" | grep -qF "≈\$1.00 API · 3 turns"
  grep -F '| 05-e |' "$f" | grep -qF "≈\$1.00 API · 3 turns"
  run grep -c '5h est.' "$f"
  [ "$output" = 0 ]
  run grep -F '| 03-c |' "$f"
  [[ "$output" != *"API"* ]] || false
}

@test "cost: the limit share reads no job that ended before the job started or started after it ended" {
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
    mkdir -p "$XDG_STATE_HOME/vibe/archive/2020-01/new-$i"
    echo "$(date +%F) 23:00:00" >"$XDG_STATE_HOME/vibe/archive/2020-01/new-$i/started"
  done
  rm "$Q"/0[12]-*/limit-pct # the scan, not its cache
  : >"$STUBS/date.calls"
  f="$BATS_TEST_TMPDIR/report.md"
  "$VIBE" queue report >"$f"
  n1="$(wc -l <"$STUBS/date.calls")"
  [ "$n1" -eq "$n0" ]
  grep -F '| 01-a |' "$f" | grep -qF '≈2% 5h est.'
}

@test "cost: the report header shows the 5h limit from the newest rate_limit_event" {
  local r at
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a cost
  drain
  run "$VIBE" queue report
  at="$(date -d @1793269800 +%H:%M 2>/dev/null || date -r 1793269800 +%H:%M)"
  [[ "$(sed -n 3p <<<"$output")" == "queue: "*" · limit 5h: 46%, resets $at" ]] || false
  rm "$Q/01-a/log"
  run "$VIBE" queue report
  [[ "$output" != *"limit 5h"* ]] || false
}

@test "docs: the --bare trap is in docs/vibe-queue.md" {
  grep -q -- '--bare' "$REPO_ROOT/docs/vibe-queue.md"
}

@test "report: takes no argument" {
  run "$VIBE" queue report --week
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage: vibe queue report"* ]] || false
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
  [ ! -s "$STUBS/gpu-in-session" ] # vibe queue gpu only asks; the runner submits after the session
  [ "$(cat "$GPU_QUEUE_DIR/queued/$(cat "$Q/01-a/gpu-job")/dir")" = "$(cd "$r/.claude/worktrees/task-a" && pwd)" ]
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
  [ ! -e "$Q/01-a/gpu-cmd" ]
}

@test "gpu: past the job's deadline= it asks for no run; before it the run is asked for" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok "deadline=2000-01-01 08:00"
  VIBE_JOB_DIR="$Q/01-a" run "$VIBE" queue gpu -- true
  [ "$status" -ne 0 ]
  [[ "$output" == *"past this job's deadline (2000-01-01 08:00)"* ]] || false
  [ ! -e "$Q/01-a/gpu-cmd" ]
  mkjob 02-b "$r" task-b ok "deadline=2999-01-01 08:00"
  VIBE_JOB_DIR="$Q/02-b" run "$VIBE" queue gpu -- echo "a b"
  [ "$status" -eq 0 ]
  [ "$(tr '\0' '|' <"$Q/02-b/gpu-cmd")" = "echo|a b|" ]
  [ -z "$(ls "$GPU_QUEUE_DIR/queued" 2>/dev/null)" ]
}

@test "gpu: past the job's deadline= the runner queues no run a job asked for by hand; the job fails" {
  local r
  r="$(make_repo proj)"
  touch "$STUBS/gpu-forge"
  mkjob 01-a "$r" task-a gpu "deadline=2000-01-01 08:00"
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/status")" = failed ]
  [[ "$(cat "$Q/01-a/note")" == "failed: no GPU run asked for"* ]] || false
  [ "$(cat "$Q/01-a/result")" = "$(cat "$Q/01-a/note")" ]
  [ ! -e "$Q/01-a/gpu-job" ]
  [ -z "$(ls "$GPU_QUEUE_DIR/queued" 2>/dev/null)" ]
}

@test "gpu: a run asked for in a session that started before deadline= is queued, though the session ends past it" {
  local r pid
  r="$(make_repo proj)"
  touch "$STUBS/gpu-forge"                         # the ask the session made before the deadline
  echo "2000-01-01 07:55:00" >"$STUBS/gpu-started" # the stub plays the clock: the session started at 07:55
  mkjob 01-a "$r" task-a gpu "deadline=2000-01-01 08:00"
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/run.out" 2>&1 3>&- &
  pid=$!
  for _ in $(seq 1 100); do
    [ "$(cat "$Q/01-a/status" 2>/dev/null)" != gpu ] || break
    sleep 0.1
  done
  [ "$(cat "$Q/01-a/status")" = gpu ]
  [ -d "$GPU_QUEUE_DIR/queued/$(cat "$Q/01-a/gpu-job")" ]
  "$REPO_ROOT/bin/gpu-queue" cancel "$(cat "$Q/01-a/gpu-job")" 2>/dev/null
  wait "$pid"
  [ "$(cat "$Q/01-a/note")" = "GPU run cancelled" ]
}

@test "add, gpu: a deadline= that is not YYYY-MM-DD HH:MM is refused; add refuses a usd= that is no number" {
  local r a
  r="$(make_repo proj)"
  a="$BATS_TEST_TMPDIR/a"
  mkdir -p "$a"
  echo task >"$a/prompt.md"
  printf 'repo=%s\nbranch=x\ndeadline=monday\n' "$r" >"$a/job"
  run "$VIBE" queue add "$a"
  [ "$status" -ne 0 ]
  [[ "$output" == *"deadline=monday — YYYY-MM-DD HH:MM"* ]] || false
  [ -z "$(ls "$Q")" ]
  mkjob 01-a "$r" task-a ok "deadline=2999-13-45 08:00"
  VIBE_JOB_DIR="$Q/01-a" run "$VIBE" queue gpu -- true
  [ "$status" -ne 0 ]
  [ ! -e "$Q/01-a/gpu-job" ]
  printf 'repo=%s\nbranch=x\nusd=abc\n' "$r" >"$a/job"
  run "$VIBE" queue add "$a"
  [ "$status" -ne 0 ]
  [[ "$output" == *"usd=abc — a number of USD or empty"* ]] || false
  [ "$(ls "$Q")" = 01-a ]
  printf 'repo=%s\nbranch=x\ndeadline=2999-01-01 08:00\nusd=2.5\n' "$r" >"$a/job"
  run "$VIBE" queue add "$a"
  [ "$status" -eq 0 ]
}

# two_findings — the stub reviewer's first answer: two findings.
two_findings() {
  printf '%s' '{"type":"result","structured_output":{"findings":[{"file":"work.txt","line":1,"summary":"empty file","failure_scenario":"reads nothing"},{"file":"x.sh","summary":"quote it","failure_scenario":"word split"}]}}' >"$STUBS/review-1.json"
}

@test "review: the prompt names both passes; the rubric reaches the reviewer through a symlink" {
  local link="$BATS_TEST_TMPDIR/link"
  mkdir -p "$link"
  ln -s "$REPO_ROOT/claude/vibe-review.sh" "$link/vibe-review.sh"
  VIBE_JOB_DIR="$BATS_TEST_TMPDIR" run bash "$link/vibe-review.sh" "$BATS_TEST_TMPDIR" proj-review1 sonnet high main
  [ "$status" -eq 0 ]
  grep -q '^Run /code-review high origin/main\.\.\.HEAD\. Then apply the lean-review rubric .* both passes ' "$STUBS/claude.log"
  grep -q '^# Lean review$' "$STUBS/claude.log"
  grep -qF -- "--settings $REPO_ROOT/claude/vibe-job-settings.json " "$STUBS/claude.log"
}

@test "review: PASSES=code runs /code-review only, with no rubric" {
  VIBE_JOB_DIR="$BATS_TEST_TMPDIR" run bash "$REPO_ROOT/claude/vibe-review.sh" "$BATS_TEST_TMPDIR" proj-review1 sonnet high main code
  [ "$status" -eq 0 ]
  grep -qx 'Run /code-review high origin/main\.\.\.HEAD\. Then return its findings through the structured output\.' "$STUBS/claude.log"
  run grep -c 'lean-review\|^# Lean review$' "$STUBS/claude.log"
  [ "$output" = 0 ]
}

@test "review: after=code reaches the reviewer; the PR body says /code-review only" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok after=code
  two_findings
  printf '1=fixed @SHA@\n2=open\n' >"$STUBS/verdicts"
  touch "$STUBS/fix-md"
  drain
  grep -q '^after=code$' "$Q/01-a-review1/job"
  grep -q '^Run /code-review high origin/main\.\.\.HEAD\. Then return its findings ' "$STUBS/claude.log"
  grep -q '^\*\*Review:\*\* R1: 2 findings → 1 fixed, 1 open (/code-review only)$' "$Q/01-a-review1/pr-body.md"
}

@test "review: a missing rubric stops the round before the reviewer starts" {
  local copy="$BATS_TEST_TMPDIR/copy"
  mkdir -p "$copy/claude"
  cp "$REPO_ROOT/claude/vibe-review.sh" "$copy/claude/"
  VIBE_JOB_DIR="$BATS_TEST_TMPDIR" run bash "$copy/claude/vibe-review.sh" "$BATS_TEST_TMPDIR" proj-review1 sonnet high main
  [ "$status" -ne 0 ]
  [ ! -e "$STUBS/claude.log" ]
}

@test "lean skills: no model invocation, the MIT notice stays" {
  for s in lean-review lean-audit; do
    grep -q '^disable-model-invocation: true$' "$REPO_ROOT/skills/$s/SKILL.md"
    grep -q '^Copyright (c) 2026 DietrichGebert$' "$REPO_ROOT/skills/$s/LICENSE"
  done
}

@test "review: findings → the job's session fixes them, a second round, one PR body with both rounds" {
  local r b
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok after=review event=c1
  two_findings
  printf '%s' '{"type":"result","structured_output":{"findings":[]}}' >"$STUBS/review-2.json"
  printf '1=fixed @SHA@\n2=rejected not reachable\n' >"$STUBS/verdicts"
  touch "$STUBS/fix-big"
  drain
  [ "$status" -eq 0 ]
  for d in 01-a 01-a-review1 01-a-review2; do [ "$(cat "$Q/$d/status")" = "done" ]; done
  [ ! -e "$Q/01-a/pr" ]
  [ "$(grep -c 'pr create' "$STUBS/gh.log")" = 1 ]
  [ "$(grep -c 'issues/1/comments' "$STUBS/gh.log")" = 1 ]
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

@test "review: a fix session that ends in an API error, an error result or a crash → the round fails, names the dirty worktree, no PR; a clean round is done" {
  local r w
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok after=review
  two_findings
  printf '1=fixed @SHA@\n2=open\n' >"$STUBS/verdicts"
  echo '{"type":"result","subtype":"success","is_error":true,"api_error_status":429,"terminal_reason":"api_error"}' >"$STUBS/fix-error"
  drain
  [ "$status" -eq 0 ]
  w="$(cat "$Q/01-a/worktree")"
  [ "$(cat "$Q/01-a-review1/status")" = failed ]
  [ "$(cat "$Q/01-a-review1/note")" = "R1: 2 findings → fix failed: API error 429; $w has uncommitted changes" ]
  [ ! -e "$Q/01-a-review1/pr" ]
  [ ! -e "$Q/01-a-review2" ]
  rm -f "$STUBS/review-count"
  echo '{"type":"result","subtype":"error_during_execution","is_error":true,"api_error_status":null}' >"$STUBS/fix-error"
  mkjob 04-d "$r" task-d ok after=review
  drain
  w="$(cat "$Q/04-d/worktree")"
  [ "$(cat "$Q/04-d-review1/status")" = failed ]
  [ "$(cat "$Q/04-d-review1/note")" = "R1: 2 findings → fix failed: error result; $w has uncommitted changes" ]
  rm -f "$STUBS/fix-error" "$STUBS/review-count"
  touch "$STUBS/fix-crash"
  mkjob 03-c "$r" task-c ok after=review
  drain
  [ "$(cat "$Q/03-c-review1/status")" = failed ]
  [ -f "$(cat "$Q/03-c/worktree")/.mcp.json" ]
  [ "$(cat "$Q/03-c-review1/note")" = "R1: 2 findings → fix failed: agent exit 3" ]
  rm -f "$STUBS/fix-crash" "$STUBS/review-count"
  mkjob 02-b "$r" task-b ok after=review
  drain
  [ "$(cat "$Q/02-b-review1/status")" = "done" ]
  [ "$(cat "$Q/02-b-review1/note")" = "R1: 2 findings → 1 fixed, 1 open" ]
  [ "$(cat "$Q/02-b-review1/pr")" = "https://example.com/pull/1" ]
}

@test "review: a fix session past review_timeout → the round fails, names the dirty worktree, no PR" {
  command -v timeout >/dev/null 2>&1 || skip "no timeout(1)"
  local r w
  r="$(make_repo proj)"
  printf 'review_timeout=3s\n' >>"$CONF"
  mkjob 01-a "$r" task-a ok after=review
  two_findings
  touch "$STUBS/fix-sleep"
  drain
  w="$(cat "$Q/01-a/worktree")"
  [ "$(cat "$Q/01-a-review1/status")" = failed ]
  [ "$(cat "$Q/01-a-review1/note")" = "R1: 2 findings → fix failed: timeout; $w has uncommitted changes" ]
  [ ! -e "$Q/01-a-review1/pr" ]
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

# verify_json VERDICT — the verify agent's result: VERDICT and one check.
verify_json() {
  printf '{"type":"result","structured_output":{"verdict":"%s","checks":[{"command":"curl -s localhost:8080/health","output":"ok 200\\n```\\n</details>"}]}}' "$1" >"$STUBS/verify.json"
}

# verify_skill REPO — a verify-web skill on origin's main.
verify_skill() {
  mkdir -p "$1/.claude/skills/verify-web"
  printf -- '---\nname: verify-web\n---\n' >"$1/.claude/skills/verify-web/SKILL.md"
  git -C "$1" add .claude && git -C "$1" commit -q -m "chore: verify skill" && git -C "$1" push -q origin main
}

@test "verify: key set → <id>-verify after the last round, on review_model and review_timeout; V: on the Review line, commands in <details>; then the gate and one PR" {
  local r b
  r="$(make_repo proj)"
  verify_skill "$r"
  mkdir -p "$r/.vibe-jobs" && echo 'echo gate ran' >"$r/.vibe-jobs/gate"
  git -C "$r" add .vibe-jobs && git -C "$r" commit -q -m "chore: gate" && git -C "$r" push -q origin main
  printf 'review_model=haiku\nreview_timeout=30m\n' >>"$CONF"
  mkjob 01-a "$r" task-a ok after=review verify=app,blast-radius
  verify_json pass
  drain
  [ "$status" -eq 0 ]
  for d in 01-a 01-a-review1 01-a-verify; do [ "$(cat "$Q/$d/status")" = "done" ]; done
  [ ! -e "$Q/01-a-review1/pr" ]
  [ ! -e "$Q/01-a-review1/gate" ]
  [ "$(grep -c 'pr create' "$STUBS/gh.log")" = 1 ]
  [ "$(cat "$Q/01-a-verify/pr")" = "https://example.com/pull/1" ]
  [ "$(cat "$Q/01-a-verify/note")" = "V: pass" ]
  [ "$(cat "$Q/01-a-verify/verify")" = pass ]
  grep -q '^review=verify$' "$Q/01-a-verify/job"
  grep -q '^timeout=30m$' "$Q/01-a-verify/job"
  grep -q -- '-p --model haiku --name proj-task-a-verify --disallowedTools Edit,Write,NotebookEdit ' "$STUBS/claude.log"
  grep -q '^Verify origin/main\.\.\.HEAD\. Drive the app: .* Then do the blast-radius skill ' "$STUBS/claude.log"
  grep -q '^# Blast radius$' "$STUBS/claude.log"
  grep -q '^# pstack adapter$' "$STUBS/claude.log"
  grep -q 'start it, drive it and stop it in one Bash call' "$STUBS/claude.log"
  grep -q '^\*\*Review:\*\* R1: review failed · V: pass$' "$Q/01-a-verify/pr-body.md"
  b="$(cat "$Q/01-a-verify/pr-body.md")"
  [[ "$b" == *"**Review:**"*"<details>"*"**R1** — review failed"*"**V** — pass"$'\n\n''    $ curl -s localhost:8080/health'$'\n''    ok 200'$'\n''    ```'$'\n''    </details>'$'\n\n'*"</details>"*"**Gate:** exit 0"* ]] || false
  [ "$(grep -c '^</details>$' "$Q/01-a-verify/pr-body.md")" = 1 ]
}

@test "verify: the blast-radius skill and the adapter reach the agent through a symlink" {
  local link="$BATS_TEST_TMPDIR/link"
  mkdir -p "$link"
  ln -s "$REPO_ROOT/claude/vibe-verify.sh" "$link/vibe-verify.sh"
  VIBE_JOB_DIR="$BATS_TEST_TMPDIR" run bash "$link/vibe-verify.sh" "$BATS_TEST_TMPDIR" proj-verify sonnet main blast-radius
  [ "$status" -eq 0 ]
  grep -q '^# Blast radius$' "$STUBS/claude.log"
  grep -q '^# pstack adapter$' "$STUBS/claude.log"
  grep -qF -- "--settings $REPO_ROOT/claude/vibe-job-settings.json " "$STUBS/claude.log"
}

@test "verify: no key → no verify step; the last review round opens the PR" {
  local r
  r="$(make_repo proj)"
  verify_skill "$r"
  mkjob 01-a "$r" task-a ok after=review
  verify_json pass
  drain
  [ "$status" -eq 0 ]
  [ ! -e "$Q/01-a-verify" ]
  [ "$(cat "$Q/01-a-review1/pr")" = "https://example.com/pull/1" ]
  run grep -q '^Verify origin/' "$STUBS/claude.log"
  [ "$status" -ne 0 ]
}

@test "verify: no verify skill → 'V: no verify skill' and no agent; blast-radius still runs" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok after=review verify=app
  mkjob 02-b "$r" task-b ok after=review verify=app,blast-radius
  verify_json pass
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a-verify/note")" = "V: no verify skill" ]
  [ "$(cat "$Q/02-b-verify/note")" = "V: pass, no verify skill" ]
  [ "$(cat "$Q/01-a-verify/pr")" = "https://example.com/pull/1" ]
  [ "$(grep -c '^Verify origin/' "$STUBS/claude.log")" = 1 ]
  grep -q '^Verify origin/main\.\.\.HEAD\. Then do the blast-radius skill ' "$STUBS/claude.log"
  grep -q '^\*\*Review:\*\* R1: review failed · V: no verify skill$' "$Q/01-a-verify/pr-body.md"
}

@test "verify: 'V: fail' and 'V: verify failed' open the PR and put the job under Needs you; 'V: no verify skill' does not" {
  local r f
  r="$(make_repo proj)"
  mkjob 03-c "$r" task-c ok after=review verify=app
  drain
  verify_skill "$r"
  mkjob 01-a "$r" task-a ok after=review verify=app
  verify_json fail
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a-verify/note")" = "V: fail" ]
  [ "$(cat "$Q/01-a-verify/pr")" = "https://example.com/pull/1" ]
  rm -f "$STUBS/verify.json"
  mkjob 02-b "$r" task-b ok after=review verify=blast-radius
  drain
  [ "$(cat "$Q/02-b-verify/note")" = "V: verify failed" ]
  [ "$(cat "$Q/03-c-verify/note")" = "V: no verify skill" ]
  run "$VIBE" queue report
  [[ "$output" == *"### Needs you"*"| 01-a-verify | done | The repo lacks work.txt. | V: fail · work.txt added. |"* ]] || false
  [[ "$output" == *"### Needs you"*"| 02-b-verify | done |"*"V: verify failed · "* ]] || false
  [[ "$output" != *"| 03-c-verify |"* ]] || false
}

@test "verify: a changed tracked file or a new commit → 'V: dirty' under Needs you; the runner leaves both and pushes nothing" {
  local r wt f
  r="$(make_repo proj)"
  verify_skill "$r"
  mkdir -p "$r/.vibe-jobs" && echo 'echo gate ran' >"$r/.vibe-jobs/gate"
  git -C "$r" add .vibe-jobs && git -C "$r" commit -q -m "chore: gate" && git -C "$r" push -q origin main
  mkjob 01-a "$r" task-a ok after=review verify=app
  verify_json pass
  touch "$STUBS/verify-dirty"
  drain
  [ "$status" -eq 0 ]
  wt="$(cat "$Q/01-a-verify/worktree")"
  [ "$(cat "$Q/01-a-verify/note")" = "V: dirty" ]
  [ "$(git -C "$wt" status --porcelain -uno)" = " M work.txt" ]
  rm -f "$STUBS/verify-dirty"
  touch "$STUBS/verify-commit"
  mkjob 02-b "$r" task-b ok after=review verify=app
  drain
  [ "$(cat "$Q/02-b-verify/note")" = "V: dirty" ]
  [ "$(git -C "$(cat "$Q/02-b-verify/worktree")" log -1 --format=%s)" = "chore: verify scaffold" ]
  [ -z "$(git -C "$BATS_TEST_TMPDIR/proj.git" branch --list task-a task-b)" ]
  [ -z "$(grep 'pr create' "$STUBS/gh.log" 2>/dev/null || true)" ]
  for d in 01-a-verify 02-b-verify; do
    [ ! -e "$Q/$d/gate.log" ]
    [ ! -e "$Q/$d/pr" ]
    grep -q '^\*\*Review:\*\* .*V: dirty' "$Q/$d/pr.md"
  done
  run "$VIBE" queue report
  [[ "$output" == *"### Needs you"*"| 01-a-verify | done |"*"V: dirty · "* ]] || false
}

@test "add: refuses verify= on a lane job, on a job with no review, a bad value, a bad after=; queues none of the dirs" {
  local r a b
  r="$(make_repo proj)"
  a="$BATS_TEST_TMPDIR/a" b="$BATS_TEST_TMPDIR/b"
  mkdir -p "$a" "$b"
  echo task >"$a/prompt.md"
  echo task >"$b/prompt.md"
  printf 'repo=%s\nbranch=x\nafter=review\nverify=app\n' "$r" >"$a/job"
  printf 'repo=%s\nbranch=y\nafter=review\nlane=ctx\nitem=one\nverify=app\n' "$r" >"$b/job"
  run "$VIBE" queue add "$a" "$b"
  [ "$status" -ne 0 ]
  [[ "$output" == *"verify= on a lane job"* ]] || false
  [ -z "$(ls "$Q")" ]
  printf 'repo=%s\nbranch=y\nverify=app\n' "$r" >"$b/job"
  run "$VIBE" queue add "$b"
  [[ "$output" == *"verify= on a job with no review"* ]] || false
  printf 'repo=%s\nbranch=y\nafter=review\noutput=report\nverify=app\n' "$r" >"$b/job"
  run "$VIBE" queue add "$b"
  [[ "$output" == *"verify= on a job with no review"* ]] || false
  printf 'repo=%s\nbranch=y\nafter=review\nverify=all\n' "$r" >"$b/job"
  run "$VIBE" queue add "$b"
  [[ "$output" == *"verify=all — app, blast-radius or app,blast-radius"* ]] || false
  printf 'repo=%s\nbranch=y\nafter=cod\n' "$r" >"$b/job"
  run "$VIBE" queue add "$b"
  [[ "$output" == *"after=cod — review, code or empty"* ]] || false
  [ -z "$(ls "$Q")" ]
  run "$VIBE" queue add "$a"
  [ "$status" -eq 0 ]
  printf 'repo=%s\nbranch=y\nafter=code\nverify=app\n' "$r" >"$b/job"
  run "$VIBE" queue add "$b"
  [ "$status" -eq 0 ]
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

@test "sweep: the open questions of PROJECT_STATUS.md on origin, the source of proposals" {
  local a
  a="$(make_repo alpha)"
  printf '## Goal\n\nWalk.\n\n## Open questions\n\n_placeholder_\n\n- Does gamma 0.8 beat 0.9?\n\n## Other\n\nx\n' >"$a/PROJECT_STATUS.md"
  git -C "$a" add PROJECT_STATUS.md
  git -C "$a" commit -q -m status
  git -C "$a" push -q
  run "$SWEEP" "$a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## goal"*"Walk."*"## open questions"*"- Does gamma 0.8 beat 0.9?"*"## roadmap"* ]] || false
  [[ "$output" != *"placeholder"* ]] || false
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

# phase_jobs REPO — one chain per phase state: done, running, to come, failed; a report job.
phase_jobs() {
  local r="$1"
  endjob 01-a "$r" task-a "" after=review verify=app
  endjob 01-a-review1 "$r" task-a "" after=review verify=app review=1
  echo "R1: 2 findings → 2 fixed" >"$Q/01-a-review1/note"
  mkjob 01-a-review2 "$r" task-a ok after=review verify=app review=2
  echo running >"$Q/01-a-review2/status"
  mkjob 02-b "$r" task-b ok after=review
  endjob 03-c "$r" task-c "" verify=app
  endjob 03-c-review1 "$r" task-c "" verify=app review=1
  echo "R1: review failed" >"$Q/03-c-review1/note"
  endjob 03-c-verify "$r" task-c "push failed" verify=app review=verify
  echo fail >"$Q/03-c-verify/verify"
  echo 1 >"$Q/03-c-verify/gate"
  mkjob 04-d "$r" task-d blocked
  echo blocked >"$Q/04-d/status"
  endjob 05-e "$r" task-e https://example.com/pull/5
  echo 0 >"$Q/05-e/gate"
  mkjob 06-f "$r" task-f ok
  echo running >"$Q/06-f/status"
  touch "$Q/06-f/gate.log"
  endjob 07-g "$r" task-g "" output=report
  echo "# report" >"$Q/07-g/report.md"
  mkjob 08-h "$r" task-h ok output=report
}

@test "phases: the status shows each chain's phases: ✓ done, ▶ running, ○ to come, ✗ failed; R2 once queued, Verify only with the key" {
  local r
  r="$(make_repo proj)"
  phase_jobs "$r"
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  grep -qxF '    ✓ Agent · ✓ R1 2 fixed · ▶ R2 · ○ Verify app · ○ Gate · ○ PR' <<<"$output"
  grep -qxF '    ○ Agent · ○ R1 · ○ Gate · ○ PR' <<<"$output"
  grep -qxF '    ✓ Agent · ✗ R1 review failed · ✗ Verify app fail · ✗ Gate exit 1 · ✗ PR push failed' <<<"$output"
  grep -qxF '    ✗ Agent' <<<"$output"
  grep -qxF '    ✓ Agent · ✓ Gate · ✓ PR' <<<"$output"
  grep -qxF '    ✓ Agent · ▶ Gate · ○ PR' <<<"$output"
  grep -qxF '    ✓ Agent · ✓ Report' <<<"$output"
  grep -qxF '    ○ Agent · ○ Report' <<<"$output"
}

# steps KEY — the steps line of KEY's block as text: `<mark> <name>` joined by ` · `.
steps() { grep -o "<div class=\"blk\" id=\"job-$1\" .*" "$XDG_STATE_HOME/vibe/web/index.html" | grep -o '<p class="steps">.*' | sed 's#</p>.*##; s#<i>—</i># · #g; s#<[^>]*>##g'; }

@test "phases: the panel shows the same steps in page words: Work, Review n, Verify, Checks, PR, Report; marked for CSS, a tooltip each" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  phase_jobs "$r"
  "$VIBE" queue page >/dev/null
  [ "$(steps proj/task-a)" = '✓ Work · ✓ Review 1 · ● Review 2 · ○ Verify · ○ Checks · ○ PR' ]
  [ "$(steps 02-b)" = '○ Work · ○ Review 1 · ○ Checks · ○ PR' ]
  [ "$(steps proj/task-c)" = '✓ Work · ✗ Review 1 · ✗ Verify · ✗ Checks · ✗ PR' ]
  [ "$(steps 04-d)" = '✗ Work' ]
  [ "$(steps 05-e)" = '✓ Work · ✓ Checks · ✓ PR' ]
  [ "$(steps 06-f)" = '✓ Work · ● Checks · ○ PR' ]
  [ "$(steps 07-g)" = '✓ Work · ✓ Report' ]
  [ "$(steps 08-h)" = '○ Work · ○ Report' ]
  # The mark is a class; a step's detail goes into its tooltip; the Review tooltip names the passes.
  grep -qF '<span class="run" tabindex="0" data-tip="A second agent reviews the diff with /code-review + lean-review; a finding sends the job back to Work.">● Review 2</span>' "$f"
  grep -qF '<span class="ok" tabindex="0" data-tip="A second agent reviews the diff with /code-review + lean-review; a finding sends the job back to Work. (2 fixed)">✓ Review 1</span>' "$f"
  grep -qF "<span class=\"bad\" tabindex=\"0\" data-tip=\"The repo's own checks (.vibe-jobs/gate) run; a fail stops the PR. (exit 1)\">✗ Checks</span>" "$f"
  grep -qE '^\.steps \.bad \{ color: var\(--bad\); \}' "$f"
  grep -qE '^\.steps \.run \{ color: var\(--fg\); font-weight: 500; \}' "$f"
}

@test "phases: an after=code job's Review tooltip names only /code-review" {
  local r f="$XDG_STATE_HOME/vibe/web/index.html"
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok after=code
  "$VIBE" queue page >/dev/null
  grep -qF '<span tabindex="0" data-tip="A second agent reviews the diff with /code-review; a finding sends the job back to Work.">○ Review 1</span>' "$f"
}

@test "phases: a lane card gets one steps line, of its running item; each feature member card keeps its own" {
  local r1 r2 f="$XDG_STATE_HOME/vibe/web/index.html"
  r1="$(make_repo proj)" r2="$(make_repo cmdr)"
  endjob 01-a "$r1" lane-x https://example.com/pull/1 "lane=Fix health" item=alpha
  mkjob 02-b "$r1" lane-x item "lane=Fix health" item=beta
  echo running >"$Q/02-b/status"
  mkjob 03-c "$r1" lane-x item "lane=Fix health" item=gamma
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(grep -c '· ○ Gate\|· ✓ Gate' <<<"$output")" = 1 ]
  [[ "$output" == *$'  lane-x · 1/3 · beta · https://example.com/pull/1\n    Fix health\n    ▶ Agent · ○ Gate · ○ PR'* ]] || false
  "$VIBE" queue page >/dev/null
  [ "$(grep -o 'class="steps"' "$f" | wc -l)" -eq 1 ]
  [ "$(steps proj/lane-x)" = '● Work · ○ Checks · ○ PR' ]
  grep -qF '○ PR</span></p><p>Fix health <a href="https://example.com/pull/1">PR</a></p><p>next: beta</p>' "$f"
  putfeature teleop "$r1 lane-x" "$r2 gamepad"
  endjob 04-d "$r2" gamepad https://example.com/pull/4
  "$VIBE" queue page >/dev/null
  [ "$(grep -o 'class="steps"' "$f" | wc -l)" -eq 2 ]
  grep -qF '<b>cmdr · gamepad</b><span class="pill">Done</span></div><p class="steps">' "$f"
  grep -qF '✓ PR</span></p><p> <a href="https://example.com/pull/4">PR</a></p>' "$f"
}

@test "steer: steer= unset leaves the agent's argv as it was and makes no FIFO; a plain job takes no steer" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  run "$VIBE" queue steer 01-a "go on"
  [ "$status" -ne 0 ]
  [[ "$output" == *"01-a takes no steer now"* ]] || false
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$STUBS/claude.log")" = "-p --model sonnet --name proj-task-a --permission-mode auto --permission-prompts none --settings $REPO_ROOT/claude/vibe-job-settings.json --add-dir $Q/01-a/agent --output-format stream-json --verbose" ]
  [ ! -e "$Q/01-a/steer" ]
}

@test "steer: steer=1 hands the text of vibe queue steer to the running agent; a crash ends the input too" {
  local r rpid i
  r="$(make_repo proj)"
  printf 'after=\nsteer=1\n' >"$CONF"
  mkjob 01-a "$r" task-a steer
  mkjob 02-b "$r" task-b crash
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/runner.log" 2>&1 3>&- &
  rpid=$!
  for i in $(seq 100); do
    if [ -e "$STUBS/steer-up" ]; then break; fi
    sleep 0.1
  done
  run "$VIBE" queue steer 01-a $'try a "smaller" step\\\nthen stop'
  [ "$status" -eq 0 ]
  [ "$output" = "steered 01-a" ]
  wait "$rpid"
  [ "$(cat "$STUBS/steered")" = $'try a "smaller" step\\\nthen stop' ]
  [ "$(cat "$Q/01-a/status")" = "done" ]
  [ "$(cat "$Q/02-b/status")" = "failed" ]
  [ "$(grep -c -- '--verbose --input-format stream-json$' "$STUBS/claude.log")" = 2 ]
  [ ! -e "$Q/01-a/steer" ]
  run "$VIBE" queue steer 01-a "too late"
  [ "$status" -ne 0 ]
}

# xstub — the extension $STUBS/x/x, first in the config. Per event it logs `<event> <job id>`; per job id it sleeps
# $STUBS/x/<id>.<event>.sleep s, prints $STUBS/x/<id>.<event>.out and exits with $STUBS/x/<id>.<event>.exit.
# Its pass logs `gpu <id>` and ends each gpu job done: else a drain waits for it.
xstub() {
  mkdir -p "$STUBS/x" "$XDG_CONFIG_HOME/vibe"
  cat >"$STUBS/x/x" <<'EOF'
#!/usr/bin/env bash
[ "$1" = event ] || exit 0
x="${0%/*}" e="$2" id="${3##*/}"
echo "$e $id" >>"$x/log"
if [ "$e" = pass ]; then
  for d in "$VIBE_STATE"/queue/*/; do
    if [ "$(cat "${d}status" 2>/dev/null)" = gpu ]; then
      basename "$d" | sed 's/^/gpu /' >>"$x/log"
      echo done >"${d}status"
    fi
  done
fi
[ ! -f "$x/$id.$e.sleep" ] || sleep "$(cat "$x/$id.$e.sleep")"
[ ! -f "$x/$id.$e.out" ] || cat "$x/$id.$e.out"
exit "$(cat "$x/$id.$e.exit" 2>/dev/null || echo 0)"
EOF
  chmod +x "$STUBS/x/x"
  echo "$STUBS/x/x" >"$XDG_CONFIG_HOME/vibe/extensions"
}

# st JOB — `<status> <note>` of a queue job.
st() { echo "$(cat "$Q/$1/status") $(cat "$Q/$1/note")"; }

@test "extension: add refuses; prepare and start end a job by their end line, fail it on a crash or a cut; prompt runs the session on its file" {
  local r a
  r="$(make_repo proj)"
  xstub
  a="$BATS_TEST_TMPDIR/a"
  mkprep "$a" "$r" x
  echo 1 >"$STUBS/x/a.add.exit"
  run "$VIBE" queue add "$a"
  [ "$status" -ne 0 ]
  [[ "$output" == *"$a: not queued — an extension refused it"* ]] || false
  [ -z "$(ls "$Q")" ]
  mkjob 01-a "$r" task-a ok && echo 1 >"$STUBS/x/01-a.prepare.exit"
  mkjob 02-b "$r" task-b ok && echo 'end skipped not today' >"$STUBS/x/02-b.prepare.out"
  mkjob 03-c "$r" task-c ok && echo 1 >"$STUBS/x/03-c.start.exit"
  mkjob 04-d "$r" task-d ok && echo 'end blocked held' >"$STUBS/x/04-d.start.out"
  # Its own prompt.md would end queued: with no run, so a done job ran on the extension's file.
  mkjob 05-e "$r" task-e wait && printf 'Do the task.\nMODE=ok\n' >"$STUBS/x/p.md" && echo "prompt $STUBS/x/p.md" >"$STUBS/x/05-e.start.out"
  drain
  [ "$status" -eq 0 ]
  [ "$(st 01-a)" = "failed an extension failed at prepare — runner.log" ]
  [ "$(st 02-b)" = "skipped not today" ]
  [ "$(st 03-c)" = "failed an extension failed at start — runner.log" ]
  [ "$(st 04-d)" = "blocked held" ]
  [ "$(cat "$Q/05-e/status")" = "done" ]
  # An event past its cut (EXT_CUT s, 60 by default) fails the job with a warning.
  mkjob 06-f "$r" task-f ok && echo 10 >"$STUBS/x/06-f.prepare.sleep"
  EXT_CUT=2 run "$VIBE" queue run --claude --drain
  [ "$status" -eq 0 ]
  [ "$(st 06-f)" = "failed an extension failed at prepare — runner.log" ]
  grep -qF 'warning: extension x: event prepare exit 124' "$Q/06-f/runner.log" || [[ "$output" == *'warning: extension x: event prepare exit 124'* ]] || false
}

@test "extension: after a queued: session, end ends the job, run takes the run, wait waits; a crash or no run fails it" {
  local r
  r="$(make_repo proj)"
  xstub
  mkjob 01-a "$r" task-a wait && echo 1 >"$STUBS/x/01-a.end.exit"
  mkjob 02-b "$r" task-b wait && echo 'end blocked waits for x' >"$STUBS/x/02-b.end.out"
  mkjob 03-c "$r" task-c wait && echo wait >"$STUBS/x/03-c.end.out"
  # run beats the session's vibe queue gpu ask: the queue submits nothing.
  mkjob 04-d "$r" task-d gpu && echo run >"$STUBS/x/04-d.end.out"
  mkjob 05-e "$r" task-e wait
  drain
  [ "$status" -eq 0 ]
  [ "$(st 01-a)" = "failed failed: an extension failed at end — runner.log" ]
  [ "$(st 02-b)" = "blocked blocked: waits for x" ]
  grep -qx 'gpu 03-c' "$STUBS/x/log"
  grep -qx 'gpu 04-d' "$STUBS/x/log"
  [ ! -e "$Q/04-d/gpu-job" ]
  [ -s "$Q/04-d/gpu-cmd" ]
  [ "$(st 05-e)" = "failed failed: no GPU run asked for (vibe queue gpu), or the session started past deadline=" ]
  [ "$(grep -c '^end ' "$STUBS/x/log")" -eq 5 ]
}
