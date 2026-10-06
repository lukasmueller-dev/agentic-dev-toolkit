# Vendoring external skills

`bin/plug` copies selected skills from external git repos into
`vendor/skills/<name>/`, pinned by SHA. The copies are committed, so every
machine gets them from `git pull`, and `install.sh` links them like local
skills. An update is a readable diff of the instructions that changed.

This is content coming **in**. Shipping the toolkit **out** as a plugin is
`docs/plugin.md`.

## Commands

| Command | Effect |
| --- | --- |
| `plug sync` | Make `vendor/` match conf + lock. New skills fetch at the locked SHA (the ref's tip if unlocked); dropped lines delete their copy. |
| `plug sync --check` | Offline verdict: conf, lock and `vendor/` agree. Exit 1 on drift. |
| `plug verify` | `--check`, plus each lock tree against its pinned commit (fetches on a cache miss). CI runs this. |
| `plug update [src]` | Re-resolve refs (all sources, or one), re-vendor, rewrite the lock. Review the `git diff`. |
| `plug list` | Sources, pins, per-skill state, collision warnings. |
| `plug doctor` | `--check` item by item, plus cache state. |

After a sync that adds or removes a skill: `./install.sh skills`.

## Files

| Path | Holds | Committed |
| --- | --- | --- |
| `plugins.conf` | What to pull (hand-edited) | yes |
| `plugins.lock` | Resolved SHAs and tree hashes (generated) | yes |
| `vendor/skills/<name>/` | The copies (written only by `plug`) | yes |
| `vendor/skills/README.md` | Keeps the dir in git for the plugin manifest | yes |
| `${PLUG_CACHE_DIR:-~/.cache/agentic-dev-toolkit/plug}/<src>.git` | Bare clone per source; disposable | no |

## `plugins.conf`

```
# source <name> <git-url> <ref>
# skill  <source> <path-in-repo> [<name>]
source mattpocock https://github.com/mattpocock/skills main
skill  mattpocock skills/productivity/grilling
skill  jt-proofreading . proofread
```

- Installed name = `<name>`, else basename of the path.
- `.` = the repo root (a repo that is one skill); `<name>` is then required.
- A `source` must appear above its `skill` lines.
- `ref` is what `update` chases; the lock is what gets installed.

## `plugins.lock`

```
source <name> <commit-sha> <date-pinned>
skill  <source> <path> <installed-name> <tree-sha>
```

- `tree-sha` is `git rev-parse <sha>:<path>` upstream.
- `--check` recomputes it from `vendor/` with `git hash-object --no-filters` + `git mktree`: no network, no cache.
- The date changes only when the SHA does.

## Sync errors (vendor/ left untouched)

| Message | Fix |
| --- | --- |
| `installed name 'x' claimed twice` | Two skill lines share an installed name; rename or drop one |
| `<src>:<path> vendored twice` | One upstream path under two names; keep one line |
| `collides with local skills/x` | Local wins; drop the skill line |
| `no directory '<path>' at <sha>` | Fix the path, or `plug update <src>` |
| `cannot fetch <url>` | Network or auth; a locked SHA already in the cache still syncs offline |
| `does not hash to <tree>` | Upstream `export-ignore`/`export-subst` attributes; copy the skill into `skills/` as a local skill and drop its line |
| `contains a symlink or submodule` | Refused: a link can point at `~/.ssh`; same fix as above |
| `lock edited by hand?` | Lock tree ≠ upstream at the pinned SHA; `plug update <src>` |
| `git ignores the files above` | Upstream nested `.gitignore` or your global excludes hide a shipped file; a commit would drop it. Sync is rolled back; copy the skill into `skills/` instead |

## Install and plugin paths

- `install.sh skills` links `vendor/skills/*/` beside `skills/*/`; `_*` skipped; a local `skills/<name>` wins with a warning.
- A dropped skill's dangling link is pruned by the installer's orphan rule.
- Plugin path: `.claude-plugin/plugin.json` `"skills": "./vendor/skills/"`, loaded in addition to `skills/`.

## Gates

- CI excludes `vendor/` from shellcheck/shfmt (`.editorconfig` `ignore = true`) and from `skill-lint --strict` (run on `skills/` only).
- `plug sync` runs `skill-lint` over incoming skills as an advisory report; it never fails the sync.
- `plug verify` is the one hard gate: integrity, not quality. `--check` alone trusts the lock's tree hashes.
- Fetches allow only `https`, `ssh`, `file` transports, with `transfer.fsckObjects`.
- `.gitignore` ends in `!vendor/**`, so an upstream `.env.example` or `*.pem` is committed, not silently dropped.

## What may be vendored

Skills only. A skill may bundle scripts the agent runs on demand; nothing may run automatically (no hooks, settings, install steps).

| Content | Verdict |
| --- | --- |
| Skills, incl. on-demand scripts | yes |
| Agents, slash commands, output styles | v2 candidate: needs per-file links under `~/.claude/agents/` |
| Hooks, settings, permission baselines | never: adopt by hand into `claude/` |
| CLIs, orchestrators, Claude Code plugin bundles | never: package manager or native marketplace |

Gate: run the `security-sweep` agent over the tree on first add and over the `git diff` of every `plug update`, before committing.
Dependencies a skill's scripts need are documented, never installed.

Rejected: plugin marketplaces (Claude-only, unreviewed updates), git
submodules (opaque SHA bumps), `npx skills add` (Node dependency, mixed
provenance).

## What breaks it

- Hand-editing `vendor/` → `--check` fails; `plug sync` restores the pinned copy.
- Hand-editing a lock tree hash to match → `--check` passes; `plug verify` (CI) and a cached `plug sync` fail.
- Committing `vendor/` without `plugins.lock` (or vice versa) → `--check` fails; run `plug sync`, commit both.
- Deleting `vendor/skills/README.md` → plugin load fails once no skills are vendored.
- A skill path with spaces → unsupported; the conf is whitespace-split.
