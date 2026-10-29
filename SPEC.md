# Spec — agentic-dev-toolkit / research-guards

> The work order for one big work item, written in a grilling session before
> the work starts. It holds what and why; `HANDOFF.md` holds where the work
> stands. Change it only when the plan changes. Its last milestone is its end
> action, so it never reaches the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `research-guards`
- **Written:** 2026-10-29

## Goal

A GPU run that goes wrong stops early with a reason, and a job that changes the eval protocol is flagged in its PR.
Research jobs read W&B through a read-only MCP whose key stays out of the agent's shell.

## Non-goals

- `eval-regression` — its own roadmap item; it gets easier with the MCP (`compare_runs_tool`).
- Multi-seed follow-ups (one follow-up after N seeds).
- The hosted W&B MCP (`mcp.withwandb.com`): not in the sandbox allowlist, no documented read-only switch.
- Changes in research repos — roadmap item "W&B MCP + `eval-paths` in humanoid-locoman-vla and safety-critic".
- `humanoid_bridge`, `g1_web_commander`: no W&B.

## Decisions

- MCP consumers: the GPU follow-up job (read, compare, `diagnose_run_tool`), `experiment-hygiene`, interactive sessions. Never a watcher: one session per check would burn the usage limit for hours.
- Early stop is a command, not an agent: the job writes `stop` into its job dir; `gpu-queue` runs it in the run's dir every `stop_every=5m`; exit 0 = stop, first stdout line = reason. A regex cannot work: safety-critic prints only `Step: N` (`track_console=False`, `scripts/train.sh:98`), locoman writes `<out>/train.log`, not stdout.
- How `stop` reads metrics (grep a log file, a console flag) is the job's choice. Job rule 14 needs a stop rule for a run over 1h; without one the run goes as today.
- Kill: the run gets its own process group; TERM, KILL after 60s; status `stopped`; the `--then` gets `GPUQ_STOP=<reason>`. `gpu-queue` has no kill code or pid file today.
- Reruns: max `gpu_reruns=1` per job chain; a second stop makes the follow-up `blocked`, both reasons in the PR body.
- Eval guard flags, never blocks: some jobs must change the eval (safety-critic `review-fixes`). A job diff that matches a glob in the repo's `.vibe-jobs/eval-paths` gets `[eval changed]` in the PR title and a "Needs you" line. No file → no guard. Reason: RE-Bench agents gamed the score in about 30% of runs; a prompt line alone cut a replication only from 10/10 to 3/10.
- Eval paths live in `.vibe-jobs/eval-paths`, one glob a line: no repo has `docs/EXPERIMENT_SETUP.md`, and the protocol is spread over docs, TOML suites and eval scripts.
- MCP: the local stdio server with `WANDB_MCP_ACCESS_MODE=read-only`; it talks to `api.wandb.ai`, which the sandbox already allows. Read-only for jobs and sessions: a write to W&B stays the training code's job.
- MCP config lives in each research repo's `.mcp.json` (the toolkit installs no MCP servers, `CLAUDE.md`). The toolkit holds the one recipe, `docs/wandb-mcp.md`, and a line in the tracker card of `references/cards.md`.
- Key: `~/.config/wandb-mcp/key` (mode 600), read by the `.mcp.json` launch command; `vibe-job-settings.json` denies reads of it to the job sandbox, so Bash cannot print it into a log or PR. No unit sets `WANDB_API_KEY`; no `~/.netrc` exists.
- Repos: humanoid-locoman-vla and safety-critic; queued safety-critic runs set `WANDB=1` (off by default, `scripts/train.sh:91`).
- Start after `job-review` merges: both change `job_run` and `job_publish` in `bin/vibe`.

## Milestones

- [ ] Stop rule: `gpu-queue` runs each job in its own process group, runs the job dir's `stop` every `stop_every=5m`, stops on exit 0 (TERM, KILL after 60s), writes status `stopped` with the reason, and passes `GPUQ_STOP` to `--then`; `vibe queue gpu` hands the job dir's `stop` to `gpu-queue` — code — done when a test in `tests/gpu-queue.bats` shows a stub run whose `stop` exits 0 ends `stopped` and its `--then` gets `GPUQ_STOP`
- [ ] Rerun limit: `gpu_reruns=1` in `queue.conf`; the follow-up prompt carries the stop reason; a second stop in one chain makes the follow-up `blocked` with both reasons — code — done when a test in `tests/vibe-queue.bats` shows a second stop gives `blocked`
- [ ] Eval guard: after `done`, the runner matches the job diff against the repo's `.vibe-jobs/eval-paths`; a match prefixes the PR title with `[eval changed]` and adds a "Needs you" line to the briefing — code — done when tests show a diff on a declared glob gets the prefix and the line, and a repo without the file gets neither
- [ ] Prompt, kit, sandbox: rule 14 in `skills/fill-queue/references/job-prompt.md` and `skills/recurring-jobs/references/job-prompt.md` needs a stop rule for a run over 1h; one line each in the tracker and eval cards of `skills/research-experiment-setup/references/cards.md`; `claude/vibe-job-settings.json` denies reads of `~/.config/wandb-mcp/key` — code — done when `./bin/skill-lint --strict skills` passes and a test checks the deny entry
- [ ] Docs and end action: `docs/wandb-mcp.md` (Requirements, steps, Verify with one MCP call, What breaks it — incl. a check that the stdio server runs outside the Bash sandbox), the rules and layout rows in `docs/vibe-queue.md`, one decision line in `PROJECT_STATUS.md`; delete this spec — code — done when `shfmt -d -i 2 -ci .`, `shfmt -f . | xargs shellcheck` and `bats tests/` pass

## End action

`delete`. Each decision moves to the PR body.
