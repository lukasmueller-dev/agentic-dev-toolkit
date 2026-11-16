# Handoff — agentic-dev-toolkit / hypothesisloop-bringup

> The baton. Present tense only: where the work stands *now* and what the
> next session should do. Overwrite it each session — never append. History
> lives in git and rationale in commit bodies, not here. Before the task
> ends, promote anything durable (project status, repo instructions, commit
> body) and delete this file from the branch: a finished task hands
> nothing off, and merged, a leftover baton strays onto the default branch.

- **Repo:** agentic-dev-toolkit
- **Branch:** `hypothesisloop-bringup`
- **Worktree:** /home/lukas-mueller/github/agentic-dev-toolkit/.claude/worktrees/hypothesisloop-bringup
- **Last updated:** 2026-11-16 · turing

## State

- No milestone of `SPEC.md` is done. No HypothesisLoop checkout exists on turing.
- On turing: docker compose v5.7.1, make, openssl, python3, tmux, tailscale (`100.107.104.64`) are present. Go, npm and podman are missing; Node is v18.19.1.
- The other workspaces are up: Kapso ran its test job; AutoResearch and AutoResearchClaw pass their checks (recipes: branch `docs/workspace-bringup`).

## Next action

Ask the user for the HypothesisLoop source (GitHub `owner/repo` or a local path), clone it at the commit of milestone 1, and read its `.env.example` and the `make dev` requirements.

## Blockers

- The repo source of HypothesisLoop is unknown: only the user can name it.

## Gotchas (unpromoted)

- The steps are interactive: give the user one step per reply.
- `docker` needs an unsandboxed Bash call in an agent session.
