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

## Frontmatter rules

Only `name` and `description` are required.

- **`name`** must match the directory name, be 1–64 characters, and contain
  only lowercase letters, digits and single hyphens. No leading or trailing
  hyphen, no consecutive hyphens, and it may not contain "claude" or
  "anthropic". CI enforces the name/directory match.
- **`description`** is the discovery surface, max 1024 characters. Write it in
  **third person** ("Analyzes…", not "I can help you…"), state both *what* it
  does and *when* to use it, and put the most important trigger first — long
  descriptions get truncated from the tail when the listing budget is tight.
- **`disable-model-invocation: true`** removes the skill from the model's
  context entirely, so it can only be run as `/<name>`. Use it for anything
  with side effects you want to time yourself — deploys, commits, sends.
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

- [ ] `name` matches the directory and the charset rules
- [ ] `description` is third person, says what *and* when, trigger words first
- [ ] Body opens with boundaries, then numbered phases
- [ ] Any bundled script is shellcheck-clean and `shfmt -i 2 -ci` formatted
- [ ] Any script resolves its own path instead of trusting `$PWD`
- [ ] Emitted documents come from `templates/`, not from a heredoc
- [ ] No reference to a specific machine, hostname, or personal workflow —
      that context belongs in `claude/CLAUDE.md`
- [ ] `bats tests/` and `./install.sh doctor` still pass
