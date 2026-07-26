# MCP servers

Model Context Protocol servers give an agent tools it does not otherwise have.
By mid-2026 there are more than eleven thousand public ones, which makes
"which should I install?" a harder question than "how do I install one?".

This file answers the first question and nothing else. It is **documentation,
not configuration**: nothing here is installed, and no tool in this repo writes
an MCP config.

## Why this is docs-only

User- and local-scoped servers live in `~/.claude.json`, a file Claude Code
writes to itself. That puts it in the same class as `settings.json`'s runtime
keys and for the same reason: a symlink or a merge would turn every server you
add interactively into a diff in this repo and push it to every other machine.
`CLAUDE.md` spells out the rule.

The plugin does not ship servers either, though it could — a plugin may carry
an `.mcp.json`. It deliberately does not, on the same grounds
`docs/plugin.md` gives for the permission baseline: a package deciding what
your agent can reach is a decision that belongs to you, not to whoever wrote
the package. That argument does not weaken because the package is this one.

Where a server genuinely belongs to a *project* rather than to you, the config
already has a home built for it: `.mcp.json` at the project root, project
scope, checked into that project's version control. That is a per-repo choice,
not a toolkit-wide one.

## The rule that matters more than the list

**Install three to five, and no more.** Every connected server's tool schemas
sit in the context window of every turn, whether or not the tools get used. A
dozen servers is not a more capable agent; it is a distracted one working with
less room to think.

The corollary is the actual curation test: *does this server do something
Claude Code cannot already do?* Most of the popular ones fail it, which is why
the "skip" list below is longer than the "install" list.

## Worth installing

Each of these earns its context because it reaches something no built-in tool
does.

### Browser control

| Server | Maintainer | Reach for it when |
| ------ | ---------- | ----------------- |
| [`chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp) | ChromeDevTools (Google) | You need the DevTools surface — performance traces, network waterfalls, console, memory — against a real Chrome |
| [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp) | Microsoft | You need to *drive* a page: fill forms, click through flows, assert what rendered |

```bash
claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest
claude mcp add --scope user playwright -- npx @playwright/mcp@latest
```

Pick one, not both, unless you are doing frontend work daily. They overlap
heavily, and the split is: DevTools for *why is this slow or broken*, Playwright
for *make the browser do this*. Playwright drives from the accessibility tree
rather than screenshots, which is why it stays cheap in tokens — no vision
model in the loop.

### GitHub — but read the caveat first

[`github/github-mcp-server`](https://github.com/github/github-mcp-server),
maintained by GitHub, remote at `https://api.githubcopilot.com/mcp/`, with a
local Docker image at `ghcr.io/github/github-mcp-server`.

```bash
claude mcp add --transport http --scope user github https://api.githubcopilot.com/mcp/
```

The caveat: **this repo's workflow already goes through the `gh` CLI**. The
settings baseline pre-allows eighteen read-only `gh` invocations — `gh pr
view`, `gh pr checks`, `gh run list` and the rest — and `vibe status`, the
`babysit-pr` skill and the PR flow are all built on them. That covers most of
what the server offers, through a tool the agent already has. Add the server
when you want GitHub reach *without* granting shell access — a read-only
reviewing context, say — and skip it otherwise.

If you do add it, use `--toolsets` to enable only the groups you need and
`--read-only` where the session has no business writing. A server that exposes
its whole surface by default is the version of this that costs you context for
tools you never call.

## Worth skipping, and why

The reference servers at
[`modelcontextprotocol/servers`](https://github.com/modelcontextprotocol/servers)
are the ones most guides open with. In Claude Code specifically, most of them
duplicate a built-in tool that is faster, cheaper and already permission-gated:

| Reference server | Skip because |
| ---------------- | ------------ |
| **Filesystem** | `Read`, `Write`, `Edit`, `Glob` and `Grep` already do this, under the permission rules in the settings baseline. The server bypasses none of that but adds schemas for all of it |
| **Git** | `Bash` with `git`. The baseline pre-allows thirty-four read-only `git` invocations, so the common case is not even a permission prompt |
| **Fetch** | `WebFetch` |
| **Time** | Genuinely small, genuinely useless — the date is in the session context |
| **Sequential Thinking** | Extended thinking is native and does not cost a round trip per thought |
| **Memory** | See below — this one is worth more than a table row |

**Memory deserves its own paragraph** because the overlap is conceptual, not
mechanical. Its knowledge-graph store is a different answer to the question
`memory/GLOBAL.md`, `HANDOFF.md`, `PROJECT_STATUS.md` and `PROJECT_ROADMAP.md`
already answer here — and those four answer it in *git*, where the other
machine sees the same state after a pull and every change is a readable diff.
A per-machine graph in a server's own store is invisible to the machine you
switch to, which is the exact failure the artifact architecture exists to
prevent. Running both means two memories that disagree.

Several servers people still reference — GitHub's original, GitLab, Google
Drive, Google Maps, PostgreSQL, Puppeteer, Redis, Sentry, Slack, SQLite — were
archived out of that repo to
[`servers-archived`](https://github.com/modelcontextprotocol/servers-archived).
Some have official replacements maintained by the vendor; some have nothing.
Check which before adopting one from an old blog post.

## Before you install anything

An MCP server is code that runs with your permissions and text that reaches
your agent as instructions. Both halves need the same scrutiny a third-party
skill gets. The `security-sweep` subagent's vetting mode is written for exactly
this — point it at the server's source before `claude mcp add`, not after.

Two specifics worth naming:

- **`npx -y <package>@latest` resolves at every launch.** Convenient, and it
  means an upstream compromise reaches you with no diff to review. Pin a
  version, or run the Docker image where one exists, for anything that touches
  credentials.
- **Remote servers see whatever you send them.** A hosted server handling repo
  content is a data-egress decision, not just a tooling one.

## A timing note

MCP `2026-07-28` lands two days after this file was written. It drops the
`initialize` handshake and `Mcp-Session-Id` for a stateless core, adds an
extensions framework, and puts Roots, Sampling and Logging into a twelve-month
deprecation window. See
[the release candidate post](https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/)
and `docs/sota/2026-W30.md`.

None of that changes the recommendations above — this file curates *servers*,
and the servers listed are maintained by parties who will track the spec. It
does mean any protocol detail you read in a guide older than this week is worth
re-checking.
