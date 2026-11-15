# HypothesisLoop workspace

Many agents work on one objective. Service on the host, no GPU, pinned to `70135ef`.
The workspace drives the compose stack of your own checkout. It serves no UI itself. Step 4 starts the UI.
Conf: [`workspaces/hypothesisloop/workspace.conf`](../../workspaces/hypothesisloop/workspace.conf). Contract: [`docs/workspaces.md`](../workspaces.md).

## Requirements

- On turing: docker with compose 2.24.4 or later, Go, Node with npm, make, openssl, python3, tmux, tailscale.
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
| vast.ai, RunPod | rented job machines, under `make dev` only | `CLOUD_COMPUTE_PROVIDERS`, `CLOUD_COMPUTE_HYPOTHESISLOOP_<PROVIDER>_API_KEY` |

- These keys need no account:

| Key | Value |
| --- | --- |
| `LOCAL_REACHABLE_ADDRESS` | the tailnet IPv4, `tailscale ip -4`. `start` binds the API, the metrics service and the object store there. |
| `UI_ORIGIN` | `http://<tailnet ip>:3000`, the one browser origin the API allows |
| `UI_API_URL` | `http://<tailnet ip>:8081`, the API as the phone reaches it |
| `OBJECT_STORE_MINIO_SECRET_ACCESS_KEY` | a secret you choose. It is also the root password of the object store. |
| `CONTAINER_REGISTRY_PROVIDER` | empty. `gcp` adds an Artifact Registry. `plain` runs under `make dev` only. |

- `GIT_HOST_PROVIDER=plain` needs the git server that only `make dev` runs. Use `github`.
- Supabase: the site URL is `<ui origin>`, the redirect allow-list holds `<ui origin>/auth/callback`, and the JWT key is ES256 or RS256.

## What it rents

`vibe ws start hypothesisloop` rents nothing. Its settings come from `make render-settings` and hold no `sandbox` or `cloud_compute` section.

`make dev` in the checkout adds both sections. Then control-service rents:

- one sandbox machine on `SANDBOX_PROVIDER` for each hosted agent: planner, coordinator, team;
- one machine per job node on each provider of `CLOUD_COMPUTE_PROVIDERS`, destroyed when the job ends. Unset, the list is `vast runpod`.

Hosted agents call models on the Claude subscription. `make dev` runs `podman compose`, and turing has docker only.
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
The pull moves the store downloads out of `start`, which must return in 120 s. Unchecked: no docker build of these two images has run.

## 3. Start

```bash
cd ~/github/agentic-dev-toolkit
vibe ws start hypothesisloop    # hypothesisloop up — http://<tailnet ip>:3000
```

`start` checks `.env`, renders the settings and brings up the compose stack detached. The address is the UI of step 4.

## 4. Start the UI

```bash
cd <checkout>
npm --prefix controlplane/ui ci
tmux new-session -d -s hloop-ui -c "$PWD" \
  "bash -c '. localdev/lib/env.sh && lib_run ui env NODE_OPTIONS=--no-experimental-strip-types npm --prefix controlplane/ui run dev'"
```

This is the UI line of `localdev/dev.sh`. `dev.sh ui` refuses here, because it needs the settings that only `make dev` writes.
`next dev` listens on every interface, port 3000. `start` writes its keys to `localdev/.run/env/ui.env`.

## 5. Start the first objective

The first objective is the tool's own demo, `tests/experiments/dummy-data-search-demo`. It trains a numpy MLP on synthetic data.
A trial holds one CPU core for about one minute. The budget is 2 core-hours in 1 hour.
Connect GitHub first. In the UI, open Settings, then GitHub, then Connect GitHub.

```bash
cd <checkout>
go build -o localdev/.bin/hl ./cli/cmd/hl
export API_URL=http://localhost:8081 PATH="$PWD/localdev/.bin:$PATH"
export HL_TOKEN="$(make -s staff-token TAG="$(cat localdev/.image-tag)")"
hl project list    # copy a project id
# add project_id, repository (owner/name) and branch to tests/experiments/dummy-data-search-demo/.hypothesisloop/experiment.yaml
hl platform-experiments start tests/experiments/dummy-data-search-demo
```

The edit of `experiment.yaml` changes the tag of the tree. `TAG=` keeps the settings on the built tag.
The demo needs two parts that the compose stack does not have.

Warning: a cluster on turing can offer the GPU to jobs outside the `gpu-queue` lock.

| The demo needs | The compose stack | The fix |
| --- | --- | --- |
| a sandbox for its coordinator and team (`coordinator_in_agentsandbox: true`) | has no `sandbox` section, so sandboxes are unavailable (`agentsandbox_not_configured`) | `make dev`, which needs podman |
| a cluster with CPU cores for its jobs | registers no cluster | `hl cluster add` and the command it prints, by the tool's `docs/install-cluster.md`. A bare-metal node gets a root systemd unit. |

Unchecked: no run of this step has happened.

## 6. Verify

```bash
cd ~/github/agentic-dev-toolkit
workspaces/hypothesisloop/status    # up — the control service answers http://127.0.0.1:8081/health
curl -s -o /dev/null -w '%{http_code}\n' "http://$(tailscale ip -4):8081/health"    # 200
hl platform-experiments get --platform-experiment <PE>    # in the step-5 shell: what the demo waits for
```

Open `http://<tailnet ip>:3000` on the phone. The sign-in page loads, and GitHub signs you in.
`vibe ws stop hypothesisloop` takes the stack down and keeps its data volumes. `tmux kill-session -t '=hloop-ui'` stops the UI.

## What breaks it

- `start of hypothesisloop ran past 120 s` → docker pulled the store images, or Go compiled `localdev/envfiles`, inside `start`. Run step 1 and the pull of step 2 first.
- `start` prints `does not set UI_ORIGIN` or another key → `make render-settings` checks keys that `start` does not. Set the key in `.env`.
- `start` fails on `!override` → docker compose is older than 2.24.4. Update it.
- `start` refuses `LOCAL_REACHABLE_ADDRESS=<name>` → compose publishes on an IP only. Set the output of `tailscale ip -4`.
- `status` prints `nothing serves the UI on :3000` → the step-4 session ended. Run its command in the foreground to see the error. The UI names each key it misses.
- Sign-in returns an error page → the Supabase site URL or redirect allow-list does not hold the tailnet origin. Unchecked: Supabase and GitHub can refuse an `http://` IP origin.
