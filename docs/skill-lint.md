# skill-lint

`bin/skill-lint` is the mechanical half of the skill quality bar: every rule it
enforces is checkable by regex or length, with no reader's judgment. The
judgment half — does a description say *what and when*, does a body open with
its boundaries — is the [judgment checklist](#judgment-checklist) at the end
of this file.

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

## Per-repo rules: `.skill-lint.conf`

A repo can *add* rules by dropping a `.skill-lint.conf` at its root; `skill-lint`
finds it by walking up from the skills directory to the git root. The file only
ever strengthens the bar — it can never relax the baseline, and errors are never
disablable. Directives are line-based and parsed in bash 3.2 (no YAML, no jq):

| Directive | Effect |
| --------- | ------ |
| `forbid-pattern <ERE> <message>` | Error when the extended regex matches a `SKILL.md` body. The pattern is the first field (no spaces); the rest is the message. |
| `require-field <key>` | Error when a skill's frontmatter lacks that key. |
| `ignore-warn <skill> <check-id>` | Silence one **warning** for one skill, by SQ ID. Errors cannot be silenced — naming an error's ID is inert. |

Config-driven errors are tagged `(.skill-lint.conf)` in the output.
`templates/skill-lint.conf.example` is a copy-paste starting point.

## Where it runs

- **CI on this repo** runs `./bin/skill-lint skills/ --strict` in the `validate`
  job — the single source of truth for the mechanical rules, so CI duplicates
  nothing.
- **Any other repo** can run `skill-lint` directly once the toolkit is
  installed, against its own `.claude/skills`.

## Judgment checklist

The **judgment** rows of [`skill-quality.md`](skill-quality.md), as questions
to ask of each `SKILL.md`. Run `skill-lint` first; grade only what it cannot.
Skip skill directories that are symlinks out of the repo (installed skills).
One finding per line: `<skill>/SKILL.md — [SQxx] <problem + fix in a clause>`.

| ID | Ask |
| -- | --- |
| SQ8 | Third-person catalog entry, beyond the `I `/`You `/`We ` openings lint catches? |
| SQ9 | Says *what* and *when*, strongest trigger first? |
| SQ10–SQ12 | Opens with boundaries, numbers its phases, bolds approval gates, defines "done"? |
| SQ13 | Side effects → `disable-model-invocation: true`, or a recorded exception? |
| SQ15 | Bundled scripts resolve their own path, never trust `$PWD`? |
| SQ16 | Emitted documents rendered from `templates/`? |
| SQ17 | Shared workflow in `SKILL.md`, ecosystem parts in `references/`, siblings at parity? |
| SQ18 | No machine, hostname or personal workflow named? |
| SQ19 | Repo prose it writes follows "Write for scanning" in `memory/GLOBAL.md`? |
