# claude/hooks/

Executable scripts that Claude Code invokes. Installed as a symlinked
directory at `~/.claude/hooks`, and wired up by `../settings.json`.

| Script                    | Invoked as             | Does                                            |
| ------------------------- | ---------------------- | ----------------------------------------------- |
| `skill-lint-on-edit.sh`   | `PostToolUse(Write\|Edit)` hook | Lints just the skill an edit touched, feeds findings back |
| `session-start-handoff.sh`| `SessionStart` hook    | Injects `HANDOFF.md` as context on `startup`/`clear` |
| `session-end-handoff.sh`  | `SessionEnd` hook      | Warns when `HANDOFF.md` / `PROJECT_STATUS.md` are stale |
| `notify-ntfy.sh`          | `Notification` hook    | Pushes to my phone via ntfy.sh                  |
| `statusline.sh`           | `statusLine` command   | Renders `repo · branch · task`                  |

`statusline.sh` is not a hook event — Claude Code calls it through the
`statusLine` setting. It lives here because it is the same kind of artifact (an
executable this toolkit installs for Claude Code to run) and one symlinked
directory beats two.

## Rules for anything added here

These scripts run inside my editing session, so they follow stricter rules than
ordinary scripts:

1. **Never break the session.** Degrade to a no-op instead. Every script here
   exits 0 when a dependency (`jq`, `curl`, `git`) is missing rather than
   erroring. Test with `PATH= /bin/bash <script>`.
2. **Say nothing when there is nothing to say.** A hook that prints on every
   invocation becomes noise and then gets ignored. `session-end-handoff.sh`
   exits silently unless a file is genuinely stale.
3. **No personal values in the script.** Topics, hostnames, and paths come from
   the environment or `~/.config/vibe/config`. A missing value means no-op, not
   an error — the repo is shared between machines that have not all opted in.
4. **Be fast.** `statusline.sh` runs on every render; it uses bash parameter
   expansion instead of `basename`/`dirname` for that reason.

## Exit codes

`0` succeeds silently. `2` is a "blocking error": the script's **stderr** is
shown, and for events that cannot be blocked — `SessionEnd` and `Notification`
among them — execution simply continues. That is the documented way to surface
text to me from those events, and it is why `session-end-handoff.sh` writes its
reminder to stderr and exits 2 rather than printing to stdout. Any other exit
code is a non-blocking error and shows up as `<hook> hook error`.

Note the consequence: a `SessionEnd` hook is **observational**. It can tell me
the handoff is stale; it cannot make the agent go and fix it. Making the agent
act would need a `Stop` hook returning `decision: block` — but `Stop` fires
every time the agent finishes a response, which is far too often for this.

`SessionStart` is the asymmetric case: it *can* inject context, but not via
stdout text or exit codes — print a JSON object to stdout and exit 0:

```json
{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}
```

`additionalContext` is added to the session before the first prompt.
`session-start-handoff.sh` uses this to hand a fresh session `HANDOFF.md`
without me having to say "read HANDOFF.md" first.

## Adding a hook

Drop the script in, `chmod +x` it (the installer does this too), and add it to
the `hooks` block in `../settings.json`:

```json
"hooks": {
  "EventName": [
    { "hooks": [ { "type": "command", "command": "$HOME/.claude/hooks/your-script.sh", "timeout": 10 } ] }
  ]
}
```

Omit `matcher` to fire on every occurrence. `matcher` filters by tool name for
`PreToolUse`/`PostToolUse`, and by reason for `SessionEnd` (`clear`, `resume`,
`logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other`) and by
type for `Notification` (`permission_prompt`, `idle_prompt`, `agent_completed`,
…). `SessionStart` matchers filter by `source` (`startup`, `resume`, `clear`,
`compact`, `fork`) — `session-start-handoff.sh` omits the matcher and checks
`source` itself in-script instead, so the one script stays the single place
that decision is made. Events like `Stop` and `UserPromptSubmit` take no
matcher at all.

Paths use `$HOME` rather than `${CLAUDE_PROJECT_DIR}`: these are user-level
hooks that must resolve identically in every repo, and `CLAUDE_PROJECT_DIR`
points at whichever project is open.

Verify a hook's stdin contract before relying on a field — run it by hand:

```bash
echo '{"cwd":"'"$PWD"'","hook_event_name":"SessionEnd","reason":"other"}' \
  | ./session-end-handoff.sh; echo "exit=$?"
```
