---
schedule: weekly
day: mon
output: pr
model: sonnet
timeout: 2h
---

`uv` repos only: refresh `uv.lock` to the newest minor and patch versions. No `uv.lock` at the repo root: `result` is `done: no uv.lock`.

- `uv lock --upgrade --dry-run`: each `Update <pkg> v<a> -> v<b>` line is a candidate. None: `result` is `done: lock is current`.
- A major bump is a candidate whose leading number differs (for `0.x`, the minor differs). A calendar version (leading number ≥ 2000, `certifi`) is not a major.
- Hold each major back with a cap: `uv lock --upgrade --upgrade-package 'idna<3'` for a locked `2.8`; `'foo<0.5'` for a locked `0.4.1`. Repeat the dry run until it shows no major.
- Apply the lock, `uv sync`, then run the repo's test command (its instruction file names it; else `uv run pytest`). No test command: commit nothing, report it.
- Green: commit `uv.lock` alone. The body lists the `Update` lines.
- Red: `git checkout -- uv.lock`. Upgrade one candidate at a time (`uv lock --upgrade-package <pkg>`, `uv sync`, suite), restoring the lock after each. Each red package is a finding.
- Then lock every green candidate together and run the suite once more. Green: commit. Red: commit nothing, name the combination.
- Stop the one-at-a-time loop after 60 minutes; list the rest as untested.

Findings: one line each.

- `<pkg> v<a> -> v<b>: major, held back`.
- `<pkg> v<a> -> v<b>: suite red, <first failing test or last line>`. This is `Needs you`.
- A `uv lock` error with its last line; candidates left untested.

May become a commit: `uv.lock`, one commit. Never `pyproject.toml` (a major needs a human), never code, never a roadmap item.
