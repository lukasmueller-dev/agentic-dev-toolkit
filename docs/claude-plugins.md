# Claude Code plugins

`claude/settings.json` declares each plugin: `extraKnownMarketplaces` (pinned `ref`) and `enabledPlugins`.
`./install.sh claude` merges them and installs them with `claude plugin`. Settings alone install nothing.

| Plugin | Gives | Guard |
| --- | --- | --- |
| `runpod@runpod` | 20 skills, the hosted MCP server `mcp.runpod.io` | `ask` on `Bash(runpodctl:*)` and `mcp__plugin_runpod_runpod__*` |
| `vastai@vast-ai` | 7 skills (`vastai`, `vastai-host`, 5 commands) | `ask` on `Bash(vastai:*)` |

- The guard: an `ask` rule prompts even where a skill's `allowed-tools` allows the call.
- `claude/vibe-job-settings.json` denies the same three rules: a queue job rents a GPU only through `vibe queue gpu`.
- Cost: about 2,800 tokens in every session (`claude plugin details <plugin>`).

## Requirements

- `runpodctl` and `vastai` with a key each: [place-runpod.md](workspaces/place-runpod.md), [place-vast.md](workspaces/place-vast.md).

## 1. Install

```bash
./install.sh claude          # "installed runpod@runpod", "installed vastai@vast-ai"
claude plugin list           # both: ✔ enabled
```

## 2. Sign in to the RunPod MCP server

In a session: `/mcp` → `runpod` → Sign in with Runpod.

## 3. Verify

```bash
claude plugin details runpod@runpod | grep 'MCP servers (1)'
```

In a session: `runpodctl pod list` asks for permission.

## 4. Move a pin

```bash
git ls-remote https://github.com/runpod/runpod-plugins-official main   # the new SHA
```

Set that SHA as `ref` in `claude/settings.json`, review the upstream diff, then `./install.sh claude`.

## What breaks it

- `claude plugin marketplace remove <m>` also deletes `<m>` from `settings.json` → `./install.sh claude` puts it back.
- A moved pin with the same plugin version updates nothing → `claude plugin uninstall <p>`, then `./install.sh claude`.
- `/plugin` disables a plugin → the next install enables it again: the baseline wins.
- `vastai` or `runpodctl` behind a path or `env` (`~/.local/bin/vastai`) misses the guard.
