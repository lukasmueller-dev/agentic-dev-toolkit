---
schedule: weekly
day: wed
output: pr
model: sonnet
timeout: 1h
---

Repos with a map only: refresh `docs/CODEBASE_MAP.md` (or the repo's `doc/`, `documentation/`) by step 5 of the `codebase-map` skill. No map: `result` is `done: no map`. Never seed one; the first read needs a human.

- `<commit>` is the `commit` in the map's frontmatter, without `-dirty`. Not a commit in this repo: commit nothing; this is `Needs you`.
- `git diff --name-status -M <commit>..HEAD`. Keep the paths the map cites (every `path:line`). None changed: `result` is `done: map is current`.
- Re-read only the changed cited files. Other lines keep their text and pointers. A cited file that is gone or renamed gets its new pointer, or `Not mapped: <what> — removed in <short hash>`.
- Run no install and no real run. A command must pass the smoke-scale rule (`docs/research-skills.md` §3 in the toolkit), else leave the line as it is.
- Read back each pointer you touched. Set `commit` to `git rev-parse --short HEAD` and `Mapped at` to today.
- Commit the map alone as `docs(map): refresh against <short hash>`. The body lists the moved sections, one line each.

Findings: one line per moved section, with the changed file. A removed or renamed file with no new home is `Needs you`.

May become a commit: the map, one commit. Never code, never `PROJECT_STATUS.md`, never a roadmap item.
