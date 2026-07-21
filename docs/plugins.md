# Plugins: pulling in external skills (design draft)

> Status: **draft / not implemented.** This documents the intended
> architecture for making the toolkit pluggable. Nothing described here
> exists yet.

The skills ecosystem has matured: `SKILL.md` is an open standard, and repos
like `anthropics/skills`, `obra/superpowers-skills`, and the collections
indexed by `VoltAgent/awesome-agent-skills` hold skills worth using as-is.
This design lets the toolkit *pull selected skills from external repos*
without giving up the properties that make it trustworthy: everything
installed by symlink, reproducible on both machines from `git pull` alone,
and no content reaching an agent that was never reviewed.

## Why not the obvious alternatives

Three existing mechanisms were considered and rejected before designing
anything new:

- **Claude Code plugin marketplaces** (`/plugin marketplace add …`) install
  into Claude Code only. The whole point of top-level `skills/` is that it is
  agent-portable; a marketplace bypasses that layer, and its updates arrive
  without review.
- **Git submodules** pin correctly but fail everywhere else: you take a whole
  repo when you want two skills out of it, every clone needs
  `submodule update --init` (the same "every clone, one time" trap as
  `core.hooksPath`, but with worse failure modes), and — decisive — a
  submodule bump is an opaque SHA change in `git diff`. A skill is
  *instructions an agent will follow*; an update whose diff you cannot read
  in review is exactly the thing this repo's conventions exist to prevent.
- **`npx skills add` style installers** write third-party content straight
  into the skills directory, mixing external and local provenance, and add a
  Node dependency to a toolkit that deliberately requires nothing but bash
  and git.

## The design in one paragraph

External skills are **vendored by copy, committed to git**. A manifest
(`plugins.conf`) names source repos and the skills wanted from each; a small
CLI (`bin/plug`) materializes them into `vendor/skills/<name>/` at a
SHA pinned in `plugins.lock`; the installer learns — once — to scan
`vendor/skills/` alongside `skills/`. Because the vendored copies are
ordinary committed files, the other machine gets byte-identical state from
`git pull`, installs work offline, `--uninstall` ownership checks work
unchanged, and every update is a readable diff of the actual instructions
that changed.

## Layout

| Path                     | Holds                                        | Committed? |
| ------------------------ | -------------------------------------------- | ---------- |
| `plugins.conf`           | What to pull: sources and skill selections   | yes        |
| `plugins.lock`           | Resolved SHAs per source, tree hash per skill| yes        |
| `vendor/skills/<name>/`  | The vendored skill directories               | yes        |
| `~/.cache/agentic-dev-toolkit/plug/<source>/` | Bare clone cache, per source | no (per machine) |

`vendor/` gets a row in the CLAUDE.md layout table: *external content,
written only by `bin/plug`, never edited by hand* — a hand edit disappears
on the next `plug sync`, which is the same reason templates have one copy.

## `plugins.conf`

Line-based and bash-3.2 parseable, same as `.skill-lint.conf` — no YAML, no
jq required:

```
# source <name> <git-url> <ref>
# skill  <source-name> <path-in-repo>
source superpowers https://github.com/obra/superpowers-skills main
skill  superpowers skills/debugging/systematic-debugging
skill  superpowers skills/testing/test-driven-development

source anthropic https://github.com/anthropics/skills main
skill  anthropic document-skills/pdf
```

`ref` is what `plug update` chases (a branch or tag). What actually gets
installed is always the SHA recorded in `plugins.lock` — the conf expresses
intent, the lock expresses state.

## `plugins.lock`

Generated, never hand-edited:

```
source superpowers 4f2a9c1d… 2026-07-21
skill  superpowers skills/debugging/systematic-debugging systematic-debugging <tree-sha>
```

Per skill it records the *installed name* (the basename, see collisions
below) and the **git tree hash** of the skill directory at the pinned
commit. Git is already a hard dependency and `git rev-parse <sha>:<path>`
is portable, unlike choosing between `sha256sum` and `shasum -a 256`. The
tree hash is what lets `plug doctor` and CI prove that `vendor/` matches
the lock — i.e. that nobody edited vendored content by hand and no sync was
half-committed.

## `bin/plug`

| Command             | Effect |
| ------------------- | ------ |
| `plug sync`         | Make `vendor/` match conf + lock. New skills are fetched at the locked SHA (or the ref's current SHA if not yet locked), removed conf entries delete their vendor copy, and the lock is rewritten. Prints a reminder to run `./install.sh skills` when the skill *set* changed. |
| `plug update [src]` | Re-resolve refs to new SHAs, re-materialize, rewrite the lock. The point of the command is the `git diff` it leaves behind. |
| `plug list`         | Sources, pins, and skills, with local-collision warnings. |
| `plug doctor`       | Verify vendor tree hashes against the lock; report drift, hand edits, and conf/lock/vendor disagreement. |
| `plug sync --check` | Doctor's core check, exit-code only — this is what CI runs. |

Fetch mechanism: one cached bare clone per source under
`~/.cache/agentic-dev-toolkit/plug/`, then
`git archive <sha> <path> | tar -x` into a temp dir and move into place.
`git archive` from a local clone works for any reachable SHA on both BSD and
GNU userlands and needs no shallow-fetch-by-SHA server support. The cache is
per machine and disposable; losing it costs one re-clone, never state.

Like every `bin/` script, `plug` resolves its repo root by walking its own
symlink chain (`script_dir()` from `bin/vibe`) and must pass shellcheck and
`shfmt -i 2 -ci` under bash 3.2.

## Installer changes — once, then never again

`build_map`'s skills section additionally scans `$REPO/vendor/skills/*/`
with the same `_*` skip, mapping to the same `~/.claude/skills/<name>`
destinations. Precedence: **a local skill in `skills/` always wins** over a
vendored one with the same basename; the collision is a warning at install
time and an error at `plug sync` time (two *sources* claiming one name is
always a sync error). That keeps the auto-discovery contract intact:
after this one change, adding or removing a plugin never touches
`install.sh`.

Because `vendor/` is inside the checkout, `owned_by_repo` already covers
it — `--uninstall` and the backup rules need no changes. One addition is
needed for *removal*: dropping a skill from the conf deletes its vendor
copy, which leaves an owned, dangling symlink in `~/.claude/skills`. The
skills target learns to prune symlinks that are owned by this repo *and*
dangling. Both conditions together make this safe under the never-delete
rule: removing a dangling symlink we own loses nothing.

## Quality gates: external content is graded, not gated

The local quality bar cannot be imposed on upstream skills — they would all
fail it, and forking them to comply defeats the purpose of pulling them in.
So the gates split:

- **CI excludes `vendor/`** from `shfmt`/`shellcheck`, from
  `skill-lint --strict`, and from repo-specific rules like the
  templates-name-no-agent check. It is not our code.
- **`plug sync` runs `skill-lint` (non-strict) over incoming skills** and
  prints findings as an advisory report. Seeing `[SQ7] description too
  short` on an incoming skill is information for the review, not a build
  failure.
- **CI runs `plug sync --check`**: conf, lock, and vendor must agree. This
  is the one hard gate, and it is about integrity, not quality.

## The review loop is the security model

A skill is prompt input to every agent on both machines. The design treats
skill updates exactly like dependency updates in software that matters:

1. Nothing is fetched at install time. `./install.sh` touches only files
   already in the checkout — offline-safe, and no network fetch can inject
   content the review never saw.
2. Everything is pinned by SHA in the lock. A compromised upstream branch
   changes nothing here until someone runs `plug update`.
3. `plug update` produces a plain-text diff of the instructions that
   changed, reviewed in the same PR flow `.githooks/pre-push` already
   forces. That diff — not a version bump — is what gets approved.

## Scope: skills only

v1 vendors skills and nothing else, deliberately:

- **Hooks** execute shell in live sessions; vendoring third-party executable
  hook code is a different risk class and stays out until there is a
  concrete need.
- **`bin/` tools** from external repos are ordinary software — install them
  with a package manager, not this.
- **Settings fragments / memory** are exactly the files whose merge
  semantics took the most care in this repo; external merge input is not
  worth the surface area.

The conf format leaves room (`skill` is a typed line) so a later `hook` or
`agent` line type is additive, behind its own explicit decision.

## Tests to add with the implementation

Following the add-a-guard-add-a-test rule:

- `plug sync` fixture flow in a throwaway git "upstream" under
  `$BATS_TEST_TMPDIR`: add, update, remove; lock correctness; idempotence
  (second sync changes nothing).
- Local-over-vendor precedence, and the two-sources-one-name sync error.
- The dangling-owned-symlink prune: prunes exactly that case, still refuses
  to touch real files and foreign symlinks.
- `plug doctor` catching a hand-edited vendor file (tree-hash mismatch).
- Degrade paths: no network (cache hit still syncs; cache miss fails with a
  clear message, exit non-zero, vendor untouched).

## When this is *not* worth building

The mechanism is ~200–300 lines of bash plus tests. It pays for itself only
if external skills are actually adopted — two or three skills from one repo
can be reviewed and copied into `skills/` by hand in ten minutes, and that
is the honest alternative. What manual copying loses is provenance ("which
upstream, which commit?") and a sane update path, which is precisely what
conf + lock + vendor provide. Build it when the third external skill shows
up; before that, copy by hand.
