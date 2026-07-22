# Skill quality criteria

The one home for the bar every skill is held to. Each criterion has a stable
ID, one line of rationale, and a tag:

- **lint** — mechanical, enforced by `bin/skill-lint`. Its findings cite the ID.
- **judgment** — needs a reader; graded by the `skill-audit` skill.

Change a criterion here and nowhere else. `skill-lint` owns the machine-checkable
wording of the **lint** rows; `skills/_template/SKILL.md` and the repo
`CLAUDE.md` point here rather than restating anything.

## Frontmatter and naming

| ID  | Tag  | Criterion | Why |
| --- | ---- | --------- | --- |
| SQ1 | lint | Frontmatter opens the file (`---` on line 1) and is closed by a second `---`. | The loader reads the skill's identity from frontmatter; an unclosed block has no identity. |
| SQ2 | lint | `name:` is present. | Without it the skill cannot be addressed or installed. |
| SQ3 | lint | `name` matches the skill's directory name. | The installer links `<name>` to the directory; a mismatch links the wrong thing. |
| SQ4 | lint | `name` is lowercase letters, digits and single hyphens, ≤64 chars, and contains neither "claude" nor "anthropic". | The open Agent Skills spec fixes the charset; the vendor words are noise in a name that already lives under one vendor. |
| SQ5 | lint | `description:` is present. | It is the only text the model sees when choosing a skill; absent, the skill is never chosen. |
| SQ6 | lint | `description` is ≤1024 characters. | The listing budget truncates longer text from the tail, silently dropping triggers. |

## Description quality

| ID  | Tag      | Criterion | Why |
| --- | -------- | --------- | --- |
| SQ7 | lint     | `description` is long enough to carry a trigger (≥ ~50 chars). | A one-clause description rarely matches the words a user actually types. |
| SQ8 | lint + judgment | `description` is third person, not first ("Analyzes…", not "I can help…"). | The model reads it as a catalog entry about the skill, not a voice speaking. skill-lint flags the obvious `I `/`You `/`We ` openings; a reader catches the rest. |
| SQ9 | judgment | `description` states both *what* the skill does and *when* to use it, most important trigger first. | Discovery is a match against the user's words; the first phrase survives truncation, so it must be the strongest trigger. |

## Body

| ID   | Tag      | Criterion | Why |
| ---- | -------- | --------- | --- |
| SQ10 | judgment | The body opens with the skill's boundaries — what it must never do. | A skill that states its limits first is one the model can trust to stop; see `implement-test-suite`. |
| SQ11 | judgment | Phases are numbered, and any phase needing approval before the next says so in bold. | A procedure the model can follow step by step beats prose it has to re-derive; unmarked gates get skipped. |
| SQ12 | judgment | The body says what "done" means and where to stop. | Without a stop condition a skill either quits early or runs past the task. |

## Invocation and side effects

| ID   | Tag      | Criterion | Why |
| ---- | -------- | --------- | --- |
| SQ13 | judgment | A skill with side effects sets `disable-model-invocation: true`. One recorded exception: a skill whose every side effect sits behind an explicit in-skill approval gate (`codebase-health` — findings are reported first, fixes need the user's category-by-category go-ahead) may stay model-invocable. | Deploys, commits and sends should be timed by the human, not auto-triggered by a description match. When the human's approval is built into the flow itself, the gate is already there. |

## Bundled files and portability

| ID   | Tag      | Criterion | Why |
| ---- | -------- | --------- | --- |
| SQ14 | lint     | Bundled `scripts/*` pass `shellcheck` and `shfmt -i 2 -ci`. | A skill script runs in the user's repo; a broken one fails there, far from here. |
| SQ15 | judgment | Scripts resolve their own location and never trust `$PWD`. | A skill is reached through a symlink in `~/.claude/skills`, so `$PWD` is the user's repo, not the skill's; see `project-status-scaffold/scaffold.sh`. |
| SQ16 | judgment | Emitted documents are rendered from `templates/`, never embedded in a heredoc or pasted into `SKILL.md`. | One copy cannot drift; three copies of `HANDOFF.md` already did. |
| SQ17 | judgment | The shared workflow stays in `SKILL.md`; everything ecosystem-specific lives in `references/<language>.md`, and sibling references keep parity. | Adding a language should be adding a file, not editing the workflow; a skill covering one language where its sibling covers two has a gap. |
| SQ18 | judgment | No reference to a specific machine, hostname, or personal workflow. | That context belongs in `memory/GLOBAL.md`; a skill naming it will not port to another setup. |

## The two enforcers

- `bin/skill-lint` — the **lint** rows, mechanically, in any repo. See
  `docs/skill-lint.md`.
- `skills/skill-audit` — the **judgment** rows, by reading each `SKILL.md`.
  It runs `skill-lint` first for the mechanical pass, then grades the rest.
