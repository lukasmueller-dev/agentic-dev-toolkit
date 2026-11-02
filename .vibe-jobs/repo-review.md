---
# repo-review in agentic-dev-toolkit. A key here overrides the catalogue; remove a key to keep its default.
# schedule: weekly | daily | monthly
# day: sun
# output: pr | report
# model: sonnet
# timeout: 1h
---

- Skip `docs/sota/`. Read `CLAUDE.md` first; it lists the traps of this repo.
- Look first at shell traps: bash 3.2, BSD and GNU userland, `set -e` and `pipefail` in a function's tail or a pipe to `head`.
- Check the installer rules: idempotent, never deletes a real file, `--uninstall` removes only its own links.
- Check a hook that exits non-zero or prints when a dependency is missing.
- Check a permission rule whose `*` spans more than it names.
