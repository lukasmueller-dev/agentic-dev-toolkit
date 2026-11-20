# vibe extensions

An extension is one executable that owns `vibe` commands and hears queue events.
The queue names no extension term. With no extension, `vibe` works, and an extension command prints one error line.

Status: `vibe` finds extensions, routes their commands, reads `readonly` and `help`, and sends every event but `status` and `report`.
`extensions/research/research` owns `vibe ws`, tool jobs, place runs and the research lifecycle: workers, the worker wake, a slurm answer, `stop --research` and `archive --research`.
Each line marked planned is the plan of the `extension-seam` milestones. This file maps every research site left in `bin/vibe` to one.

## Discovery

| Source | Form |
| ------ | ---- |
| `~/.config/vibe/extensions` (`$XDG_CONFIG_HOME/vibe/extensions`) | one path to an executable per line; `~/` expands; blank and `#` lines skip |
| the toolkit checkout | each `extensions/<name>/<name>` |

- The config lines come first. The first extension of a name wins, so a config line replaces a checkout extension of that name.
- A path that is no executable file prints a warning and is skipped.
- `vibe ext list` prints `<name><TAB><path>` per extension.

## Calls

| Call | When | Output |
| ---- | ---- | ------ |
| `<ext> describe` | each `vibe` call, and `vibe-web` for its routes | the describe lines below |
| `<ext> cmd <argv...>` | `vibe <argv...>` starts with a `command` line of the extension | its own; `vibe` execs it, so stdin, stdout and the exit status pass through |
| `<ext> event <name> <args...>` | the queue reaches the event | per event, below; stdin is empty |

`vibe` cuts `describe` after 10 s and an event after 60 s (`timeout -k 5`; 124: cut).
`start` has no cut, because a tool run lasts hours.
Slow work, such as a `ws tick` over ssh, forks and returns at once.

Environment of each call:

| Variable | Value |
| -------- | ----- |
| `VIBE_BIN` | the `vibe` executable: an extension calls the queue only through its commands |
| `VIBE_STATE` | the queue state root (`$XDG_STATE_HOME/vibe`); the queue is `$VIBE_STATE/queue/` |

The extension sources no toolkit file and calls no `vibe` function. It reads and writes the job files of the next sections.

## Describe lines

| Line | Effect |
| ---- | ------ |
| `command <word>...` | `vibe` runs the extension for argv that starts with the words; an argument `--x=v` matches the word `--x` |
| `readonly <word>...` | on a client, `vibe` forwards the command to the server over ssh |
| `branch <prefix>` | `branch_ok` takes `<prefix>/<slug>/<slug>` (planned) |
| `route <act> <argv...>` | a `vibe-web` POST route, in the form of its `ROUTES` table (planned) |
| `help <text>` | a line of `vibe --help`, before the `vibe job` lines; the text verbatim |
| `wip <file>` | `queue ready` refuses a PR that holds the file (planned) |

## Events

An event with no output and exit 0 changes nothing. `vibe` does not send a planned event yet.
Each extension hears each event. A non-zero exit warns with the extension name; the event status is the first non-zero exit.

| Event | Where | Output | Non-zero exit |
| ----- | ----- | ------ | ------------- |
| `pass` | `cmd_queue_run`, each pass before the scan | none | a warning; the runner goes on |
| `add <dir>` | `cmd_queue_add`, per dir before `queue_add`; it can change the dir | none | the add stops; stderr shows why |
| `prepare <job>` | `job_prepare`, before the worktree | `end <status> <note>`: the job ends so | the job ends failed |
| `start <job>` | `job_run`, before the agent session; no cut | `prompt <file>`: the session runs on it; `end <status> <note>`: no session | the job ends failed |
| `end <job>` | `job_run`, after a session with a `queued:` result | `run`: it took the session's run; `wait`: the job waits with no run; `end <status> <note>`: the job ends so | the job ends failed |
| `answer <job> <text>` | `cmd_queue_answer` first; `cmd_queue_retry` with a note, when the job has no `HANDOFF.md` and is no lane side job | `handled [<message>]`: vibe prints the message and does nothing more | the answer stops; no warning, the extension's stderr says why |
| `follow <from> <to> <kind>` | each follow-up job `vibe` makes: `follow_dir` (kind `answer`, `retry`, `fix`), `review_follow` (`review`), `cmd_queue_follow` (`gpu`, with `GPUQ_EXIT` and `GPUQ_LOG`) | `gpu`: `result <text>`, the Result line of the follow-up's prompt; it copies or drops its own files and keys in `<to>` | a warning |
| `steer <job> <text>` | `cmd_queue_steer`, when the job has no session FIFO | `steered <name>` | 3: not supported; else: failed |
| `holder` | `gpu_holder`, after the gpu-queue checks | the label of what holds the GPU | none |
| `card <holder>` | `queue_web`, once per page write; `<holder>`: what holds the GPU (`gpu_holder`), may be empty | lines below | the card is missing |
| `status` (planned) | `cmd_queue_status`, after the Features group | text lines | none |
| `report` (planned) | `queue_report_md`, after the Features table | markdown | none |

After `end`, the job takes status gpu with a `run` line, a `vibe queue gpu` run, or a `wait` line, in that order; else it fails.
At `follow`, `<to>` holds `job` and `prompt.md` (kind `gpu`: `job` only) and the runner cannot start it yet: it is no queue dir, or it waits for the end of `<from>`.

`card` prints these lines:

| Line | Effect |
| ---- | ------ |
| `dot` | the extension tab shows its lamp |
| `tab<TAB><html>` | a line of the extension tab (`<ext-tab>` in `queue-page.html`) |
| `chip<TAB><job id><TAB><text>` | the chip of the job's row (`page_row`) |
| `button<TAB><job id><TAB><html>` | a field or button in the job's block (`job_buttons`) |
| `<section><TAB><row>`, `blk<TAB><block>`, `style<TAB><css>` | the `page_row` printer form and page CSS (planned) |

A button sets `data-verb` for its progress text (planned).

The spec names stop, archive and retry as events. They need none:

- stop: `queue stop --research` is a passed command; a running tool job reads the `stop` file.
- archive: `queue archive --research` is a passed command; it archives with `vibe queue archive <id>...`.
- retry: a retry with a note sends `answer`, unless the note goes to `vibe queue answer`, which sends it.

## Job keys and files

The queue reads these keys generically. The extension writes them in the job file it makes or at `add`.

| Key | Queue effect | Replaces |
| --- | ------------ | -------- |
| `card=<ext>` (planned) | the job sits in the extension's card: not in its repo group, not in the counts or report rows while done with no PR | `research=` in `is_member`, `queue_counts`, `report_rows`, `triage_archive` |
| `publish=push` | the runner pushes the branch and opens no PR; `vibe queue worker` writes it | `hid=` in `job_publish` |
| `deadline=` | the hard stop of paid work: `queue gpu` (`deadline_gate`) and `gpu_submit` (`session_late`) stay in `vibe`; the extension's `queue worker` and `queue gpu --place` refuse past it themselves (`YYYY-MM-DD HH:MM` local time, `VIBE_AT` as now) | none |

Job-dir files the queue keeps: `stop`, `drain` (`now`: `queue gpu` asks for nothing), `gpu-cmd`, `gpu-job`, `cost`, `infra`, `slot`.
A job whose `slot` file holds `gpu` takes the one GPU slot: the next such job waits queued. The `research` extension writes it at `pass` and removes it when the tool run ends.
An extension owns the rest of its files (`run/`, `out/`, `tool.log`, `tool-exit`, `close.md`, `paste.md`, `slurm.log`, `workers`, `workers.log`, `fan`, `run-result`).
An extension queues a job with `vibe queue add <dir>` and ends a job in status `gpu` itself: `status` done, `note`, `ended`.

## Site map: bin/vibe

| Site | Does now | Goes to |
| ---- | -------- | ------- |
| header usage `queue ready`, `pr_check` | refuse a PR that holds `RESEARCH.md` | `wip RESEARCH.md` |
| `branch_ok` | takes `research/<slug>/<hid>` | `branch research` |
| `deadline_gate` | the deadline of `queue gpu`, `queue gpu --place` and `queue worker` | stays for `queue gpu`; the extension checks `deadline=` for its two commands (tests: `worker: refused past`, `gpu --place: past the job's deadline=`) |
| `cmd_queue_gpu` | the `drain=now` message names research | stays, generic text |
| `gpu_submit`, `session_late` | `deadline=` | stays |
| `queue_counts` | a done research job with no PR is not counted | `card=` |
| `queue_jobs` | the Research group | `card`, `status` |
| `research_cost`, `research_line` | the live box of a place run through `vibe ws box` | `card` |
| `research_row`, `RESEARCH_WORKERS` | the archived costs (the extension's `archived_costs`, inline), the default `workers=` | `card` |
| `status_line research` | terminal rows of a question | `status` |
| `status_card`, `page_row research` | the page Research card | `card` |
| `act_btn research-archive`, `st_tip` research tips | page buttons, state tips | `card` |
| `is_member`, `report_rows`, `triage_archive` | a research job sits in its question's card | `card=` |
| `queue_report_md` | `research_md` | `report` |

A comment that names research moves or changes with the code it describes.

## Site map: bin/vibe-web and the page

| Site | Does now | Goes to |
| ---- | -------- | ------- |
| `vibe-web` `ROUTES` | `research-archive`, `research-stop`, `research-stop-now`, `ws-start`, `ws-stop` | `route` |
| `vibe-web` `PARAMS` | `research`, `place` patterns | `route` (planned: a generic slug pattern) |
| `vibe-web` `FILES` | `tool.log`, `out/report.md`, `out/files` | stays: job files the page lists |
| `queue-page.html` | the Research card and Workspaces tab CSS, `<section id="workspaces">`, the Workspaces tab link | `card` (`style`, `tab`) |
| `queue-page.js` | `VERB` entries of the research and `ws` acts | `data-verb` on the `card` buttons |

## Function lists

Each list leaves `bin/vibe` in one milestone.
The `ws` functions, the place run (`place_queue place_pass run_alive place_run place_gate`) and the engine list are in `extensions/research/research` now.

Engine list (the research lifecycle):
`coordinator drain_copy slurm_waits place_take workers_take archived_costs run_result cmd_queue_worker has_baseline research_item fan_in worker_block`

Card list (research card, status, report):
`research_head research_mu research_workers research_paste research_card research_md research_slugs research_metric research_tree research_cost research_row has_run research_place research_look research_why research_progress research_line`
