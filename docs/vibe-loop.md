# Unattended loops

`vibe loop` runs a task without you sitting in front of it. It sets up a branch
and worktree exactly like `vibe start`, but instead of dropping you into an
interactive agent it runs a loop: each round invokes the agent headlessly
against a prompt, commits whatever changed, then checks whether the task is
done. On the server the whole loop lives in a tmux session, so it keeps going
after you disconnect — which is the entire point.

```bash
cd ~/git/myproject
vibe loop "port the config parser to the new schema" \
  --until 'npm test' --max 20
```

That creates the `port-the-config-parser-to-the-new-schema` branch and
worktree, seeds `LOOP.md`, and starts iterating: agent, commit, `npm test`.
When the tests pass it stops.

## The five ways it stops

Every loop is bounded. It ends the moment any of these is true:

| Stop         | Trigger                                                       |
| ------------ | ------------------------------------------------------------- |
| **success**  | the `--until` command exits `0`                               |
| **max**      | `--max` iterations have run (default 10)                      |
| **time up**  | the `--for` wall-clock budget is spent (unset by default)     |
| **stall**    | two rounds in a row produced no new commit and no diff        |
| **diverged** | with `--push`, the remote has moved under the branch — an unattended loop never merges or forces, so it stops for a human |

`--for` takes a short duration — `45s`, `90m`, `6h`, `2d` — and bounds an
overnight run by the clock rather than by a round count you have to guess:
`vibe loop "..." --for 8h`. It is checked after the round's push, so the last
iteration is never left unpushed, and the deadline is stored with the rest of
the loop state, so resuming a killed loop honours the original deadline instead
of restarting the clock. Give a loop both `--max` and `--for` and whichever
comes first ends it.

`--until` is optional; without it a loop runs until it maxes out or stalls.
Stall detection is what saves you from watching an agent spin uselessly: if it
stops making changes, the loop notices and quits rather than burning the full
`--max`.

The result of every run is a phone push (below), so you learn *how* it ended
without checking.

### Exit status (foreground)

When the loop runs in the foreground — locally, see
[where it runs](#where-it-runs) — its exit code is the outcome, so
`vibe loop … && next-step` can branch on it:

| Exit | Outcome                                    |
| ---- | ------------------------------------------ |
| `0`  | success — the `--until` check passed       |
| `2`  | stalled                                    |
| `3`  | maxed                                      |
| `4`  | time up                                    |
| `5`  | stopped — `--push` hit a diverged remote   |

`1` stays the ordinary failure exit — bad flags, a refused start — so "the
loop ran and did not pass" is distinguishable from "vibe refused to run it".
Note that a loop without `--until` has no way to end in success, so it always
exits non-zero; ignore the code if all you wanted was a bounded run. On the
server the loop is detached into tmux, where the runner's exit status has no
caller to read it — there the state file (`.vibe-loop.state` `STATUS`) and
the ntfy push carry the outcome.

## What each round does

1. Run the agent once, headless, handing it `LOOP.md` as the prompt — the same
   `VIBE_AGENT_CMD $VIBE_AGENT_HEADLESS_ARGS "<prompt>"` shape `vibe park` uses.
   The agent's own chatter goes to a log rather than the terminal (the loop
   prints its path at startup): `<git-dir>/vibe-agent.log`, inside the
   worktree's git dir, so it never dirties the tree or reaches a commit. On the
   terminal you get the spinner and the loop's own lines only — an agent
   writing straight to the tty would collide with the spinner, and a CLI agent
   that finds a tty also probes it for colours, whose replies the terminal
   echoes back as visible escape-sequence garbage.
2. Stage everything and commit it as `vibe loop: iteration N` — but only if the
   round produced real work. A round that changed nothing but the loop's own
   log is not progress and makes no commit.
3. With `--push`, push that commit, using the same divergence guard as
   `vibe sync`: never a force-push, and it stops the loop if the remote moved
   in a way a human has to resolve.
4. Run `--until`. Exit `0` and the loop is done.

Because every round commits, `vibe status` and the `vibe done` guard see the
work like any other branch — nothing is stranded in an uncommitted state.

## Ending in a pull request: `--pr`

`--pr` makes the loop open its own PR once it stops, so an overnight run is
waiting as something reviewable rather than as a branch you have to remember
to look at. It implies `--push`.

What it does when the loop ends:

- **Drops `LOOP.md` and `HANDOFF.md` from the branch** as their own commit,
  archiving the brief in the worktree's git dir first. Both are start-of-task
  input, not deliverable; left on the branch they land in the PR diff and stray
  onto the default branch on merge — the same leak `vibe done` refuses to let
  through. A resumed loop is re-seeded from that archive, so the exact brief it
  was running comes back rather than a fresh render of the raw task string.
- **Titles the PR from the newest commit the agent wrote itself**, skipping the
  loop's own `vibe loop:` bookkeeping subjects, bounded at the loop's start
  commit.
- **Opens a draft unless the stop check passed.** `maxed`, `timeup` and
  `stalled` all produce a draft whose body says which one it was, so unfinished
  work stays visible without ever looking like a merge candidate.
- **Never fails the run.** No `gh`, no auth, a diverged remote, a rejected
  `gh pr create` — each warns and leaves the branch pushed for you to open by
  hand. An already-open PR for the branch is left alone, so resuming a loop
  never opens a second one.

The body is rendered from [`templates/LOOP_PR.md`](../templates/LOOP_PR.md):
the goal, how the run ended, the round count, the stop check as it was actually
measured, and a note to the reviewer that no human saw the intermediate states.

## The prompt: `LOOP.md`

The agent's brief for every round is `LOOP.md` in the worktree, rendered from
[`templates/LOOP.md`](../templates/LOOP.md) on the first run. It carries the
goal, the done-criteria, the constraints, and an iteration log the loop appends
to. Keep the goal and done-criteria precise — they are the only instructions
the agent gets each round, with no one there to clarify.

Substitute your own with `--prompt <file>`; it is rendered through the same
placeholder contract, so `<branch>`, `<goal>` and the rest still fill in.

The better way to author a brief is the `loop-brief` skill
([`skills/loop-brief/`](../skills/loop-brief/)): it refines a rough idea
interactively, stages the finished `LOOP.md` on the task branch, and pushes.
Since `vibe loop` never overwrites an existing `LOOP.md` — and, when the
branch exists only on origin, creates the worktree tracking it — a brief
pushed from one machine is exactly what the loop runs on the other.

## Resuming

The loop's source of truth is git history plus a small state file
(`.vibe-loop.state`) in the worktree — iteration count, last result,
timestamps. That file is **gitignored, never committed**: it is machine-local
runtime state (it even holds the runner's PID), not part of the branch's work.
The deliverable travels in the commits; the state file only tracks where the
loop is.

So if the runner is killed mid-round — you close the session, the box reboots —
just run the same command again:

```bash
vibe loop "port the config parser to the new schema"
```

It reads the state file and git history and picks up from the next iteration.
It does not start over. Re-running while a loop is genuinely still live is
refused, so you cannot accidentally run two.

## Permissions and blast radius

A headless agent cannot answer a permission prompt — there is no one to answer
it. By default `vibe loop` runs the agent with its own default permission
behaviour, which means a round can block on a prompt it cannot satisfy.
Starting a fresh loop this way prints a warning to say so, since the loop will
run — and stall, per the table above — rather than refuse to start.

To let a loop actually run unattended you can opt into a permissive mode:

```bash
vibe loop "..." --dangerously-allow-all
```

This appends `VIBE_LOOP_PERMISSIVE_ARGS` to the agent invocation — your agent's
"skip every permission prompt" flag. The name is blunt on purpose. **Understand
the blast radius before you use it:** the worktree is isolated from your other
checkouts, but the agent runs as *you*, with your `$HOME`, your credentials,
and your network. A permissive agent can touch anything your account can, not
just the files in the worktree. `--dangerously-allow-all` refuses to start
unless `VIBE_LOOP_PERMISSIVE_ARGS` is set, so it can never be a silent default.

### Bounding it: `--sandbox`

The answer to that blast radius is not to skip fewer prompts, it is to make the
prompts unnecessary by confining what a round can reach:

```bash
vibe loop "..." --sandbox --dangerously-allow-all
```

`--sandbox` appends `VIBE_LOOP_SANDBOX_ARGS` to the agent invocation — your
agent's "confine this run" flags, typically restricting filesystem writes to the
worktree and network access to an allowlist. It composes with
`--dangerously-allow-all` rather than replacing it: permissive says *don't ask*,
sandbox says *and you couldn't have done it anyway*. That pairing is the one to
reach for when you leave a loop running overnight, and the startup warning for a
fresh non-permissive loop recommends it.

Like its sibling it is **empty by default and names no agent** — every agent
spells its sandbox differently, so the value is yours to set — and `--sandbox`
refuses to start unless `VIBE_LOOP_SANDBOX_ARGS` is set, rather than silently
running unconfined. The choice is recorded in `.vibe-loop.state`, so a loop
resumed after a kill comes back sandboxed without your having to remember the
flag.

## Where it runs

- **Server** — the loop runs in a tmux session named like any other task, so it
  survives disconnect. `vibe attach <task>` drops you into it to watch;
  attaching never fast-forwards under a live loop (the loop owns the branch).
  `--no-attach` starts the session and returns instead of attaching — for
  starting a loop from a remote-controlled agent session (say, from the phone)
  or a script, where attaching would nest or hang the caller.
- **Local** — there is no persistent session to detach into, so the loop
  runs in the **foreground**. It does not silently fork into the background;
  you either watch it or start it on the server instead. `vibe loop` says so
  when it takes the foreground path.

## Finishing

`vibe done` refuses to remove a worktree while its loop is still running —
removing it out from under the runner would corrupt the loop. Stop it first, or
let `done` do it:

```bash
vibe done --stop "port the config parser to the new schema"
```

`--stop` kills the loop's session, marks the state stopped, then applies the
usual `done` guards (it still refuses to discard uncommitted or unpushed work
unless you add `--force`).

The brief gets the same end-of-task treatment as the handoff: a finished task
does not carry it into the PR. `done` refuses while `LOOP.md` is still on the
branch — delete it first (`git rm LOOP.md`, then `vibe sync`), or pass
`--keep-brief` to leave it in the branch history deliberately.

## Notifications

Loop endings reuse the same ntfy.sh mechanism as the
[phone notifications](notifications.md): set `VIBE_NTFY_TOPIC` and every loop
ending pushes to your phone — success, maxed, time-up, stalled, or stopped on a
diverged remote — high priority for the four that need your attention. With
`--pr`, the push carries the PR's URL. Unset, it is silent. See
[notifications.md](notifications.md) for the topic.

## Configuration

| Variable                     | Default | Purpose                                    |
| ---------------------------- | ------- | ------------------------------------------ |
| `VIBE_AGENT_HEADLESS_ARGS`   | `-p`    | Args that make the agent run one-shot      |
| `VIBE_LOOP_PERMISSIVE_ARGS`  | unset   | Args for `--dangerously-allow-all`         |
| `VIBE_LOOP_SANDBOX_ARGS`     | unset   | Args for `--sandbox`                       |

`VIBE_AGENT_HEADLESS_ARGS` is shared with `vibe park` — it is the flag set that
turns your agent into a one-shot, non-interactive run, with the prompt appended
as the final argument. It defaults to Claude Code's `-p`; point it at whatever
your agent uses if it is something else, or the loop will hang on the first
round waiting for an interactive prompt.
