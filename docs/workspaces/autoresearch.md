# AutoResearch workspace

EvoMap AutoResearch takes one idea through plan, code, run and independent review. Queue job, GPU, pinned to the `commit` in the conf.
Conf: [`workspaces/autoresearch/workspace.conf`](../../workspaces/autoresearch/workspace.conf). Contract: [`docs/workspaces.md`](../workspaces.md).

## Requirements

- Docker on the place; on turing the `gpu-queue` lock is free.
- `~/.config/vibe/workspaces/autoresearch.env`, mode 600: step 2. `claude setup-token` makes the Claude token.
- An OpenRouter key (`sk-or-v1-…`) with credit: a reviewer call asks for 8192 tokens.
- `run` exports every `KEY=VALUE` line of `/ws/secrets.env`. Turing and runpod copy the whole file, so a key the conf does not name (for example `ANTHROPIC_BASE_URL`) reaches the tool.
- Places: turing and runpod. Vast is not one: it copies only the keys the conf names, and step 2 sets keys that the conf does not name. Add vast to `places=` after a real run proves a `secrets=` list for it.
- The conf does not name `AR_MODEL_AGENT` or `AR_LIMIT_MARGIN`: the surface refuses to start when a named key is unset, so a named key is required.
- The idea is `in/brief.md`. There is no idea generation step.
- Cost: the agent runs on the subscription; the reviewers bill per token on OpenRouter. `hours` limits time; the credit limit of the key caps the spend.
- `run_pending_forge.py` is never called: it can push to `gh-pages`.

## 1. Build the image

```bash
vibe ws build autoresearch
conf=workspaces/autoresearch/workspace.conf
img="$(sed -n 's/^image=//p' "$conf"):$(sed -n 's/^commit=//p' "$conf")"
```

Built on turing on 2026-11-16. The apt packages and the `ralph-loop` plugin install unpinned, so a rebuild of the same tag can differ. `PIP_CUTOFF` in the Dockerfile fixes the Python packages.
Rented place: `docker push "$img"` and make the package public. Turing uses the local image.

## 2. Write the secrets file

```bash
f=~/.config/vibe/workspaces/autoresearch.env; umask 077; : >"$f"
for k in CLAUDE_CODE_OAUTH_TOKEN GPT_CRITIC_API_KEY OPENAI_API_KEY; do   # the last two: the OpenRouter key
  read -rsp "$k: " v && echo && printf '%s=%s\n' "$k" "$v" >>"$f"
done; unset v
printf '%s\n' >>"$f" \
  GPT_CRITIC_BASE_URL=https://openrouter.ai/api/v1 GPT_CRITIC_MODEL=google/gemini-3.5-flash \
  OPENAI_BASE_URL=https://openrouter.ai/api/v1 OPENAI_MID_MODEL=openai/gpt-5-mini \
  GEMINI_API_KEY=unused AR_MODEL_AGENT=claude-opus AR_MODEL_CRITIC=gpt-critic-endpoint \
  AR_MODEL_CODE_REVIEWER=gpt-critic-endpoint AR_MODEL_CONSENSUS_CHECKER=gpt-critic-endpoint \
  AR_MODEL_CRITIC_SECONDARY=oai-mid
```

The `agent` role runs on the subscription (`claude-opus-4-8`). OpenRouter runs the code reviewer, the critic and the second critic: only the `gpt-critic` and `oai-mid` routes take a model name from env.
`GEMINI_API_KEY=unused` fills a key the conf names; no role uses a Gemini route. The second critic must be another model than the critic.

## 3. Check the runner

```bash
docker run --rm --env-file ~/.config/vibe/workspaces/autoresearch.env "$img" \
  claude -p --dangerously-skip-permissions "Reply with the word ok."
```

It prints a reply that holds `ok`. The supervisor uses the same flag, so this also proves `IS_SANDBOX=1`. Stop here if it fails.

## 4. Check the reviewers

```bash
docker run --rm --env-file ~/.config/vibe/workspaces/autoresearch.env --entrypoint sh "$img" -c \
  'export PATH=/opt/venv/bin:$PATH; cd /opt/autoresearch && python3 scripts/render_env.py >/dev/null && ar-runtime/scripts/ar-preflight-mcp.sh'
```

It ends `MCP preflight: 两个 server 都可用` and exits 0: the coordinator stops on this gate only.
`scripts/preflight.py` also lists `ideator` and `freshness_refresher` as unresolved: they serve idea generation, which this workspace does not use.

## 5. Verify

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
- Step 4 prints `HTTP 402 … can only afford <n>` → the credit or the credit limit of the key is too low. Raise it on openrouter.ai.
- Step 4 prints `secondary_critic failed` → an `OPENAI_*` key or `AR_MODEL_CRITIC_SECONDARY` is missing, or it names the critic's model.
- `files/` lacks one of the six paths → the tool did not write it. `run` copies only the paths that exist.
