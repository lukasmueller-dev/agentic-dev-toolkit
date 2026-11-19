# Claude Code plugins

`claude/settings.json` declares each plugin: `extraKnownMarketplaces` (pinned `ref`) and `enabledPlugins`.
`./install.sh claude` merges them and installs them with `claude plugin`. Settings alone install nothing.
The repo's own plugins live in `claude/marketplace/` (marketplace `toolkit`, added by path `~/.claude/marketplace`, read in place).

| Plugin | Gives | Guard |
| --- | --- | --- |
| `runpod@runpod` | 20 skills, the hosted MCP server `mcp.runpod.io` | `ask` on `Bash(runpodctl:*)` and each MCP tool that changes or runs something; MCP reads (`list-*`, `get-*`, docs) allowed |
| `vastai@vast-ai` | 7 skills (`vastai`, `vastai-host`, 5 commands) | `ask` on `Bash(vastai:*)` |
| `wandb@toolkit` | the W&B MCP server, key `${WANDB_API_KEY}` | allowed; the key is unset in sandboxed Bash |

- The guard: an `ask` rule prompts even where a skill's `allowed-tools` allows the call.
- `claude/vibe-job-settings.json` denies the same three rules: a queue job rents a GPU only through `vibe queue gpu`.
- Cost: about 2,800 tokens in every session (`claude plugin details <plugin>`).

## Requirements

- `runpodctl` and `vastai` with a key each: [place-runpod.md](workspaces/place-runpod.md), [place-vast.md](workspaces/place-vast.md).

## 1. Add the keys

```bash
mkdir -p ~/.config/vibe/secrets && chmod 700 ~/.config/vibe/secrets
read -rsp 'W&B key: ' k && (umask 077 && printf 'WANDB_API_KEY=%s\n' "$k" >>~/.config/vibe/secrets.env); unset k
# one repo with another key: ~/.config/vibe/secrets/<repo>.env, same format; it wins
```

`claude-rc@<repo>` loads both files. A terminal `claude` does not: `set -a; . ~/.config/vibe/secrets.env; set +a` first.

## 2. Install

```bash
./install.sh claude          # "installed runpod@runpod", "installed vastai@vast-ai", "installed wandb@toolkit"
claude plugin list           # all three: ✔ enabled
```

## 3. Sign in to the RunPod MCP server

In a session: `/mcp` → `runpod` → Sign in with Runpod.

## 4. Restart the servers

Warning: a restart ends the sessions of that server.

```bash
systemctl --user daemon-reload && systemctl --user restart 'claude-rc@*'
claude mcp remove wandb -s user   # a server added by hand before; else two W&B servers
```

## 5. Verify

```bash
claude plugin details runpod@runpod | grep 'MCP servers (1)'
```

In a session: `/mcp` shows `plugin:wandb:wandb` connected.

In a session: `runpodctl pod list` asks for permission.

## 6. Move a pin

```bash
git ls-remote https://github.com/runpod/runpod-plugins-official main   # the new SHA
```

Set that SHA as `ref` in `claude/settings.json`, review the upstream diff, then `./install.sh claude`.

## What breaks it

- `claude plugin marketplace remove <m>` also deletes `<m>` from `settings.json` → `./install.sh claude` puts it back.
- A moved pin with the same plugin version updates nothing → `claude plugin uninstall <p>`, then `./install.sh claude`.
- `/plugin` disables a plugin → the next install enables it again: the baseline wins.
- `vastai` or `runpodctl` behind a path or `env` (`~/.local/bin/vastai`) misses the guard.
- A new RunPod MCP tool is on no list: auto mode lets the classifier decide. Add it to `allow` (read) or `ask` (write).
- `ask` beats `allow`: a catch-all `mcp__plugin_runpod_runpod__*` in `ask` prompts on every read again.
- `plugin:wandb:wandb` fails with HTTP 401 → `WANDB_API_KEY` is unset in that server: check step 1, then step 4.
- Queue jobs have no key: the W&B server fails to connect there.
- An unsandboxed Bash call sees `WANDB_API_KEY`: `envVars` scrubs sandboxed commands only.
