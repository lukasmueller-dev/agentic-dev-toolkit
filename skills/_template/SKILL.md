---
name: skill-template
description: Starter skill. Copy this directory to skills/<your-skill-name>/ and rewrite every section. This description is the only thing the model sees when deciding whether to load a skill, so it must say what the skill does AND when to use it, in third person, with the words a user would actually say.
disable-model-invocation: true
---

# Skill Template

> **This directory is not installed.** `install.sh` skips any skill directory
> whose name starts with `_`. That skip is the *only* thing keeping this file
> out of `~/.claude/skills` — Claude Code itself does **not** ignore
> underscore-prefixed directories, and would happily load this as a real
> skill. `disable-model-invocation: true` above is the second layer of that
> belt: even if it were installed, the model could not auto-trigger it.

Copy this directory, rename it, and rewrite everything below. Delete this
blockquote and the checklist at the bottom when you do.

## The quality bar lives in one place

Every rule a skill is held to — with a stable ID and its rationale — is in
[`docs/skill-quality.md`](../../docs/skill-quality.md). Read it once; this
template will not restate it. The **lint**-tagged rules are enforced
mechanically by `bin/skill-lint` (run it before you commit); the
**judgment**-tagged rules are what the `skill-audit` skill grades.

## Frontmatter

Only `name` and `description` are required (SQ2–SQ6). In short: `name` matches
the directory; `description` is third person, says *what* and *when*, trigger
first (SQ8, SQ9).

- **`disable-model-invocation: true`** removes the skill from the model's
  context entirely, so it can only be run as `/<name>`. Set it for anything
  with side effects you want to time yourself — deploys, commits, sends (SQ13).
  Leave it off for skills the model should reach for on its own.

Keep to those fields unless you need more. `name`/`description` are the only
ones in the open Agent Skills standard; everything else (`argument-hint`,
`allowed-tools`, `model`, `context: fork`) is a Claude Code extension and will
not port to other agents.

## Body structure

The body is the instruction set, loaded only once the skill is invoked. Write
it as procedure, not prose.

1. **State the boundaries first.** What this skill must never do is more
   useful than what it does — see `implement-test-suite`, which opens with
   "never change the behavior of production code".
2. **Number the phases.** Detect → plan → confirm → act → deliver. If a phase
   needs user approval before the next one starts, say so in bold.
3. **Say what "done" means**, and where to stop.

## Bundled files

Ship anything the skill needs beside `SKILL.md`. Nothing here is loaded until
the skill actually reads it, so detail is cheap:

```
skills/<name>/
  SKILL.md          the workflow — language- and tool-agnostic
  references/       one file per language/ecosystem, read on demand
    _template.md    the shape every reference in this skill follows
    python.md
  scripts/          executable helpers the skill runs
```

Point at bundled files by path from the body ("read the matching reference
file `references/<language>.md`") — that is what triggers the model to load
them. Keep the shared workflow in `SKILL.md` and everything
ecosystem-specific in `references/`, so adding a language means adding a file
rather than editing the workflow.

**Scripts must resolve their own location**, never trust `$PWD`: a skill runs
inside the *user's* repo, and is normally reached through a symlinked
directory in `~/.claude/skills`. See
`skills/project-status-scaffold/scaffold.sh` for the symlink-walking pattern,
and use `templates/` for any document the skill emits rather than embedding a
copy.

## Before you commit

Run `skill-lint skills/` — it clears the mechanical rows (SQ1–SQ8, SQ14). Then
eyeball the judgment rows it cannot:

- [ ] `description` says *what* and *when*, trigger words first (SQ9)
- [ ] Body opens with boundaries, then numbered phases, then "done" (SQ10–SQ12)
- [ ] `disable-model-invocation: true` if the skill has side effects (SQ13)
- [ ] Any script resolves its own path instead of trusting `$PWD` (SQ15)
- [ ] Emitted documents come from `templates/`, not a heredoc (SQ16)
- [ ] Shared workflow in `SKILL.md`, ecosystem-specific in `references/` (SQ17)
- [ ] No reference to a specific machine, hostname, or workflow (SQ18)
- [ ] `bats tests/` and `./install.sh doctor` still pass
