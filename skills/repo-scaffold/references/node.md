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
- **yarn** — `cache: yarn` and `yarn run`. The install command depends on the
  Yarn line: `yarn.lock` exists for both. Yarn 1 (classic) uses
  `yarn install --frozen-lockfile`; Yarn 2+ (Berry — a `.yarnrc.yml` or a
  `packageManager: "yarn@3…"` field in `package.json`) renamed it to
  `yarn install --immutable` and rejects `--frozen-lockfile`.
- **bun** (`bun.lock`, `bun.lockb`) — `oven-sh/setup-bun`, `bun install`,
  `bun run`.
- **No lockfile** — `npm install` instead of `npm ci`, **and drop the
  `cache: npm` line from `setup-node`**: with no `package-lock.json` that
  step fails before install runs (`Dependencies lock file is not found`).
  Flag that the lockfile should be committed.

Keep the `--if-present` steps: they make the workflow valid before every
script exists — but confirm at least one of `lint`/`typecheck`/`test`/`build`
actually resolves to a script, or the workflow reports green while running
nothing. If the repo's suite is under a differently-named script (`test:unit`,
`vitest`), point the `test` step at it. If the repo pins a Node version
(`.nvmrc`, `engines`), use it instead of `lts/*`.
