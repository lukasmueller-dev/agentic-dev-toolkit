# Python

## Detection markers

`pyproject.toml`, `setup.py`, `setup.cfg`, `requirements*.txt`, `Pipfile`,
`uv.lock`, `poetry.lock`, or a top-level package of `.py` files.

## Templates

- Gitignore: `templates/gitignore/python.gitignore`
- CI: `templates/ci/python.yml`

## Adapting the CI template

The template assumes uv with a `pyproject.toml` (`uv sync`, `uv run`). Match
the repo's real tooling instead of imposing it:

- **pip / requirements.txt** — replace setup-uv and `uv sync` with
  `actions/setup-python` plus `pip install -r requirements.txt`, and drop the
  `uv run` prefixes.
- **poetry** — `pipx install poetry`, `poetry install`, `poetry run …`.
- **No ruff configured** — keep the ruff steps only if ruff is (or is being
  made) part of the repo; otherwise substitute the linter the repo actually
  uses, or drop the lint step rather than fail every run.
- **No tests yet** — keep the pytest step; a red first run is the honest
  state, and `pytest --collect-only -q` can stand in until tests exist only
  if the user prefers a green baseline.
- **mypy/pyright** — add a typecheck step only if the repo already configures
  one.
