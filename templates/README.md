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
| `vibe.config.example`| `~/.config/vibe/config` | Config, not a document  |
| `skill-lint.conf.example` | `<repo>/.skill-lint.conf` | Config, not a document; copied per repo |

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
| `<date>`      | Render date — `YYYY-MM-DD`, with time and zone appended by `bin/vibe` |
| `<machine>`   | Where it was rendered — `local` or `server`, with the hostname in parentheses when rendered by `bin/vibe` |
| `<goal>`      | The task a loop is working toward (`LOOP.md`, `LOOP_PR.md`) |
| `<until>`     | The loop's stop-check command, or `—` (`LOOP.md`, `LOOP_PR.md`) |
| `<max>`       | The loop's max round count (`LOOP.md`, `LOOP_PR.md`) |
| `<outcome>`   | One-line verdict on how the loop ended (`LOOP_PR.md` only) |
| `<status>`    | The loop's final state — `success`, `maxed`, … (`LOOP_PR.md` only) |
| `<iter>`      | Rounds actually run (`LOOP_PR.md` only)              |
| `<last>`      | Result of the last stop check — `pass`/`fail`/`none` (`LOOP_PR.md` only) |

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
- **Consumers never overwrite.** Both renderers skip a file that already
  exists; updating is an edit, not a regeneration.

## Consumers

- `bin/vibe` — seeds `HANDOFF.md` into each new worktree (`vibe start`),
  `LOOP.md` into an unattended-loop worktree (`vibe loop`), and renders
  `LOOP_PR.md` as the PR body when a loop ends with `--pr`
- `skills/project-status-scaffold/scaffold.sh` — scaffolds both files
- `skills/project-status-scaffold/SKILL.md` — points the model at these files
- `skills/loop-brief/brief.sh` — renders `LOOP.md` (and seeds `HANDOFF.md`)
  into a task worktree before an unattended loop starts
- `skills/handoff-brief/handoff.sh` — seeds `HANDOFF.md` into a task worktree
  before a dedicated session picks the task up (the rendering itself lives in
  `skills/_lib/vibe-lib.sh`, shared by both brief scripts)

Each resolves this directory from its own location on disk, following
symlinks, so the templates are found whether the script is run from the repo
or through its installed symlink.
