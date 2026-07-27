# templates/

Canonical document templates. **Single source of truth** — every tool that
emits one of these files renders it from here rather than embedding its own
copy.

| File                 | Lives at        | Lifespan                        |
| -------------------- | --------------- | ------------------------------- |
| `HANDOFF.md`         | worktree root   | Short — one per worktree/branch, cleared when the task ends |
| `LOOP.md`            | worktree root   | Short — one per unattended loop  |
| `LOOP_PR.md`         | never on disk   | Rendered straight into a PR body when a loop ends with `--pr` |
| `PROJECT_STATUS.md`  | repo root       | Long  — one per repo            |
| `PROJECT_ROADMAP.md` | repo root       | Long  — one per repo; finished items removed, not archived |
| `vibe.config.example`| `~/.config/vibe/config` | Config, not a document  |
| `skill-lint.conf.example` | `<repo>/.skill-lint.conf` | Config, not a document; copied per repo |
| `repo/pre-push`      | `<repo>/.githooks/pre-push` | Long — git hook blocking direct pushes to the default branch |
| `gitignore/*.gitignore` | `<repo>/.gitignore` | Long — fragments concatenated per project type (`common` + each detected type) |
| `ci/*.yml`           | `<repo>/.github/workflows/ci.yml` | Long — starting-point workflow per project type, adapted to the repo's tooling |
| `research/CODEBASE_MAP.md` | `<repo>/docs/CODEBASE_MAP.md` | Long — one per repo; a re-run diffs against it rather than replacing it |
| `research/RUNBOOK.md` | `<repo>/docs/RUNBOOK.md` | Long — one per repo; appended to for the repo's whole life, never regenerated |

`research/` holds the documents the `research-*` skill family emits into a
target repo's `docs/` (`docs/research-skills.md` §2 and §3). Each lands in the
PR of the skill that emits it, not up front.

The `repo/`, `gitignore/`, and `ci/` files carry no placeholder tokens — they
are copied (and then adapted in place by their consumer), not rendered. The
placeholder contract below applies to the document templates.

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
| `<machine>`   | Where it was rendered — `local` or `server`, with the hostname in parentheses |
| `<goal>`      | The task a loop is working toward (`LOOP.md`, `LOOP_PR.md`) |
| `<until>`     | The loop's stop-check command, or `—` (`LOOP.md`, `LOOP_PR.md`) |
| `<max>`       | The loop's max round count (`LOOP.md`, `LOOP_PR.md`) |
| `<outcome>`   | One-line verdict on how the loop ended (`LOOP_PR.md` only) |
| `<status>`    | The loop's final state — `success`, `maxed`, … (`LOOP_PR.md` only) |
| `<iter>`      | Rounds actually run (`LOOP_PR.md` only)              |
| `<last>`      | Result of the last stop check — `pass`/`fail`/`none` (`LOOP_PR.md` only) |
| `<mode>`      | Which half of a fixed schema gets depth — `research`/`application` (`research/CODEBASE_MAP.md` only) |
| `<commit>`    | The revision the document describes, short SHA, suffixed `-dirty` when the tree had uncommitted changes (`research/CODEBASE_MAP.md` only) |

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

- `bin/vibe` — seeds `HANDOFF.md` into each new worktree (`vibe start`),
  `LOOP.md` into an unattended-loop worktree (`vibe loop`), and renders
  `LOOP_PR.md` as the PR body when a loop ends with `--pr`
- `skills/project-status-scaffold/scaffold.sh` — scaffolds all three status
  documents (`PROJECT_STATUS.md`, `PROJECT_ROADMAP.md`, `HANDOFF.md`)
- `skills/project-status-scaffold/SKILL.md` — points the model at these files
- `skills/add-roadmap-item` — renders `PROJECT_ROADMAP.md` from the template
  (via `scaffold.sh`) when the repo lacks one, before adding an item to it
- `skills/loop-brief/brief.sh` — renders `LOOP.md` (and seeds `HANDOFF.md`)
  into a task worktree before an unattended loop starts
- `skills/handoff-brief/handoff.sh` — seeds `HANDOFF.md` into a task worktree
  before a dedicated session picks the task up
- `skills/babysit-pr/brief.sh` — renders `LOOP.md` (and seeds `HANDOFF.md`)
  for the loop that babysits a PR to mergeable (the rendering itself lives in
  `skills/_lib/vibe-lib.sh`, shared by the brief scripts)
- `skills/repo-scaffold` — copies `repo/pre-push`, concatenates
  `gitignore/*`, and adapts `ci/*` into the repo being scaffolded
- `skills/research-cartographer/map.sh` — renders `research/CODEBASE_MAP.md`
  into the target repo's `docs/`, and never overwrites an existing one
- `skills/research-first-run/env.sh` — renders `research/RUNBOOK.md` into the
  target repo's `docs/`, and never overwrites an existing one

Each resolves this directory from its own location on disk, following
symlinks, so the templates are found whether the script is run from the repo
or through its installed symlink.
