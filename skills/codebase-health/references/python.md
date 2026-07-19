# Python rules

Check tool availability first (`command -v <tool>` or `<tool> --version`).
A missing tool is not an error: skip it, note the gap in the report, and
lean more on judgment for that category.

## Candidate-finding tools

- `ruff check .` — lint; unused imports/variables (F401, F841); enable
  `C901` for McCabe complexity if configured.
- `radon cc -s -a <scope>` — cyclomatic complexity; treat grade C or worse
  as a candidate, not automatically a finding.
- `vulture <scope>` — dead-code candidates. High false-positive rate:
  verify each hit (dynamic access, plugins, `__all__`) before reporting.
- `pylint --disable=all --enable=duplicate-code <scope>` or
  `jscpd --pattern "**/*.py"` — exact/near-exact clones.

## Semantic duplication pre-filter

Shortlist function pairs that share at least two of: similar length
(within ~30%), same arity/signature shape, overlapping identifier sets.
Only the shortlist goes to judgment.

## Test discovery

Look for `pytest.ini`, `[tool.pytest.ini_options]` in `pyproject.toml`, a
`tests/` directory, or `unittest` patterns — but prefer the invocation in
CLAUDE.md, Makefile, or CI config, since that is what the team actually
runs. Capture the full output for baseline comparison.

## Doc surfaces

- Docstrings vs. real signatures, parameter names, return types, and
  raised exceptions.
- README install/usage vs. `pyproject.toml` / `setup.cfg` reality
  (entry points, extras, supported Python versions).
- CLAUDE.md commands and structure claims vs. the actual repo.
- Example configs and inline comments in config files vs. real keys.

## Behavior-risk traps — report, never auto-fix

- Mutable default arguments: "fixing" `def f(x=[])` changes semantics for
  callers relying on the shared default.
- Import reordering or removal where imports have side effects
  (registration, monkeypatching, logging setup).
- Removing "unused" names that are exported via `__all__`, accessed via
  `getattr`/string lookup, or referenced in configs/entry points.
- Changing exception types or messages that callers may catch or match on.
- Converting between list-returning and generator functions; anything
  relying on dict insertion order or `is` comparisons.
