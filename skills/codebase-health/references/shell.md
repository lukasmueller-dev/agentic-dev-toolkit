# Shell rules

Check tool availability first (`command -v <tool>` or `<tool> --version`).
A missing tool is not an error: skip it, note the gap in the report, and
lean more on judgment for that category.

**Scope by shebang, not by extension.** Many shell scripts have no `.sh`
suffix — CLIs, hooks, and installers usually have none at all. Use
`shfmt -f <scope>` to enumerate them; a glob on `*.sh` silently misses the
files most worth scanning. Note the dialect per file too (`bash`, `sh`,
`zsh`): a finding that is safe in bash may be a bashism in a `#!/bin/sh`
script.

## Candidate-finding tools

- `shellcheck <files>` — lint and dead code. The codes that matter here:
  SC2034 (unused variable), SC2317 (unreachable command), SC2086/SC2046
  (unquoted expansion), SC2155 (`local x="$(cmd)"` masks the exit status).
  Prefer the repo's own invocation if it has one, so severity and
  `disable=` directives match what the project already accepts.
- `shfmt -d -i 2 -ci <scope>` — formatting drift. Match the flags the repo
  uses (check CI config or an `.editorconfig`) rather than imposing a style;
  a whole-repo reformat is diff noise, not a health finding.
- `jscpd --pattern "**/*.{sh,bash}"` — exact/near-exact clones. Feed it the
  shebang-discovered file list where extensions are missing.
- `checkbashisms <files>` — for `#!/bin/sh` scripts only; flags constructs
  that work in bash and break under dash.
- **No standard complexity tool exists for shell.** Use proxies: function
  bodies over ~50 lines, nesting past 3 levels, `case` statements with many
  near-identical arms, and functions taking more than a few positional
  parameters. Each is a candidate, not a finding.

## Semantic duplication pre-filter

The units are functions, `case` arms, and whole scripts in a `bin/`-style
directory. Shortlist pairs sharing at least two of: similar body length
(within ~30%), the same set of external commands invoked (`sed`, `awk`,
`git`, …), overlapping variable names, the same option-parsing shape.

Copy-pasted usage/`--help` blocks and argument-parsing loops are the most
common real duplication in shell repos — check those first. Be careful
before proposing extraction: see the `BASH_SOURCE` trap below.

## Test discovery

Look for `tests/*.bats` (bats), `shunit2`, or plain `test.sh` runners — but
prefer the invocation named in the repo's agent instruction file, `Makefile`,
or CI workflow, since that is what the project actually runs. Shell suites
frequently need a scratch `HOME` or `PATH` stub to be meaningful, so run the
documented command rather than invoking a runner directly. Capture the full
output for baseline comparison.

Where there is no suite, `shellcheck` clean/failing state is the fallback
gate named in the skill's preflight step.

## Doc surfaces

- A script's `usage()`/`--help` text vs. the flags its `getopts` or `case`
  block actually accepts — drift here is near-universal and easy to verify.
- Shell completion files vs. the real subcommand and flag lists.
- README and instruction-file command examples vs. the scripts as they are
  now: run them, or at minimum confirm every flag still parses.
- Comments above a function vs. what it does, especially the documented
  return convention (exit status vs. stdout).
- Installer or setup docs vs. the paths and filenames the script really
  writes.
- Man pages, where the repo ships them.

## Behavior-risk traps — report, never auto-fix

- **Quoting is not cosmetic.** Adding quotes to `$var` changes behavior
  wherever the value was *meant* to word-split (accumulated flag strings,
  `$@` vs `$*`). Verify intent before "fixing" an SC2086.
- **Extracting code into a function changes `set -e`.** `[[ cond ]] && cmd`
  is exempt from errexit as a bare statement, but as a function's *tail*
  statement it becomes the function's exit status, and the call site has no
  exemption. Trailing `&&`-lists are why an extraction that looks pure can
  abort the script.
- **Calling a function as a condition disables errexit inside it.**
  `if myfunc; then`, `myfunc || rc=1`, and `(myfunc)` switch errexit off for
  the whole call, so failures that used to stop the script fall through.
  Moving a call into one of those shapes is a behavioral change.
- **Pipelines with early-exiting consumers.** Under `set -o pipefail`, a
  producer feeding `head` or `grep -q` dies of SIGPIPE (141) once the input
  outgrows a pipe buffer, and that status wins. `grep -v` exits 1 when it
  filters everything out. Refactoring into or out of such a pipeline changes
  when the script fails — and small test fixtures hide it.
- **Subshell boundaries eat assignments.** Rewriting
  `while read …; done < file` as `cmd | while read …` puts the loop in a
  subshell, so every variable it sets is lost at the end. The same applies
  to `$(...)`, `(...)`, and the right-hand side of a pipe generally.
- **`local` is a contract change.** Adding it to a variable a caller reads
  afterwards breaks the caller silently. Merging two functions can likewise
  turn a local into a shared global.
- **`local x="$(cmd)"` swallows `cmd`'s exit status** (SC2155). Collapsing a
  declare-then-assign pair into one line removes a failure check that
  `set -e` was relying on.
- **Moving code changes `BASH_SOURCE`, `$0`, and `$FUNCNAME`.** Any script
  that resolves its own directory — especially one invoked through a
  symlink — breaks when that logic is extracted into a sourced library.
  Deduplicate the *body*, never the location-resolving preamble.
- **Portability is a behavior axis.** "Simplifying" to `mapfile`,
  associative arrays, or `${var,,}` breaks bash 3.2, which macOS still
  ships. `readlink -f`, `sed -i` without an argument, and `stat -c` are
  GNU-only; BSD `sed` also matches nothing for `\|` alternation in a BRE.
  If the repo states a floor, hold to it; if it does not, assume the
  scripts run somewhere you cannot see.
- **`${var//pat/rep}` is not literal about `&`** on bash ≥ 5.2, where
  `patsub_replacement` expands an unescaped `&` in the replacement to
  whatever matched. Escaping is itself unportable, so treat a rewrite into
  this form as behavior-changing.
- **"Unused" is hard to prove in shell.** A variable may be exported to a
  child process, read by a sourced file, referenced indirectly via
  `${!name}`, or consumed by an `eval`/`trap` string. A function may be a
  trap handler, a completion callback, or called by name from another file.
  Grep the whole repo, including non-shell callers, before removing either.
- **`trap` and `IFS` are ambient.** A `trap` set inside a function applies
  to the whole shell, and code that relied on a modified `IFS` or `set -f`
  behaves differently once extracted into a helper that does not.
- **`case` arms are order-dependent** and `;;&` continues matching where
  `;;` stops. Merging near-identical arms can change which one wins.
- **Error text and exit codes are an interface.** Callers grep messages and
  branch on specific non-zero statuses; changing either while "tidying" a
  failure path is a behavioral change.
