# skill-lint

`bin/skill-lint` is the mechanical half of the skill quality bar: every rule it
enforces is checkable by regex or length, with no reader's judgment. The
judgment half — does a description say *what and when*, does a body open with
its boundaries — belongs to the `skill-audit` skill, not here.

It lives in `bin/` (not `claude/`) because `SKILL.md` is an open standard. The
installer symlinks it into `~/bin`, so it runs in every repo, against any
repo's local skills.

## Usage

```
skill-lint [--strict] [<skills-dir>...]
```

- A `<skills-dir>` is the *parent* of skill directories — each holds a
  `SKILL.md` at `<skills-dir>/<name>/SKILL.md`.
- With no argument it uses `./.claude/skills` if that exists, else `./skills`.
- Directories whose name starts with `_` are skipped, matching the installer.
- `--strict` promotes warnings to errors.

Output is one finding per line, `<path>: error|warn: <message>`, then a summary.
Exit status is 1 if any error was found, 0 otherwise.

## What it checks

**Errors** (the non-negotiable bar):

- frontmatter opens the file (`---` on line 1) and is closed by a second `---`
- `name:` and `description:` are both present
- `name` matches the skill's directory name
- `name` is lowercase letters, digits and single hyphens, ≤64 chars, and
  contains neither "claude" nor "anthropic"
- `description` is ≤1024 characters
- any bundled `scripts/*` pass `shellcheck` and `shfmt -i 2 -ci`

**Warnings** (promoted to errors under `--strict`):

- `description` reads first-person (starts with `I `/`You `/`We `)
- `description` is under ~50 characters, likely too thin to trigger reliably

The `description:` value is read from its single line; a YAML block scalar is
measured only by its first line, which is enough for the length heuristics.

## Degrades, never breaks

The linter is meant to be useful on a machine that has nothing but bash. If
`shfmt` is absent the bundled-script checks are skipped entirely (it is also
how the script files are discovered); if `shellcheck` is absent, formatting is
still checked but correctness is not. Either way a note is written to stderr and
the frontmatter rules still run.

## Where it runs

- **CI on this repo** runs `./bin/skill-lint skills/ --strict` in the `validate`
  job — the single source of truth for the mechanical rules, so CI duplicates
  nothing.
- **Any other repo** can run `skill-lint` directly once the toolkit is
  installed, against its own `.claude/skills`.
