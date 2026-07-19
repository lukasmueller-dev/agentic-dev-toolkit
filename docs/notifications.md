# Phone notifications via ntfy.sh

When an agent runs unattended in a tmux session on the VPS, the thing you
actually want to know is *"has it stopped and started waiting for me?"*
`claude/hooks/notify-ntfy.sh` answers that with a push to your phone.

It is wired to Claude Code's `Notification` hook, which fires when Claude Code
wants attention — a permission prompt, an idle prompt, a finished agent.

## Setup

### 1. Pick a topic

On the public ntfy.sh instance **the topic name is the only access control**.
Anyone who knows it can read your notifications *and* publish to them. So do not
pick `lukas-claude`. Generate a random one:

```bash
echo "claude-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 16)"
```

### 2. Subscribe on your phone

Install the ntfy app ([iOS](https://apps.apple.com/us/app/ntfy/id1625396347),
[Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy)),
then **Subscribe to topic** and enter the same string. No account needed.

### 3. Tell the toolkit the topic

Either an environment variable:

```bash
echo 'export VIBE_NTFY_TOPIC="claude-xxxxxxxxxxxxxxxx"' >> ~/.zshrc   # Mac
echo 'export VIBE_NTFY_TOPIC="claude-xxxxxxxxxxxxxxxx"' >> ~/.bashrc  # server
```

…or the vibe config file, which is the better choice on the server because it
does not depend on how the shell was started:

```bash
mkdir -p ~/.config/vibe
printf 'VIBE_NTFY_TOPIC=claude-xxxxxxxxxxxxxxxx\n' >> ~/.config/vibe/config
chmod 600 ~/.config/vibe/config
```

The environment variable wins if both are set. **With neither set the hook does
nothing at all** — that is deliberate, so the same repo installs cleanly on a
machine you have not set up for notifications.

### 4. Test it

```bash
echo '{"cwd":"'"$PWD"'","notification_type":"idle_prompt"}' \
  | ~/.claude/hooks/notify-ntfy.sh
```

Your phone should buzz with the repo and branch as the title. If nothing
arrives, work through:

```bash
echo "${VIBE_NTFY_TOPIC:-<unset>}"        # is the topic visible to this shell?
command -v curl jq                        # both present?
curl -fsS -d "test" "https://ntfy.sh/$VIBE_NTFY_TOPIC"   # does a raw push work?
```

Note that Claude Code only sees `VIBE_NTFY_TOPIC` if it was exported in the
shell that launched it. After editing `~/.zshrc`, restart Claude Code. This is
the usual cause of "it works from my terminal but not from the hook" — and the
reason the config file is more reliable.

## What gets sent

| Notification type                  | Priority | Tag                |
| ---------------------------------- | -------- | ------------------ |
| `permission_prompt`                | high     | 🔒 `lock`           |
| `idle_prompt`, `agent_needs_input` | high     | ⏳ `hourglass`      |
| `agent_completed`                  | default  | ✔️ `heavy_check_mark` |
| anything else                      | default  | 🤖 `robot`          |

Title is `repo · branch`, so several worktrees of the same repo stay
distinguishable. Body is the notification message plus its type.

## Keeping it quiet

To stop pushes without uninstalling anything, unset the topic — comment out the
line in `~/.config/vibe/config` or `unset VIBE_NTFY_TOPIC`. To disable the hook
entirely, remove the `Notification` block from `claude/settings.json`.

## Privacy

Messages transit ntfy.sh in the clear and include your repo and branch names.
If that matters, ntfy supports end-to-end-ish setups via a self-hosted server —
point the `curl` URL in `notify-ntfy.sh` at your own instance and add an
`Authorization: Bearer` header.

## The other way in: Claude Code Remote Control

Notifications tell you *that* a session needs you. To actually *drive* it from
your phone, type `/rc` in the running session, then open the Claude app → Code
tab and pick the session by name. The session stays on the VPS; the phone is
just a window into it. See [vibe.md](vibe.md).
