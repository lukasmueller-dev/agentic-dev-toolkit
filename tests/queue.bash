#!/usr/bin/env bash
# Shared setup of the queue suites: throwaway repos with a bare origin. A stub
# `claude` acts on the MODE line of its prompt; a stub `gh` records its calls
# under $STUBS. The stub prints a system/init event (session id sess-<job id>)
# unless $STUBS/no-init exists. With --input-format stream-json it reads its prompt
# from the first message and ends with a result event. The runner runs with --drain, so each test ends.
# A suite adds stub modes in $STUBS/claude.more: the stub sources it after its mode pick.

VIBE="$REPO_ROOT/bin/vibe"

queue_setup() {
  unset VIBE_JOB_DIR # this suite may run inside a queue job: vibe queue gpu writes there
  git_env
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"
  cat >"$STUBS/claude" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$STUBS/claude.log"
# text — the text of the stream-json user message on stdin.
text() { jq -r '.message.content[0].text'; }
sj=""
case "\$*" in *"--input-format stream-json"*) sj=1 ;; esac
if [ -n "\$sj" ]; then IFS= read -r m && prompt="\$(printf '%s' "\$m" | text)"; else prompt="\$(cat)"; fi
case "\$prompt" in
  "Run /code-review"*)
    echo "\$prompt" >>"$STUBS/claude.log"
    k=\$((\$(cat "$STUBS/review-count" 2>/dev/null || echo 0) + 1))
    echo "\$k" >"$STUBS/review-count"
    [ ! -f "$STUBS/review-sleep" ] || sleep 30
    if [ -f "$STUBS/review-\$k.json" ]; then cat "$STUBS/review-\$k.json"; else echo '{"type":"result","result":"no schema"}'; fi
    exit 0
    ;;
  "Verify origin/"*)
    echo "\$prompt" >>"$STUBS/claude.log"
    [ ! -f "$STUBS/verify-dirty" ] || echo dirty >>work.txt
    [ ! -f "$STUBS/verify-commit" ] || { echo x >x.txt && git add x.txt && git commit -q -m "chore: verify scaffold"; }
    if [ -f "$STUBS/verify.json" ]; then cat "$STUBS/verify.json"; else echo '{"type":"result","result":"no schema"}'; fi
    exit 0
    ;;
esac
jd="\${VIBE_JOB_DIR%/agent}" # the runner's job dir: \$VIBE_JOB_DIR is its agent/
[ -f "$STUBS/no-init" ] || echo '{"type":"system","subtype":"init","session_id":"sess-'"\${jd##*/}"'"}'
mode="\$(printf '%s\n' "\$prompt" | sed -n 's/^MODE=//p')"
case "\$prompt" in *"## GPU run finished"*) mode=ok && { [ -e "\${jd%-gpu}/ended" ] && echo ended || echo open; } >"$STUBS/parent-at-follow" ;; *"The time limit stopped"*) mode=handoff ;; *"A reviewer found problems"*) mode=fix ;; esac
[ ! -f "$STUBS/claude.more" ] || . "$STUBS/claude.more"
case "\$mode" in
  gpu)
    echo code >code.txt && git add code.txt && git commit -q -m "feat: train script"
    "$VIBE" queue gpu -- sh -c '[ ! -f $STUBS/gpu-sleep ] || sleep 30; echo trained >out.txt; cat $STUBS/gpu-result 2>/dev/null; true'
    [ ! -f "$STUBS/gpu-forge" ] || printf 'true\0' >"\$VIBE_JOB_DIR/gpu-cmd"
    [ ! -f "$STUBS/gpu-started" ] || cp "$STUBS/gpu-started" "\$jd/started"
    ls "\$GPU_QUEUE_DIR/queued" >"$STUBS/gpu-in-session" 2>/dev/null || true
    echo "queued: training" >"\$VIBE_JOB_DIR/result"
    ;;
  wait) echo "queued: workers run" >"\$VIBE_JOB_DIR/result" ;;
  leak)
    echo work >work.txt && git add work.txt && git commit -q -m "feat: work"
    ln -s "$STUBS/secret" "\$VIBE_JOB_DIR/pr.md"
    echo "done: work.txt added" >"\$VIBE_JOB_DIR/result"
    ;;
  forge)
    for f in "$STUBS"/forge/*; do rm -f "\$VIBE_JOB_DIR/\${f##*/}" && cp "\$f" "\$VIBE_JOB_DIR/"; done
    if [ -f "$STUBS/forge-sleep" ]; then touch "$STUBS/forged" && sleep 30; fi
    echo work >work.txt && git add work.txt && git commit -q -m "feat: work"
    echo "done: work.txt added" >"\$VIBE_JOB_DIR/result"
    ;;
  gpurace)
    echo code >code.txt && git add code.txt && git commit -q -m "feat: train script"
    "$VIBE" queue gpu -- true
    GPUQ_EXIT=0 "$VIBE" queue follow "\$jd"
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
  steer)
    touch "$STUBS/steer-up"
    IFS= read -r -t 20 m && printf '%s' "\$m" | text >"$STUBS/steered"
    echo "done: steered" >"\$VIBE_JOB_DIR/result"
    ;;
  crash) exit 3 ;;
  oom) echo half >wip.txt && kill -9 \$\$ ;;
  silent) ;;
  sleep) sleep 30 ;;
  slow) echo half >wip.txt && sleep 30 ;;
  fix)
    if [ -f "$STUBS/fix-error" ]; then
      echo half >>work.txt && cat "$STUBS/fix-error"
      exit 0
    fi
    [ ! -f "$STUBS/fix-crash" ] || { : >.mcp.json && exit 3; }
    [ ! -f "$STUBS/fix-sleep" ] || { echo half >>work.txt && sleep 30; }
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
if [ -n "\$sj" ]; then echo '{"subtype":"success","type":"result"}' && cat >/dev/null; fi
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
  local id="$1" repo="$2" branch="$3" mode="$4" l
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

# mkprep DIR REPO BRANCH — a prepared job dir for `vibe queue add`.
mkprep() {
  mkdir -p "$1"
  printf 'repo=%s\nbranch=%s\nmodel=sonnet\ncontext=night work\n' "$2" "$3" >"$1/job"
  printf 'Do the task.\nMODE=ok\n' >"$1/prompt.md"
}

# gpuq STATE NAME DIR — a run made by `gpu-queue submit`, so a change of its layout turns the test red;
# STATE running or finished moves it where `gpu-queue run` puts it. held and parked: `gpu-queue` writes no such dir yet, the test makes it. Prints the run's id.
gpuq() {
  local gq="${GPU_QUEUE_DIR:-$XDG_STATE_HOME/gpu-queue}" id
  id="$("$REPO_ROOT/bin/gpu-queue" submit --name "$2" --dir "$3" -- true)"
  if [ "$1" != queued ]; then
    mkdir -p "$gq/$1"
    mv "$gq/queued/$id" "$gq/$1/$id"
  fi
  echo "$id"
}
