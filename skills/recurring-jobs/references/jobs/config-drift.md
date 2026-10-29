---
schedule: weekly
day: mon
output: pr
model: sonnet
timeout: 1h
---

Config and code must agree. Find keys one side has and the other ignores.

- Config files: `*.toml`, `*.yaml`, `*.yml`, `*.json`, `*.ini`, `.env.example`. Skip lockfiles, `vendor/`, `node_modules/` and files a tool outside the repo reads (CI workflows, agent settings, `pyproject.toml` tool tables).
- Unread key: a config key whose name appears in no code file. Check: `grep -rnw '<key>' . --exclude-dir=.git --exclude-dir=vendor --exclude-dir=node_modules`; every hit is a config file, markdown or `PROJECT_ROADMAP.md`.
- Unset flag: an env var or config key that code reads (`os.environ`, `getenv`, `${VAR:-…}`, `cfg.get`) and no config file, `.env.example`, README or `docs/` sets or lists.
- A key read through a built name (`cfg[f"{x}_rate"]`) or set by the system (`HOME`, `PATH`, `TMPDIR`) is not a finding.

Findings: one line each, `file:line`, the key, which side is missing. A key that looks planned (a TODO, a feature flag with a docs line) is `Needs you`, not an item.

May become a commit: `PROJECT_ROADMAP.md` items, all in one commit. Never config, never code.
One item per finding, at most 10 a run; the rest is one report line with the count.
Skip a key the roadmap already names.

- Unread key: `Delete key <key> from <file>.` Done when `grep -nw '<key>' <file>` prints nothing.
- Unset flag: `Document <flag> (read at <file:line>) in <config or docs file>.` Done when `grep -nw '<flag>' <that file>` prints a line.
- Run the done-when before you write the item. A check that already holds is no item.
