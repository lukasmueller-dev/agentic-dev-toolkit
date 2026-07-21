# skills/_lib/

Shared helpers for skill scripts. **Not a skill** — the underscore prefix
makes `install.sh` and `skill-lint` skip this directory, exactly like
`_template/`. Nothing here is ever linked into `~/.claude/skills`.

`vibe-lib.sh` holds everything the brief-staging scripts
(`loop-brief/brief.sh`, `handoff-brief/handoff.sh`) must agree on with
`bin/vibe`: worktree layout, config precedence, the loop state file, template
rendering, and the handoff content filter. Before the lib existed each script
carried its own copy of these, with a "kept in lockstep with bin/vibe"
comment doing the work a single definition does now.

`bin/vibe` still has its own copies — it is deliberately a single
self-contained file. If its behavior changes (worktree paths, config keys,
the loop state format), this lib must change with it; the bats suites for
both skills are what catch a drift.

## Sourcing it

A skill script reaches this directory *through its own resolved location*,
never `$PWD` — the script runs symlinked from `~/.claude/skills`:

```bash
SKILL_DIR="$(script_dir)" # the symlink-walking helper each script carries
LIB_PROG=myname           # prefix for die/info messages
# shellcheck source=../_lib/vibe-lib.sh
. "$(dirname "$SKILL_DIR")/_lib/vibe-lib.sh"
```

`script_dir()` itself cannot live here: a script needs it to find this file.
The lib expects the caller to run under `set -euo pipefail`.
