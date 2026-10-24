# claude/agents/

Empty on purpose: the global subagents were cut in the 2026-10 usage audit
(built-in `/code-review` and `/security-review` cover them).

To add one: drop `<name>.md` here, add an `agents` list entry for it in
`.claude-plugin/plugin.json` (the manifest takes files, not a directory), and
re-run `./install.sh` — `~/.claude/agents` is linked only once this directory
holds more than this README.
