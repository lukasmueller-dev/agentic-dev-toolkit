# Handoff — agentic-dev-toolkit / fix-render-template-ampersand

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `fix-render-template-ampersand`
- **Worktree:** /root/git/worktrees/agentic-dev-toolkit/fix-render-template-ampersand
- **Last updated:** 2026-07-21 16:31 UTC · server (srv1841294)

## State

Nothing written yet — the branch is at `main` plus this handoff.

`render_template` silently corrupts any substitution value containing `&`.
Bash 5.2 expands an unescaped `&` in the replacement half of
`${var//pattern/replacement}` to the text the pattern matched — the
`patsub_replacement` shell option, which is **on by default**. So rendering a
template with a value like `a && b` writes the *token* back into the output
where each `&` was.

There are two identical copies of the function, and both have the bug:

- `bin/vibe:250` — used by `seed_handoff` and `seed_loop`.
- `skills/_lib/vibe-lib.sh:38` — used by the `loop-brief` and `handoff-brief`
  skill scripts.

The duplication is deliberate: the lib is standalone so a symlinked skill does
not have to depend on `bin/vibe`. Fix both rather than dedupe them.

The failure is silent — no error, no non-zero exit, just a wrong file. It was
found when a `vibe loop --until '… && … && …'` command was rendered into a
`LOOP.md` header and every `&&` came out as `<until><until>`. Anything with an
`&` in it is affected: `--until` command chains (by far the common case), a
task name or goal containing `&`, a worktree path containing `&`.

One file already hit this: the brief on branch `ralphify-vibe-loop`. Its
header was repaired by hand and pushed, so it needs no re-render — do not
regenerate it.

## Next action

Reproduce first, so the fix is verified against the real behaviour rather than
against this description:

```bash
bash -c 'c="a<t>b"; echo "${c//<t>/x && y}"'
# bash 5.2 → ax<t><t>yb        (wrong)
# bash 3.2 → ax && yb          (correct)
```

Then add `shopt -u patsub_replacement 2>/dev/null || true` to both copies of
`render_template`. Both halves of that line are required: bash 3.2 does not
know the option, and a bare `shopt -u` on an unknown option exits non-zero,
which aborts the script under `set -e`. `shopt` is shell-global, not
function-scoped, so decide deliberately between unsetting it once near the top
of each script and saving/restoring it around the substitution loop.

While in there, correct both function comments. They currently justify the
pure-bash approach by saying a value containing the delimiter "cannot corrupt
the substitution", which is now only half true — say that `&` is the case the
`shopt` handles.

Then add coverage. Nothing in `tests/` exercises `render_template` today, so
test it end to end through the two entry points:

- `tests/vibe-loop.bats` — run `vibe loop` with an `--until` containing `&&`
  and assert the rendered `LOOP.md` header holds the command verbatim.
- `tests/loop-brief.bats` — same assertion through `brief.sh create`, which
  covers the `skills/_lib` copy.

## Blockers

_What is stopping progress, and what would unblock it._

## Gotchas (unpromoted)

CI's macOS leg cannot catch this class of bug. macOS ships bash 3.2, which has
no `patsub_replacement`, so the corrupted path never runs there; only the Linux
leg with bash ≥ 5.2 reproduces it. Any test added must assert the same literal
output under both, which the fix above makes true.

Escaping the value instead — `${2//&/\\&}` — was considered and rejected: under
bash 3.2 the backslash stays literal in the output, so the escape would have to
be conditional on the bash version, whereas the `shopt` normalises both
versions to one behaviour.

If this turns out to be worth warning future work about, `CLAUDE.md`'s shell
section already lists the bash 3.2 / BSD-vs-GNU traps and is where a line about
`patsub_replacement` belongs — promote it there before finishing.
