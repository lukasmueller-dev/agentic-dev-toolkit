# skills/_lib/

Shared helpers for skill scripts. **Not a skill** — the underscore prefix
makes `install.sh` and `skill-lint` skip this directory, exactly like
`_template/`.

| File | Holds | Used by |
| --- | --- | --- |
| `lib.sh` | `die`/`info`, `render_template`, git helpers, brief staging (`.claude/worktrees/<branch>`, seed, validate, push, remove) | every skill script |
| `doc-lib.sh` | `seed_doc`: render a template into the target repo's docs dir, never overwriting | `codebase-map`, `research-*` seed scripts |

## Sourcing it

A skill script reaches this directory through its own resolved location,
never `$PWD` — the script runs symlinked from `~/.claude/skills`:

```bash
SKILL_DIR="$(script_dir)" # the symlink-walking helper each script carries
LIB_PROG=myname           # prefix for die/info messages
# shellcheck source=../_lib/lib.sh
. "$(dirname "$SKILL_DIR")/_lib/lib.sh"
```

The lib expects the caller to run under `set -euo pipefail`.
