#!/usr/bin/env bats
#
# research — the research extension's queue side: the card, status and report of a question, its workers,
# place runs, stop, archive and answer. The queue setup: tests/queue.bash; the extension runs from a copy
# outside the checkout (research_ext in tests/research.bash).

load helper
load queue
load research

setup() {
  queue_setup
  research_ext
  research_modes
}

# rpage — write the page: $XDG_STATE_HOME/vibe/web/index.html.
rpage() { "$VIBE" queue page >/dev/null; }

# shellcheck disable=SC2016  # a literal $ in the expected text
@test "page: a research question is one row; its block has the head line, a row per worker, a builds= row below its parent" {
  local f="$XDG_STATE_HOME/vibe/web/index.html" r
  r="$(make_repo proj)"
  research_fixture "$Q" "$r"
  rpage
  [ "$(grep -o '<div class="row"' "$f" | wc -l)" -eq 1 ]
  grep -qF '<div class="row" data-k="research/lr"><i class="lamp l-bad"></i><a class="t" href="#job-research/lr"><b>lr <span class="n">2 of 4 items</span></b><span class="why">h3 · paste · Research · proj</span></a></div>' "$f"
  grep -qF '<div class="blk" id="job-research/lr" hidden><div class="bh"><i class="lamp l-bad"></i><span class="st" title="One of its items needs your answer or your check.">Needs you</span><h2>lr <span class="n">2 of 4 items</span></h2><code class="meta">proj · Research</code></div><div class="job lane research s-blocked">' "$f"
  grep -qF '<p>Does a wider net help &amp; by how much?</p><p class="stats">best 0.84 (h4) · $1.20 of $50 · deadline 2026-11-18 09:00</p><p>needs you · paste h3 · h2 on runpod</p><p>h3 · paste</p><div class="jacts" data-slug="lr">' "$f"
  # The order: h4 builds on h1, so it sits below it, one level in.
  [ "$(grep -o 'style="--d:[0-9]" data-hid="[a-z0-9]*"' "$f" | tr -d '"\n')" = 'style=--d:0 data-hid=h1style=--d:1 data-hid=h4style=--d:0 data-hid=h2style=--d:0 data-hid=h3' ]
  grep -qF '<div class="wk" style="--d:0" data-hid="h2"><i class="lamp l-ok"></i><span class="wh"><b>h2</b> <span class="n">Running · runpod</span></span><span class="wm">$1.20</span><p>wider net</p><p class="stats">run on runpod</p></div>' "$f"
  grep -qF '<div class="wk" style="--d:1" data-hid="h4"><i class="lamp l-done"></i><span class="wh"><b>h4</b> <span class="n">Done · turing</span></span><span class="wm">0.84 · $0.00</span>' "$f"
  grep -qF '<div class="wk" style="--d:0" data-hid="h3"><i class="lamp l-bad"></i><span class="wh"><b>h3</b> <span class="n">paste · slurm</span></span><span class="wm"></span>' "$f"
  # Its jobs are in no repo group, and a done job with no PR is no `no PR` job: only h3 counts.
  run grep -c '<h2>proj</h2>' "$f"
  [ "$output" = 0 ]
  [[ "$("$VIBE" queue status | head -n 1)" == *" · 1 no PR · "* ]] || false
}

@test "page: a research question with no worker job reads its workers= budget in the head" {
  local f="$XDG_STATE_HOME/vibe/web/index.html" c="$Q/20261117-100000-proj-research-lr" r
  r="$(make_repo proj)"
  research_fixture "$Q" "$r"
  rm -r "$Q"/20261117-1001* "$Q"/20261117-1002* "$Q"/20261117-1003* "$Q"/20261117-1004*
  echo running >"$c/status"
  rpage
  [[ "$("$VIBE" queue status)" == *$'\n  lr · 0 of 3 workers · thinking\n'* ]] || false
  grep -qF '<b>lr <span class="n">0 of 3 workers</span></b>' "$f"
  sed -i.bak 's/^workers=3$/workers=5/' "$c/job"
  [[ "$("$VIBE" queue status)" == *$'\n  lr · 0 of 5 workers · thinking\n'* ]] || false
}

# shellcheck disable=SC2016  # a literal $ in the expected text
@test "page: a research state line, first match: needs you, drained, on <place>, coding, closing, thinking, queued, done" {
  local f="$XDG_STATE_HOME/vibe/web/index.html" r h="$Q/20261117-100300-proj-research-lr-h3" c="$Q/20261117-100000-proj-research-lr" h2="$Q/20261117-100200-proj-research-lr-h2" st t
  r="$(make_repo proj)"
  research_fixture "$Q" "$r"
  # line <text> — the card's state line on the page and in the status.
  line() {
    rpage
    grep -qF "<p>$1</p>" "$f"
    [[ "$("$VIBE" queue status)" == *$'\n'"    $1"$'\n'* ]] || false
  }
  line 'needs you · paste h3 · h2 on runpod'
  echo blocked >"$c/status" && echo "blocked: name the metric" >"$c/note"
  line 'needs you · coordinator blocked, paste h3 · h2 on runpod'
  echo "done" >"$c/status" && echo "done" >"$h/status"
  # After a Stop, drained comes before a live run.
  echo drain >"$c/drain"
  line 'drained · stop question · h2 on runpod'
  echo now >"$h2/drain"
  line 'drained · stop now · h2 on runpod'
  # The pill reads the state word: a drained question is not done, and keeps Stop now.
  [[ "$("$VIBE" queue status)" == *$'\n  lr · 3/4 · drained\n'* ]] || false
  grep -qF '<div class="job lane research s-held"><div class="top"><b>lr · 3 of 4 items</b><span class="pill">Drained</span>' "$f"
  grep -qF '<span class="st" title="No new run starts: the state line says why.">Drained</span>' "$f"
  # A drained question loses Stop question and keeps Stop now while h2 runs; Archive waits for each job to end.
  grep -qF '<div class="jacts" data-slug="lr"><button data-act="research-stop-now" data-verb="Stopping…" data-confirm title="Cut every run now">Stop now</button></div>' "$f"
  rm "$c/drain" "$h2/drain"
  st="$XDG_STATE_HOME/vibe/workspaces/research-${h2##*/}" t=$(($(date +%s) + 3600))
  mkdir -p "$st" && echo "$t" >"$st/limit"
  hm() { LC_ALL=C date -d "@$1" '+%a %H:%M' 2>/dev/null || LC_ALL=C date -r "$1" '+%a %H:%M'; }
  line "on runpod · h2 · box until $(hm "$t")"
  # The PROGRESS contract names the run and gives its steps; the last two lines give the ETA.
  printf 'PROGRESS {"done":100,"total":1000,"at":%s,"run":"seed42"}\nStep: 7\nPROGRESS {"done":200,"total":1000,"at":%s,"run":"seed42"}\n' \
    $((t - 3700)) $((t - 3600)) >"$st/log"
  line "on runpod · seed42 · 200 of 1000 steps · eta $(hm $((t - 2800))) · box until $(hm "$t")"
  # The repo writes the run name: a | and control bytes drop out, so the fields hold and no escape reaches the terminal.
  printf 'PROGRESS {"done":2,"total":10,"at":1,"run":"a|b\\u001b]0;x\\u0007c"}\n' >"$st/log"
  line "on runpod · ab]0;xc · 2 of 10 steps · box until $(hm "$t")"
  # An `at` in ms or ns, or a stalled run, gives an ETA in the past or a week out: no ETA, no error.
  printf 'PROGRESS {"done":1,"total":10,"at":1700000000000000000}\nPROGRESS {"done":2,"total":10,"at":1700000001000000000}\n' >"$st/log"
  line "on runpod · h2 · 2 of 10 steps · box until $(hm "$t")"
  printf 'PROGRESS {"done":200,"total":1000,"at":%s000}\nPROGRESS {"done":300,"total":1000,"at":%s000}\n' $((t - 3700)) $((t - 3600)) >"$st/log"
  line "on runpod · h2 · 300 of 1000 steps · box until $(hm "$t")"
  printf 'PROGRESS {"done":100,"total":300,"at":%s}\nPROGRESS {"done":200,"total":300,"at":%s}\n' $((t - 435600)) $((t - 349200)) >"$st/log"
  line "on runpod · h2 · 200 of 300 steps · box until $(hm "$t")"
  printf 'PROGRESS {"done":1,"total":10000,"at":%s}\nPROGRESS {"done":2,"total":10000,"at":%s}\n' $((t - 3700)) $((t - 3600)) >"$st/log"
  line "on runpod · h2 · 2 of 10000 steps · box until $(hm "$t")"
  [[ "$("$VIBE" queue status 2>&1 >/dev/null)" != *date:* ]] || false
  printf 'PROGRESS {"done":100,"total":1000,"at":%s,"run":"seed42"}\nStep: 7\nPROGRESS {"done":200,"total":1000,"at":%s,"run":"seed42"}\n' \
    $((t - 3700)) $((t - 3600)) >"$st/log"
  # One line gives no ETA; with no PROGRESS line, the last Step: before Average time: gives the steps.
  sed -i.bak 1d "$st/log"
  line "on runpod · seed42 · 200 of 1000 steps · box until $(hm "$t")"
  printf 'INFO - Step: 0\nINFO - Step: 131072\nINFO - Average time: 21.5 s\nINFO - Step: 9\n' >"$st/log"
  line "on runpod · h2 · 131072 steps · box until $(hm "$t")"
  rm "$st/log"
  # A live run keeps the gpu look: the brand glider runs.
  grep -qF '<div class="job lane research s-gpu"><div class="top"><b>lr · 3 of 4 items</b><span class="pill">On runpod</span>' "$f"
  grep -qF '<span class="st" title="A run uses its box at that place now.">On runpod</span>' "$f"
  echo "done" >"$h2/status" && echo running >"$h/status"
  line coding
  # A coordinator that waits for its workers has no run of its own: it is not on turing.
  echo gpu >"$c/status"
  line coding
  echo queued >"$h/status"
  line queued
  grep -qF '<span class="pill">Queued</span>' "$f"
  echo "done" >"$c/status" && echo running >"$h/status"
  echo '{"metric": 0.5}' >"$h/run-result"
  line closing
  echo "done" >"$h/status" && echo running >"$c/status"
  line thinking
  # A stop the runner has not done yet: the coordinator still runs.
  touch "$c/stop"
  line thinking
  rm "$c/stop"
  echo queued >"$c/status"
  line queued
  echo "done" >"$c/status"
  line "done"
  # A stopped question that ended with its coordinator done is done: its PR to review and Archive stay.
  echo drain >"$c/drain" && echo https://github.com/o/proj/pull/5 >"$c/pr"
  line "done"
  grep -qF '<a class="btn" href="https://github.com/o/proj/pull/5" target="_blank" rel="noopener">Open PR ↗</a>' "$f"
  grep -qF 'data-act="research-archive" data-verb="Archiving…"' "$f"
  rm "$c/drain" "$c/pr"
  # A coordinator that `vibe queue stop` ended needs no answer: the question drained, the newest run says why.
  echo failed >"$c/status" && echo stopped >"$c/note" && touch "$c/stop"
  mkdir -p "$c/run" && echo vast >"$c/run/place" && echo 124 >"$c/run/exit"
  line 'drained · run at its limit · on vast'
  # No run lives: Archive alone.
  grep -qF '<div class="jacts" data-slug="lr"><button data-act="research-archive" data-verb="Archiving…" data-confirm>Archive</button></div>' "$f"
  # The agent writes run/place: other text than runpod or vast gives the job's place=.
  printf 'evil|x\033]0;t\007\n' >"$c/run/place"
  line 'drained · run at its limit · on turing'
  echo vast >"$c/run/place"
  # An ended run keeps its steps from run/log, with no ETA.
  printf 'PROGRESS {"done":1,"total":9,"at":1}\nPROGRESS {"done":2,"total":9,"at":2,"run":"s1"}\n' >"$c/run/log"
  line 'drained · run at its limit · s1 on vast · 2 of 9 steps'
  [[ "$("$VIBE" queue status)" == *$'\n  lr · 4/4 · drained\n'* ]] || false
  echo 1 >"$c/run/exit" && echo 'failed: smoke' >"$c/run/log"
  line 'drained · smoke failed · on vast'
  echo usd >"$c/run/exit"
  line 'drained · run over usd= · on vast'
  rm -r "$c/run"
  line 'drained · deadline passed'
  # No other reason: the stop file says why, not a bare drained.
  sed -i.bak 's/^deadline=.*/deadline=2099-01-01 00:00/' "$c/job"
  mkdir -p "$c/run" && echo vast >"$c/run/place" && echo 0 >"$c/run/exit"
  line 'drained · stopped · on vast'
  # An older worker run that hit its limit is no reason: the stopped coordinator has no run of its own.
  rm -r "$c/run"
  mkdir -p "$h2/run" && echo runpod >"$h2/run/place" && echo 124 >"$h2/run/exit"
  line 'drained · stopped · h2 on runpod'
}

@test "page: a gpu job whose run ended reads closing (a worker) or thinking (the coordinator), not done" {
  local r h="$Q/20261117-100300-proj-research-lr-h3" c="$Q/20261117-100000-proj-research-lr" h2="$Q/20261117-100200-proj-research-lr-h2"
  r="$(make_repo proj)"
  research_fixture "$Q" "$r"
  rm "$h/paste.md" && echo "done" >"$h/status"
  # place_run wrote run/exit; the follow-up is not queued yet, so h2 is still gpu.
  mkdir -p "$h2/run" && echo runpod >"$h2/run/place" && echo 0 >"$h2/run/exit"
  [[ "$("$VIBE" queue status)" == *$'\n  lr · 3/4 · closing\n'*$'\n    closing · h2 on runpod\n'*'h2 · runpod  closing'* ]] || false
  echo "done" >"$h2/status" && rm -r "$h2/run"
  echo gpu >"$c/status" && mkdir -p "$c/run" && echo vast >"$c/run/place" && echo 0 >"$c/run/exit"
  [[ "$("$VIBE" queue status)" == *$'\n  lr · 4/4 · thinking\n'*$'\n    thinking · on vast\n'* ]] || false
}

# shellcheck disable=SC2016  # a literal $ in the expected text
@test "page: a research best follows better=, skips a null metric; session 2 gives the state and adds its cost" {
  local f="$XDG_STATE_HOME/vibe/web/index.html" r c="$Q/20261117-100000-proj-research-lr" h2="$Q/20261117-100200-proj-research-lr-h2"
  r="$(make_repo proj)"
  research_fixture "$Q" "$r"
  sed -i.bak 's/^better=higher/better=lower/' "$c/job"
  rpage
  grep -qF 'best 0.81 (h1) · ' "$f"
  echo 'RESULT {"metric": null}' >"$Q/20261117-100100-proj-research-lr-h1/run-result"
  rpage
  grep -qF 'best 0.84 (h4) · ' "$f"
  # Session 2 of h2: a follow-up job on the same hid, queued, with its own cost.
  rjob "$Q" "${h2##*/}-gpu" queued "$r" research/lr/h2 research=lr card=research hid=h2 place=runpod "idea=wider net" builds=root follow=1 "parent=${h2##*/}"
  echo 0.30 >"$h2-gpu/cost"
  echo "done" >"$h2/status"
  rpage
  grep -qF '<span class="n">Closing · runpod</span></span><span class="wm">$1.50</span>' "$f"
  grep -qF '$1.50 of $50' "$f"
  [ "$(grep -o 'data-hid="h2"' "$f" | wc -l)" -eq 1 ]
}

# shellcheck disable=SC2016  # a literal $ in the expected text
@test "research: spend sums the coordinator chain's cost and the archived jobs'; a live box counts price × (now − started), not its reservation" {
  local r c="$Q/20261117-100000-proj-research-lr" h2="$Q/20261117-100200-proj-research-lr-h2" st a
  r="$(make_repo proj)"
  research_fixture "$Q" "$r"
  echo 0.19 >"$c/cost"
  rjob "$Q" "${c##*/}-gpu" "done" "$r" research/lr research=lr card=research usd=50
  echo 0.05 >"$c-gpu/cost"
  [[ "$("$VIBE" queue status)" == *'$1.44 of $50'* ]] || false
  # h2's box is up an hour at 2 USD/h: its cost file holds the gate's reservation of 1.20.
  st="$XDG_STATE_HOME/vibe/workspaces/research-${h2##*/}"
  mkdir -p "$st" "$h2/run"
  echo 2 >"$st/price" && echo $(($(date +%s) - 3600)) >"$st/started"
  run "$VIBE" queue status
  [[ "$output" == *'h2 · runpod  running  $2.00'* && "$output" == *'$2.24 of $50'* ]] || false
  # Gate passed, box not up yet: a price and no started is 0, not price × now.
  rm "$st/started"
  run "$VIBE" queue status
  [[ "$output" == *'h2 · runpod  running  $0.00'* && "$output" == *'$0.24 of $50'* ]] || false
  echo 0 >"$h2/run/exit"
  [[ "$("$VIBE" queue status)" == *'$1.44 of $50'* ]] || false
  # A retried job is archived: its cost counts on; another repo's or another research's does not.
  a="$XDG_STATE_HOME/vibe/archive/2026-11"
  rjob "$a" 20261116-090000-proj-research-lr failed "$r" research/lr research=lr
  echo 3.40 >"$a/20261116-090000-proj-research-lr/cost"
  rjob "$a" 20261116-090100-other-research-lr failed /elsewhere research/lr research=lr
  echo 9 >"$a/20261116-090100-other-research-lr/cost"
  rjob "$a" 20261116-090200-proj-research-x failed "$r" research/x research=x
  echo 9 >"$a/20261116-090200-proj-research-x/cost"
  [[ "$("$VIBE" queue status)" == *'$4.84 of $50'* ]] || false
  # With the coordinator archived, the workers' repo still keeps another repo's cost out.
  mv "$c" "$c-gpu" "$a/"
  [[ "$("$VIBE" queue status)" == *$'(h4) · $4.84\n'* ]] || false
}

# shellcheck disable=SC2016  # a literal $ in the expected text
@test "research: status has a Research group with a line per question (2/4) and a line per worker with its place; the report has one row" {
  local r c="$Q/20261117-100000-proj-research-lr"
  r="$(make_repo proj)"
  research_fixture "$Q" "$r"
  run "$VIBE" queue status
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | sed -n '3,13p')" = 'Research
  lr · 2/4 · needs you
    Does a wider net help & by how much?
    best 0.84 (h4) · $1.20 of $50 · deadline 2026-11-18 09:00
    needs you · paste h3 · h2 on runpod
    h1 · turing  done  0.81 · $0.00
      h4 · turing  done  0.84 · $0.00
    h2 · runpod  running  $1.20
    h3 · slurm  paste
    needs you: h3 paste' ]
  # Its jobs are in no repo group of the status.
  run grep -c '^proj$' <("$VIBE" queue status)
  [ "$output" = 0 ]
  echo blocked >"$c/status" && echo "blocked: name the metric" >"$c/note"
  [[ "$("$VIBE" queue status)" == *$'    needs you: coordinator blocked: name the metric\n    needs you: h3 paste'* ]] || false
  run "$VIBE" queue report
  grep -qF '| lr | needs you | 2/4 | Does a wider net help & by how much? | best 0.84 (h4) · $1.20 of $50 · deadline 2026-11-18 09:00 | h1 turing done · h4 turing done · h2 runpod running · h3 slurm paste | needs you · coordinator blocked, paste h3 · h2 on runpod |  |' <<<"$output"
  # The coordinator's PR is in the row: its done job has no row of its own.
  echo https://example.com/pull/5 >"$c/pr"
  [[ "$("$VIBE" queue report)" == *'| [PR](https://example.com/pull/5) |'* ]] || false
  # A done worker has no row of its own; the one that needs you has.
  [[ "$output" != *research-lr-h1* && "$output" != *research-lr-h4* && "$output" == *research-lr-h3* ]] || false
}

@test "research: a coordinator whose push or PR failed is a no PR job in the header, the status, the report and its row" {
  local r c="$Q/20261117-100000-proj-research-lr"
  r="$(make_repo proj)"
  research_fixture "$Q" "$r"
  echo "done" >"$Q/20261117-100200-proj-research-lr-h2/status"
  echo "done" >"$Q/20261117-100300-proj-research-lr-h3/status"
  echo "push failed: rejected" >"$c/pr"
  run "$VIBE" queue status
  [[ "${lines[0]}" == *" · 1 no PR · "* ]] || false
  [[ "$output" == *$'    PR: push failed: rejected\n'* ]] || false
  run "$VIBE" queue report
  [[ "$output" == *"| 20261117-100000-proj-research-lr | done |"* ]] || false
  [[ "$output" == *"| **push failed: rejected** |"* ]] || false
  # The same job with a PR URL has a link in its question's row and none of its own.
  echo https://example.com/pull/5 >"$c/pr"
  run "$VIBE" queue report
  [[ "$output" == *"| [PR](https://example.com/pull/5) |"* && "$output" != *"| 20261117-100000-proj-research-lr | done |"* ]] || false
  [[ "$("$VIBE" queue status | head -n 1)" == *" · 0 no PR · "* ]] || false
}

@test "research: a builds= cycle, a self-reference and an unknown hid keep every worker on the card, at depth 0" {
  local f="$XDG_STATE_HOME/vibe/web/index.html" r
  r="$(make_repo proj)"
  research_fixture "$Q" "$r"
  # h1 and h3 build on each other; h4 builds on h1; h2 on itself; h5 on a hid that is not there.
  sed -i.bak 's/^builds=.*/builds=h3/' "$Q"/*-h1/job
  sed -i.bak 's/^builds=.*/builds=h1/' "$Q"/*-h3/job
  sed -i.bak 's/^builds=.*/builds=h2/' "$Q"/*-h2/job
  rjob "$Q" 20261117-100500-proj-research-lr-h5 queued "$r" research/lr/h5 research=lr card=research hid=h5 place=turing idea=x builds=h9
  rpage
  [ "$(grep -o 'style="--d:[0-9]" data-hid="[a-z0-9]*"' "$f" | tr -d '"\n')" = 'style=--d:0 data-hid=h2style=--d:0 data-hid=h5style=--d:0 data-hid=h1style=--d:0 data-hid=h3style=--d:0 data-hid=h4' ]
  # h3 is in the cycle: its paste field is on the page.
  [ "$(grep -o 'class="paste"' "$f" | wc -l)" -eq 1 ]
}

@test "queue archive --research: a question archives with all its jobs once each has ended; a live one refuses all" {
  local r a
  r="$(make_repo proj)" a="$XDG_STATE_HOME/vibe/archive/$(date +%Y-%m)"
  research_fixture "$Q" "$r"
  run "$VIBE" queue archive --research lr
  [ "$status" -ne 0 ]
  [[ "$output" == *"research-lr-h2 has not ended (gpu)"* ]] || false
  [ "$(find "$Q" -mindepth 1 -maxdepth 1 -name "*research-lr*" | wc -l)" -eq 5 ]
  echo "done" >"$Q/20261117-100200-proj-research-lr-h2/status"
  run "$VIBE" queue archive --research lr
  [ "$status" -eq 0 ]
  [ "$(find "$Q" -mindepth 1 -maxdepth 1 -name "*research-lr*" | wc -l)" -eq 0 ]
  [ "$(find "$a" -mindepth 1 -maxdepth 1 -name "*research-lr*" | wc -l)" -eq 5 ]
  run "$VIBE" queue archive --research lr
  [[ "$output" == *"no research job 'lr'"* ]] || false
  run "$VIBE" queue archive --research
  [[ "$output" == *"usage: vibe queue archive --research <slug>"* ]] || false
}

@test "gpu --place: past the job's deadline= it asks for no place run" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok "deadline=2000-01-01 08:00"
  VIBE_JOB_DIR="$Q/01-a" run "$VIBE" queue gpu --place runpod -- true
  [ "$status" -ne 0 ]
  [[ "$output" == *"past this job's deadline (2000-01-01 08:00)"* ]] || false
  [ ! -e "$Q/01-a/run" ]
}

# places — stub places runpod and vast, polled each 0.1 s: each verb but tick to $STUBS/place.log; exec runs the folder's script
# with WS_IN for /ws/in. $STUBS/fail-up: up fails; short-limit: the limit is 3 s after up; price: what price prints,
# none: price exits 3; out-links: pull leaves a link and a FIFO in out/; pull-hang, down-hang: that verb sleeps 30 s.
places() {
  local w="$BATS_TEST_TMPDIR/workspaces"
  export VIBE_WORKSPACES="$w" VIBE_WS_POLL=0.1
  mkdir -p "$w/_places"
  cat >"$w/_places/runpod" <<EOF
#!/usr/bin/env bash
v="\$1"
shift
[ "\$v" != tick ] || exit 0
echo "\${0##*/} \$v\${*:+ \$*} hours=\$WS_HOURS folder=\${WS_DIR#"\$WS_STATE"/}" >>"$STUBS/place.log"
case "\$v" in
  up)
    if [ -e "$STUBS/fail-up" ]; then echo "\${0##*/}: no machine free" >&2 && exit 1; fi
    echo pod-1 >"\$WS_STATE/id"
    echo "\$WS_NAME" >"$STUBS/ws-name"
    date +%s >"\$WS_STATE/started"
    if [ -e "$STUBS/short-limit" ]; then echo \$((\$(date +%s) + 3)); else echo \$((\$(date +%s) + WS_HOURS * 3600)); fi >"\$WS_STATE/limit"
    ;;
  exec)
    [ -x "\$WS_DIR/\$1" ] || exit 3
    WS_IN="\$WS_STATE/in" exec "\$WS_DIR/\$@"
    ;;
  pull)
    [ ! -e "$STUBS/pull-hang" ] || exec sleep 30
    mkdir -p "\$WS_STATE/out" && echo pulled >"\$WS_STATE/out/note"
    if [ -e "$STUBS/out-links" ]; then ln -sfn "\$HOME" "\$WS_STATE/out/home" && mkfifo "\$WS_STATE/out/fifo"; fi
    ;;
  down)
    [ ! -e "$STUBS/down-hang" ] || exec sleep 30
    rm -f "\$WS_STATE/id"
    ;;
  price) if [ -e "$STUBS/price" ]; then cat "$STUBS/price"; else exit 3; fi ;;
esac
EOF
  cp "$w/_places/runpod" "$w/_places/vast"
  chmod +x "$w/_places/runpod" "$w/_places/vast"
}

# research_repo — a repo whose main holds .claude/research/ (runpod, vast; hours=2) and train.sh; echoes its path.
# $STUBS/run-sleep: train.sh waits 30 s first; run-hold: it waits while the file exists; run-end: it got past the wait.
research_repo() {
  local r
  r="$(make_repo proj)"
  mkdir -p "$r/.claude/research"
  printf '%s\n' kind=run result=folder places=runpod,vast hours=2 image=ghcr.io/x/research commit=0123456789abcdef0123456789abcdef01234567 >"$r/.claude/research/workspace.conf"
  # shellcheck disable=SC2016  # the script expands it
  printf '#!/bin/sh\ncd "${WS_IN:-/ws/in}/repo" && exec "${WS_IN:-/ws/in}/cmd"\n' >"$r/.claude/research/run"
  printf '#!/bin/sh\necho %s\n' "'RESULT {\"metric\": 0.1, \"partial\": true}'" >"$r/.claude/research/stop"
  chmod +x "$r/.claude/research/run" "$r/.claude/research/stop"
  cat >"$r/train.sh" <<EOF
echo "in \${PWD##*/} at \$(git rev-parse HEAD), commits: \$(git rev-list --all | wc -l | tr -d ' ')"
[ ! -e "$STUBS/run-sleep" ] || sleep 30
while [ -e "$STUBS/run-hold" ]; do sleep 0.1; done
touch "$STUBS/run-end"
echo 'RESULT {"metric": 0.5}'
echo 'RESULT {"metric": 0.7, "seed": 1}'
echo "a last line"
EOF
  git -C "$r" add -A && git -C "$r" commit -q -m "feat: research folder" && git -C "$r" push -q origin main
  printf '%s' "$r"
}

@test "gpu --place: up, exec run, pull, down at runpod or vast, in the repo's .claude/research/, hours from its conf; then the follow-up" {
  local r p
  places
  r="$(research_repo)"
  touch "$STUBS/out-links"
  mkjob 01-a "$r" task-a place place=runpod
  mkjob 02-b "$r" task-b place place=vast
  drain
  [ "$status" -eq 0 ]
  for p in runpod vast; do
    [ "$(grep "^$p " "$STUBS/place.log")" = "$(printf '%s %s hours=2 folder=in/repo/.claude/research\n' "$p" price "$p" up "$p" 'exec run' "$p" pull "$p" down)" ]
  done
  [ "$(cat "$Q/01-a/run/place")" = runpod ]
  grep -qx "in repo at $(cat "$Q/01-a/run/commit"), commits: 1" "$Q/01-a/run/log"
  [ "$(cat "$Q/01-a/run/exit")" = 0 ]
  [ "$(cat "$Q/01-a/run/price")" = 0 ]
  # place_run copies them before the instance dir goes; no code reads them yet (PR research-card-status keeps the copy).
  [[ "$(cat "$Q/01-a/run/started")" =~ ^[0-9]+$ ]] || false
  [[ "$(cat "$Q/01-a/run/limit")" =~ ^[0-9]+$ ]] || false
  [ ! -e "$XDG_STATE_HOME/vibe/workspaces/research-01-a" ]
  [ "$(cat "$Q/01-a/cost")" = 0.00 ]
  [ "$(cat "$Q/01-a/run-result")" = '{"metric":0.7,"seed":1}' ]
  grep -qF -- '- Result: {"metric":0.7,"seed":1}' "$Q/01-a-gpu/prompt.md"
  [ "$(cat "$Q/01-a/out/note")" = pulled ]
  [ "$(cat "$STUBS/ws-name")" = research-proj ]
  # A link or FIFO the rented machine leaves in out/ never reaches the job dir.
  [ "$(ls -A "$Q/01-a/out")" = note ]
  [ "$(ls -A "$Q/02-b/out")" = note ]
  [ ! -e "$Q/01-a/gpu-job" ]
  [ ! -e "$XDG_STATE_HOME/vibe/workspaces/research-01-a" ]
  [ "$(cat "$Q/01-a/note")" = "GPU run exit 0 → 01-a-gpu" ]
  grep -qF -- "- Log: $Q/01-a/run/log" "$Q/01-a-gpu/prompt.md"
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
  [ "$(cat "$Q/02-b-gpu/status")" = "done" ]
}

@test "gpu --place: the run is cut before the limit; the stop script's RESULT line ends the log, then pull and down" {
  local r
  command -v timeout >/dev/null || command -v gtimeout >/dev/null || skip "no timeout(1): no bound"
  places
  r="$(research_repo)"
  touch "$STUBS/short-limit" "$STUBS/run-sleep"
  export VIBE_WS_STOP_SECS=2
  mkjob 01-a "$r" task-a place
  drain
  [ "$status" -eq 0 ]
  [ "$(cut -d' ' -f2,3 "$STUBS/place.log")" = "$(printf '%s\n' 'price hours=2' 'up hours=2' 'exec run' 'exec stop' 'pull hours=2' 'down hours=2')" ]
  [ "$(cat "$Q/01-a/run/exit")" = 124 ]
  [ "$(tail -n 1 "$Q/01-a/run/log")" = 'RESULT {"metric": 0.1, "partial": true}' ]
  [ "$(cat "$Q/01-a/run-result")" = '{"metric":0.1,"partial":true}' ]
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
}

@test "gpu --place: a hung pull or down ends after VIBE_WS_TICK_SECS; the instance stays for vibe ws tick, the follow-up runs" {
  local r
  command -v timeout >/dev/null || command -v gtimeout >/dev/null || skip "no timeout(1): no bound"
  places
  r="$(research_repo)"
  touch "$STUBS/pull-hang" "$STUBS/down-hang"
  export VIBE_WS_TICK_SECS=1
  mkjob 01-a "$r" task-a place
  SECONDS=0
  drain
  [ "$status" -eq 0 ]
  [ "$SECONDS" -lt 25 ]
  [ "$(cut -d' ' -f2 "$STUBS/place.log" | tail -n 2)" = "$(printf '%s\n' pull down)" ]
  grep -qxF 'vibe: down of research-01-a failed — vibe ws status research-01-a' "$Q/01-a/run/log"
  [ "$(cat "$XDG_STATE_HOME/vibe/workspaces/research-01-a/id")" = pod-1 ]
  [ "$(cat "$XDG_STATE_HOME/vibe/workspaces/research-01-a/owner")" = "$Q/01-a" ]
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
}

@test "gpu --place: no .claude/research/ in the repo is one error line; nothing is queued" {
  local r
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok
  echo "$r" >"$Q/01-a/worktree"
  VIBE_JOB_DIR="$Q/01-a" run "$VIBE" queue gpu --place runpod -- sh train.sh
  [ "$status" -ne 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == "vibe: no .claude/research/ in $r: --place runpod runs the repo's research folder"* ]] || false
  [ ! -e "$Q/01-a/run" ]
  [ -z "$(ls "$GPU_QUEUE_DIR/queued" 2>/dev/null)" ]
}

# refused PLACE MESSAGE — vibe queue gpu --place PLACE in job 01-a stops with the one line `vibe: MESSAGE`.
refused() {
  local out
  if out="$(VIBE_JOB_DIR="$Q/01-a" "$VIBE" queue gpu --place "$1" -- sh train.sh 2>&1)"; then return 1; fi
  printf '%s\n' "$out"
  [ "$out" = "vibe: $2" ]
}

@test "gpu --place: a bad conf, a place it lacks, a missing secret, no run script, an uncommitted folder or file, or a second run is one error line; nothing is queued" {
  local r c f=.claude/research good e="$HOME/.config/vibe/workspaces/research-proj.env"
  places
  r="$(research_repo)"
  c="$r/$f/workspace.conf"
  good="$(cat "$c")"
  mkjob 01-a "$r" task-a ok
  echo "$r" >"$Q/01-a/worktree"
  sed -i.bak 's/^places=.*/places=runpod,mars/' "$c"
  refused runpod "$f/workspace.conf: unknown place mars"
  sed -i.bak 's/^result=.*/result=branch/; s/^places=.*/places=runpod,vast/' "$c"
  refused runpod "$f/workspace.conf needs kind=run and result=folder"
  printf '%s\n' "$good" | sed 's/^places=.*/places=runpod/' >"$c"
  refused vast "$f/workspace.conf has no place 'vast' — places=runpod"
  printf '%s\n' "$good" | grep -v '^hours=' >"$c"
  refused runpod "$f/workspace.conf needs hours=: the limit of a run"
  printf '%s\n' "$good" | grep -v '^commit=' >"$c"
  refused runpod "$f/workspace.conf needs image= and commit=: runpod rents that image"
  printf '%s\n' "$good" secrets=HF_TOKEN >"$c"
  refused runpod "research-proj needs HF_TOKEN: write KEY=VALUE lines to $e, mode 600"
  mkdir -p "${e%/*}"
  echo OTHER=1 >"$e"
  chmod 644 "$e"
  refused runpod "$e: others can read it — chmod 600 $e"
  chmod 600 "$e"
  refused runpod "$e does not set: HF_TOKEN"
  echo HF_TOKEN=hf-x >>"$e"
  refused runpod "commit $f/ first: the run takes the worktree's HEAD"
  printf '%s\n' "$good" >"$c"
  rm "$c.bak" "$BATS_TEST_TMPDIR/workspaces/_places/vast"
  refused vast "no place script 'vast' in $BATS_TEST_TMPDIR/workspaces/_places"
  chmod -x "$r/$f/run"
  refused runpod "$f/run is missing or not executable: the place runs it"
  chmod +x "$r/$f/run"
  echo "# changed" >>"$r/$f/run"
  refused runpod "commit $f/ first: the run takes the worktree's HEAD"
  [ ! -e "$Q/01-a/run" ]
  [ -z "$(ls "$GPU_QUEUE_DIR/queued" 2>/dev/null)" ]
  git -C "$r" checkout -q -- "$f"
  echo "# changed" >>"$r/train.sh"
  refused runpod "commit your changes first: the run takes the worktree's HEAD"
  git -C "$r" checkout -q -- train.sh
  echo scratch >"$r/scratch.txt"
  mkdir "$Q/01-a/run"
  refused runpod "this job queued its run already ($Q/01-a/run): one run per session"
  [ -z "$(ls "$Q/01-a/run")" ]
}

@test "gpu: run-result holds the last RESULT line of the run log, on turing too; a turing run costs 0" {
  local r pid
  r="$(make_repo proj)"
  printf 'RESULT {"metric": 1}\nRESULT {"metric": 2.5, "seed": 3}\nbye\n' >"$STUBS/gpu-result"
  mkjob 01-a "$r" task-a gpu research=q1
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/run.out" 2>&1 &
  pid=$!
  for _ in $(seq 1 100); do
    [ "$(cat "$Q/01-a/status" 2>/dev/null)" != gpu ] || break
    sleep 0.1
  done
  "$REPO_ROOT/bin/gpu-queue" run --once
  wait "$pid"
  [ "$(cat "$Q/01-a/run-result")" = '{"metric":2.5,"seed":3}' ]
  grep -qF -- "- Result: {\"metric\":2.5,\"seed\":3} ($Q/01-a/run-result)" "$Q/01-a-gpu/prompt.md"
  [ "$(cat "$Q/01-a/cost")" = 0 ]
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
}

@test "gpu: no RESULT line, one that does not parse or a metric that is no finite number means failed; a plain GPU job has no Result line" {
  local r log="$BATS_TEST_TMPDIR/run.log" i
  r="$(make_repo proj)"
  mkjob 01-a "$r" task-a ok research=q1
  for i in 'loss 0.3' 'RESULT {"metric": "high"}' 'RESULT {"metric": 1' 'RESULT {"metric": NaN}' 'RESULT {"metric": -Infinity}'; do
    echo '{"metric":9}' >"$Q/01-a/run-result"
    printf '%s\n' "$i" >"$log"
    rm -rf "$Q/01-a-gpu"
    GPUQ_EXIT=0 GPUQ_LOG="$log" "$VIBE" queue follow "$Q/01-a" >/dev/null
    [ ! -e "$Q/01-a/run-result" ]
    grep -qF -- '- Result: none — no RESULT line: the run failed' "$Q/01-a-gpu/prompt.md"
  done
  mkjob 02-b "$r" task-b ok
  GPUQ_EXIT=0 GPUQ_LOG="$log" "$VIBE" queue follow "$Q/02-b" >/dev/null
  run grep -c 'Result:' "$Q/02-b-gpu/prompt.md"
  [ "$output" = 0 ]
}

@test "gpu --place: a failed up writes infra, runs nothing more there; the follow-up gets Exit: infra and the reason" {
  local r
  places
  r="$(research_repo)"
  touch "$STUBS/fail-up"
  mkjob 01-a "$r" task-a place
  drain
  [ "$status" -eq 0 ]
  [ "$(cut -d' ' -f1,2 "$STUBS/place.log")" = "$(printf '%s\n' 'runpod price' 'runpod up')" ]
  [ "$(cat "$Q/01-a/infra")" = "runpod: no machine free" ]
  [ "$(cat "$Q/01-a/run/exit")" = infra ]
  [ ! -e "$Q/01-a/run-result" ]
  [ ! -e "$XDG_STATE_HOME/vibe/workspaces/research-01-a" ]
  grep -qF -- '- Exit: infra' "$Q/01-a-gpu/prompt.md"
  grep -qF -- '- Infra: runpod: no machine free' "$Q/01-a-gpu/prompt.md"
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
  rm "$STUBS/fail-up" "$STUBS/place.log"
  echo n/a >"$STUBS/price"
  mkjob 02-b "$r" task-b place
  drain
  [ "$(cat "$STUBS/place.log")" = "runpod price hours=2 folder=in/repo/.claude/research" ]
  [ "$(cat "$Q/02-b/infra")" = "vibe: no price from runpod (exit 0): n/a" ]
  [ "$(cat "$Q/02-b/run/exit")" = infra ]
  [ ! -e "$Q/02-b/cost" ]
}

@test "gpu --place: the usd gate refuses a start when spent + hours × price is above usd; spent is the cost of the research's live and archived jobs of its repo" {
  local r a="$XDG_STATE_HOME/vibe/archive/2026-11/00-w"
  places
  r="$(research_repo)"
  echo 0.5 >"$STUBS/price"
  mkdir -p "$a"
  printf 'repo=%s\nbranch=w\nresearch=q1\n' "$r" >"$a/job"
  echo 0.40 >"$a/cost"
  mkjob 00-x "$r" task-x ok research=q1
  mkjob 00-y "$r" task-y ok research=q2
  mkjob 00-z "$(make_repo other)" task-z ok research=q1
  echo "done" | tee "$Q/00-x/status" "$Q/00-y/status" >"$Q/00-z/status"
  echo 1.50 >"$Q/00-x/cost"
  echo 9.00 | tee "$Q/00-y/cost" >"$Q/00-z/cost"
  mkjob 01-a "$r" task-a place research=q1 usd=2.8
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/run/exit")" = usd ]
  [ "$(grep -c ' up ' "$STUBS/place.log")" -eq 0 ]
  grep -qF -- '- Exit: usd' "$Q/01-a-gpu/prompt.md"
  grep -qF -- '- Result: none — usd gate: spent 1.90 + 2 h × 0.5 USD/h is above usd=2.8: no start' "$Q/01-a-gpu/prompt.md"
  [ "$(cat "$Q/01-a/cost")" = 0 ]
  [ ! -e "$Q/01-a/infra" ]
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
  # A lock a killed runner left in the gate: over 1 min old, the next gate breaks it.
  mkdir "$XDG_STATE_HOME/vibe/usd.lock"
  touch -t 200001010000 "$XDG_STATE_HOME/vibe/usd.lock"
  mkjob 02-b "$r" task-b place research=q1 usd=3
  drain
  [ "$(cat "$Q/02-b/run/exit")" = 0 ]
  [ "$(grep -c '^runpod up ' "$STUBS/place.log")" -eq 1 ]
  [ "$(cat "$Q/02-b/run/price")" = 0.5 ]
  [ "$(cat "$Q/02-b/cost")" = 0.00 ]
  [ ! -e "$XDG_STATE_HOME/vibe/usd.lock" ]
  mkjob 03-c "$r" task-c place research=q1 usd=abc
  drain
  [ "$(cat "$Q/03-c/run/exit")" = usd ]
  [ "$(grep -c '^runpod up ' "$STUBS/place.log")" -eq 1 ]
  grep -qF -- '- Result: none — usd gate: usd=abc is no number: no start' "$Q/03-c-gpu/prompt.md"
}

@test "gpu --place: the usd gate counts a running run at its full hours: of two runs that start in one pass, one starts" {
  local r j pid
  places
  r="$(research_repo)"
  echo 0.5 >"$STUBS/price"
  touch "$STUBS/run-hold"
  for j in 01-a 02-b; do
    mkjob "$j" "$r" "task-$j" ok research=q1 usd=1.5
    echo "$r" >"$Q/$j/worktree"
    echo gpu >"$Q/$j/status"
    mkdir "$Q/$j/run"
    echo runpod >"$Q/$j/run/place"
    git -C "$r" rev-parse HEAD >"$Q/$j/run/commit"
    printf '#!/usr/bin/env bash\nsh train.sh\n' >"$Q/$j/run/cmd"
  done
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/run.out" 2>&1 &
  pid=$!
  for _ in $(seq 1 100); do
    if [ -e "$Q/01-a-gpu/job" ] || [ -e "$Q/02-b-gpu/job" ]; then break; fi
    sleep 0.1
  done
  [ "$(cat "$Q/01-a/cost" "$Q/02-b/cost" | sort | tr '\n' ' ')" = "0 1.00 " ]
  rm "$STUBS/run-hold"
  wait "$pid"
  [ "$(cat "$Q/01-a/run/exit" "$Q/02-b/run/exit" | sort | tr '\n' ' ')" = "0 usd " ]
  [ "$(grep -c '^runpod up ' "$STUBS/place.log")" -eq 1 ]
  [ "$(cat "$Q/01-a-gpu/status") $(cat "$Q/02-b-gpu/status")" = "done done" ]
}

@test "gpu --place: a run whose process died before its end is infra too, also when a reboot gave its pid to another command" {
  local r j
  r="$(make_repo proj)"
  sleep 30 &
  for j in 01-a 02-b; do
    mkjob "$j" "$r" "task-$j" ok
    mkdir -p "$Q/$j/run"
    echo runpod >"$Q/$j/run/place"
    echo gpu >"$Q/$j/status"
  done
  echo 999999 >"$Q/01-a/run/pid"
  echo "$!" >"$Q/02-b/run/pid"
  drain
  kill "$(cat "$Q/02-b/run/pid")"
  [ "$status" -eq 0 ]
  for j in 01-a 02-b; do
    [ "$(cat "$Q/$j/run/exit")" = infra ]
    grep -qF 'the run process died' "$Q/$j/infra"
    grep -qF -- '- Infra: the run process died' "$Q/$j-gpu/prompt.md"
    [ "$(cat "$Q/$j/status")" = "done" ]
    [ "$(cat "$Q/$j-gpu/status")" = "done" ]
  done
}

@test "gpu --place: a run/commit git reads as an option, a run/place other than runpod and vast, or a link in run/ is infra; git runs nothing" {
  local r j
  places
  r="$(research_repo)"
  for j in 01-a 02-b 03-c 04-d; do
    mkjob "$j" "$r" "task-$j" ok
    echo "$r" >"$Q/$j/worktree"
    echo gpu >"$Q/$j/status"
    mkdir "$Q/$j/run"
    printf '#!/usr/bin/env bash\nsh train.sh\n' >"$Q/$j/run/cmd"
  done
  echo runpod >"$Q/01-a/run/place"
  echo "--upload-pack=touch $STUBS/pwned #" >"$Q/01-a/run/commit"
  echo turing >"$Q/02-b/run/place"
  git -C "$r" rev-parse HEAD >"$Q/02-b/run/commit"
  # A link to a host file the sandbox hides: the runner must not copy it to the place or print its first line.
  echo SECRET-LINE >"$BATS_TEST_TMPDIR/secret"
  for j in 03-c 04-d; do git -C "$r" rev-parse HEAD >"$Q/$j/run/commit"; done
  echo runpod >"$Q/03-c/run/place"
  ln -sf "$BATS_TEST_TMPDIR/secret" "$Q/03-c/run/cmd"
  ln -s "$BATS_TEST_TMPDIR/secret" "$Q/04-d/run/place"
  drain
  [ "$status" -eq 0 ]
  [ ! -e "$STUBS/pwned" ]
  [ ! -e "$STUBS/place.log" ]
  for j in 01-a 02-b 03-c 04-d; do
    [ "$(cat "$Q/$j/run/exit")" = infra ]
    grep -qxF 'vibe: run/place must be runpod or vast, run/commit a commit id, run/cmd a file, and none a link' "$Q/$j/infra"
    [ "$(cat "$Q/$j-gpu/status")" = "done" ]
  done
  run grep -rlF SECRET-LINE "$Q" "$XDG_STATE_HOME/vibe/workspaces"
  [ "$status" -eq 1 ]
}

@test "gpu --place: the runner writes no job dir file through a link the agent planted; cost takes the runner's price" {
  local r f h="$BATS_TEST_TMPDIR/host-file"
  places
  r="$(research_repo)"
  echo 0.5 >"$STUBS/price"
  mkjob 01-a "$r" task-a ok research=q1
  echo "$r" >"$Q/01-a/worktree"
  echo gpu >"$Q/01-a/status"
  mkdir "$Q/01-a/run"
  echo runpod >"$Q/01-a/run/place"
  git -C "$r" rev-parse HEAD >"$Q/01-a/run/commit"
  printf '#!/usr/bin/env bash\nsh train.sh\n' >"$Q/01-a/run/cmd"
  echo keep >"$h"
  for f in run/log run/price cost; do ln -s "$h" "$Q/01-a/$f"; done
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$h")" = keep ]
  for f in run/log run/price run/pid run/exit cost; do
    [ -f "$Q/01-a/$f" ]
    [ ! -L "$Q/01-a/$f" ]
  done
  [ "$(cat "$Q/01-a/run/price")" = 0.5 ]
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
}

@test "gpu --place: a run/pid the runner cannot write warns; the runner goes on, starts the run once, runs the next job" {
  local r
  places
  r="$(research_repo)"
  mkjob 01-a "$r" task-a ok
  echo "$r" >"$Q/01-a/worktree"
  echo gpu >"$Q/01-a/status"
  mkdir -p "$Q/01-a/run/pid"
  echo runpod >"$Q/01-a/run/place"
  git -C "$r" rev-parse HEAD >"$Q/01-a/run/commit"
  printf '#!/usr/bin/env bash\nsh train.sh\n' >"$Q/01-a/run/cmd"
  mkjob 02-b "$r" task-b ok
  drain
  [ "$status" -eq 0 ]
  [[ "$output" == *"vibe: warning: $Q/01-a: place run pass failed"* ]] || false
  [ "$(grep -c '^runpod up ' "$STUBS/place.log")" -eq 1 ]
  [ "$(cat "$Q/01-a/run/exit")" = 0 ]
  [ "$(cat "$Q/02-b/status")" = "done" ]
}

@test "gpu --place: after a reboot, a run whose run/pid the runner could not write ends as infra; no second run starts" {
  local r g="$XDG_STATE_HOME/vibe/workspaces/run.01-a"
  places
  r="$(research_repo)"
  mkjob 01-a "$r" task-a ok
  echo "$r" >"$Q/01-a/worktree"
  echo gpu >"$Q/01-a/status"
  mkdir -p "$Q/01-a/run/pid" "${g%/*}"
  echo runpod >"$Q/01-a/run/place"
  echo 999999 >"$g" # the extension's copy of the pid, dead after the reboot
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/01-a/run/exit")" = infra ]
  grep -qF 'the run process died' "$Q/01-a/infra"
  [ ! -e "$STUBS/place.log" ]
  [ ! -e "$g" ]
}

@test "gpu --place: vibe ws tick leaves an instance past its limit to the place run that owns it; a dead run's goes down" {
  local r st="$XDG_STATE_HOME/vibe/workspaces/research-01-a" f="$BATS_TEST_TMPDIR/fake/research" pid
  places
  r="$(research_repo)"
  mkjob 01-a "$r" task-a ok
  mkdir -p "$Q/01-a/run" "$st" "${f%/*}"
  printf '#!/bin/sh\nsleep 30\n' >"$f"
  chmod +x "$f"
  # A place run is a fork of the research extension's pass event.
  "$f" event pass &
  pid=$!
  echo "$pid" >"$Q/01-a/run/pid"
  echo runpod >"$st/place"
  echo pod-1 >"$st/id"
  echo $(($(date +%s) - 10)) >"$st/limit"
  echo "$r/.claude/research" >"$st/dir"
  echo "$Q/01-a" >"$st/owner"
  run "$VIBE" ws tick
  [ "$status" -eq 0 ]
  [ ! -e "$STUBS/place.log" ]
  [ "$(cat "$st/id")" = pod-1 ]
  kill "$pid"
  wait "$pid" || true
  run "$VIBE" ws tick
  [ "$status" -eq 0 ]
  [ "$(cut -d' ' -f1-3 "$STUBS/place.log")" = "$(printf '%s\n' 'runpod exec stop' 'runpod down hours=2')" ]
  [ ! -e "$st/id" ]
}

# coord_wt REPO [ROW] — REPO's worktree research-q1 with RESEARCH.md committed: items h1, h2 (builds on h1), h3, h4, h5 (builds on h2); the
# ledger holds ROW, by default a baseline row. Echoes its path.
coord_wt() {
  local w="$1/.claude/worktrees/research-q1"
  "$VIBE" start -C "$1" research-q1 >/dev/null 2>&1
  {
    printf '# Research — proj / research-q1\n\n## Backlog\n\n### h1 wider net — open\n\n- Idea: a wider net fits.\n\n'
    # shellcheck disable=SC2016  # literal backticks in RESEARCH.md
    printf '### h2 warmup — open\n\n- **Builds on:** `h1`, its width\n\n### h3 dropout — open\n\n### h4 batch — open\n\n### h5 wide — deep — open\n\n- Builds on: h2.\n\n## Ledger\n\n'
    printf '| id | commit | run | cost | result | verdict | evidence |\n| --- | --- | --- | --- | --- | --- | --- |\n'
    printf '%s\n' "${2-| baseline | 0123abc | 1 | 0 | 0.50 | baseline | runs/baseline/log |}"
  } >"$w/RESEARCH.md"
  git -C "$w" add RESEARCH.md && git -C "$w" commit -q -m "docs(research): q1"
  printf '%s' "$w"
}

# coord R W [JOB-LINE...] — the coordinator job 01-c of research q1 on R's worktree W, as a session sees it.
coord() {
  mkjob 01-c "$1" research-q1 ok research=q1 "${@:3}"
  echo "$2" >"$Q/01-c/worktree"
}

# qjob PATTERN — the one queue dir whose name ends in PATTERN.
qjob() { find "$Q" -mindepth 1 -maxdepth 1 -name "*$1"; }

@test "worker: a job for an item of the committed RESEARCH.md on research/<slug>/<hid> from HEAD; worker keys, after=, no question=" {
  local r w j
  r="$(make_repo proj)"
  w="$(coord_wt "$r")"
  coord "$r" "$w" usd=5 "deadline=2999-01-01 08:00" "question=Does width help?" workers=3 better=higher timeout=3h
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h2 --place runpod
  [ "$status" -eq 0 ]
  j="$(qjob -proj-research-q1-h2)"
  [ "$output" = "queued ${j##*/}: worker h2 at runpod on research/q1/h2" ]
  [ "$(git -C "$r" rev-parse research/q1/h2)" = "$(git -C "$w" rev-parse HEAD)" ]
  [ "$(cat "$j/job")" = "$(printf '%s\n' "repo=$r" model=sonnet research=q1 usd=5 'deadline=2999-01-01 08:00' timeout=3h \
    branch=research/q1/h2 'context=Research worker h2: warmup' hid=h2 place=runpod idea=warmup builds=h1 after= publish=push card=research)" ]
  grep -qxF '# Agent job: Research worker h2: warmup' "$j/prompt.md"
  grep -qF -- "- **Repo / branch:** $r · \`research/q1/h2\`" "$j/prompt.md"
  grep -qF -- '- **Time limit:** 3h' "$j/prompt.md"
  grep -qF "\`runs/h2/row.md\` holds the ledger row of the run" "$j/prompt.md"
  # The extension renders job-prompt.md with its own copy of job_prompt: a slot vibe fills and it does not shows here.
  no_slot "$j/prompt.md"
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h1
  [ "$status" -eq 0 ]
  j="$(qjob -research-q1-h1)"
  grep -qx place=turing "$j/job"
  grep -qx builds=root "$j/job"
  grep -qx 'idea=wider net' "$j/job"
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h5
  [ "$status" -eq 0 ]
  j="$(qjob -research-q1-h5)"
  grep -qx 'idea=wide — deep' "$j/job"
  grep -qx builds=h2 "$j/job"
  [ -z "$(find "$Q" -mindepth 1 -maxdepth 1 -name '.*')" ]
}

@test "research prompts: add appends the coordinator block once to a research= job with no hid=; a worker prompt ends in the worker block" {
  local r w a b c j n
  r="$(make_repo proj)"
  a="$BATS_TEST_TMPDIR/a" b="$BATS_TEST_TMPDIR/b" c="$BATS_TEST_TMPDIR/c"
  mkprep "$a" "$r" Bad-Branch
  echo research=q1 >>"$a/job"
  run "$VIBE" queue add "$a"
  [ "$status" -ne 0 ]
  sed -i.bak 's/^branch=.*/branch=rq/' "$a/job" && rm "$a/job.bak"
  mkprep "$b" "$r" plain
  mkprep "$c" "$r" rw
  printf 'research=q1\nhid=h9\n' >>"$c/job"
  run "$VIBE" queue add "$a" "$b" "$c"
  [ "$status" -eq 0 ]
  [ "$(cat "$(qjob -proj-rq)/prompt.md")" = "$(printf 'Do the task.\nMODE=ok\n\n' && cat "$REPO_ROOT/skills/fill-queue/references/research.md")" ]
  [ "$(cat "$(qjob -proj-plain)/prompt.md")" = "$(printf 'Do the task.\nMODE=ok')" ]
  [ "$(cat "$(qjob -proj-rw)/prompt.md")" = "$(printf 'Do the task.\nMODE=ok')" ]
  w="$(coord_wt "$r")"
  coord "$r" "$w"
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h1
  [ "$status" -eq 0 ]
  j="$(qjob -research-q1-h1)"
  n="$(wc -l <"$REPO_ROOT/skills/fill-queue/references/research-worker.md")"
  [ "$(tail -n "$((n + 1))" "$j/prompt.md")" = "$(echo && cat "$REPO_ROOT/skills/fill-queue/references/research-worker.md")" ]
  grep -qxF '# Agent job: Research worker h1: wider net' "$j/prompt.md"
  [ "$(grep -c '^## Research' "$j/prompt.md")" = 1 ]
}

@test "worker: refused at workers= live workers; an ended worker, another research or another repo's counts not; one hid runs once" {
  local r w n
  r="$(make_repo proj)"
  w="$(coord_wt "$r")"
  coord "$r" "$w" workers=2
  mkjob 02-w "$r" research/q1/h1 ok research=q1 hid=h1
  mkjob 03-w "$r" research/q1/h2 ok research=q1 hid=h2
  echo gpu >"$Q/03-w/status"
  mkjob 04-w "$r" research/q1/h3 ok research=q1 hid=h3
  echo "done" >"$Q/04-w/status"
  mkjob 05-w "$r" research/q2/h9 ok research=q2 hid=h9
  mkjob 06-w "$(make_repo other)" research/q1/h4 ok research=q1 hid=h4
  n="$(find "$Q" -mindepth 1 -maxdepth 1 | wc -l)"
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h3
  [ "$status" -ne 0 ]
  [ "$output" = "vibe: workers=2: h1 h2 run — start the next one after a worker ends" ]
  [ "$(find "$Q" -mindepth 1 -maxdepth 1 | wc -l)" = "$n" ]
  run git -C "$r" rev-parse --verify -q research/q1/h3
  [ "$status" -ne 0 ]
  echo "done" >"$Q/02-w/status"
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h2
  [ "$status" -ne 0 ]
  [ "$output" = "vibe: worker h2 runs already" ]
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h3
  [ "$status" -eq 0 ]
}

@test "worker: refused past the coordinator's deadline=" {
  local r w
  r="$(make_repo proj)"
  w="$(coord_wt "$r")"
  coord "$r" "$w" "deadline=2000-01-01 08:00"
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h1
  [ "$status" -ne 0 ]
  [ "$output" = "vibe: past this job's deadline (2000-01-01 08:00): start no worker, finish the task" ]
  [ "$(ls "$Q")" = 01-c ]
  run git -C "$r" rev-parse --verify -q research/q1/h1
  [ "$status" -ne 0 ]
}

@test "worker: refused with no baseline row in the ledger of RESEARCH.md at HEAD; an uncommitted one counts not" {
  local r w
  r="$(make_repo proj)"
  w="$(coord_wt "$r" '| h1 | 0123abc | 1 | 0 | 0.60 | passed | runs/h1/log |')"
  coord "$r" "$w"
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h2
  [ "$status" -ne 0 ]
  [ "$output" = "vibe: no baseline row in the ledger of RESEARCH.md at HEAD: run the baseline first" ]
  echo '| baseline | 0123abc | 1 | 0 | 0.50 | baseline | runs/baseline/log |' >>"$w/RESEARCH.md"
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h2
  [ "$status" -ne 0 ]
  [ "$(ls "$Q")" = 01-c ]
  git -C "$w" commit -q -am "docs(research): baseline row"
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h2
  [ "$status" -eq 0 ]
}

@test "worker: refused outside a coordinator job, for a hid that is no slug, an item RESEARCH.md lacks, or a branch git refuses" {
  local r w
  r="$(make_repo proj)"
  w="$(coord_wt "$r")"
  mkjob 01-a "$r" task-a ok
  VIBE_JOB_DIR="$Q/01-a" run "$VIBE" queue worker h1
  [ "$output" = "vibe: vibe queue worker runs inside a research coordinator job: research=, no hid=" ]
  mkjob 02-w "$r" research/q1/h1 ok research=q1 hid=h1
  VIBE_JOB_DIR="$Q/02-w" run "$VIBE" queue worker h2
  [ "$output" = "vibe: vibe queue worker runs inside a research coordinator job: research=, no hid=" ]
  coord "$r" "$w"
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker H1
  [ "$output" = "vibe: hid 'H1' is no slug: lowercase letters, digits, . _ -" ]
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h9
  [ "$output" = "vibe: no item '### h9 <name>' in RESEARCH.md at HEAD: commit it first" ]
  git -C "$r" branch research/q1/h3 main
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h3
  [ "$status" -ne 0 ]
  [ "$output" = "vibe: no branch research/q1/h3: fatal: a branch named 'research/q1/h3' already exists" ]
  [ "$(ls "$Q")" = "$(printf '%s\n' 01-a 01-c 02-w)" ]
}

@test "worker: a worker queued with no publish= or card= gets publish=push and card=research at the pass, pushes its branch and opens no PR" {
  local r
  r="$(make_repo proj)"
  mkjob 02-w "$r" research/q1/h1 ok research=q1 hid=h1
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/02-w/status")" = "done" ]
  grep -qx publish=push "$Q/02-w/job"
  grep -qx card=research "$Q/02-w/job"
  git --git-dir="$BATS_TEST_TMPDIR/proj.git" rev-parse -q --verify research/q1/h1 >/dev/null
  touch "$STUBS/gh.log"
  [ "$(grep -c 'pr create' "$STUBS/gh.log" || true)" = 0 ]
}

@test "worker: the runner runs each worker, pushes its branch, opens no PR; the worker ends wake the coordinator" {
  local r w c0 h c
  r="$(make_repo proj)"
  w="$(coord_wt "$r")"
  c0="$(git -C "$w" rev-parse HEAD)"
  echo 2 >"$STUBS/coord-blocks"
  mkjob 01-c "$r" research-q1 workers research=q1
  drain
  [ "$status" -eq 0 ]
  [ "$(grep -c '^asked for worker h[12] at ' "$STUBS/worker.out")" = 2 ]
  [ "$(grep -c '^queued .*: worker h[12] at ' "$Q/01-c/workers.log")" = 2 ]
  [ ! -e "$Q/01-c/agent/workers" ]
  for h in h1 h2; do
    [ "$(cat "$(qjob "-research-q1-$h")/status")" = "done" ]
    [ ! -e "$(qjob "-research-q1-$h")/pr" ]
    [ "$(git -C "$r" rev-parse "research/q1/$h~1")" = "$c0" ]
    [ "$(git --git-dir="$BATS_TEST_TMPDIR/proj.git" rev-parse "research/q1/$h")" = "$(git -C "$r" rev-parse "research/q1/$h")" ]
    [ -d "$r/.claude/worktrees/research/q1/$h" ]
  done
  run grep -c 'pr create' "$STUBS/gh.log"
  [ "$output" -ge 1 ]
  run grep 'pr create.*research/q1' "$STUBS/gh.log"
  [ "$status" -ne 0 ]
  [ "$(cat "$Q/01-c/status")" = "done" ]
  [[ "$(cat "$Q/01-c/note")" == "worker h"[12]" ended → "* ]] || false
  c="$(grep -lx research=q1 "$Q"/*/job | xargs grep -L '^hid=' | sort | tail -n 1)"
  c="${c%/job}"
  [ "$c" != "$Q/01-c" ]
  [ "$(cat "$c/status")" = "done" ]
  grep -qF -- '- Worker: h1 · ' "$c/prompt.md"
  grep -qF -- '- Worker: h2 · ' "$c/prompt.md"
}

@test "worker: the runner queues each ask of a session and logs each refusal; a session whose every ask is refused fails" {
  local r
  r="$(make_repo proj)"
  coord_wt "$r" >/dev/null
  printf 'h9 turing\nh1 turing\n' >"$STUBS/workers-ask"
  mkjob 01-c "$r" research-q1 askworkers research=q1
  drain
  [ "$status" -eq 0 ]
  grep -qF "vibe: no item '### h9 <name>' in RESEARCH.md at HEAD" "$Q/01-c/workers.log"
  grep -q '^queued .*: worker h1 at turing on research/q1/h1$' "$Q/01-c/workers.log"
  [ -n "$(qjob -research-q1-h1)" ]
  [ -z "$(qjob -research-q1-h9)" ]
  printf 'h9 turing\n' >"$STUBS/workers-ask"
  mkjob 05-c "$r" research-q1b askworkers research=q2
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/05-c/status")" = failed ]
  [[ "$(cat "$Q/05-c/note")" == "failed: each worker this session asked for was refused — vibe: no "* ]] || false
}

@test "worker: two worker ends queue one coordinator follow-up with both; the waiting session ends done; a worker with a session 2 wakes none" {
  local r c st nt
  r="$(make_repo proj)"
  mkjob 01-c "$r" research-q1 ok research=q1
  echo gpu >"$Q/01-c/status"
  date '+%F %T' >"$Q/01-c/ended"
  mkjob 02-w "$r" research/q1/h1 ok research=q1 hid=h1
  echo '{"metric":0.7}' >"$Q/02-w/run-result"
  mkjob 03-w "$r" research/q1/h2 ok research=q1 hid=h2
  mkjob 04-w "$r" research/q1/h3 ok research=q1 hid=h3
  mkdir "$Q/04-w-gpu"
  for c in 02-w:done:"done: row written" 03-w:failed:"failed: infra" 04-w:done:"GPU run exit 0 → 04-w-gpu"; do
    IFS=: read -r c st nt <<<"$c"
    echo "$st" >"$Q/$c/status"
    echo "$nt" >"$Q/$c/note"
    date '+%F %T' >"$Q/$c/ended"
  done
  drain
  [ "$status" -eq 0 ]
  c="$(qjob -proj-research-q1)"
  [ "$(echo "$c" | wc -l)" = 1 ]
  [ "$(cat "$c/status")" = "done" ]
  grep -qx follow=1 "$c/job"
  grep -qx parent=01-c "$c/job"
  [ "$(grep -c '^## Worker finished$' "$c/prompt.md")" = 2 ]
  grep -qxF -- '- Worker: h1 · job 02-w · branch research/q1/h1' "$c/prompt.md"
  grep -qxF -- '- End: done — done: row written' "$c/prompt.md"
  grep -qxF -- "- Result: {\"metric\":0.7} ($Q/02-w/run-result)" "$c/prompt.md"
  grep -qxF -- '- Worker: h2 · job 03-w · branch research/q1/h2' "$c/prompt.md"
  grep -qxF -- '- Result: none' "$c/prompt.md"
  run grep -c 'h3' "$c/prompt.md"
  [ "$output" = 0 ]
  [ "$(cat "$Q/01-c/status")" = "done" ]
  [ "$(cat "$Q/01-c/note")" = "worker h1 ended → ${c##*/}" ]
  [ "$(cat "$Q/02-w/fan")" = "${c##*/}" ]
  [ "$(cat "$Q/03-w/fan")" = "${c##*/}" ]
  [ "$(cat "$Q/04-w/fan")" = "follow-up 04-w-gpu" ]
}

@test "worker: a worker end waits while the coordinator session runs" {
  local r pid run c
  r="$(make_repo proj)"
  mkjob 01-c "$r" research-q1 wait research=q1
  sleep 30 3>&- &
  pid=$!
  echo running >"$Q/01-c/status"
  echo "$pid" >"$Q/01-c/pid"
  mkjob 02-w "$r" research/q1/h1 ok research=q1 hid=h1
  echo "done" >"$Q/02-w/status"
  date '+%F %T' >"$Q/02-w/ended"
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/run.out" 2>&1 &
  run=$!
  sleep 1
  [ ! -e "$Q/02-w/fan" ]
  [ "$(ls "$Q")" = "$(printf '%s\n' 01-c 02-w)" ]
  kill "$pid"
  wait "$run"
  c="$(qjob -proj-research-q1)"
  [ "$(cat "$Q/02-w/fan")" = "${c##*/}" ]
  grep -qx parent=01-c "$c/job"
  [ "$(cat "$c/status")" = "done" ]
}

@test "worker: 4 calls at once at workers=3 queue 3 workers; the lock is gone after them" {
  local r w h pids=() p
  r="$(make_repo proj)"
  w="$(coord_wt "$r")"
  coord "$r" "$w" workers=3
  for h in h1 h2 h3 h4; do
    VIBE_JOB_DIR="$Q/01-c" "$VIBE" queue worker "$h" >"$BATS_TEST_TMPDIR/$h.out" 2>&1 &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p" || true; done
  [ "$(find "$Q" -mindepth 1 -maxdepth 1 -name '*-research-q1-h*' | wc -l | tr -d ' ')" = 3 ]
  [ "$(cat "$BATS_TEST_TMPDIR"/h*.out | grep -c '^vibe: workers=3: .* run — start the next one after a worker ends$')" = 1 ]
  [ -z "$(find "$Q" -mindepth 1 -maxdepth 1 -name '.*')" ]
}

@test "worker: a done, an archived or no coordinator gets no wake; the worker's fan says why; another repo's coordinator is none" {
  local r a="$XDG_STATE_HOME/vibe/archive/2026-11"
  r="$(make_repo proj)"
  mkjob 01-c "$r" research-q1 ok research=q1
  mkjob 02-k "$r" research-q2 ok research=q2
  mkjob 03-w "$r" research/q1/h1 ok research=q1 hid=h1
  mkjob 04-w "$r" research/q2/h1 ok research=q2 hid=h1
  mkjob 05-w "$r" research/q3/h1 ok research=q3 hid=h1
  mkjob 06-k "$(make_repo other)" research-q3 ok research=q3
  for j in 01-c 02-k 03-w 04-w 05-w 06-k; do
    echo "done" >"$Q/$j/status"
    date '+%F %T' >"$Q/$j/ended"
  done
  echo timeout >"$Q/02-k/status"
  mkdir -p "$a"
  mv "$Q/02-k" "$a/"
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/03-w/fan")" = "no wake: 01-c done" ]
  [ "$(cat "$Q/04-w/fan")" = "no wake: 02-k archived" ]
  [ "$(cat "$Q/05-w/fan")" = "no coordinator" ]
  [ "$(ls "$Q")" = "$(printf '%s\n' 01-c 03-w 04-w 05-w 06-k)" ]
  [ "$(cat "$a/02-k/status")" = timeout ]
}

@test "worker: a blocked coordinator holds the wake until a session is queued; a timed-out one gets a follow-up" {
  local r c
  r="$(make_repo proj)"
  mkjob 01-c "$r" research-q1 ok research=q1
  mkjob 02-k "$r" research-q2 ok research=q2
  mkjob 03-w "$r" research/q1/h1 ok research=q1 hid=h1
  mkjob 04-w "$r" research/q2/h1 ok research=q2 hid=h1
  for c in 01-c:blocked 02-k:timeout 03-w:done 04-w:done; do
    echo "${c#*:}" >"$Q/${c%:*}/status"
    date '+%F %T' >"$Q/${c%:*}/ended"
  done
  drain
  [ "$status" -eq 0 ]
  [ ! -e "$Q/03-w/fan" ]
  c="$(qjob -proj-research-q2)"
  [ "$(cat "$Q/04-w/fan")" = "${c##*/}" ]
  grep -qx parent=02-k "$c/job"
  grep -qxF -- '- Worker: h1 · job 04-w · branch research/q2/h1' "$c/prompt.md"
  [ "$(cat "$Q/02-k/status")" = timeout ]
  mkjob 05-c "$r" research-q1 ok research=q1
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/03-w/fan")" = 05-c ]
  grep -qxF -- '- Worker: h1 · job 03-w · branch research/q1/h1' "$Q/05-c/prompt.md"
  [ "$(cat "$Q/05-c/status")" = "done" ]
  [ "$(cat "$Q/01-c/status")" = blocked ]
}

@test "answer: a slurm worker waits blocked: it counts at workers= and wakes no one; its answer writes run-result and queues session 2" {
  local r w
  r="$(make_repo proj)"
  w="$(coord_wt "$r")"
  coord "$r" "$w" workers=1
  # Not gpu: a drain waits for a gpu job, and nothing wakes this one while the slurm run is out.
  echo blocked >"$Q/01-c/status"
  date '+%F %T' >"$Q/01-c/ended"
  mkjob 02-w "$r" research/q1/h1 slurm research=q1 hid=h1 place=slurm
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/02-w/status")" = blocked ]
  [ -s "$Q/02-w/paste.md" ]
  git --git-dir="$BATS_TEST_TMPDIR/proj.git" cat-file -e research/q1/h1:runs/h1/job.sbatch
  [ ! -e "$Q/02-w/fan" ]
  [ "$(ls "$Q")" = "$(printf '%s\n' 01-c 02-w)" ]
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h2
  [ "$status" -ne 0 ]
  [ "$output" = "vibe: workers=1: h1 run — start the next one after a worker ends" ]
  run "$VIBE" queue answer 02-w 'RESULT {"metric": 0.8'
  [ "$status" -ne 0 ]
  [ "$output" = 'vibe: bad RESULT line — RESULT {"metric": <a finite number>}' ]
  [ ! -e "$Q/02-w-gpu" ]
  [ "$(cat "$Q/02-w/status")" = blocked ]
  run "$VIBE" queue answer 02-w 'RESULT {"metric": 0.8}'
  [ "$status" -eq 0 ]
  [ "$output" = 'queued session 2 of 02-w — result: {"metric":0.8}' ]
  [ "$(cat "$Q/02-w/run-result")" = '{"metric":0.8}' ]
  [ "$(cat "$Q/02-w/cost")" = 0 ]
  [ "$(cat "$Q/02-w/status")" = "done" ]
  grep -qxF -- '- Exit: slurm' "$Q/02-w-gpu/prompt.md"
  grep -qxF -- "- Log: $Q/02-w/slurm.log" "$Q/02-w-gpu/prompt.md"
  grep -qxF -- "- Result: {\"metric\":0.8} ($Q/02-w/run-result)" "$Q/02-w-gpu/prompt.md"
  grep -qx 'hid=h1' "$Q/02-w-gpu/job"
  [ ! -e "$Q/02-w/HANDOFF.md" ]
}

@test "stop --research: drain — the research starts no worker, its runs go on; a follow-up stays stopped; another research runs on" {
  local r w
  r="$(make_repo proj)"
  w="$(coord_wt "$r")"
  coord "$r" "$w"
  mkjob 02-w "$r" research/q1/h1 ok research=q1 hid=h1
  echo gpu >"$Q/02-w/status"
  mkjob 03-k "$r" research-q2 ok research=q2
  run "$VIBE" queue stop --research q1
  [ "$status" -eq 0 ]
  [ "$output" = "research q1: drain — 2 jobs" ]
  [ "$(cat "$Q/01-c/drain") $(cat "$Q/02-w/drain")" = "drain drain" ]
  [ ! -e "$Q/03-k/drain" ]
  VIBE_JOB_DIR="$Q/01-c" run "$VIBE" queue worker h2
  [ "$status" -ne 0 ]
  [ "$output" = "vibe: research q1 is stopped (vibe queue stop --research): start no worker, close the runs" ]
  run git -C "$r" rev-parse --verify -q research/q1/h2
  [ "$status" -ne 0 ]
  VIBE_JOB_DIR="$Q/02-w" run "$VIBE" queue gpu -- true
  [ "$status" -eq 0 ]
  [ -s "$Q/02-w/gpu-cmd" ]
  GPUQ_EXIT=0 GPUQ_LOG=/dev/null run "$VIBE" queue follow "$Q/02-w"
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/02-w-gpu/drain")" = drain ]
  run "$VIBE" queue stop --research nope
  [ "$status" -ne 0 ]
  [ "$output" = "vibe: no job of research nope in the queue" ]
  run "$VIBE" queue stop --research q1 --later
  [ "$status" -ne 0 ]
  [ "$output" = "vibe: usage: vibe queue stop <id> | --research <slug> [--now]" ]
}

@test "stop --research --now: a place run is cut as at its limit: stop, pull, down, a partial result; a run not up yet does not start; gpu queues no run" {
  local r j pid
  command -v timeout >/dev/null || command -v gtimeout >/dev/null || skip "no timeout(1): no bound"
  places
  r="$(research_repo)"
  touch "$STUBS/run-hold"
  for j in 01-a:q1 02-b:q2; do
    mkjob "${j%:*}" "$r" "task-${j%:*}" ok "research=${j#*:}"
    echo "$r" >"$Q/${j%:*}/worktree"
    echo gpu >"$Q/${j%:*}/status"
    mkdir "$Q/${j%:*}/run"
    echo runpod >"$Q/${j%:*}/run/place"
    git -C "$r" rev-parse HEAD >"$Q/${j%:*}/run/commit"
    printf '#!/usr/bin/env bash\nsh train.sh\n' >"$Q/${j%:*}/run/cmd"
  done
  "$VIBE" queue stop --research q2 --now >/dev/null
  "$VIBE" queue run --claude --drain >"$BATS_TEST_TMPDIR/run.out" 2>&1 &
  pid=$!
  for _ in $(seq 1 100); do
    if grep -q '^runpod exec run' "$STUBS/place.log" 2>/dev/null; then break; fi
    sleep 0.1
  done
  # The run leads its own process group: a cut of the pass event (timeout signals its group) leaves it alone.
  j="$(cat "$Q/01-a/run/pid")"
  [ "$(ps -o pgid= -p "$j" | tr -d ' ')" = "$j" ]
  run "$VIBE" queue stop --research q1 --now
  [ "$output" = "research q1: now — 1 jobs" ]
  wait "$pid"
  rm "$STUBS/run-hold"
  # The TERM reached the run under timeout(1): no orphan gets past the wait.
  sleep 0.5
  [ ! -e "$STUBS/run-end" ]
  [ "$(cut -d' ' -f2,3 "$STUBS/place.log")" = "$(printf '%s\n' 'price hours=2' 'up hours=2' 'exec run' 'exec stop' 'pull hours=2' 'down hours=2')" ]
  [ "$(cat "$Q/01-a/run/exit")" = 124 ]
  [ "$(tail -n 1 "$Q/01-a/run/log")" = 'RESULT {"metric": 0.1, "partial": true}' ]
  [ "$(cat "$Q/01-a/run-result")" = '{"metric":0.1,"partial":true}' ]
  [ "$(cat "$Q/01-a-gpu/status")" = "done" ]
  [ "$(cat "$Q/01-a-gpu/drain")" = now ]
  [ "$(cat "$Q/02-b/run/exit")" = stopped ]
  grep -qxF -- '- Exit: stopped' "$Q/02-b-gpu/prompt.md"
  grep -qxF -- '- Result: none — vibe: stopped before up (vibe queue stop --research --now)' "$Q/02-b-gpu/prompt.md"
  [ "$(cat "$Q/02-b/cost")" = 0 ]
  [ ! -e "$XDG_STATE_HOME/vibe/workspaces/research-01-a" ]
  VIBE_JOB_DIR="$Q/01-a-gpu" run "$VIBE" queue gpu -- true
  [ "$status" -ne 0 ]
  [ "$output" = "vibe: this job is stopped (drain=now): queue no run, finish the task" ]
}

@test "close: past deadline= and over usd=, a slurm worker's session 2 and the coordinator's close session still run" {
  local r c
  r="$(make_repo proj)"
  mkjob 02-w "$r" research/q1/h1 slurm research=q1 hid=h1 place=slurm usd=1 "deadline=2000-01-01 08:00"
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/02-w/status")" = blocked ]
  VIBE_JOB_DIR="$Q/02-w" run "$VIBE" queue gpu -- true
  [ "$status" -ne 0 ]
  # The coordinator waits for its worker (gpu); its research spent 5 USD of usd=1.
  mkjob 01-c "$r" research-q1 ok research=q1 usd=1 "deadline=2000-01-01 08:00"
  echo gpu >"$Q/01-c/status"
  date '+%F %T' >"$Q/01-c/ended"
  echo 5.00 >"$Q/01-c/cost"
  "$VIBE" queue answer 02-w 'RESULT {"metric": 0.9}' >/dev/null
  drain
  [ "$status" -eq 0 ]
  [ "$(cat "$Q/02-w-gpu/status")" = "done" ]
  [ "$(cat "$Q/02-w/fan")" = "follow-up 02-w-gpu" ]
  c="$(qjob -proj-research-q1)"
  [ "$(cat "$Q/02-w-gpu/fan")" = "${c##*/}" ]
  grep -qxF -- '- Worker: h1 · job 02-w-gpu · branch research/q1/h1' "$c/prompt.md"
  grep -qxF -- "- Result: {\"metric\":0.9} ($Q/02-w/run-result)" "$c/prompt.md"
  [ "$(cat "$c/status")" = "done" ]
  [ "$(cat "$Q/01-c/status")" = "done" ]
}
