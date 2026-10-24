# skills/_lib/

Shared helpers for skill scripts. **Not a skill** — the underscore prefix
makes `install.sh` and `skill-lint` skip this directory, exactly like
`_template/`. Nothing here is ever linked into `~/.claude/skills`.

`vibe-lib.sh` holds everything the brief-staging scripts
(`handoff-brief/handoff.sh`, `codebase-review/review.sh`) must agree on with
`bin/vibe`: worktree layout, config precedence, template rendering, and the
handoff content filter. Before the lib existed each script
carried its own copy of these, with a "kept in lockstep with bin/vibe"
comment doing the work a single definition does now.

`doc-lib.sh` seeds a document from `templates/` into a target repo's docs
directory, never overwriting: `codebase-map` and the `research-*` seed scripts
share it.

`bin/vibe` still has its own copies — it is deliberately a single
self-contained file. If its behavior changes (worktree paths, config keys),
this lib must change with it; the bats suites for
the brief-staging skills are what catch a drift.

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
