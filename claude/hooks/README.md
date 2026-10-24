# claude/hooks/

Executable scripts that Claude Code invokes. Installed as a symlinked
directory at `~/.claude/hooks`, and wired up by `../settings.json`.

| Script                    | Invoked as             | Does                                            |
| ------------------------- | ---------------------- | ----------------------------------------------- |
| `session-start-handoff.sh`| `SessionStart` hook    | Injects `HANDOFF.md` as context on `startup`/`clear` |
| `statusline.sh`           | `statusLine` command   | Renders `repo · branch · task`                  |
| `inject-global-memory.sh` | `SessionStart` hook, **plugin only** | Injects `memory/GLOBAL.md` where no `~/.claude/CLAUDE.md` exists |

`statusline.sh` is not a hook event — Claude Code calls it through the
`statusLine` setting. It lives here because it is the same kind of artifact (an
executable this toolkit installs for Claude Code to run) and one symlinked
directory beats two.

`inject-global-memory.sh` is wired by `../../.claude-plugin/hooks.json` and by
nothing in `settings.json`, so on a machine with the symlink install it is an
inert file sitting in `~/.claude/hooks`. It replaces the global memory file a
plugin cannot install; `tests/plugin.bats` asserts it stays out of the
baseline, and `docs/plugin.md` has the reasoning.

## Rules for anything added here

These scripts run inside my editing session, so they follow stricter rules than
ordinary scripts:

1. **Never break the session.** Degrade to a no-op instead. Every script here
   exits 0 when a dependency (`jq`, `git`) is missing rather than erroring.
   Test with `PATH= /bin/bash <script>`.
2. **Say nothing when there is nothing to say.** A hook that prints on every
   invocation becomes noise and then gets ignored.
3. **No personal values in the script.** Hostnames and paths come from the
   environment or `~/.config/vibe/config`. A missing value means no-op, not an
   error.
4. **Be fast.** `statusline.sh` runs on every render; it uses bash parameter
   expansion instead of `basename`/`dirname` for that reason.

## Exit codes

`0` succeeds silently. `2` is a "blocking error": the script's **stderr** is
shown, and for events that cannot be blocked execution simply continues. Any
other exit code is a non-blocking error and shows up as `<hook> hook error`.

`SessionStart` injects context not via stdout text or exit codes — print a JSON
object to stdout and exit 0:

```json
{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}
```

`additionalContext` is added to the session before the first prompt.
`session-start-handoff.sh` uses this to hand a fresh session `HANDOFF.md`
without me having to say "read HANDOFF.md" first.

## Adding a hook

Drop the script in, `chmod +x` it (the installer does this too), and add it to
the `hooks` block in `../settings.json` — and to `../../.claude-plugin/hooks.json`
with a `${CLAUDE_PLUGIN_ROOT}` path; `tests/plugin.bats` fails until both agree:

```json
"hooks": {
  "EventName": [
    { "hooks": [ { "type": "command", "command": "$HOME/.claude/hooks/your-script.sh", "timeout": 10 } ] }
  ]
}
```

Omit `matcher` to fire on every occurrence. `matcher` filters by tool name for
`PreToolUse`/`PostToolUse`. `SessionStart` matchers filter by `source`
(`startup`, `resume`, `clear`, `compact`, `fork`) — `session-start-handoff.sh`
omits the matcher and checks `source` itself in-script instead, so the one
script stays the single place that decision is made.

Paths use `$HOME` rather than `${CLAUDE_PROJECT_DIR}`: these are user-level
hooks that must resolve identically in every repo, and `CLAUDE_PROJECT_DIR`
points at whichever project is open.

Verify a hook's stdin contract before relying on a field — run it by hand:

```bash
echo '{"cwd":"'"$PWD"'","hook_event_name":"SessionStart","source":"startup"}' \
  | ./session-start-handoff.sh; echo "exit=$?"
```
