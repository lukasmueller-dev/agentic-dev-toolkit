# Workspaces

One folder per outside research tool under `workspaces/`; `vibe ws` reads it.
A `kind=service` tool stays up with a link. A `kind=run` tool runs as a queue job.
The sections after Commands are the contract: tools and places obey them as written.

## Commands

```bash
vibe ws list                 # each tool: name, kind, gpu, places, label: role; a bad conf prints why and exits 1
vibe ws status [<instance>]  # each instance: state, place, limit, address
vibe ws build <name>         # docker build -t <image>:<commit> --build-arg COMMIT=<commit> workspaces/<name>
vibe ws start <name>         # a service: up at the first of its places, then its start script and url
vibe ws stop <instance>      # its stop script, then down
vibe ws tick                 # each instance with an id: its place's tick; the runner runs it each pass
```

- `VIBE_WORKSPACES` overrides the folder; the default is `workspaces/` in the toolkit checkout.
- `list` flags a conf with no `kind` or `places`, a line that is not `key=value`, an unknown or doubled key, a value that breaks its row below, `result` on a service, or a run with no `result`. `hours` must be a whole number above 0.
- `status` reads the state files only and calls no place: `waits for the GPU` while a start waits for the lock, `down` with no `id` file, `past limit` when `limit` has passed, else `up`.
- `start` refuses a secret the env file does not set, and an env file that others can read.
- `start` fails and brings the place down when the start script runs past 120 s.
- `stop` and a tick past the limit run the stop script for 300 s at most, then `down`.
- `start` on turing with `gpu=yes` runs under `gpu-queue lock`, detached, and prints `up` or `waits for the GPU`. The lock stays held until `stop` or the limit removes the `id` file.
- The turing place publishes `ports` on the tailscale address only. `up` copies the kept `data/` back into `/ws/data`.
- The queue page lists the lines of `status` under `Tools`.
- A `kind=run` tool runs as a queue job: `/enqueue` route Tool run. Flow, stop and steer: [Tool jobs](vibe-queue.md#tool-jobs).

## Layout

- `workspaces/<name>/` holds `workspace.conf`, `Dockerfile` and the scripts.
- `workspaces/_places/<place>` is one script per place.
- `docs/workspaces/<name>.md` is the recipe.
- `tests/ws-<member>.bats` the tests.
- A name that starts with `_` is no workspace.

## `workspace.conf`

`key=value` lines, `#` comments.

| Key | Value |
| --- | --- |
| `label` | text |
| `role` | one line |
| `kind` | `service` or `run` |
| `runs` | `container` or `host` (default `container`) |
| `gpu` | `yes` or `no` |
| `places` | comma list of `turing`, `runpod`, `vast` |
| `hours` | default limit |
| `image` | image name |
| `commit` | 40 hex, the image tag |
| `secrets` | space list of env names |
| `ports` | comma list, the first is the UI |
| `result` | `branch` or `folder` (`kind=run` only) |

## In the container

| Path | Holds |
| --- | --- |
| `/ws/scripts` | the folder, read-only |
| `/ws/in` | read-only: `repo/` a git clone at one commit, `brief.md`, `args` as `key=value` |
| `/ws/data` | kept and copied back |
| `/ws/out` | a run's output |
| `/ws/secrets.env` | the secrets |

Env: `WS_NAME`, `WS_INSTANCE`, `WS_PLACE`, `WS_HOURS`.

## Script verbs

Bash; exit 0 ok, 3 verb not supported, other error.

| Verb | Does |
| --- | --- |
| `start` | returns in 120 s or less with the service detached |
| `stop` | ends the tool's work and keeps `/ws/data` |
| `status` | prints one line: `up\|down\|running\|done\|error — <text>` |
| `run` | blocks until done or `WS_HOURS` |
| `steer "<text>"` | hands the text to the tool for its next boundary |

## Run output

- `/ws/out/result` (one line, `done: …` or `failed: …`), `/ws/out/report.md`.
- `result=branch`: `repo.bundle`, `branch` (the ref name in it), `score` (the tool's claim).
- `result=folder`: `files/`.

## Place verbs

`workspaces/_places/<place> <verb>` with env `WS_INSTANCE`, `WS_STATE`, `WS_DIR` and `WS_CONF_<KEY>` per conf key.

| Verb | Does |
| --- | --- |
| `up` | the container runs `sleep infinity` with `/ws/in`, `/ws/data` and the secrets file in place; a failed `up` leaves nothing behind |
| `exec <script> [arg…]` | runs `/ws/scripts/<script>`, passes stdout and the exit code |
| `pull` | copies `/ws/data` and `/ws/out` into `$WS_STATE` |
| `url` | prints the address of the first port as the tailnet reaches it |
| `down` | `pull`, then destroy; destroys after a failed `pull` too |
| `tick` | called on each runner pass; `pull` when the last one is 10 min old or more, `down` when `limit` has passed |

## State on turing

- `~/.local/state/vibe/workspaces/<instance>/`: `place`, `id`, `started`, `limit` (epoch), `url`, `pulled` (epoch), `data/`, `out/`.
- Instance: `<name>` for a service, `<name>-<job id>` for a run.
- Secrets: `~/.config/vibe/workspaces/<name>.env`, mode 600, `KEY=VALUE`.

## Queue job

- Keys `tool=<name>`, `place=<place>`, `hours=<n>`.
- Input in the job dir as `in/brief.md` and `in/args`.
- The runner writes `out/` (the copy of `/ws/out`), `tool.log` and `tool-exit`.
