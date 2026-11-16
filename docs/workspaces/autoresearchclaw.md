# AutoResearchClaw workspace

AutoResearchClaw takes one topic through 23 stages, with real experiment runs, to a paper folder. Queue job, GPU, pinned to `be4ba47`.
Conf: [`workspaces/autoresearchclaw/workspace.conf`](../../workspaces/autoresearchclaw/workspace.conf). Contract: [`docs/workspaces.md`](../workspaces.md).

## Requirements

- Docker on the place; on turing the `gpu-queue` lock is free.
- `CLAUDE_CODE_OAUTH_TOKEN=<token>` in `~/.config/vibe/workspaces/autoresearchclaw.env`, mode 600. `claude setup-token` makes the token.
- Token risk: the agent (`acpx --approve-all`) and the experiment code run as root in one container. Both can read the token and `/ws/secrets.env`. Use a token you can revoke, and revoke it after the run.
- `in/brief.md` is the topic. `run` passes the whole file as the topic. There is no `in/args`.
- Not for: its RL prompt allows only small classic-control tasks. The image holds torch, scikit-learn, scipy, matplotlib and gymnasium.
- Cost: the agent runs on the subscription. The tool's cost limits are dead code, so `hours` is the only stop.

## 1. Build the image

```bash
vibe ws build autoresearchclaw
conf=workspaces/autoresearchclaw/workspace.conf
img="$(sed -n 's/^image=//p' "$conf"):$(sed -n 's/^commit=//p' "$conf")"
```

The image is unbuilt. The Dockerfile pins the base image, the npm packages and the direct pip packages. The apt packages and the tool's own Python dependencies resolve at build time.
Rented place: `docker push "$img"` and make the package public. Turing uses the local image.

## 2. Check the token

```bash
docker run --rm --env-file ~/.config/vibe/workspaces/autoresearchclaw.env "$img" acpx claude exec "say ok"
```

It prints a reply that holds `ok`. The tool calls the model through the same `acpx`. Stop here if it fails.

## 3. Queue the run

Queue a job on any repo (`/enqueue`, route Tool run) with `tool=autoresearchclaw`, `place=turing` and `hours=4`.
`in/brief.md` holds one line:

```text
Effect of L2 regularization strength on the test accuracy of a small MLP on the scikit-learn digits dataset
```

While the run goes, `vibe queue steer <job id> "<text>"` hands the text to the next stage.
Stages 8, 9 and 17 read it as guidance. Stages 9, 14, 16, 17 and 21 also quote it as context, 1000 characters at most.
A late text shapes the analysis and the paper, not the experiments that ran: check the paper against `code/`.
`vibe queue stop <job id>` ends the pipeline.

## 4. Verify

```bash
job=~/.local/state/vibe/queue/<job id>
cat "$job/out/result"    # done: paper in files/, <n> stages done, <n> failed, degraded=<bool>
ls "$job/out/files"      # paper_final.md  paper.tex  references.bib  code/  …
cat "$job/out/report.md" # stage counts and verified citations of the total
```

Exit 0 of the tool proves no paper: `run` reads `pipeline_summary.json` and checks `paper_final.md`.
The paper, its numbers and its citation counts are the tool's claim. Check them before use.

## What breaks it

- `failed: hour limit of <n> h reached after stage <s>` → the tool ran out of time. Queue a new job with more `hours`; it starts at stage 1.
- `failed: stopped after stage <s>` or `failed: killed after stage <s>` → `stop` or the limit ended the tool.
- `failed: no valid pipeline_summary.json …` → the tool died early. `tool.log` has the error. A bad token ends here too: repeat step 2.
- `failed: ended at stage <s> (<status>) …` → a stage failed. `files/` holds `deliverables/` only if the tool wrote it; the same holds after a stop or a kill.
- `done:` with `1 failed` → `--skip-noncritical-stage` skipped a stage. The paper exists. The tool exits 1 after any failed stage, so `run` reads the summary instead.
- `degraded=true` → a stage accepted a weaker result. Read `report.md` and the paper with care.
- `steer` prints `stage <n> does not read the text itself` → by design. The later stages among 9, 14, 16, 17 and 21 quote it as context. Stages 22 and 23 ignore it.
- `steer` exits 1 → no run folder yet, or all 23 stages are done.
- No PDF in `files/` → the image has no LaTeX. `paper.tex` and `paper_final.md` are there; compile elsewhere.
- Resume: `run` adds `--resume` when `checkpoint.json` exists. The queue removes an instance's state, `data/` included, when its job ends. A stop, the hour limit or a retry then starts at stage 1. Only a crash of the job process leaves the instance up, and its redo resumes.
- Counts after a resume → the tool counts only the stages of its own call. The result line says `(resumed run: counts cover the last part only)`.
- A checkpoint at stage 23 → `run` does not start the tool again. It gives the verdict and the copy only.
