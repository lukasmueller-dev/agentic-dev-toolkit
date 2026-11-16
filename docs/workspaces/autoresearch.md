# AutoResearch workspace

EvoMap AutoResearch takes one idea through plan, code, run and independent review. Queue job, GPU, pinned to the `commit` in the conf.
Conf: [`workspaces/autoresearch/workspace.conf`](../../workspaces/autoresearch/workspace.conf). Contract: [`docs/workspaces.md`](../workspaces.md).

## Requirements

- Docker on the place; on turing the `gpu-queue` lock is free.
- `~/.config/vibe/workspaces/autoresearch.env`, mode 600, one `KEY=VALUE` per line. The conf names `CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token` makes it), `GEMINI_API_KEY`, `GPT_CRITIC_API_KEY` and `GPT_CRITIC_BASE_URL`.
- `run` exports every `KEY=VALUE` line of `/ws/secrets.env`. Turing and runpod copy the whole file, so a key the conf does not name (for example `ANTHROPIC_BASE_URL`) reaches the tool.
- Places: turing and runpod. Vast is not one: it copies only the keys the conf names, and the `agent` role needs `ANTHROPIC_BASE_URL` and a token that the conf does not name. Add vast to `places=` after a real run proves a `secrets=` list for it.
- The conf does not name `AR_MODEL_AGENT` or `AR_LIMIT_MARGIN`: the surface refuses to start when a named key is unset, so a named key is required.
- The idea is `in/brief.md`. There is no idea generation step.
- Cost: the critic and the reviewers call models of other providers. Each provider bills per token. `hours` limits time, not spend.
- `run_pending_forge.py` is never called: it can push to `gh-pages`.

## 1. Build the image

```bash
vibe ws build autoresearch
conf=workspaces/autoresearch/workspace.conf
img="$(sed -n 's/^image=//p' "$conf"):$(sed -n 's/^commit=//p' "$conf")"
```

The image is unbuilt. The apt packages and the `ralph-loop` plugin install unpinned, so a rebuild of the same tag can differ. `PIP_CUTOFF` in the Dockerfile fixes the Python packages.
Rented place: `docker push "$img"` and make the package public. Turing uses the local image.

## 2. Check the runner

```bash
docker run --rm --env-file ~/.config/vibe/workspaces/autoresearch.env "$img" \
  claude -p --dangerously-skip-permissions "Reply with the word ok."
```

It prints a reply that holds `ok`. The supervisor uses the same flag, so this also proves `IS_SANDBOX=1`. Stop here if it fails.

## 3. Choose the agent model

```bash
echo 'AR_MODEL_AGENT=claude-opus' >> ~/.config/vibe/workspaces/autoresearch.env
```

With the default config the `agent` role is `deepseek-v4-pro`. For a Claude token, set `AR_MODEL_AGENT=claude-opus` as above. Unchecked: no real run has used it.

## 4. Verify

Queue a job with `tool=autoresearch`, `place=turing`, `hours=<n>` and the idea in `in/brief.md`. Then read the job dir:

```bash
job=~/.local/state/vibe/queue/<job id>
cat "$job/out/result"    # done: AutoResearch finished, files/ holds the results
ls "$job/out/files"      # results  review.md  critic.md  blind_review.md  state.md  decisions.log
```

`out/report.md` copies `results/summary.md`, which is the tool's claim: check its numbers with the repo's own metric command.
`run` ends the tool 30 min before `hours`: the place counts `hours` from the start of `up`, and its `down` pulls at the limit. `AR_LIMIT_MARGIN` (seconds, in the secrets file) changes the margin.
A cut run ends `failed: stopped at the limit, supervisor exit <n>`, and `files/` keeps what the tool wrote.

## What breaks it

- `steer` exits 3 → by design. The tool hash-binds `idea.md` and the engine checks `state.md`, so no file takes a note. The surface reads 3 as "verb not supported".
- `stop` exits 1 → `run` has not written the result in 280 s (`AR_STOP_WAIT`). The surface gives `stop` 300 s, then runs `down` anyway: a long copy of `results/` is cut.
- `failed: scripts/render_env.py did not write the Claude Code settings` → the tool's MCP preflight fails without `ar-runtime/.claude/settings.local.json`. `run` calls `scripts/render_env.py` after it exports the secrets. Read the error in `tool.log`.
- No `out/result` after the place destroyed the machine at the limit → `up` took longer than the margin. Raise `AR_LIMIT_MARGIN` in the secrets file.
- `failed: stopped` or `failed: stopped at the limit` → `run` sent TERM, then KILL after 60 s (`AR_KILL_GRACE`). A cut run is never `done:`.
- `files/` lacks one of the six paths → the tool did not write it. `run` copies only the paths that exist.
