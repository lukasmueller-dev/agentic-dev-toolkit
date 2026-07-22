# Node (including Next.js)

## Detection markers

`package.json`. It is a Next.js repo when `next` is in the dependencies or a
`next.config.*` exists — same templates either way; the gitignore already
carries the Next.js entries.

## Templates

- Gitignore: `templates/gitignore/node.gitignore`
- CI: `templates/ci/node.yml`

## Adapting the CI template

The template assumes npm with a lockfile. Match the repo's package manager —
the lockfile says which:

- **pnpm** (`pnpm-lock.yaml`) — add `pnpm/action-setup`, set
  `cache: pnpm`, replace `npm ci` with `pnpm install --frozen-lockfile` and
  `npm run X --if-present` with `pnpm run --if-present X`.
- **yarn** (`yarn.lock`) — `cache: yarn`, `yarn install --frozen-lockfile`,
  `yarn run`.
- **bun** (`bun.lock`, `bun.lockb`) — `oven-sh/setup-bun`, `bun install`,
  `bun run`.
- **No lockfile** — `npm install` instead of `npm ci`, and flag that the
  lockfile should be committed.

Keep the `--if-present` steps: they make the workflow valid before every
script exists. If the repo pins a Node version (`.nvmrc`, `engines`), use it
instead of `lts/*`.
