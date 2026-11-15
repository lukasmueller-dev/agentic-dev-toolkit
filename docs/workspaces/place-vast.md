# Vast.ai place

`workspaces/_places/vast` runs a workspace on a rented Vast.ai machine. It rents on-demand offers on datacenter hosts only.
Script: [`workspaces/_places/vast`](../../workspaces/_places/vast). Contract: [`docs/workspaces.md`](../workspaces.md). Unchecked: no real instance has run it.

## Requirements

- `vastai` 1.11.0 or newer, `jq`, `rsync` and `tailscale` on turing.
- `rsync` 3.4.0, or a distro build with the fixes for CVE-2024-12084 to 12088 and CVE-2024-12747. `pull` relies on `--safe-links`.
- A Vast.ai account with prepaid credit and no saved card. The credit is the last money stop: Vast has no spend limit per machine.
- A public tool image that holds `rsync`. The instance pulls it with no registry login, and the script copies over `rsync`.
- An ssh key pair that `ssh` uses with no `-i`, for example `~/.ssh/id_ed25519`. The script names no key file.

## 1. Install the CLI

```bash
uv tool install 'vastai>=1.11.0'
vastai --version
zcat /usr/share/doc/rsync/changelog.Debian.gz | grep -c CVE-2024-12088   # 1 or more; else rsync --version shows 3.4.0 or newer
```

The script passes `-y` to `destroy instance`. Without it, `vastai` asks, prints `Aborted.` and exits 0.

## 2. Add the keys

Warning: `vastai create ssh-key` with no argument offers to replace `~/.ssh/id_ed25519`. Always give it the public key.

```bash
vastai set api-key <key>
vastai create ssh-key "$(cat ~/.ssh/id_ed25519.pub)"
vastai show user                                      # Credit: the prepaid amount
```

Vast adds the account's ssh keys to each new instance. A key added later does not reach an instance that runs.

## 3. Push the image

```bash
vibe ws build <name>
img="$(sed -n 's/^image=//p' workspaces/<name>/workspace.conf):$(sed -n 's/^commit=//p' workspaces/<name>/workspace.conf)"
docker push "$img"
```

Make the package public. A private image never reaches `running`, so `up` waits `VAST_WAIT` and destroys the instance.

## 4. Choose the offers

```bash
vastai search offers 'num_gpus=1 cpu_arch=amd64 verified=true rentable=true datacenter=True' -o dph
printf '%s\n' 'VAST_QUERY=num_gpus=1 cpu_arch=amd64' 'VAST_DISK=50' 'VAST_WAIT=1200' >>~/.config/vibe/workspaces/<name>.env
```

These are the defaults. `up` adds `verified=true rentable=true datacenter=True` to `VAST_QUERY` and rents the cheapest offer by `dph`.
`VAST_DISK` is in GB; `VAST_WAIT` is the seconds to `running` and an ssh answer. The `VAST_*` keys stay on turing.

## 5. Start

```bash
grep '^places=vast' workspaces/<name>/workspace.conf   # a service starts at the first place in places
vibe ws start <name>
```

A queue job names `place=vast` and `hours=<n>` instead. At the limit, `vibe ws tick` copies the data back and destroys the instance.

## 6. Verify

```bash
vibe ws status <name>                      # up, vast, the limit, http://<tailnet address>:<port>
vastai show instances                      # one row, Label <name>
vibe ws stop <name>
vastai show instances                      # no row with Label <name>
ls ~/.local/state/vibe/workspaces/<name>   # data/ out/ pulled, and no id
```

Open the address on the phone. An ssh tunnel from turing to the instance carries the UI.

## What breaks it

- `an up runs for <instance>` → a killed `up` left `up.lock`. Find the label in `vastai show instances` and destroy a leaked row. Then `rmdir` the lock.
- `no offer for: …` or `create failed for offer …` → `vastai` exits 0 on an HTTP error. Run the same call without `--raw` and read the error, for example a bad API key or no credit.
- `no offer for: "num_gpus=…` → quotes in the env file reach the query. Write `VAST_QUERY=` with no quotes.
- `is not running after <n> s` → the image is private, `vastai show ssh-keys` lacks your key, or the image pull takes longer than `VAST_WAIT`. `up` destroys the instance first.
- `instance <id> is exited` (or `unknown`, `offline`) → the host failed. `up` destroys the instance; start again.
- `no ssh tunnel to port <port>` → a process on turing holds that port. Stop it and start again.
- `instance <id> is still alive` → Vast did not confirm the destroy. The `id` file stays, so the next `vibe ws tick` past the limit tries again. Check https://cloud.vast.ai/instances/.
- `pull failed before the destroy` → the image has no `rsync`, or the host died. `data/` holds the last good `pull`, at most 10 min old.
- A secret is missing in `/ws/secrets.env` → only the names in `secrets` of `workspace.conf` leave turing. Add the name there.
- A storage charge after a stop → a stopped instance still bills storage. Never `vastai stop instance`; `down` destroys it.
