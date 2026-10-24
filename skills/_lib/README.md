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

`research-lib.sh` holds the detections the `research-*` skill family shares —
repo kind and execution context, both used by `codebase-map`. It belongs to
none of those skills: the contracts in `docs/research-skills.md` §4 and §5 fix the
signals and the verdict rules, so that two skills classifying the same repo
cannot disagree. Each pair is a verdict function plus a reason function,
modelled on `detect_env`/`env_reason` in `bin/vibe`, and both always exit 0 —
"cannot tell" is a verdict, not an error.

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
