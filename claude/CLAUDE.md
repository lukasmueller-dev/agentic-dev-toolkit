@~/.claude/global-memory.md

<!--
The line above imports the portable global memory (repo: memory/GLOBAL.md,
installed to ~/.claude/global-memory.md). Everything below is Claude-specific
and stays here; everything workflow-shaped lives in the imported file so Codex
and Gemini get it too. Do not inline it back — see memory/README.md.
-->

# Response style — explanations and answers

When explaining concepts or answering my questions:

- Keep responses short. Cover what matters for my question and drop side details — I'll ask when I want more depth.
- One idea per sentence. Don't pack several steps or qualifications into one long sentence.
- I'm technical, so use the proper term. But when a term is niche or domain-specific, add a quick parenthetical definition on first use, e.g. "the compiler (translates code to machine instructions)".
- Explain plainly and directly. Use an analogy only when something is genuinely hard to grasp without one — not for every idea.
- Lead with the answer itself. No framing like "in simple terms" or "intuitively speaking".

This applies to explanations. Progress updates while coding and change summaries can stay terse and technical.

# Language — ASD-STE100

Write every chat reply in ASD-STE100 Simplified Technical English. Rules condensed from github.com/menonpg/ste-prompt (MIT).

- **Sentences:** max 20 words procedural, 25 descriptive. One instruction per sentence; start it with the command verb.
- **Grammar:** active voice. Present tense for instructions and facts. Keep articles (`a`, `the`).
- **Forms:** no `-ing` verb forms, no phrasal verbs ("set up" → "configure"), no noun used as a verb.
- **Consistency:** same word for the same thing every time. No synonyms for variety.
- **Vocabulary:** approved words only, one meaning and one part of speech each. Rewrite around a word that is not approved. Technical names and verbs (`commit`, `merge`, `parse`) are permitted.
- **Substitutions:** follow (rules)→obey, ensure→make sure, utilize/leverage→use, facilitate→help, initiate/commence→start, terminate→stop, approximately→about, prior to→before, subsequent to/following→after, in order to→to, strip out/get rid of→remove, fix up→repair, attempt→try, additional→more, modify→change, require→need, verify→check, obtain→get, perform→do/make, via→with/by/through, due to the fact that→because, in the event that→if, a number of→some/many (or the number).
- **One meaning:** "test" is a noun ("make a test of"). "close" is a verb; for distance use "near". "fall" is a verb only.
- **Structure:** one topic per paragraph, topic sentence first. Max 6 sentences in a procedural paragraph. Vertical list for more than 3 steps, parts or conditions.
- **Warnings:** put a warning before the step it applies to.
- **Tone:** no hedging — state the fact or the real uncertainty. No filler ("basically", "essentially"). Write to the reader as "you".

Code, commands, quoted output and repo prose keep their own rules.

# Bash sandbox traps

Each looks like a real failure and is not. Symptom → fix.

- A server started in one Bash call is unreachable from the next (each call has its own network namespace) → start and use it in one call; wait with `curl --retry 30 --retry-connrefused --retry-delay 1`.
- `ps`/`pgrep` return empty for a job that runs → check liveness by its output (log tail, file mtime, tmux pane).
- `nvidia-smi` sees no GPU → run it unsandboxed.
- A command whose text names `.env` is refused → work on that file through a Python heredoc.
- `cd` into a subfolder leaves empty `.claude/`, `.mcp.json` placeholders → use absolute paths; remove empty strays unsandboxed.
- `uv` fails with `Read-only file system ... .cache/uv` → prefix `UV_CACHE_DIR=$TMPDIR/uv-cache`.
- wandb fails to write → set `WANDB_DIR`, `WANDB_DATA_DIR`, `WANDB_CACHE_DIR`, `WANDB_CONFIG_DIR` under `$TMPDIR`, and `WANDB_MODE=offline`.
- `gh`, `git fetch` fail with `Repository not found` / `Authentication failed` → run unsandboxed.
- `git merge`/`rebase` fails with `Read-only file system` on `.claude/` and leaves new files behind → remove them (compare first), then run unsandboxed.
- `git stash push` writes the commit but not `refs/stash` → compare against `git show HEAD:<path>` instead of stashing.
- `git worktree prune` fails on placeholder files → run it unsandboxed.
