## Research job

`RESEARCH.md` in the worktree root is your work order and your lab book. This block replaces rule 13.
Each session does one turn of the loop, then exits. The last "GPU run finished" block of this prompt is the run you close now; earlier ones are history.

1. **Read first:** `RESEARCH.md`, `HANDOFF.md`, the log of the last run.
2. **Close the last run.** Compute the metric the way `RESEARCH.md` says. Add its ledger row: numbers, verdict against the criterion, the path of the evidence. A run that failed gets a row too.
3. **Never move a criterion after its run.** A result read by another criterion is `exploratory`.
4. **Pick the next item:** the best open one that fits the budget. Best = what the result decides, per compute hour. A cheap check that can drop a costly item goes first.
5. **Register before you code.** The item has Idea, Evidence, Code, Cost, Pass and Then in `RESEARCH.md`, in a commit before its run.
6. **Build the least.** New behavior sits behind a switch that is off by default. Run the repo's tests for what you touch.
7. **Test yourself.** The run command starts with a smoke check: minutes, the same code path, checks that fail loud. The long run starts only when it passes.
8. **Run one snapshot.** The command names one commit and runs a copy of it, never the live worktree. Queue it: `vibe queue gpu -- <command>`. One run per session.
9. **Use the wait.** After you queue the run, prepare the next item's code when it does not need the result. Commit before you exit.
10. **Own ideas.** You may add an item under the rules of "Own ideas". Base it on data that exists, and name the files. Rule 5 holds for it.
11. **Budget.** Before each run, add its expected cost to the ledger. Past the deadline, the compute or the run count: queue nothing, go to rule 13.
12. **Exit of a turn:** overwrite `HANDOFF.md` (state, the run in the queue, next action), commit, write `pr.md`, write `result` as `queued: <item>`.
13. **End.** Nothing open fits the budget, or the question is answered: do the end action, write `report.md`, write `result` as `done: <the answer in one line>`. `RESEARCH.md` says what becomes of `HANDOFF.md` (this goes before rule 10); without a word there, delete it.

A blocked item is not a blocked job: mark it `dropped: <why>` and take the next one. Stop as `blocked:` only when no item can run.

Report every run, also the ones that fail. One run shows a sign, not a claim: say which results are which.
