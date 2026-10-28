# Handoff — agentic-dev-toolkit / vibe-job-triage

- **Repo:** agentic-dev-toolkit
- **Branch:** `vibe-job-triage`
- **Worktree:** .claude/worktrees/vibe-job-triage
- **Last updated:** 2026-10-28 · workstation

## State

`vibe job triage` is built and tested (PR #122). The roadmap item is deleted. GitHub reports the PR as conflicting with `main`.

## Next action

Merge `origin/main` into this branch and resolve the conflicts. Keep both sides' behavior. Run the four local checks (shellcheck, shfmt, `env -u VIBE_JOB_DIR bats tests/`, skill-lint if a skill changed). Commit the merge, then delete this file.

## Blockers

None. The review approved the feature; only the merge with `main` is open.

## Gotchas (unpromoted)

- Sandbox placeholder files in the worktree root make 3 `install.bats` tests fail inside a job. They pass in a clean copy.
