#!/usr/bin/env bash
# Shared helpers of the research and ws suites: the research extension copied out of the checkout,
# the stub claude's research modes, and a research question as job dirs.

# research_ext — extensions/research/ copied out of the checkout, with the files it reads there, as the first line of
# the extensions config: the suite proves it runs anywhere. Call it after XDG_CONFIG_HOME is set.
research_ext() {
  local x="$BATS_TEST_TMPDIR/rx" c="${XDG_CONFIG_HOME:-$HOME/.config}/vibe"
  mkdir -p "$x/extensions" "$x/skills/fill-queue" "$x/templates" "$x/docs" "$c"
  cp -R "$REPO_ROOT/extensions/research" "$x/extensions/"
  cp -R "$REPO_ROOT/skills/fill-queue/references" "$x/skills/fill-queue/"
  cp "$REPO_ROOT/templates/job-pr.md" "$REPO_ROOT/templates/job-report.md" "$x/templates/"
  cp -R "$REPO_ROOT/workspaces" "$x/"
  cp -R "$REPO_ROOT/docs/workspaces" "$x/docs/"
  echo "$x/extensions/research/research" >>"$c/extensions"
}

# research_modes — the stub claude's research modes (tests/queue.bash), in $STUBS/claude.more.
# A coordinator in status gpu that nothing wakes keeps --drain from its end: the test hangs; give it blocked.
# A coordinator prompt with fewer `## Worker finished` blocks than $STUBS/coord-blocks (default 1) ends `queued:`.
research_modes() {
  cat >"$STUBS/claude.more" <<EOF
case "\$prompt" in *"## GPU run finished"*) ;; *"## Worker finished"*) mode=ok && [ "\$(printf '%s\n' "\$prompt" | grep -c '^## Worker finished\$')" -ge "\$(cat "$STUBS/coord-blocks" 2>/dev/null || echo 1)" ] || mode=wait ;; *"Agent job: Research worker"*) mode=ok ;; esac
case "\$mode" in
  place)
    git commit -q --allow-empty -m "feat: train"
    p="\$(sed -n 's/^place=//p' "\$VIBE_JOB_DIR/job")"
    "$VIBE" queue gpu --place "\${p:-runpod}" -- sh train.sh >>"$STUBS/queue-gpu.out" 2>&1
    echo "queued: training" >"\$VIBE_JOB_DIR/result"
    ;;
  slurm)
    h="\$(sed -n 's/^hid=//p' "\$VIBE_JOB_DIR/job")"
    mkdir -p "runs/\$h" && echo '#SBATCH --time=1:00:00' >"runs/\$h/job.sbatch" && git add runs && git commit -q -m "feat: \$h sbatch"
    printf '1. git fetch\n2. sbatch\n3. the RESULT line\n' >"\$VIBE_JOB_DIR/paste.md"
    echo "blocked: \$h waits for its slurm run — paste.md" >"\$VIBE_JOB_DIR/result"
    ;;
  askworkers)
    cat "$STUBS/workers-ask" >>"\$VIBE_JOB_DIR/workers"
    echo "queued: workers" >"\$VIBE_JOB_DIR/result"
    ;;
  workers)
    "$VIBE" queue worker h1 >>"$STUBS/worker.out" 2>&1
    "$VIBE" queue worker h2 --place runpod >>"$STUBS/worker.out" 2>&1
    echo "queued: workers h1 h2" >"\$VIBE_JOB_DIR/result"
    ;;
  close)
    printf '%s\n' "\$prompt" >"$STUBS/close-prompt"
    if [ -f "$STUBS/close-blocked" ]; then
      printf '## Next action\n\nName the metric.\n' >HANDOFF.md && git add HANDOFF.md && git commit -q -m "docs: handoff"
      echo "blocked: no metric command" >"\$VIBE_JOB_DIR/result"
      exit 0
    fi
    if [ -d "\$VIBE_JOB_DIR/out/files" ]; then
      echo "# One table" >"\$VIBE_JOB_DIR/report.md"
    else
      printf 'feat: tool branch\n\n**Context:** c\n**Changed:** tool.txt\n**Verify:** cat tool.txt\n' >"\$VIBE_JOB_DIR/pr.md"
    fi
    echo "done: tool result checked" >"\$VIBE_JOB_DIR/result"
    ;;
esac
EOF
}

# research_fixture QDIR REPO — the question `lr` as job dirs, written by hand from the contract: a coordinator
# (done) and 4 workers. h1 turing, done, 0.81; h2 runpod, run in flight, $1.20; h3 slurm, blocked on a paste;
# h4 turing, done, 0.84, builds on h1. Spent $1.20 of $50; best 0.84 (h4); state line `needs you · paste h3 · h2 on runpod`.
research_fixture() {
  local q="$1" r="$2" w="research-lr"
  rjob "$q" 20261117-100000-proj-$w "done" "$r" research/lr "research=lr" card=research "question=Does a wider net help & by how much?" \
    "usd=50" "workers=3" "better=higher" "deadline=2026-11-18 09:00"
  echo "done: baseline row" >"$q/20261117-100000-proj-$w/note"
  rjob "$q" 20261117-100100-proj-$w-h1 "done" "$r" research/lr/h1 "research=lr" card=research "hid=h1" "place=turing" "idea=baseline" "builds=root"
  echo '{"metric": 0.81}' >"$q/20261117-100100-proj-$w-h1/run-result"
  echo 0 >"$q/20261117-100100-proj-$w-h1/cost"
  echo "done: row written" >"$q/20261117-100100-proj-$w-h1/note"
  rjob "$q" 20261117-100200-proj-$w-h2 gpu "$r" research/lr/h2 "research=lr" card=research "hid=h2" "place=runpod" "idea=wider net" "builds=root"
  echo 1.20 >"$q/20261117-100200-proj-$w-h2/cost"
  echo "queued: run on runpod" >"$q/20261117-100200-proj-$w-h2/note"
  rjob "$q" 20261117-100300-proj-$w-h3 blocked "$r" research/lr/h3 "research=lr" card=research "hid=h3" "place=slurm" "idea=lr 3e-4" "builds=root"
  printf '1. git fetch the commit\n2. sbatch runs/h3/job.sbatch\n3. print the RESULT line\n' >"$q/20261117-100300-proj-$w-h3/paste.md"
  echo "blocked: paste 3 steps on the cluster" >"$q/20261117-100300-proj-$w-h3/note"
  rjob "$q" 20261117-100400-proj-$w-h4 "done" "$r" research/lr/h4 "research=lr" card=research "hid=h4" "place=turing" "idea=baseline + warmup" "builds=h1"
  echo '{"metric": 0.84, "n": 3}' >"$q/20261117-100400-proj-$w-h4/run-result"
  echo 0 >"$q/20261117-100400-proj-$w-h4/cost"
  echo "done: row written" >"$q/20261117-100400-proj-$w-h4/note"
}
