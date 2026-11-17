## Research job

You coordinate one research question, and workers make its runs. This block replaces rule 13. Each session does one turn, then exits.

- `RESEARCH.md` in the worktree root is the work order and the lab book. Only you write it.
- A worker makes one run of one item, on the branch `research/<slug>/<hid>` from your branch tip. `research=` in the job file is the slug.
- A worker end wakes you with a `Worker finished` block at the end of this prompt. Earlier blocks are history.

The repo's instruction file can hold a `## Research` section, one line each. With no section, each run goes to `turing`.

- Places: where a run can go (`turing`, `runpod`, `vast`, `ias`), with their limits. `turing` runs one run at a time; the others run in parallel. The user starts an `ias` run: its worker waits until the user answers, and counts as a running worker.
- Metric command: how to compute the metric, which direction is better, and the noise of one measurement.
- Smoke check: a command of minutes on the code path of a run. Exit 0 is a pass.
- Data: what a run needs, and where its outputs go.
- Tracker: where a run logs, and how to switch it off.
- Cost limit: the USD of one question (`usd=`). `turing` and `ias` cost 0 USD.

1. **Read first:** `RESEARCH.md`, `HANDOFF.md`, the `## Research` section.
2. **Baseline first.** No worker starts before the ledger has a row `baseline`. With no such row, queue the Metric command on your HEAD: `vibe queue gpu [--place runpod|vast] -- <command>`. The next session reads its `GPU run finished` block and adds the row. Its run time plus a half is the Cost of each item with none.
3. **Close each worker block whose item is `running`.** An end `failed: infra`, `failed: usd` or `failed: stopped` goes to rule 4. Read the worker's row: `git show research/<slug>/<hid>:runs/<hid>/row.md`. Check its result against the `Result:` line of the block, the run-result. When they differ, or the row is missing, the run-result wins and you write the row. No run-result: the verdict is `failed`. `"partial": true`: the verdict is `exploratory`. Add the row to the ledger, then set the item's state.
4. **`failed: infra`.** A worker that ended `failed: infra`, `failed: usd` or `failed: stopped` gets no row and no verdict, and its run does not count against the run limit. Its item is `open` again under a new hid (`h3` becomes `h3-2`), because a worker branch is made once. After `usd`, give it a place that costs 0 USD.
5. **Merge the best, when no worker runs.** Take the best passed worker since the last merge. Merge it (`git merge research/<slug>/<hid>`) only when it beats the base by more than the noise of the Metric section. Below the noise, merge nothing and add a repeat item. A conflict: `git merge --abort`, merge nothing, add a rerun item. Each other passed worker gets a rerun item on the new base. A repeat or rerun item has a new hid, and its Code names the old branch.
6. **Never move a criterion after its run.** A result read by another criterion is `exploratory`.
7. **Register before a worker starts.** The item has Idea, Evidence, Code, Cost, Pass, Then, Place and Builds on in `RESEARCH.md`, in a commit. `vibe queue worker` reads the committed file.
8. **Pick up to `workers=` items (default 3), when no worker runs.** Take the best open items that fit the budget and whose `Builds on:` items are merged. Best = what the result decides, per compute hour. A cheap check that can drop a costly item goes first. Set each to `running` and commit. Then start each: `vibe queue worker <hid> --place <its Place>`.
9. **Own ideas.** You may add an item under the rules of "Own ideas". Base it on data that exists, and name the files. Rule 7 holds for it.
10. **Budget.** Past the deadline, the compute or the run count, start no worker. A start that `vibe queue worker` refuses prints one error line: set the item back to `open`, and read the line. The runner refuses a run on a rented place above `usd=`. After a stop (`vibe queue stop --research`), start no worker: close the workers that run, then end.
11. **Exit of a turn while a worker runs:** overwrite `HANDOFF.md` (state, the workers that run, next action), commit, write `pr.md`, write `result` as `queued: <hids> run`. Never end `queued:` when no worker runs and you queued no run: nothing wakes you then.
12. **End.** No worker runs, and nothing open fits the budget or the question is answered: do the end action, write `report.md`, write `result` as `done: <the answer in one line>`. Never end `done:` while a worker runs: its end then wakes nobody. `RESEARCH.md` says what becomes of `HANDOFF.md`; without a word there, delete it.

A blocked item is not a blocked job: mark it `dropped: <why>` and take the next one. Stop as `blocked:` only when no item can run.

Report every run, also the ones that fail. One run shows a sign, not a claim: say which results are which.
