# Handoff — agentic-dev-toolkit / track-c-pass

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `track-c-pass`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/track-c-pass
- **Last updated:** 2026-07-22 14:00 UTC · server (srv1841294)

## State

Not started. Mission: work through every open item in `PROJECT_STATUS.md`
Track C — the verification-debt track opened by review round one (PR #36)
and extended by round two (PR #38). The branch is cut from the PR #38 merge
commit, so the Track C list in this worktree is the authoritative, current
one. Ten items, two kinds.

Mechanical — no owner decision needed:

1. Assert bash 3.2 in CI rather than assume it — `ci.yml` only *prints*
   `bash --version` on the macOS leg, so a runner-image change would retire
   the portability guarantee with a green build.
2. `install.sh` chmods `+x` inside the developer's own checkout
   (`install.sh:704-705`), and the tests run the real installer ~25× per
   suite run — a deliberately non-executable `*.sh` under a skill would
   have its mode flipped by running the tests.
3. `tests/helper.bash` never redirects `HOME` (only `install.bats` does),
   contra `CLAUDE.md`'s testing contract.
4. Test coverage: server side of `cmd_loop`/`cmd_loop_run`/`cmd_rc`,
   `--uninstall --dry`, both jq-absent degrade paths, `vibe list`, and a
   *conflicting* `resume --rebase`; strengthen four assertions that pass
   vacuously (`install.bats:172`, `vibe-loop.bats:100`, `hooks.bats:322`,
   `vibe-ui.bats:50` — line numbers predate PRs #37/#38's new tests:
   re-locate them by grepping for the assertions, do not trust them).
5. Residual doc drift: `docs/vibe.md:170` (`--force` does not override the
   running-loop guard) · `project-status-scaffold/SKILL.md:29` (points at
   a template that is not there) · `implement-test-suite/SKILL.md:13,103`
   (`codebase-healthiness` → `codebase-health`) · `docs/vibe-loop.md:20-29`
   (a fifth stop condition, diverged remote, missing from the table).

Owner-decision items — implement a concrete proposal, but state the
decision taken explicitly in the PR body so the owner can reject it in
review:

6. The reviewer subagents (`diff-reviewer`, `docs-drift`,
   `security-sweep`) grant unscoped `Bash`, defeating the recorded
   read-only-by-allowlist decision. Already researched: agent frontmatter
   `tools:` accepts bare tool names only, so the supported mechanism is a
   per-agent `PreToolUse` hook that vets Bash commands (exit 2 blocks the
   call). The open decision is that classifier's allow/deny policy.
7. `claude/settings.json`: secret files are readable via allowed
   `Bash(cat:*)`/`grep`/`head`/`tail` despite the `Read()` deny rules; the
   sandbox gates only `~/.aws/credentials` and `~/.ssh`. Fix direction:
   sandbox credential entries for `.env`, `*.pem`, `id_rsa`,
   `id_ed25519`, `~/.config/gh/hosts.yml`. Nits in the same file: the
   `git push origin +main` refspec form is not denied, and the `--force`
   deny prefix also blocks the safe `--force-with-lease`. Settings
   changes were explicitly held back for owner go-ahead in round two —
   flag them loudly in the PR.
8. SQ13: `commit-push-pr` and `sync-with-main` are model-invocable yet
   autonomously push or force-push (`codebase-health` is borderline).
   Either add `disable-model-invocation: true` or record a deliberate
   exemption in `docs/skill-quality.md` — today the divergence is silent.
9. `render_template` (two copies: `bin/vibe` and
   `skills/_lib/vibe-lib.sh`) substitutes tokens sequentially, so a goal
   string that itself contains a later placeholder (the machine or date
   token, angle-bracketed in the template) is re-substituted inside the
   rendered brief. Fix: order-independent rendering, both copies together.
10. Skill-structure pass per `docs/skill-quality.md`: `commit-push-pr`
    keeps its stop conditions at EOF instead of opening with them;
    `project-status-scaffold` never defines "done"; `codebase-health`'s
    step-5 approval gate is not bold-marked; `implement-test-suite`'s
    description has no trigger phrases.

## Next action

Run the repo's gate first and treat it as the baseline:

```
shfmt -f . | xargs shellcheck
shfmt -d -i 2 -ci .
bats tests/
./install.sh doctor
./bin/skill-lint skills/ --strict
```

At handoff time: all clean, 265/265, and the PR #38 merge is green on all
four CI jobs (macOS leg on bash 3.2.57) — a failure you see is yours.
Then take the items in the order above, one commit per item with the
failure it prevents in the body, striking each from Track C as it lands.

## Blockers

None. Items 6–8 land as proposals, not faits accomplis — the PR body must
name each decision taken on the owner's behalf.

## Gotchas (unpromoted)

- If main moves before this session starts, `git rebase origin/main` —
  never `vibe resume`, which only fast-forwards to the branch's own
  upstream and reports "already up to date" while arbitrarily far behind
  main. That mistake cost round one eight stale findings.
- CI is opt-in per PR: add the `run-ci` label (`gh pr edit N --add-label
  run-ci`) or the merge box reads a skipped run as passing.
- Tightening the settings *baseline* does not retract rules already merged
  into live machines — the installer unions arrays, so a removed allow
  rule needs manual cleanup on each machine. Say so in the PR.
- Every new guard gets a test (repo rule), and bash 3.2 / BSD+GNU
  portability applies to anything written for item 6 — hooks must also
  exit 0 and stay silent when a dependency is missing.
