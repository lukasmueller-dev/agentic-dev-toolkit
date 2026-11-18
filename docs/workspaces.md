# Workspaces

One folder per outside research tool under `workspaces/`; `vibe ws` reads it.
A `kind=service` tool stays up with a link. A `kind=run` tool runs as a queue job.
The sections after Commands are the contract: tools and places obey them as written.

## Commands

```bash
vibe ws list                 # each tool: name, kind, gpu, places, label: role; a bad conf prints why and exits 1
vibe ws status [<instance>]  # each instance: state, place, limit, address; a failed detached start: its reason
vibe ws build <name>         # docker build -t <image>:<commit> --build-arg COMMIT=<commit> workspaces/<name>
vibe ws start <name> [--place P] [--hours N]  # a service: up at P (default: the first of its places) for N hours (default: its hours), then its start script and url
vibe ws stop <instance>      # its stop script, then down
vibe ws tick                 # each instance with an id: its place's tick; the runner runs it each pass
```

- `VIBE_WORKSPACES` overrides the folder; the default is `workspaces/` in the toolkit checkout.
- `list` flags a conf with no `kind` or `places`, a line that is not `key=value`, an unknown or doubled key, a value that breaks its row below, `result` on a service, or a run with no `result`. `hours` must be a whole number above 0.
- `status` reads the state files only and calls no place: `waits for the GPU` while a start waits for the lock, `starts` while a detached start runs, `stops` while a page stop runs, `down` with no `id` file, `past limit` when `limit` has passed, else `up`.
- `start` refuses a secret the env file does not set, an env file that others can read, a place not in `places`, and an `--hours` that is not a whole number above 0.
- `start` fails and brings the place down when the start script runs past 120 s.
- `stop` and a tick past the limit run the stop script for 300 s at most, then `down`.
- `start` on turing with `gpu=yes` runs `vibe ws hold` under `gpu-queue lock`, detached. It prints `waits for the GPU` when the lock stays busy for 3 s, else it waits for `up`. The lock stays held until `stop` or the limit removes the `id` file.
- `start` from the page (`VIBE_WEB=1`) detaches every start as `vibe ws hold` and returns after 3 s at most: `up`, `starts` or `waits for the GPU`.
- `stop` ends a detached start that waits for the GPU or runs the place's `up`: TERM, and the place's `up` removes what it made.
- `stop` refuses a start whose start script runs, and an instance that `stops`.
- `stop` from the page detaches the stop script and `down` as `vibe ws down`, returns `stops`, and the tick skips the instance meanwhile.
- The turing place publishes `ports` on the tailscale address only. `up` copies the kept `data/` back into `/ws/data`.
- The queue page's Workspaces tab has a card per service with Start, Stop and Open UI ↗: [Page](vibe-queue.md#3-page).
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

`workspaces/_places/<place> <verb>` with env `WS_INSTANCE`, `WS_STATE`, `WS_DIR`, `WS_NAME` and `WS_CONF_<KEY>` per conf key.
`WS_NAME` names the env file; empty, the place takes the folder name.

| Verb | Does |
| --- | --- |
| `up` | the container runs `sleep infinity` (turing: `docker create --init`, so PID 1 reaps killed processes) with `/ws/in`, `/ws/data` and the secrets file in place; a failed `up` leaves nothing behind |
| `exec <script> [arg…]` | runs `/ws/scripts/<script>`, passes stdout and the exit code |
| `price` | prints the USD per hour that an `up` costs now; turing exits 3 and costs 0 |
| `pull` | copies `/ws/data` and `/ws/out` into `$WS_STATE` |
| `url` | prints the address of the first port as the tailnet reaches it |
| `down` | `pull`, then destroy; destroys after a failed `pull` too |
| `tick` | called on each runner pass; `pull` when the last one is 10 min old or more, `down` when `limit` has passed |

## State on turing

- `~/.local/state/vibe/workspaces/<instance>/`: `place`, `id`, `started`, `limit` (epoch), `url`, `pulled` (epoch), `data/`, `out/`.
- A detached start adds `holder` (the pid of `vibe ws hold`), `hold.log`, and `waits` or `starts` while it waits or starts; `starts` holds `script` once the start script runs.
- A page stop adds `stops` (the pid of `vibe ws down`) and `stop.log`; a failed one keeps `stop.log`.
- Instance: `<name>` for a service, `<name>-<job id>` for a run, `research-<job id>` for a [research run](vibe-queue.md#research-jobs).
- A research run adds `dir`: its folder, the clone's `.claude/research/`. The place verbs use that folder, not one under `workspaces/`.
- It adds `name` too: `research-<repo folder>`, so each repo has its own env file.
- After `exec run` it adds `owner`, its job dir. Its run then stops, pulls and downs the instance; `vibe ws tick` skips it while that run's process lives.
- Secrets: `~/.config/vibe/workspaces/<name>.env`, mode 600, `KEY=VALUE`.

## Queue job

- Keys `tool=<name>`, `place=<place>`, `hours=<n>`.
- Input in the job dir as `in/brief.md` and `in/args`.
- The runner writes `out/` (the copy of `/ws/out`), `tool.log` and `tool-exit`.
