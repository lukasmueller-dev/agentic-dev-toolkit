# TypeScript / JavaScript rules

Check tool availability first (`npx <tool> --version` or check
`package.json` devDependencies). A missing tool is not an error: skip it,
note the gap in the report, and lean more on judgment for that category.

## Candidate-finding tools

- `npx eslint <scope>` — lint; `no-unused-vars`, `complexity` rule if
  configured.
- `npx tsc --noEmit` — type-check; record its clean/failing state in
  preflight and hold fixes to the same state.
- `npx ts-prune` — unused-export candidates. Verify each hit: dynamic
  `import()`, framework conventions (Next.js pages/routes, config files),
  and public package APIs all look "unused" but are not.
- `npx jscpd --pattern "**/*.{ts,tsx,js,jsx}"` — exact/near-exact clones.

## Semantic duplication pre-filter

Shortlist function/component pairs that share at least two of: similar
length (within ~30%), same parameter/props shape, overlapping identifier
sets. React components with near-identical JSX trees but different names
are prime candidates. Only the shortlist goes to judgment.

## Test discovery

Check `package.json` scripts (`test`, `test:*`) first — that is what the
team actually runs. Common frameworks: vitest, jest, playwright. Prefer
the CI config's invocation when it differs.

## Doc surfaces

- TSDoc/JSDoc vs. real signatures, props, and return types.
- README setup/usage vs. `package.json` scripts, engine ranges, and env
  variables actually read in code.
- CLAUDE.md commands and structure claims vs. the actual repo.
- Example `.env.example` / config files vs. the keys the code reads.

## Behavior-risk traps — report, never auto-fix

- Removing "unused" exports consumed by dynamic import, dependency
  injection, or framework file conventions.
- Barrel files (`index.ts`): reordering or pruning re-exports can change
  module evaluation order and side effects.
- Converting value imports to type-only imports (or vice versa) where it
  changes emitted JS or triggers `verbatimModuleSyntax` differences.
- Replacing `enum` with `const` objects or unions — changes runtime
  artifacts consumers may rely on.
- Tightening types on public APIs: a compile-time-only change for this
  repo can be a breaking change for downstream consumers.
