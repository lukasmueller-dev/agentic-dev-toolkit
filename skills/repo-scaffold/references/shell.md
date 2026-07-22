# Shell

## Detection markers

The repo is *primarily* shell: executable scripts with `sh`/`bash` shebangs
(what `shfmt -f .` finds) and no stronger marker from another type. A couple
of helper scripts in a Python repo do not make it a shell repo — but they are
still worth covering with this CI's lint job alongside the primary type's.

## Templates

- Gitignore: shell needs no entries of its own — `common.gitignore` suffices.
- CI: `templates/ci/shell.yml`

## Adapting the CI template

- **bats** — the test step degrades to a note when there is no `tests/`
  directory, so the template lands safely before tests exist. The flip side:
  it cannot tell *not yet* from *no longer*, so once the repo has real tests,
  point the step at the actual directory (`tests/`, `test/`, `spec/`) rather
  than leaving the fallback — otherwise a later rename leaves CI green while
  running nothing.
- **Formatting flags** — the template checks `shfmt -i 2 -ci`. If the repo
  already formats differently, match the repo; changing its style is not
  scaffolding.
- **bash 3.2 / BSD portability** — if the scripts must run on macOS's
  shipped bash, add a `macos-latest` matrix leg. It bills at 10× on private
  repos, so on billed repos raise it as a choice instead of adding it
  silently.
- **Sourced files without shebangs** (completions, libs) — `shfmt -f` misses
  them; add an explicit `shellcheck -s bash <file>` step per file, as they
  still have to parse.
