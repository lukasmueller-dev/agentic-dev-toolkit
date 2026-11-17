## Research worker

You make one run of one item of `RESEARCH.md`: `hid=` and `place=` in the job file name it. A coordinator job owns the question and merges the best worker. This block replaces rules 9 to 13. The runner opens no PR, so write no `pr.md`.

- Write only code and files under `runs/<hid>/`. Never change `RESEARCH.md` or `HANDOFF.md`: the coordinator writes them.
- Read first: your item, the Metric, the Limits and How a run is made in `RESEARCH.md`, and the `## Research` section of the repo's instruction file.
- The item's Code can name another worker's branch: merge that branch first.

Session 1: the code and the run.

1. **Build the least.** New behavior sits behind a switch that is off by default. Run the repo's tests for what you touch.
2. **Test yourself.** Run the Smoke check of the `## Research` section on the code path of the run. The run starts only when it passes.
3. **Commit.** The run takes the commit at HEAD.
4. **Queue one run.** `place=turing`: `vibe queue gpu -- <command>`. `place=runpod` or `vast`: `vibe queue gpu --place <place> -- <command>`. The last line of the run's output is `RESULT {"metric": <number>}`.
5. **Exit:** write `result` as `queued: <hid> at <place>`.

`place=ias`: you queue no run, because the user starts it on IAS.

1. **Write the job.** Copy the repo's `.claude/research/job.sbatch` to `runs/<hid>/job.sbatch` and put the command of the run in it. Commit.
2. **Write `paste.md`** in the job dir: 3 steps, each a command. Step 1 fetches your commit (`git fetch origin research/<slug>/<hid>`, then `git checkout <commit>`). Step 2 is `sbatch runs/<hid>/job.sbatch`. Step 3 prints the last `RESULT` line of the job's output.
3. **Exit:** write `result` as `blocked: <hid> waits for its IAS run, paste.md`. The runner pushes the branch. The user's answer is the output of step 3, and it starts session 2.

Session 2: a `GPU run finished` block ends this prompt. Close the run.

1. **No run.** `Exit: infra`, `usd` or `stopped`: the place failed, the budget refused the start, or a stop came before it. Write `result` as `failed: <exit>: <reason>`, and stop.
2. **Read** the log and the `Result:` line, the run-result of the runner. `none` means the run failed.
3. **Write `runs/<hid>/row.md`:** one row in the ledger columns of `RESEARCH.md`, then the path of the evidence on its own line. The result is the `metric` of the run-result. The cost is the hours of the run and the USD in the `cost` file beside the run-result. The verdict judges the result against the item's Pass: `passed` or `failed`, and `exploratory` for `"partial": true`.
4. **Commit** the row and the evidence under `runs/<hid>/`. Write `result` as `done: <hid> <metric> <verdict>`.

Report the run as it is, also when it fails. One run shows a sign, not a claim.
