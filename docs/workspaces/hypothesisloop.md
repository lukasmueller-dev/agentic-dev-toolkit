# HypothesisLoop workspace

Many agents work on one objective. Service on the host, no GPU, pinned to `70135ef`.
The workspace drives the compose stack of your own checkout. It serves no UI itself. Step 4 starts the UI.
Conf: [`workspaces/hypothesisloop/workspace.conf`](../../workspaces/hypothesisloop/workspace.conf). Contract: [`docs/workspaces.md`](../workspaces.md).

## Requirements

- On turing: docker with compose 2.24.4 or later, Go, Node with npm, make, openssl, python3, tmux, tailscale. Step 5 also needs podman and `cloudflared`.
- Your HypothesisLoop checkout at `70135ef89035c15a7969c957740690524d6dc7f2`.
- `HLOOP_REPO=<checkout>` in `~/.config/vibe/workspaces/hypothesisloop.env`, mode 600.
- These accounts, with their keys in `<checkout>/.env`:

| Account | For | Keys |
| --- | --- | --- |
| Claude subscription | agent models. Control-service does not start without the key. | `MODEL_ANTHROPIC_OAUTH_TOKEN`. `claude setup-token` prints one; the tool's docs name no command. |
| Supabase project | UI sign-in | `IDENTITY_PROVIDER=supabase`, `IDENTITY_SUPABASE_PROJECT_REF`, `IDENTITY_SUPABASE_PUBLISHABLE_KEY`, `IDENTITY_SIGN_IN_PROVIDERS=github` |
| GitHub OAuth App | the GitHub provider of Supabase, callback `https://<ref>.supabase.co/auth/v1/callback` | none. Its id and secret go into Supabase. |
| GitHub App of `controlplane/clients/githost/github/app-manifest.json` | the repository of each experiment. Setup and callback URL: `<ui origin>/settings/repository`. | `GIT_HOST_PROVIDER=github`, `GIT_HOST_GITHUB_APP_ID`, `GIT_HOST_GITHUB_APP_SLUG`, `GIT_HOST_GITHUB_APP_PRIVATE_KEY`, `GIT_HOST_GITHUB_CLIENT_ID`, `GIT_HOST_GITHUB_CLIENT_SECRET` |
| `fly`, `e2b` or `cloudrun` | hosted agents, under `make dev` only | `SANDBOX_PROVIDER`, `SANDBOX_<PROVIDER>_API_KEY`. `cloudrun` takes no key. |
| vast.ai, RunPod | rented job machines, under `make dev` only | `CLOUD_COMPUTE_PROVIDERS`, `CLOUD_COMPUTE_HYPOTHESISLOOP_<PROVIDER>_API_KEY`, `..._ACCOUNT_ID` (vast.ai: numeric) |

- These keys need no account:

| Key | Value |
| --- | --- |
| `LOCAL_REACHABLE_ADDRESS` | the tailnet IPv4, `tailscale ip -4`. `start` binds the API, the metrics service and the object store there. |
| `UI_ORIGIN` | `http://<tailnet hostname>:3000`, the one browser origin the API allows. Not the IP: Supabase refuses its sign-in. |
| `UI_API_URL` | `http://<tailnet hostname>:8081`, the API as the phone reaches it |
| `OBJECT_STORE_MINIO_SECRET_ACCESS_KEY` | a secret you choose. It is also the root password of the object store. |
| `CONTAINER_REGISTRY_PROVIDER` | empty. `gcp` adds an Artifact Registry. `plain` runs under `make dev` only. |

- `GIT_HOST_PROVIDER=plain` needs the git server that only `make dev` runs. Use `github`.
- Supabase: the site URL is `<ui origin>`, the redirect allow-list holds `<ui origin>/**`, and the JWT key is ES256 or RS256. The exact `/auth/callback` entry misses the `?next=` return.

## What it rents

`vibe ws start hypothesisloop` rents nothing. Its settings come from `make render-settings` and hold no `sandbox` or `cloud_compute` section.

`make dev` in the checkout adds both sections. Then control-service rents:

- one sandbox machine on `SANDBOX_PROVIDER` for each hosted agent: planner, coordinator, team;
- one machine per job node on each provider of `CLOUD_COMPUTE_PROVIDERS`, destroyed when the job ends. Unset, the list is `vast runpod`.

Hosted agents call models on the Claude subscription. Step 5 runs `make dev`.
`start` refuses an unset `CLOUD_COMPUTE_PROVIDERS`. List only the providers you agree to rent on. A later `make dev` reads the same `.env`.

## 1. Fill the checkout's `.env`

```bash
cd <checkout>
[ -e .env ] || { cp .env.example .env && sed -i '/^CLOUD_COMPUTE_PROVIDERS*=/d' .env; }
chmod 600 .env    # set the keys of Requirements
make -s render-settings
```

A fresh `.env` loses the rent list of the example, so you write `CLOUD_COMPUTE_PROVIDERS` yourself.
`render-settings` names each key it misses. Repeat until it prints nothing.

## 2. Build the images

```bash
cd <checkout>
tag="$(bash localdev/lib/image-tag.sh)"
go mod vendor &&
  docker build --platform linux/amd64 -f controlplane/build/Dockerfile.control-service -t "localhost:5000/hypothesisloop-control-service:$tag" . &&
  docker build --platform linux/amd64 -f controlplane/build/Dockerfile.metrics-service -t "localhost:5000/hypothesisloop-metrics-service:$tag" . &&
  echo "$tag" >localdev/.image-tag
rm -rf vendor
for i in library/postgres:16-alpine greptime/greptimedb:v1.2.1 memgraph/memgraph:3.13.1 pgsty/silo:RELEASE.2026-09-16T00-00-00Z; do docker pull "docker.io/$i"; done
```

`make local-images` fails on turing. It runs `podman compose` and pushes over HTTP. These are its two build lines for docker, with no push. The name `localhost:5000` is local: nothing pulls it.
The pull moves the store downloads out of `start`, which must return in 120 s.

## 3. Start

```bash
cd ~/github/agentic-dev-toolkit
vibe ws start hypothesisloop    # hypothesisloop up — http://<tailnet ip>:3000
```

`start` checks `.env`, renders the settings, brings up the compose stack detached and waits 45 s for the API health check. The address is the UI of step 4.

## 4. Start the UI

```bash
cd <checkout>
npm --prefix controlplane/ui ci
addr="$(tailscale ip -4)"
tmux new-session -d -s hloop-ui -c "$PWD" \
  "bash -c '. localdev/lib/env.sh && lib_run ui env NODE_OPTIONS=--no-experimental-strip-types npm --prefix controlplane/ui run dev -- -H $addr'"
```

This is the UI line of `localdev/dev.sh`. `dev.sh ui` refuses here, because it needs the settings that only `make dev` writes.
`-H` binds `next dev` to the tailnet address, port 3000, as `start` binds the API. `start` writes its keys to `localdev/.run/env/ui.env`.

## 5. Rent compute: `make dev`

`make dev` runs the control plane from source, with sandboxes, rented job machines, a git server and an image registry. It needs ports 3000 and 8081.

```bash
vibe ws stop hypothesisloop
systemctl --user enable --now podman.socket    # once; podman compose needs its API socket
cd <checkout>    # .env: GIT_HOST_PROVIDER='plain', CONTAINER_REGISTRY_PROVIDER='plain', IMAGE_REGISTRY, IMAGE_TAG
tmux new-session -d -s hloop-dev "env PATH=\"$HOME/.nvm/versions/node/<version>/bin:$PATH\" bash -c 'make dev > localdev/.run/make_dev.log 2>&1'"
```

`make dev` returns after about 2 min; the first run downloads about 1.9 GB of store images. It ends with each service `running`. Sign in again: the podman databases are new.
`cloudflared` opens public quick tunnels for the API, metrics, object store, git server and registry. Their URLs change on each restart.

Rented machines pull `harness-base` and `node-agent` from `IMAGE_REGISTRY`. Publish them once per tag, then set each GHCR package public:

```bash
cd <checkout> && go mod vendor
make image-harness-base image-node-agent REGISTRY=ghcr.io/<owner> TAG="$(bash localdev/lib/image-tag.sh)" CONTAINER_ENGINE=docker IMAGE_PLATFORM=linux/amd64
rm -rf vendor    # IMAGE_TAG in .env = that tag
```

Smoke run: the demo `tests/experiments/dummy-data-search-demo`, cut to one `hyperparameter-search` executor, `budget_accelerator_hours: 1`, `max_agents: 1`. It costs about $2.

```bash
export API_URL=http://localhost:8081 PATH="$PWD/localdev/.bin:$PATH"
export HL_TOKEN="$(make -s staff-token)" HL_ORG=<org id>    # hl org list; your org is "Default org"
hl project list    # add project_id, repository (owner/name) and branch to the copy's experiment.yaml
hl platform-experiments start <copy of the demo>
```

Stop: `bash localdev/dev.sh down && make tunnels-down`, then `podman stop` the stores. The volumes stay.

## 6. Verify

```bash
cd ~/github/agentic-dev-toolkit
workspaces/hypothesisloop/status    # up — the control service answers http://127.0.0.1:8081/health
curl -s -o /dev/null -w '%{http_code}\n' "http://$(tailscale ip -4):8081/health"    # 200
hl platform-experiments get --platform-experiment <PE>    # in the step-5 shell: closed, with COMPLETED jobs
```

Open `http://<tailnet ip>:3000` on the phone. The sign-in page loads, and GitHub signs you in.
`vibe ws stop hypothesisloop` ends the UI session, takes the stack down and keeps its data volumes.

## What breaks it

- `start of hypothesisloop ran past 120 s` → docker pulled the store images, or Go compiled `localdev/envfiles`, inside `start`. Run step 1 and the pull of step 2 first.
- `start` prints `the control service did not answer` → the 20 log lines above it name the cause. `start` has taken the stack down. Fix the cause, then start again.
- `start` prints `does not set UI_ORIGIN` or another key → `make render-settings` checks keys that `start` does not. Set the key in `.env`.
- `start` prints `differs from the commit in workspace.conf` → the tailnet binds cover the compose file of `70135ef` only. Check out `70135ef` in the checkout.
- `start` fails on `!override` → docker compose is older than 2.24.4. Update it.
- `start` refuses `LOCAL_REACHABLE_ADDRESS=<value>` → compose publishes on an IP only, and `start` binds to the tailnet (100.64.0.0/10) only. Set the output of `tailscale ip -4`.
- `status` prints `nothing serves the UI on http://<tailnet ip>:3000` → the step-4 session ended. Run its command in the foreground to see the error. The UI names each key it misses.
- Sign-in fails with a CORS error on `<ref>.supabase.co/auth/v1/authorize` → `UI_ORIGIN` is the tailnet IP. Set the tailnet hostname.
- Sign-in lands on `/?code=` → the Supabase redirect allow-list misses `<ui origin>/**`.
- `start` prints `metrics-service is not running` → its last 20 log lines name the cause. `start` has taken the stack down.
- `make dev` fails on `podman.sock: no such file` → `systemctl --user enable --now podman.socket`.
- `make dev` prints `ui: running`, and port 3000 refuses → `localdev/.run/ui.log` shows `npm: No such file`. Put the nvm `bin` on `PATH`, then `bash localdev/dev.sh ui`.
- Every RunPod job ends `create_failed` (`pulls its image with a login`) → RunPod pulls public images only, and the plain registry needs a login. Use vast.ai, or a public job image.
- Port 3000 still answers after `dev.sh down` → a `next-server` from `dev.sh ui` survives. Kill it by its pid.
