# Python: pytest specifics

Framework: **pytest**. Detect the repo's packaging tool first (uv, poetry,
plain pip/setuptools) and put config where the repo already keeps it —
prefer `pyproject.toml` (`[tool.pytest.ini_options]`) for new setups; keep an
existing `pytest.ini`/`setup.cfg` if one is already in use.

## Config template (greenfield)

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-ra --strict-markers"
markers = [
    "slow: long-running tests, excluded from the fast tier",
    "gpu: requires a CUDA/Metal-capable device",
    "sim: requires a real simulator (e.g. MuJoCo)",
]
```

Tier commands (document these in the PR description):

- Fast tier (default dev loop): `pytest -m "not slow and not gpu and not sim"`
- Full run: `pytest`
- One tier only: `pytest -m sim`

Add markers beyond `slow`/`gpu`/`sim` only if the plan justifies them, and
always register them (`--strict-markers` makes typos fail loudly).

## Layout and naming

- `tests/` mirrors the import package: `src/pkg/module.py` →
  `tests/pkg/test_module.py`; test functions `test_<behavior>`, not
  `test_<method_name>`.
- Shared fixtures in `conftest.py` at the *lowest* directory level that needs
  them; repo-wide fixtures in `tests/conftest.py`.
- Prefer factory fixtures (a fixture returning a builder function) over many
  near-duplicate object fixtures.

## Determinism and numerics

- Seed every RNG a test touches (`random`, `numpy`, `torch` if present) in a
  fixture; never rely on global seeding done by production code.
- Float comparisons: `numpy.testing.assert_allclose` / `pytest.approx` with
  explicit tolerances — never `==` on floats or arrays.
- Use `tmp_path` for all filesystem output; no test writes into the repo.

## Mocking heavy dependencies (sim / GPU)

- Mock at the module boundary the code under test imports, using
  `monkeypatch` or `unittest.mock.patch` — patch where the name is *used*,
  not where it is defined.
- For simulators, prefer a small hand-written fake (e.g. an object exposing
  `step()`/`reset()` returning fixed arrays of the right shape/dtype) over
  deep `MagicMock` chains; shape and dtype contracts are the main thing unit
  tests should pin down.
- The real-dependency version of the same behavior becomes an integration
  test with the `sim`/`gpu` marker. Guard against missing hardware inside
  marked tests with `pytest.importorskip(...)` or a `skipif` on device
  availability, so a full local run degrades gracefully.

## Property-based tests (hypothesis)

Only when the approved plan proposes them. Good targets: geometric/numeric
invariants (e.g. rotations stay orthonormal, transforms compose),
serialization round-trips, shape/dtype contracts across array functions.
Practicalities: `deadline=None` for anything numerically heavy, cap
`max_examples` (50–200), and pin failures with `@example(...)` once found.

## Coverage

Tool: `pytest-cov` (`--cov=<package> --cov-report=term-missing`). Implement
whichever policy the plan approved:

- **Hard gate**: `--cov-fail-under=<N>` in CI.
- **Report only**: print the report and upload it as a CI artifact; no gate.
- **Ratchet**: keep the current threshold in a small repo file (e.g.
  `.coverage-threshold`), fail CI below it, and raise the file's value in the
  same PR whenever coverage increases.

## GitHub Actions template

Adapt install steps to the repo's tooling; the shape stays the same — a fast
job on every push/PR, marked tiers in a separate job per the plan.

```yaml
name: tests
on: [push, pull_request]

jobs:
  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -e ".[dev]"   # or: uv sync --dev
      - run: pytest -m "not slow and not gpu and not sim" --cov

  integration:
    # trigger per the approved plan: PRs to main only, nightly schedule, etc.
    if: github.base_ref == 'main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -e ".[dev]"
      - run: pytest -m "slow or sim" # gpu tier only if a GPU runner exists
```

Do not add a `gpu` CI job unless the repo actually has a GPU runner —
otherwise leave the `gpu` tier local-only and say so in the PR description.

## Existing suites

Everything above yields to conventions the repo already has: keep its config
file location, marker names, layout, and CI structure, and extend them. Only
propose changing a convention in the plan, explicitly, with a reason.
