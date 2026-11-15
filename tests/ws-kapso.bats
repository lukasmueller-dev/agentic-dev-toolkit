#!/usr/bin/env bats
#
# workspaces/kapso — conf, Dockerfile and the run, stop and steer scripts, against a stub kapso.

load helper

WS_SRC="$REPO_ROOT/workspaces/kapso"

setup() {
  git_env
  WS="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$WS/in/repo/eval" "$WS/data" "$WS/out" "$BATS_TEST_TMPDIR/bin"
  echo "# brief" >"$WS/in/brief.md"
  printf 'evaluation=eval\nexperiments=3\n' >"$WS/in/args"
  echo "CLAUDE_CODE_OAUTH_TOKEN=tok" >"$WS/secrets.env"
  unset CLAUDE_CODE_OAUTH_TOKEN
  export KAPSO_WS_ROOT="$WS" WS_HOURS=2 STUB_LOG="$BATS_TEST_TMPDIR/kapso.log"
  export STUB_SOLUTION="$BATS_TEST_TMPDIR/solution.json"
  # The stub logs its arguments joined by |; `build` seeds a campaign repo with one branch.
  cat >"$BATS_TEST_TMPDIR/bin/kapso" <<'EOF'
#!/usr/bin/env bash
{
  printf '%s' "$1"
  printf '|%s' "${@:2}"
  echo "|token=${CLAUDE_CODE_OAUTH_TOKEN-unset}"
} >>"$STUB_LOG"
cmd=$1
if [ "$cmd" = report ]; then
  echo "# stub report" >"$4"
elif [ "$cmd" = build ]; then
  case " $* " in *" --stop "*) exit 0 ;; esac
  while [ $# -gt 0 ]; do
    if [ "$1" = --output ]; then campaign=$2; fi
    shift
  done
  git init -q -b main "$campaign"
  git -C "$campaign" commit -q --allow-empty -m seed
  git -C "$campaign" branch kapso/exp-2
  mkdir -p "$campaign/.kapso"
  cp "$STUB_SOLUTION" "$campaign/.kapso/solution.json"
  exit "${STUB_RC:-0}"
fi
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/kapso"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

solution() { printf '%s\n' "$1" >"$STUB_SOLUTION"; }

@test "run: a campaign that met its goal gives result, report, bundle, branch and score" {
  solution '{"branch":"kapso/exp-2","commit":"c0ffee","score":0.91,"goal_achieved":true,"stopped_reason":"goal_achieved"}'
  run "$WS_SRC/run"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS/out/result")" = "done: kapso/exp-2, score 0.91" ]
  [ "$(cat "$WS/out/branch")" = "kapso/exp-2" ]
  [ "$(cat "$WS/out/score")" = "0.91" ]
  [ "$(cat "$WS/out/report.md")" = "# stub report" ]
  git bundle list-heads "$WS/out/repo.bundle" | grep -q 'refs/heads/kapso/exp-2'
}

@test "run: kapso gets the brief, repo, evaluation, budget, the override and the token" {
  solution '{"branch":"kapso/exp-2","score":1,"goal_achieved":true}'
  run "$WS_SRC/run"
  [ "$status" -eq 0 ]
  grep -qxF "build|--brief|$WS/in/brief.md|--repo|$WS/in/repo|--evaluation|$WS/in/repo/eval|--output|$WS/data/campaign|--budget-experiments|3|--budget-minutes|115|--config|$WS_SRC/config.yaml|token=tok" "$STUB_LOG"
}

@test "run: a solution without goal_achieved, or with false, gives failed:" {
  local json
  for json in '{"branch":"kapso/exp-2","score":0.4}' '{"branch":"kapso/exp-2","score":0.4,"goal_achieved":false,"stopped_reason":"budget_exhausted"}'; do
    rm -rf "$WS/data/campaign" "$WS/out"/*
    solution "$json"
    run "$WS_SRC/run"
    [ "$status" -eq 0 ]
    [[ "$(cat "$WS/out/result")" == "failed: goal not achieved ("* ]] || false
    [ "$(cat "$WS/out/branch")" = "kapso/exp-2" ]
  done
  [ "$(cat "$WS/out/result")" = "failed: goal not achieved (budget_exhausted)" ]
}

@test "run: a campaign with no branch gives failed: and no bundle, branch or score" {
  solution '{"branch":null,"commit":null,"score":null,"goal_achieved":false,"stopped_reason":"budget_exhausted"}'
  run "$WS_SRC/run"
  [ "$status" -eq 0 ]
  [ "$(cat "$WS/out/result")" = "failed: goal not achieved (budget_exhausted)" ]
  [ -s "$WS/out/report.md" ]
  [ ! -e "$WS/out/repo.bundle" ]
  [ ! -e "$WS/out/branch" ]
  [ ! -e "$WS/out/score" ]
}

@test "run: a kapso exit code is the script's, with a failed: result and a report" {
  solution '{"branch":"kapso/exp-2","score":1,"goal_achieved":true}'
  STUB_RC=7 run "$WS_SRC/run"
  [ "$status" -eq 7 ]
  [ "$(cat "$WS/out/result")" = "failed: run exit 7, see tool.log" ]
  [ -s "$WS/out/report.md" ]
}

@test "run: missing args still leave a failed: result" {
  echo "experiments=3" >"$WS/in/args"
  run "$WS_SRC/run"
  [ "$status" -ne 0 ]
  [[ "$(cat "$WS/out/result")" == "failed: "* ]] || false
  [ ! -e "$STUB_LOG" ]
}

@test "stop: ends the campaign in /ws/data and keeps it" {
  run "$WS_SRC/stop"
  [ "$status" -eq 0 ]
  [ "$(cat "$STUB_LOG")" = "build|--output|$WS/data/campaign|--stop|token=unset" ]
}

@test "steer: the text is one argument to kapso inbox note" {
  run "$WS_SRC/steer" "try a smaller batch size"
  [ "$status" -eq 0 ]
  [ "$(cat "$STUB_LOG")" = "inbox|note|$WS/data/campaign|try a smaller batch size|token=unset" ]
  run "$WS_SRC/steer"
  [ "$status" -ne 0 ]
}

@test "conf, Dockerfile and override agree: a run, branch result, one pinned commit, no Codex, no pause" {
  local commit
  commit="$(sed -n 's/^commit=//p' "$WS_SRC/workspace.conf")"
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || false
  grep -qx 'kind=run' "$WS_SRC/workspace.conf"
  grep -qx 'result=branch' "$WS_SRC/workspace.conf"
  grep -qx 'secrets=CLAUDE_CODE_OAUTH_TOKEN' "$WS_SRC/workspace.conf"
  grep -qxF "ARG COMMIT=$commit" "$WS_SRC/Dockerfile"
  grep -qE 'claude-code@[0-9]+\.[0-9]+\.[0-9]+ ' "$WS_SRC/Dockerfile"
  grep -q 'git config --system user.email' "$WS_SRC/Dockerfile"
  grep -qF 'mkdir -p /ws && chown node:node /ws' "$WS_SRC/Dockerfile"
  # shellcheck disable=SC2016 # the Dockerfile line holds a literal $PATH
  grep -qx 'ENV PATH=/home/node/venv/bin:/opt/kapso/bin:$PATH' "$WS_SRC/Dockerfile"
  grep -qx '  enabled: false' "$WS_SRC/config.yaml"
  grep -qx '    cli: claude_code' "$WS_SRC/config.yaml"
  grep -qF "${commit:0:7}" "$REPO_ROOT/docs/workspaces/kapso.md"
}

# recipe_file NAME — the body of the recipe's `cat >NAME <<'EOF'` block.
recipe_file() { sed -n "\\#^cat >$1 <<'EOF'\$#,/^EOF\$/p" "$REPO_ROOT/docs/workspaces/kapso.md" | sed '1d;$d'; }

@test "recipe: the test repo scores 0.375 as written and 1.0 once count_words splits on any whitespace" {
  local d="$BATS_TEST_TMPDIR/recipe-repo"
  mkdir -p "$d/eval"
  recipe_file words.py >"$d/words.py"
  recipe_file eval/evaluate.py >"$d/eval/evaluate.py"
  cd "$d"
  run python3 -B eval/evaluate.py
  [ "$status" -eq 0 ]
  [ "$output" = "accuracy: 0.375" ]
  printf 'def count_words(text):\n    return len(text.split())\n' >words.py
  run python3 -B eval/evaluate.py
  [ "$output" = "accuracy: 1.000" ]
  jq -e '.score == 1 and .evaluation_script_path == "kapso_evaluation/evaluate.py"' eval/result.json
}
