# DeepScientist workspace

Research studio with a web UI; its quests run Claude Code agents. Service, GPU, pinned to 1.6.0.
Conf: [`workspaces/deepscientist/workspace.conf`](../../workspaces/deepscientist/workspace.conf). Contract: [`docs/workspaces.md`](../workspaces.md).

## Requirements

- Docker on the place; on turing the `gpu-queue` lock is free.
- `CLAUDE_CODE_OAUTH_TOKEN=<token>` in `~/.config/vibe/workspaces/deepscientist.env`, mode 600. `claude setup-token` makes the token.
- No `~/.claude` login file is needed. Step 2 proves it.

## 1. Build the image

```bash
commit="$(sed -n 's/^commit=//p' workspaces/deepscientist/workspace.conf)"
img="ghcr.io/lukasmueller-dev/ws-deepscientist:$commit"
docker build -t "$img" workspaces/deepscientist
```

The build runs `ds init`: uv and the Python env download once, so a start needs no install. Expect minutes.
Rented place: `docker push "$img"` and make the package public. Turing uses the local image.

## 2. Check the runner

```bash
docker run --rm --env-file ~/.config/vibe/workspaces/deepscientist.env "$img" \
  claude -p --permission-mode bypassPermissions "Reply with the word ok."
```

It prints a reply that holds `ok`. The container has no `~/.claude`, so the token alone logs the runner in. Stop here if it fails.

## 3. Start

```bash
vibe ws start deepscientist
```

`start` links the image's seed (`/opt/ds-seed/runtime`) into `/ws/data/runtime` and starts the daemon with `--auth true`.
The queue page lists the link without the token.

## 4. Verify

```bash
export WS_INSTANCE=deepscientist WS_STATE=~/.local/state/vibe/workspaces/deepscientist WS_DIR="$PWD/workspaces/deepscientist"
workspaces/_places/turing exec status    # up — /?token=<token>
workspaces/_places/turing url            # http://<tailnet address>:20999
```

The full link is the address plus the path from `status`. Open it on the phone: the UI loads.
`curl -s -o /dev/null -w '%{http_code}\n' <address>/api/health` prints `401`: no token, no access.
`vibe ws stop deepscientist` ends the daemon, keeps `/ws/data` and frees the GPU lock.

## What breaks it

- `status` prints a path, not a host → add the address from `url`.
- Claude Code refuses all permissions as root → `IS_SANDBOX=1` is missing. The image sets it and `start` sets it with `PATH`, because an ssh exec channel may not carry the image `ENV`.
- Step 2 prints a login prompt or an auth error → the token is wrong or expired; run `claude setup-token` again.
- `pull` is slow and big → the place follows the `runtime/` links and copies the Python env again. Copy links as links.
- The token shows in a file under `/ws/data` → only `.ws-token` and `runtime/daemon.json` may hold it, both mode 600.
  The daemon also prints it into `logs/daemon.log`. `start` links `/ws/data/logs` to `${TMPDIR:-/tmp}/ds-logs`, so `pull` skips the log. A place that follows links copies it.
  The launch-card log is a temp file, not in `/ws/data`.
- `run` or `steer` exits 3 → expected. DeepScientist is a service, so both scripts only `exit 3`: "verb not supported".
