# RunPod place

`workspaces/_places/runpod` runs a workspace on a rented RunPod pod, one pod per instance.
Script: [`workspaces/_places/runpod`](../../workspaces/_places/runpod). Contract: [`docs/workspaces.md`](../workspaces.md). Unchecked: no real pod has run it.

## Requirements

- `runpodctl` with the `pod` and `ssh info` commands, `jq`, `rsync`, `ssh` and `tailscale` on turing.
- `rsync` 3.4.0, or a distro build of 3.2.3 or newer with the fixes for CVE-2024-12084 to 12088 and CVE-2024-12747.
  `pull` copies from a pod that runs an untrusted tool, and its bound needs `--stop-after`.
- A RunPod account with prepaid credit and auto-pay off. The credit is the last money stop: RunPod has no spend limit per pod.
- A public tool image that holds `rsync`. Its entrypoint writes `$PUBLIC_KEY` to `/root/.ssh/authorized_keys` and starts `sshd`.
  `up` replaces the image CMD with `sleep infinity`, so a CMD that starts `sshd` never runs.

## 1. Install the CLI

```bash
mkdir -p ~/.local/bin
wget -qO ~/.local/bin/runpodctl https://github.com/runpod/runpodctl/releases/latest/download/runpodctl-linux-amd64
chmod +x ~/.local/bin/runpodctl && runpodctl version
runpodctl ssh --help | grep -w info      # one line; none means a runpodctl too old for the script
zcat /usr/share/doc/rsync/changelog.Debian.gz | grep -c CVE-2024-12088   # 1 or more; else rsync --version shows 3.4.0 or newer
rsync --help | grep -c -- --stop-after   # 1; 0 means an rsync older than 3.2.3
```

## 2. Add the keys

```bash
runpodctl doctor                          # asks for the API key, saves it in ~/.runpod/config.toml, adds an ssh key
runpodctl pod list --output json          # [] or your pods: the key works
```

RunPod gives a new pod the account's public keys as `PUBLIC_KEY`. A key added later does not reach a pod that runs.

## 3. Push the image

```bash
vibe ws build <name>
img="$(sed -n 's/^image=//p' workspaces/<name>/workspace.conf):$(sed -n 's/^commit=//p' workspaces/<name>/workspace.conf)"
docker push "$img"
```

Make the package public. A private image gives no ssh, so `up` waits `RUNPOD_WAIT` and deletes the pod.

## 4. Check the CLI output

Warning: this step rents a pod. It bills until the delete at the end of the step.

```bash
runpodctl gpu list                        # pick the cheapest id
out="$(runpodctl pod create --name ws-check --gpu-id '<id>' --image "$img" --container-disk-in-gb 20 \
  --ports 22/tcp --cloud-type SECURE --docker-args "sleep infinity" --output json)"
id="$(jq -r '.id // empty' <<<"$out")" && echo "id=$id"                        # not empty
runpodctl pod get "$id" --output json | jq -r .runtimeStatus                   # running, after some minutes
runpodctl ssh info "$id" --output json | jq '{ip, port, key: .ssh_key.path}'   # no null
runpodctl pod list --output json | jq --arg id "$id" 'type == "array" and any(.[]; .id == $id and .name == "ws-check")'   # true
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=accept-new -p <port> -i <key> root@<ip> rsync --version
runpodctl pod delete "$id"
runpodctl pod get "$id"                   # after a minute: an error that says not found
```

The script's field names come from the `runpodctl` source, not from a real run. Other output: stop, and change the script first.
Do this step again after each `runpodctl` update.

## 5. Configure the place

```bash
mkdir -p ~/.config/vibe/places
install -m 600 /dev/null ~/.config/vibe/places/runpod.env
echo 'RUNPOD_GPU_ID=<id from step 4>' >>~/.config/vibe/places/runpod.env   # no quotes
```

The header of `workspaces/_places/runpod` lists the other `RUNPOD_*` keys and their defaults.
`up` sends `~/.config/vibe/workspaces/<name>.env` to `/ws/secrets.env` over ssh stdin. Keep the API key out of that file.

## 6. Start

```bash
grep '^places=.*runpod' workspaces/<name>/workspace.conf   # one line: runpod is one of its places
vibe ws start <name> --place runpod --hours <n>            # a pod always has a limit; no --hours: the conf's hours
```

A queue job names `place=runpod` and `hours=<n>` instead. At the limit, `vibe ws tick` copies the data back and deletes the pod.

## 7. Verify

```bash
vibe ws status <name>                                 # up, runpod, the limit, http://<tailnet address>:<port>
runpodctl pod list --output json | jq -r '.[].name'   # ws-<name>
vibe ws stop <name>
runpodctl pod list --output json | jq -r '.[].name'   # no ws-<name>
ls ~/.local/state/vibe/workspaces/<name>              # data/ out/ pulled, and no id
```

Open the address on the phone. An ssh tunnel from turing to the pod carries the UI.

## What breaks it

- `pod <id> gives no ssh after <n>s` → the image is private, its entrypoint starts no `sshd`, or the pull takes longer than `RUNPOD_WAIT`. `up` deletes the pod first.
- `pod create printed no id`, or a `runpodctl` error from the create → no credit, no free GPU of that id, or a new output shape.
  `up` deletes a pod named `ws-<instance>` if one exists.
- `--gpu-id` gets quotes → the script reads `runpod.env` as `KEY=VALUE` lines and does not source it. Write the id with no quotes.
- `runpod.env: others can read it` → `chmod 600` it. `up` refuses the file; `tick` and `down` warn and still delete.
- `hours must be a whole number above 0 …` → the conf has no `hours`, or a queue job has no `hours=`. Set `hours=<n>` with no leading zero.
- `already up: pod <id>` → the `id` file names a pod. Run `vibe ws stop <name>` first.
- `no input: …/in/ is missing` → a `kind=run` needs `$WS_STATE/in/`. A queue job with `tool=<name>` and `place=runpod` writes it.
- `the pod list fails, so the id of pod ws-<instance> is unknown` → `runpodctl pod list` fails. The `id` file keeps `pending`, so the next `vibe ws tick` looks for the pod by name again.
- `pod <id> still exists; delete it with: …` → RunPod did not confirm the delete. The `id` file stays, so the next `vibe ws tick` tries again.
- `pull failed; deleting pod <id> anyway` → the image has no `rsync`, or the pod died. `data/` holds the last good `pull`, at most 10 min old.
- `stopping at requested limit` (rsync exit 30) or `pull ran past its bound of 300s` → a pull in `tick`, or in `down` past the limit, stops after 5 min.
  A cut file stays in `.rsync-partial/`, and the next pull resumes it. `pulled` keeps the time of the last full pull.
- `vibe ws stop` waits a long time → before the limit, `down` copies all of `/ws/data` with no time bound. `--timeout=60` ends only a dead link.
- The phone link is dead → turing lost the pod for more than 10 min, and the tunnel ended. The next `vibe ws tick` opens it again.
- `no tunnel` and `ControlPath too long` in `tunnel.log` → `$WS_STATE/tunnel.sock` is over 104 characters. Use a short instance name.
- A long `exec run` ends with ssh exit 255 and no result → turing lost the pod for more than 10 min, and ssh gave up.
  `vibe ws run` then calls `down`, which pulls `/ws/data` and deletes the pod. Start the run again.
