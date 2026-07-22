# Handoff — agentic-dev-toolkit / fresh-review

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fresh-review`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/fresh-review
- **Last updated:** 2026-07-22 · server (srv1841294)

## State

Review complete. Deliverable is the ranked findings below. **No code was
changed** — this branch carries only this handoff.

Baseline: repo verification is green — `shellcheck` 0, `shfmt -d -i 2 -ci` 0,
`bats tests/` 252/252, `./install.sh doctor` ok with one warn (this machine's
`~/.claude/settings.json` is missing part of the baseline; run
`./install.sh claude`). Everything below is what those four checks do *not*
catch.

**Read this caveat first.** This worktree is 1 ahead / **9 behind**
`origin/main` (`d633013`). The brief said to fast-forward with `vibe resume`
first; `vibe resume` reported *"already up to date"* and did nothing, because
it fast-forwards a branch to **its own** upstream (`origin/fresh-review`,
in sync) and has no notion of the default branch — see F19. So the review ran
against a stale tree, and every finding below was **re-validated against
`origin/main` afterwards**. Items already fixed on main are listed separately
at the end rather than dropped, because they show which classes of bug recur.

Severity is "what it costs when it bites", not "how hard it is to fix".

### P1 — silent failure or work at risk

**F1. `bin/vibe:757-759` — a `--pr` loop dies at the finish line, silently.
CONFIRMED, live on main.**
`loop_pr_title` pipes `git log` into `awk … {exit}` … `head -1`. The head of
the pipe closes early, `git log` takes SIGPIPE (141), and `pipefail` +
`set -e` unwind `loop_pr_title` → `loop_open_pr` (called bare at `:857`) →
`run_loop` (bare at `:1052`) → the script exits 141.
*Scenario:* `vibe loop refactor --pr --max 20` runs for hours on the server,
succeeds, strips the brief, pushes — then exits 141. **No PR, no warning, no
ntfy push**, on the one path where nobody is watching. Defeats the
"every failure warns and returns 0" contract at `:800-805`.
*Reproduced in this repo at main's code:* exit=141, success line never
printed. Fails from ~50 commits of history, i.e. every real repo — the test
fixtures are tiny, which is why the suite is green.

**F2. GitHub Actions is billing-blocked; three PRs merged with zero CI.
CONFIRMED.**
`gh run view 29882642897` → *"The job was not started because recent account
payments have failed or your spending limit needs to be increased."* Five
consecutive runs affected; last green run on main is `29876411407`
(PR #32). **PRs #33, #34 and #35 merged unverified.** Mitigating: `d633013`
passes everything locally. This has happened before — `ci.yml`'s own comment
cites a stray-file leak that landed "while Actions was disabled by billing".

**F3. 228 lines of unmerged design work with no PR. CONFIRMED.**
`origin/claude/open-source-alternatives-2yiha7` is 2 commits ahead of main
with `docs/plugins.md` (+228), not on main, and
`gh pr list --head …` is empty — no PR was ever opened. It is the design doc
for the *open* `PROJECT_STATUS.md:82-86` TODO (`.claude-plugin/` manifest).
Recover before any branch pruning.

**F4. `install.sh:326-346` — the settings merge silently deletes user-added
hooks. CONFIRMED by execution.**
The array union covers `permissions.allow/deny` and the sandbox paths;
`hooks.<Event>` is left to jq's `*`, which replaces arrays wholesale. A
user's own `SessionEnd` hook is gone after every `./install.sh`, for the four
events the baseline defines. Survives only for events the baseline lacks.
Nothing in the output says a hook was dropped. This is exactly the
accumulated state CLAUDE.md's union rule exists to protect.

**F5. `claude/hooks/notify-ntfy.sh:76` — `curl -d` treats a leading `@` as a
filename. CONFIRMED against a local listener.**
`body` is the notification `.message`. A message starting with `@` posts the
contents of that local file to the public ntfy topic — where the topic name
*is* the access control. If the path doesn't exist, curl fails and the push
is silently lost (`|| true`). One-word fix: `--data-raw`.

### P2 — wrong behavior, misleading output, or a guard that doesn't guard

**F6. `claude/hooks/session-end-handoff.sh:41-67` — nags precisely when the
user did it right. CONFIRMED.**
`newest_work_mtime()` folds in `git log -1 --format=%ct` unconditionally,
including the commit *containing* HANDOFF.md. Written at T, committed at T+n
⇒ `commit_t > file_t` forever. Every correctly-finished session gets
"stale handoff" on a clean tree — the fastest way to train the user to ignore
the hook. The tracked-file half correctly excludes the status files; the
commit half doesn't.

**F7. `.github/workflows/ci.yml:15-17` — post-merge CI cancels itself.
CONFIRMED.**
Concurrency group is `workflow-ref`, so each push to `main` cancels the
previous main run; two merges are recorded `cancelled`. Since PR runs are now
opt-in via the `run-ci` label, post-merge is the *only* net, and it
self-cancels — contradicting the workflow's own comment at `:4-8`.

**F8. `ci.yml` — two neutrality guards pass vacuously if their file is
renamed. CONFIRMED.**
The template-neutrality and GLOBAL.md-neutrality steps use
`if grep …; then exit 1; fi`. `grep` exits **2** on a missing file, which is
falsy ⇒ green forever. The sibling import guard uses `grep -q … || fail` and
is correct, so the pattern is inconsistent within one job.

**F9. `bin/skill-lint:208` — unterminated frontmatter passes SQ1. CONFIRMED.**
The close check greps the *whole* file for `-x ---`, so any markdown
horizontal rule in the body satisfies it. A SKILL.md that never closes its
frontmatter lints clean while the agent's loader sees it as malformed. The
most basic structural check in the linter is a false negative.

**F10. `bin/skill-lint:219-243` — only double quotes are stripped, so
`name: 'aaa'` fails CI. CONFIRMED.**
Valid YAML produces two spurious errors (`name ''aaa'' does not match…`),
and under `--strict` fails the build on correct input.

**F11. bash 3.2 is real but unasserted. CONFIRMED both ways.**
The macOS leg genuinely runs `3.2.57` (verified in job log 88787821017) —
but `ci.yml:96` only *prints* `bash --version`. Scripts use
`#!/usr/bin/env bash`, so a future runner image putting bash 5 first silently
retires the entire 3.2 guarantee with a green build.

**F12. `install.sh:272-273` vs `:625` — three code paths disagree about
"ours". CONFIRMED.**
`do_link` does `rm "$dst"` on *any* symlink, ours or not, with no warning —
while `do_unlink` carefully skips foreign links and `doctor` reports them
`warn (not ours)`. A `~/.claude/CLAUDE.md` managed by stow/chezmoi vanishes
and the run prints plain `linked`.
Separately, `doctor`'s VS Code check compares two `jq` outputs that both
swallow errors with `2>/dev/null`; when the target has a trailing `//`
comment both are empty, empty == empty, and `doctor` reports `ok` for the
exact file `install` refused to touch. The Claude-settings check at `:609`
guards with `jq empty` first and gets this right.

**F13. `skills/_lib/vibe-lib.sh:66-71` — `export KEY=VALUE` in the config is
blessed by `doctor` and invisible to everything else. CONFIRMED.**
`bin/vibe` *sources* the config and `vibe doctor` explicitly permits the
`export ` prefix; `read_config`'s sed and both completion files do not.
Result: `bin/vibe` uses the configured worktree root while the brief-staging
skills fall back to `~/git/worktrees` — the exact split the lib's own header
warns about ("re-seed a blank brief into a second worktree").

**F14. `bin/vibe:718-724` — a failed *first* push is reported as
"the remote diverged". CONFIRMED by reading.**
The `no-upstream` branch ends in a bare `return`, inheriting the push's
status; `run_loop:996-1002` reads non-zero as divergence and pushes
*"loop stopped: remote diverged — resolve manually"* to your phone. Any
network blip, missing `origin`, or rejected pre-push hook triggers it.

**F15. `bin/vibe:681-690` — the atomic-write temp file is not gitignored.
CONFIRMED.**
`loop_ignore_state` excludes the literal `.vibe-loop.state`, but
`loop_write_state` writes `$sf.tmp.$$` with no trap. A kill mid-write leaves
`.vibe-loop.state.tmp.4711`, which makes `vibe done` refuse the tree as dirty
and gets committed by `run_loop`'s `git add -A` — a PID in the PR diff. Also
(C1): `.vibe-loop.state` itself is not in `.gitignore`, only in
`info/exclude` written at runtime.

**F16. `skills/commit-push-pr/SKILL.md:56` tells the agent to do what
`vibe done` refuses. CONFIRMED.**
It says *"Clear `HANDOFF.md` back to its bare headings"*; `bin/vibe:1779-1783`
dies with *"HANDOFF.md is still on branch … Delete it"*, and
`memory/GLOBAL.md:24-29` says delete. An agent following this skill produces
a branch `vibe done` blocks, and lands an empty husk on the default branch —
the exact leak `bin/vibe:1778` cites PR #14 for.

**F17. `bin/vibe:1821-1873` — `vibe park` on the default branch has no guard.
PLAUSIBLE (by design, but sharp).**
With no argument, `dir_for_optional_task` falls back to the cwd's toplevel —
the main checkout. `sync_dir` refuses only a detached HEAD, so `vibe park`
typed out of habit in `~/git/myrepo` on `main` rewrites HANDOFF.md,
`git add -A`, commits everything and pushes to `origin/main`. This repo is
saved by `.githooks/pre-push`; other repos are not.

### P3 — test blind spots, drift, hygiene

Test suite (harness itself is **clean** — I verified by marker-file diff that
no test writes into the real `$HOME`, `~/.claude`, `~/bin`, the real worktree
root, or the real tmux server):

- **`install.sh:704-705` chmods the developer's checkout during `bats`.**
  `tests/install.bats` runs the real installer against the real `$REPO_ROOT`
  ~25× per run; `$src` is a repo path. A no-op today (all such files are
  already `+x`), but a deliberately non-executable `*.sh` under a skill gets
  its mode flipped by running the tests, and the guard at
  `tests/install.bats:101` filters mode-only changes by design.
- **`tests/helper.bash` never redirects `HOME`** — only `install.bats` does,
  contra CLAUDE.md. Nothing exploits it today; a new test calling `bin/vibe`
  without the wrapper functions would target the real worktree root.
- **`script_dir()` in `bin/vibe` is never exercised through a symlink**, yet
  every real invocation is symlinked. If the walk broke, `TEMPLATE_DIR` would
  point at `~/templates` and all 252 tests would still pass.
- **`claude/settings.json`'s five hook paths are never checked against
  `claude/hooks/`.** Rename one and Claude Code silently runs nothing —
  indistinguishable from the hooks' own "stay quiet" contract.
- Uncovered: the entire server path of `cmd_loop`/`cmd_loop_run`/`cmd_rc`,
  `--uninstall --dry` (destructive if `DRY` were dropped), `install_vscode`'s
  invalid-JSON refusal, both jq-absent degrade paths, `vibe list`,
  a *conflicting* `resume --rebase`, and the loop's LOOP.md-revert branch.
- Weak/vacuous: `tests/install.bats:172` (asserts only `"missing"`, which
  other lines also print), `tests/vibe-loop.bats:100` (asserts no `"ahead"` —
  equally true if the push never happened), `tests/hooks.bats:322` (never
  asserts the "only"), `tests/vibe-ui.bats:50` (needles are common English
  words). Twelve tests use `run` without asserting `$status`.
- The three literal copies of the handoff-scaffold regex (`bin/vibe:169`,
  `session-start-handoff.sh:41`, `vibe-lib.sh:160`) are kept in lockstep by
  comment; nothing cross-checks them.

Docs drift (verified, ranked): `docs/vibe.md:170` claims `--force` "overrides
every check" but the running-loop guard at `bin/vibe:1727-1734` runs
unconditionally · `skills/project-status-scaffold/SKILL.md:29` points at "the
template below", which no longer exists · `skills/implement-test-suite/
SKILL.md:13,103` names a nonexistent skill `codebase-healthiness`
(it is `codebase-health`) · `docs/vibe-loop.md:20-29` "The four ways it
stops" omits the fifth (diverged remote, `bin/vibe:995-1002`) · CLAUDE.md
understates CI, which also guards `LOOP_PR.md`, vscode jsonc parsing, the
Claude memory import, and stray root handoffs.

Dead/cosmetic: `bin/vibe:1664`'s `|| echo "(gh not authenticated)"` binds to
a pipeline whose status is `sed`'s — unreachable · `bin/vibe:328`
`repo_root()` is never called · `ci.yml`'s `collect` step output is never
consumed and its completions comment is factually wrong (`shfmt -f .` *does*
list `completions/vibe.bash`) · `completions/vibe.bash:66` omits `-f`.

Branch hygiene: **20 fully-merged remote branches** never deleted, 4 stale
locals with `: gone]` upstreams, and 4 abandoned brief-only branches
(`vibe-ui`, `vibe-refactor`, `skill-quality`, `loop-prompt-file-setup`) whose
handoffs were never deleted before abandonment. 0 open PRs, all worktrees
clean, no secrets or path leaks, all file modes correct, no stray `HANDOFF.md`
on main.

### Already fixed on `origin/main` (found against the stale tree)

Recorded because the recurrence pattern matters, not as open work:
`install.sh` backup-path collision (basename clobber — a real violation of
"never deletes a real file") · `install.sh --help` truncated by a hardcoded
`sed` range · `statusline.sh` faking a task segment at shallow paths ·
`loop_stop` dropping the `PR` key · `cmd_list`'s `&&`-tail `set -e` trap ·
the server loop-resume path starting nothing while reporting success ·
`tests/helper.bash` not unsetting `VIBE_LOOP_SANDBOX_ARGS` · the
`attach`/`resume` machinery doc claim.

**F19 (meta). `vibe resume` cannot do what this brief asked of it.**
`ff_worktree` (`bin/vibe:1887`) targets `@{u}`. A task branch's upstream is
its own remote branch, so `vibe resume` never catches a branch up to the
default branch — that is `sync-with-main`'s job. The brief's instruction was
impossible, `resume` reported success, and the review silently ran 9 commits
stale. Worth either a doc fix or a `vibe resume --onto-main`.

## Next action

Owner decision, in this order:

1. **Fix the Actions billing (F2)** — everything else in CI is moot until
   runs can execute, and main is currently merging unverified.
2. **Recover `origin/claude/open-source-alternatives-2yiha7` (F3)** before
   any branch pruning.
3. Say which of F1/F4/F5 to patch. F1 is the one that costs real work
   silently; all three are small, localized fixes.

Nothing here is committed as a fix. If patches are wanted, they should be
separate branches per concern, not one sweep — and note this branch must be
rebased onto `origin/main` first (`git rebase origin/main`, not
`vibe resume`).

## Blockers

GitHub Actions cannot run (F2) — billing. This blocks verifying any patch
that comes out of this review.

## Gotchas (unpromoted)

- `vibe resume` ≠ "catch up to main" (F19). Anything instructing an agent to
  fast-forward onto the default branch must say `git rebase origin/main` or
  invoke `sync-with-main`. **Promote to `docs/vibe.md` or the skill.**
- Reviewing from a worktree cut days ago silently reviews the wrong code.
  Re-validate findings against `origin/main` before reporting. **Promote to
  CLAUDE.md if review passes become routine.**
