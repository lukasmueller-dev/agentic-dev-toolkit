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

The rules are the **lint**-tagged rows of [`skill-quality.md`](skill-quality.md),
which is their single home — this doc does not restate them. Every finding cites
that row's ID (e.g. `[SQ4] name '…' must be lowercase…`), so a message points
straight back to the rationale.

In short: the frontmatter rows (SQ1–SQ6) are hard errors; the two description
heuristics (SQ7 short, SQ8 first-person) are warnings that `--strict` promotes;
bundled-script cleanliness is SQ14.

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
