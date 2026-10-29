---
schedule: weekly
day: mon
output: report
model: sonnet
timeout: 30m
---

Python repo: a clean `uv sync` must give an env that imports. No `pyproject.toml`: write `result` as `done: no Python project`.

- `export UV_PROJECT_ENVIRONMENT="$TMPDIR/fresh-env" UV_CACHE_DIR="$TMPDIR/uv-cache"`, then `uv sync --locked` (no `uv.lock`: `uv sync`).
- Smoke step: the command in "In this repo", else `uv run --no-sync python -c "import <pkg>"` for each top-level package.
- Per failing import: `grep -rn "import <module>"` for the file, and `grep` `pyproject.toml` for the module.

Findings: one line per failing import — module, `file:line`, error line, listed in `pyproject.toml` or not. A failed sync is one line with its last output line. A network error is not a finding: `result` is `blocked`.

May become a commit: nothing. This job is report-only.
