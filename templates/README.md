# templates/

Canonical document templates. **Single source of truth** — every tool that
emits one of these files renders it from here rather than embedding its own
copy.

| File                 | Lives at        | Lifespan                        |
| -------------------- | --------------- | ------------------------------- |
| `HANDOFF.md`         | worktree root   | Short — one per worktree/branch, cleared when the task ends |
| `PROJECT_STATUS.md`  | repo root       | Long  — one per repo            |
| `PROJECT_ROADMAP.md` | repo root       | Long  — one per repo; finished items removed, not archived |
| `vibe.config.example`| `~/.config/vibe/config` | Config, not a document  |
| `skill-lint.conf.example` | `<repo>/.skill-lint.conf` | Config, not a document; copied per repo |
| `codebase/CODEBASE_MAP.md` | `<repo>/docs/CODEBASE_MAP.md` | Long — one per repo; a re-run diffs against it rather than replacing it |
| `research/EXPERIMENT_SETUP.md` | `<repo>/docs/EXPERIMENT_SETUP.md` | Long — one per repo; one row per card |
| `research/HARDWARE_TRIAL.md` | `<repo>/docs/hardware/<platform>.md` | Long — one per hardware platform |

`codebase/` and `research/` go into *another* repo's `docs/`, never into this one
(`docs/research-skills.md` §2).

How the documents divide information between them — and why the handoff must
end a task empty — is `docs/artifact-architecture.md`. The templates encode
that contract structurally: `HANDOFF.md` keeps every placeholder on a single
`_italic_` line so tooling can tell scaffolding from content by filtering
lines.

## Why these live here

`HANDOFF.md` was previously embedded in three places (`bin/vibe`'s heredoc,
`skills/project-status-scaffold/scaffold.sh`, and prose inside that skill's
`SKILL.md`) and `PROJECT_STATUS.md` in two. They drifted: the copies disagreed
on whether the header carried a metadata block or a `Last updated` line, and
two of them named a specific CLI in the body. Consumers now read these files.

## Placeholder contract

Templates are plain Markdown containing angle-bracket tokens. A renderer
substitutes every occurrence; unknown tokens are left alone so a partial
render still produces a readable file.

| Token         | Substituted with                                    |
| ------------- | --------------------------------------------------- |
| `<repo>`      | Repository name                                      |
| `<branch>`    | Current branch                                       |
| `<worktree>`  | Absolute path to the worktree root                   |
| `<date>`      | Render date — `YYYY-MM-DD`, with time and zone appended by `bin/vibe` and the brief scripts (`scaffold.sh` stays day-only) |
| `<machine>`   | Hostname of the machine that rendered it |
| `<commit>`    | The revision the document describes, short SHA, suffixed `-dirty` when the tree had uncommitted changes (`codebase/`, `research/` only) |
| `<platform>`  | Hardware platform name (`research/HARDWARE_TRIAL.md` only) |

An unrendered template is itself valid, readable Markdown. That is deliberate:
an agent with no access to the scripts can copy one by hand and fill the
tokens in.

## Rules

- **Stay tool-neutral.** No template may name a specific CLI, machine,
  hostname, or agent. `HANDOFF.md` is written for "the next session", not for a
  particular tool — anything else re-couples the document to one workflow and
  starts the drift over.
- **Add a token, document it here.** The table above is the contract that
  `bin/vibe` and `skills/project-status-scaffold/scaffold.sh` implement.
- **Consumers never overwrite.** Every renderer below skips a file that
  already exists; updating is an edit, not a regeneration.

## Consumers

- `bin/vibe` — seeds `HANDOFF.md` into each new worktree (`vibe start`)
- `skills/project-status-scaffold/scaffold.sh` — scaffolds all three status
  documents (`PROJECT_STATUS.md`, `PROJECT_ROADMAP.md`, `HANDOFF.md`)
- `skills/project-status-scaffold/SKILL.md` — points the model at these files
- `skills/add-roadmap-item` — renders `PROJECT_ROADMAP.md` from the template
  (via `scaffold.sh`) when the repo lacks one, before adding an item to it
- `skills/handoff-brief/handoff.sh` — seeds `HANDOFF.md` into a task worktree
  before a dedicated session picks the task up
- `skills/codebase-map/map.sh` — renders `codebase/CODEBASE_MAP.md` into the
  target repo's `docs/`, and never overwrites an existing one
- `skills/research-experiment-setup/seed.sh`, `skills/research-hardware-trial/seed.sh`
  — render `research/` the same way, through `skills/_lib/doc-lib.sh`

Each resolves this directory from its own location on disk, following
symlinks, so the templates are found whether the script is run from the repo
or through its installed symlink.
