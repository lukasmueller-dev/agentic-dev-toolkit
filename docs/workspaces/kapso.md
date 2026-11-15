# Kapso workspace

Kapso improves one metric in a repo by a tree of experiments. The result is a branch. Queue job, GPU, pinned to `8b897c7`.
Conf: [`workspaces/kapso/workspace.conf`](../../workspaces/kapso/workspace.conf). Contract: [`docs/workspaces.md`](../workspaces.md).

## Requirements

- Docker on the place; on turing the `gpu-queue` lock is free.
- `CLAUDE_CODE_OAUTH_TOKEN=<token>` in `~/.config/vibe/workspaces/kapso.env`, mode 600. `claude setup-token` makes the token.
- A GitHub remote on the repo: the runner pushes the result branch and opens a draft PR.
- `in/brief.md` is the Kapso brief. `in/args` holds two keys, and `run` fails without either:

| Key | Value |
| --- | --- |
| `evaluation` | the directory in the repo that holds the evaluator, for example `eval` |
| `experiments` | the experiment budget, a whole number |

- Kapso gets `hours` × 60 − 5 minutes, so the bundle fits before the place's limit. `config.yaml` turns the inbox off and runs Kapso's inference on Claude Code with `claude-opus-5-5`. The experiment sessions keep Kapso's host model, `claude-opus-5`.
- Cost: each experiment starts Claude Code sessions on the subscription. `experiments` and `hours` bound the run, not the tokens.

## 1. Build the image

```bash
commit="$(sed -n 's/^commit=//p' workspaces/kapso/workspace.conf)"
img="ghcr.io/lukasmueller-dev/ws-kapso:$commit"
docker build -t "$img" workspaces/kapso
```

The image is unbuilt. Claude Code is pinned to 2.1.310. The base image, the apt packages and Kapso's dependencies install unpinned, so a rebuild of the same tag can differ.
Rented place: `docker push "$img"` and make the package public. Turing uses the local image.

## 2. Check the container

```bash
docker run --rm --env-file ~/.config/vibe/workspaces/kapso.env \
  -v "$PWD/workspaces/kapso:/ws/scripts:ro" "$img" \
  sh -c 'mkdir -p /ws/data /ws/out && id -u && kapso doctor build --config /ws/scripts/config.yaml --models'
```

It prints `1000`, then a report where every item is ok, and exits 0. `--models` probes the Claude Code login with a few one-token calls.
The `mkdir` repeats what `up` does as the container user `node` (uid 1000); the Dockerfile makes `/ws` writable for it. Stop here if it fails.

## 3. Make the test repo

```bash
mkdir ~/github/kapso-test && cd ~/github/kapso-test && git init -q -b main && mkdir eval
cat >words.py <<'EOF'
def count_words(text):
    return len(text.split(" "))
EOF
cat >eval/evaluate.py <<'EOF'
import json, pathlib, sys
sys.path.insert(0, ".")
from words import count_words
CASES = [("a b c", 3), ("", 0), ("  a  b ", 2), ("a\tb\nc", 3), ("one", 1), ("a, b. c!", 3), ("x  y", 2), ("   ", 0)]
score = sum(count_words(t) == n for t, n in CASES) / len(CASES)
out = f"accuracy: {score:.3f}"
pathlib.Path(__file__).with_name("result.json").write_text(json.dumps({"evaluation_script_path": "kapso_evaluation/evaluate.py", "evaluation_output": out, "score": score}))
print(out)
EOF
printf 'eval/result.json\n__pycache__/\n' >.gitignore
python3 eval/evaluate.py    # accuracy: 0.375
git add -A && git commit -qm "baseline" && gh repo create kapso-test --private --source . --push
```

`count_words` fails on empty text, repeated spaces, tabs and newlines, so one experiment can reach 1.0.
Kapso refuses an evaluation directory that holds a `result.json`: the `.gitignore` keeps the one from the check out of the clone.

## 4. Queue the run

Queue a job on `~/github/kapso-test` with `tool=kapso`, `place=turing` and `hours=1`. Its `in/` holds two files.

```text
# in/args
evaluation=eval
experiments=3
```

```text
# in/brief.md
Objective    Make count_words in words.py count the words of any text, so that accuracy on the evaluator reaches 1.0.
Measured by  kapso_evaluation/evaluate.py, accuracy over fixed cases
Target       1.0
Rules
  - the evaluator is never modified
```

The brief has no `Budget` line: `run` sets the budget from `in/args` and `hours`.

## 5. Verify

```bash
job=~/.local/state/vibe/queue/<job id>
cat "$job/out/result"                              # done: kapso/exp-<n>, score 1.0
cat "$job/out/branch" "$job/out/score"             # kapso/exp-<n>  1.0
git bundle list-heads "$job/out/repo.bundle"       # <sha> refs/heads/kapso/exp-<n>
```

The job ends as a draft PR on `kapso-test`. `out/report.md` and `out/score` are Kapso's claim. The closing session runs `python3 eval/evaluate.py` on the branch: the PR body shows `accuracy: 1.000`.
While the run goes, `vibe queue steer <job id> "<text>"` adds a note: only agent sessions that start after it read it. `vibe queue stop <job id>` ends the campaign and keeps its checkpoint.

## What breaks it

- `mkdir: cannot create directory '/ws/data': Permission denied`, in step 2 or at `up` → the image lacks the `chown node:node /ws` line: Docker makes `/ws` as root for the bind mounts. Rebuild from the current Dockerfile (step 1).
- `failed: run exit <n>, see tool.log` → `kapso build` or a step before the verdict failed. `tool.log` has the error. A missing `evaluation=` or `experiments=` in `in/args` ends here too.
- `failed: goal not achieved (<reason>)` → the campaign ended below the target, for example `budget_exhausted`. When Kapso picked a branch, `out/` still holds the bundle and the score.
- `eval/result.json is the evaluator's own output, left by an earlier run` in `tool.log` → the repo commits a `result.json`. Remove it from the repo and queue again.
- `steer` exits with an error on a text that looks like a token → Kapso refuses it. Put a secret in `kapso.env`, not in a note.
