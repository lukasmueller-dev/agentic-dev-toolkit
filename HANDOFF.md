# Handoff — agentic-dev-toolkit / vendor-academic-writing

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `vendor-academic-writing`
- **Worktree:** /home/lukas-mueller/git/worktrees/agentic-dev-toolkit/vendor-academic-writing
- **Last updated:** 2026-10-06 09:03 CEST · local (turing)

## State

Not started. Goal: vendor 5 academic-writing skills from github.com/JakobThumm via `bin/plug`.
All MIT; each repo is one skill at its **repo root**; one `source` per repo, ref `main`.

| Repo | Install as | Notes |
| --- | --- | --- |
| proofreading | `proofread` | matches its frontmatter `name`; scripts need `pymupdf` |
| writing-simple-style | `writing-simple-style` | scripts; uses `iso-obp` MCP server |
| writing-assistance | `writing-assistance` | no frontmatter — vendor anyway (Claude Code falls back to dir name + first paragraph) |
| literature-review | `literature-review` | scripts call crossref/doi.org (`requests`) |
| editor-review | `editor-review` | invokes literature-review via `Skill`; spawns agents |

Agreed design (each fixes a blocker found during design):
- `plug`: `skill <src> <path> [<name>]`; name required when path is `.` (today `norm_path` turns `.` into `''` and dies). Root tree sha = `<sha>^{tree}`. Lock already has an installed-name column.
- Policy (`docs/vendoring-external-skills.md` "What may be vendored"): skills may bundle scripts the agent runs on demand, never automatically. Gate: `security-sweep` agent over the tree on first add and every `plug update` diff.
- `plug sync` refuses when `git ls-files -oi --exclude-standard vendor/skills/<name>` is non-empty (an upstream nested `.gitignore` would hide vendored files on a fresh clone). Current upstream `.gitignore`s hide nothing.
- zeroshot-academic-writing is a Zeroshot graph (npm orchestrator), not a skill: do **not** vendor; add a short install recipe to `docs/` pointing at the vendored reviewer skills.
- Docs get a requirements table (`pymupdf`, `requests`, `iso-obp` MCP); nothing auto-installed.

## Next action

1. `bin/plug`: add the optional installed-name field + root-path support; bats tests for `.`, `./`, missing name, name collision, a file hidden by a nested `.gitignore` (and the ignore guard itself).
2. Add the 5 sources/skills to `plugins.conf`; `bin/plug sync`; `./install.sh skills`.
3. Run the `security-sweep` agent over the 5 vendored trees; report findings before committing.
4. Update `docs/vendoring-external-skills.md` (conf syntax, policy, requirements, zeroshot recipe).
5. Run the "Before committing" gate from `CLAUDE.md`; PR with `run-ci` label.

## Blockers

- Upstream PR adding frontmatter to JakobThumm/writing-assistance: ask the user before opening it (outward-facing).

## Gotchas (unpromoted)

- Every new bats `[[ ]]` needs `|| false` — `tests/suite.bats` fails the run otherwise.
- `git add` new files before `bats` (the "creates nothing under skills/" guard).
- editor-review and literature-review must be vendored together.
