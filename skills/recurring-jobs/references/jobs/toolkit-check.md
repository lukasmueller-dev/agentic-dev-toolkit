---
schedule: weekly
day: sat
output: report
model: sonnet
timeout: 30m
---

The toolkit's own health; run it only in the toolkit repo.

- `<main checkout>/install.sh doctor` by its main-checkout path (from a worktree it reports "not ours").
- `./bin/plug verify`, then for each pin in `plugins.lock`: commits on the upstream default branch newer than the pin (`git ls-remote`, a shallow fetch into `$TMPDIR`).
- `bats tests/`, `shfmt -f . | xargs shellcheck`, `./bin/skill-lint --strict skills`.
- Symlinks under `~/.claude/skills` and `~/bin` that resolve into the checkout but to nothing.

Findings: a red command with its last line; a vendored skill with newer upstream commits (count + first subject).

May become a commit: nothing. This job is report-only.
