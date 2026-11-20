# vibe extensions

An extension is one executable that owns `vibe` commands and hears queue events.
The queue names no extension term. With no extension, `vibe` works, and an extension command prints one error line.

Status: `vibe` finds extensions, routes their commands and sends `pass`.
Each other event and describe line below is the plan of the `extension-seam` milestones; this file maps every research and `ws` site to one.

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
| `readonly <word>...` | on a client, `vibe` forwards the command to the server over ssh (planned) |
| `branch <prefix>` | `branch_ok` takes `<prefix>/<slug>/<slug>` (planned) |
| `route <act> <argv...>` | a `vibe-web` POST route, in the form of its `ROUTES` table (planned) |
| `help <text>` | a line of `vibe --help` (planned) |
| `wip <file>` | `queue ready` refuses a PR that holds the file (planned) |

## Events

An event with no output and exit 0 changes nothing. Only `pass` is wired now.
Each extension hears each event. A non-zero exit warns with the extension name; the event status is the first non-zero exit.

| Event | Where | Output | Non-zero exit |
| ----- | ----- | ------ | ------------- |
| `pass` | `cmd_queue_run`, each pass before the scan | none | a warning; the runner goes on |
| `add <dir>` | `cmd_queue_add`, per dir before `queue_add` | none | the add stops; stderr shows why |
| `prepare <job>` | `job_prepare`, before the worktree | `end <status> <note>`: the job ends so | the job ends failed |
| `start <job>` | `job_run`, before the agent session | `prompt <file>`: the session runs on it; `end <status> <note>`: no session | the job ends failed |
| `end <job>` | `job_run`, after a session with a `queued:` result | `wait`: status gpu; `end failed <note>` | the job ends failed |
| `answer <job> <text>` | `cmd_queue_answer` first; `cmd_queue_retry` with a note | `handled`: vibe does nothing more | the answer stops |
| `follow <from> <to>` | each follow-up job: `follow_job`, `follow_dir` (answer, retry), `cmd_queue_fix`, `cmd_queue_follow` | none; it copies or drops its own files and keys in `<to>` | a warning |
| `steer <job> <text>` | `cmd_queue_steer`, when the job has no session FIFO | `steered <name>` | 3: not supported; else: failed |
| `holder` | `gpu_holder`, after the gpu-queue checks | the label of what holds the GPU | none |
| `card [<job>]` | `queue_web`; with a job: `page_row` and `job_buttons` | page HTML, form below | the card is missing |
| `status` | `cmd_queue_status`, after the Features group | text lines | none |
| `report` | `queue_report_md`, after the Features table | markdown | none |

`card` with no job prints `<section><TAB><row>` and `blk<TAB><block>` lines (the `page_row` printer form), `tab<TAB><html>` (a page tab) and `style<TAB><css>`.
`card <job>` prints `chip<TAB><text>` and `button<TAB><html>`.
A button sets `data-verb` for its progress text.

The spec names stop, archive and retry as events. They need none:

- stop: `queue stop --research` is a passed command; a running tool job reads the `stop` file.
- archive: `queue archive --research` is a passed command.
- retry: a retry with a note sends `answer` first.

## Job keys and files

The queue reads these keys generically. The extension writes them in the job file it makes or at `add`.

| Key | Queue effect | Replaces |
| --- | ------------ | -------- |
| `card=<ext>` | the job sits in the extension's card: not in its repo group, not in the counts or report rows while done with no PR | `research=` in `is_member`, `queue_counts`, `report_rows`, `triage_archive` |
| `publish=push` | the runner pushes the branch and opens no PR | `hid=` in `job_publish` |
| `slot=gpu` | one running job with `slot=gpu` at a time; the next waits queued | `tool_gpu` in `cmd_queue_run` |
| `deadline=` | stays: the hard stop of `queue gpu` (`deadline_gate`, `session_late`) | none |

Job-dir files the queue keeps: `stop`, `drain` (`now`: `queue gpu` asks for nothing), `gpu-cmd`, `gpu-job`, `run-result`, `cost`, `infra`.
An extension owns the rest of its files (`run/`, `out/`, `tool.log`, `tool-exit`, `close.md`, `paste.md`, `slurm.log`, `workers`).

## Site map: bin/vibe

| Site | Does now | Goes to |
| ---- | -------- | ------- |
| header usage: `ws`, `queue worker`, `queue gpu --place`, `--research`; the Docs line | help lines | `help` |
| header usage `queue ready`, `pr_check` | refuse a PR that holds `RESEARCH.md` | `wip RESEARCH.md` |
| `role_gate` | `ws list`, `ws status` read-only on a client | `readonly` |
| main dispatch `ws)`, `cmd_ws` | the `ws` command | `command ws` |
| `branch_ok` | takes `research/<slug>/<hid>` | `branch research` |
| `coordinator` | research= with no hid= | engine |
| `deadline_gate` | the deadline of `queue gpu` and `queue worker` | stays (`deadline=`) |
| `cmd_queue_add` | the research block in a coordinator prompt | `add` |
| `job_prepare` | `tool_check`; a folder result sets `output=report` | `prepare` |
| `job_publish` | a worker (`hid=`) pushes and opens no PR | `publish=push` |
| `job_run` | `tool_job`, `close.md`, the agent copies of `in out tool.log tool-exit` | `start` |
| `job_run` | `queued:`: `workers_take`, `place_take`, a coordinator waits | `end` |
| `cmd_queue_run` | `ws_tick_bg`; `place_pass`, `fan_in` per job | `pass` |
| `cmd_queue_run` | `tool_gpu`: one GPU tool job at a time | `slot=gpu` |
| `cmd_queue_archive` | `--research <slug>` | `command queue archive --research` |
| `cmd_queue_stop` | `--research <slug> [--now]` | `command queue stop --research` |
| `cmd_queue_retry` | a waiting slurm worker goes to answer | `answer` |
| `cmd_queue_answer` | a slurm worker: `slurm.log`, `run_result`, session 2 | `answer` |
| `cmd_queue_answer` | copies `out/`, `tool-exit`, `tool.log`, `close.md` to the follow-up | `follow` |
| `cmd_queue_steer` | a tool job: its steer script | `steer` |
| `cmd_queue_fix` | drops `tool=` from the follow-up | `follow` |
| `cmd_queue_gpu` | `--place P`: `place_queue` | `command queue gpu --place` |
| `cmd_queue_gpu` | the `drain=now` message names research | stays, generic text |
| `follow_job`, `drain_copy` | drops `tool=`; copies `drain` | `follow` |
| `cmd_queue_follow` | research: cost 0, the no-RESULT text, the Result line | `follow` |
| `cmd_queue_worker`, `RESEARCH_WORKERS` | the worker command | `command queue worker` |
| `gpu_submit`, `session_late` | `deadline=` | stays |
| `queue_counts` | a done research job with no PR is not counted | `card=` |
| `queue_jobs` | the Research group | `card`, `status` |
| `status_line research` | terminal rows of a question | `status` |
| `status_card`, `page_row research` | the page Research card | `card` |
| `act_btn research-archive`, `st_tip` research tips | page buttons, state tips | `card` |
| `page_row` | the chip `<tool> · <place>` of a tool job | `card <job>` |
| `job_buttons` | the steer button of a tool job | `card <job>` |
| `queue_web` | `ws_page`, `<workspaces>`, `<wsdot>` | `card` (`tab`) |
| `queue_web` | the `WS_GH` variable (the GitHub URL of the toolkit) | stays, a generic name |
| `gpu_holder`, `gpu_busy` | a `ws` instance or a tool job holds the GPU | `holder` |
| `is_member`, `report_rows`, `triage_archive` | a research job sits in its question's card | `card=` |
| `queue_report_md` | `research_md` | `report` |
| `WS_ROOT`, `WS_STATES`, `WS_INST_RE` | the `ws` state | the ws list below |

A comment that names research or `ws` moves or changes with the code it describes.

## Site map: bin/vibe-web and the page

| Site | Does now | Goes to |
| ---- | -------- | ------- |
| `vibe-web` `ROUTES` | `research-archive`, `research-stop`, `research-stop-now`, `ws-start`, `ws-stop` | `route` |
| `vibe-web` `PARAMS` | `research`, `place` patterns | `route` (planned: a generic slug pattern) |
| `vibe-web` `FILES` | `tool.log`, `out/report.md`, `out/files` | stays: job files the page lists |
| `queue-page.html` | the Research card and Workspaces tab CSS, `<section id="workspaces">`, `<workspaces>` | `card` (`style`, `tab`) |
| `queue-page.js` | `VERB` entries of the research and `ws` acts | `data-verb` on the `card` buttons |

## Function lists

Each list leaves `bin/vibe` in one milestone.

ws list (`ws` and tool jobs):
`tool_inst tool_conf tool_place tool_hours tool_gpu tool_check tool_run copy_out tool_unsafe tool_job tool_up tool_steers ws_recipe ws_page ws_check cmd_ws_list ws_holder ws_gpu ws_stopper ws_state ws_inst ws_line ws_lines cmd_ws_status ws_dir ws_name ws_place ws_secrets ws_up ws_up_line cmd_ws_build cmd_ws_start cmd_ws_hold cmd_ws_run ws_stop_cuts cmd_ws_stop cmd_ws_down ws_down cmd_ws_tick ws_tick_bg cmd_ws`

Engine list (the research lifecycle):
`coordinator drain_copy slurm_waits place_take workers_take place_queue place_pass run_alive place_run place_gate archived_costs run_result cmd_queue_worker has_baseline research_item fan_in worker_block`

Card list (research card, status, report):
`research_head research_mu research_workers research_paste research_card research_md research_slugs research_metric research_tree research_cost research_row has_run research_place research_look research_why research_progress research_line`
