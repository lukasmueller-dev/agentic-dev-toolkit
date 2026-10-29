---
schedule: weekly
day: fri
output: report
model: sonnet
timeout: 1h
---

Run the repo's suite 5 times; report the tests that pass in some runs and fail in others.

- Suite command: the one in the instruction file ("Before committing"), else the README. A repo file may name another command or another N.
- Run it N times in a row with per-test output (`bats --tap`, `pytest -rA`, `go test -v`). Write run `i` to `$VIBE_JOB_DIR/runs/run<i>.raw`. Go on after a red run.
- Stop starting runs when one run took over 10 minutes. Say how many runs finished.
- Reduce each run to `$VIBE_JOB_DIR/runs/run<i>.txt`: one `PASS <test>` or `FAIL <test>` line per test, none for skipped tests. For bats:

  ```bash
  grep -E '^(not )?ok ' run1.raw | grep -v '# skip' | sed -E 's/^ok [0-9]+ /PASS /; s/^not ok [0-9]+ /FAIL /'
  ```

- Tally with this command; it prints one line per flaky test:

  ```bash
  cat "$VIBE_JOB_DIR"/runs/run*.txt | awk '{ s = $1; $1 = ""; t = substr($0, 2); if (s == "PASS") p[t]++; else f[t]++ }
    END { for (t in f) if (t in p) printf "%s — %d pass / %d fail\n", t, p[t], f[t] }'
  ```

Findings: one line per flaky test, as the tally prints it, plus the first line of its failure message. Tests that fail in every run are red, not flaky: one line with their count. Nothing flaky: say so with N.

May become a commit: nothing. This job is report-only.
