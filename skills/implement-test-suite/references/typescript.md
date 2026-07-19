# TypeScript / JavaScript: Vitest specifics

Framework: **Vitest** for greenfield setups. Detect what the repo already uses
first — Jest, Mocha, AVA, or `node:test` — and extend that instead of migrating
it; a framework swap is a behavior change to the build, and belongs in the plan
as an explicit proposal, never as a side effect.

Detect the package manager before writing any command: `pnpm-lock.yaml`,
`yarn.lock`, `bun.lockb`, or `package-lock.json`. Use the repo's own
`package.json` scripts as the entry point rather than inventing new ones.

## Markers do not exist here — use projects

`SKILL.md` says unit and integration tests are separated by markers, not
directories. JavaScript test runners have no marker system, so the equivalent
is a **filename suffix plus a Vitest project**. Keep the tree mirroring the
source either way.

- `src/pkg/thing.ts` → `src/pkg/thing.test.ts` (unit, co-located) or
  `tests/pkg/thing.test.ts` (separate tree) — follow whichever the repo uses.
- Integration tests get a second suffix: `thing.integration.test.ts`.

## Config template (greenfield)

```ts
// vitest.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    projects: [
      {
        // fast tier: the default dev loop
        test: {
          name: "unit",
          include: ["**/*.test.ts"],
          exclude: ["**/*.integration.test.ts", "**/node_modules/**"],
          environment: "node",
        },
      },
      {
        test: {
          name: "integration",
          include: ["**/*.integration.test.ts"],
          environment: "node",
          testTimeout: 30_000,
        },
      },
    ],
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov"],
    },
  },
});
```

Tier commands (document these in the PR description):

- Fast tier: `vitest run --project unit`
- Full run: `vitest run`
- One tier: `vitest run --project integration`

Use `environment: "jsdom"` only for code that genuinely touches the DOM;
`node` is faster and catches accidental browser-API dependence.

## Type checking is a separate gate

Unlike Python, the type checker is a real test here and does not run as part
of the suite. Add `tsc --noEmit` as its own CI step and its own
`package.json` script. Vitest's `--typecheck` with `expectTypeOf` is worth
proposing only when the scope's public surface is the types themselves
(generic helpers, builder APIs).

## Determinism

- **Time**: `vi.useFakeTimers()` in a `beforeEach`, `vi.useRealTimers()` in
  `afterEach`; `vi.setSystemTime(new Date("2024-01-01"))` for anything that
  formats or compares dates. Never assert on `Date.now()` directly.
- **Randomness**: inject the RNG or stub it with
  `vi.spyOn(Math, "random").mockReturnValue(0.5)`. Seed any library RNG in a
  fixture rather than relying on production code to seed it.
- **Floats**: `expect(x).toBeCloseTo(y, precision)` — never `toBe` on a
  computed float.
- **Filesystem**: `await fs.mkdtemp(path.join(os.tmpdir(), "test-"))`, removed
  in `afterEach`. No test writes into the repo.
- **Concurrency**: Vitest runs files in parallel by default. Anything sharing
  a port, a database, or a fixed temp path needs
  `describe.sequential`/`test.sequential` or a per-worker resource.

## Mocking heavy dependencies

- `vi.mock("./module", factory)` is **hoisted above imports**, so it cannot
  close over variables declared later in the file. Use `vi.hoisted()` for
  shared mock state, or `vi.doMock` (not hoisted) when order matters.
- Mock the module the code under test imports, not the transitive dependency —
  patch where the name is *used*.
- Prefer a small hand-written fake over deep `vi.fn()` chains. For an SDK
  client, a plain object with the two methods actually called is clearer and
  fails better than a proxy that answers everything.
- `vi.spyOn(obj, "method")` for partial doubles; restore with
  `restoreMocks: true` in config so no test leaks into the next.
- The real-dependency version of the same behavior becomes the
  `.integration.test.ts` file. Guard it against a missing service with
  `describe.skipIf(!process.env.DATABASE_URL)` so a full local run degrades
  gracefully instead of failing.

## Property-based tests (fast-check)

Only when the approved plan proposes them. Good targets: serialization
round-trips (`parse(format(x)) === x`), invariants of sorting/merging helpers,
and idempotence of normalizers.

```ts
import fc from "fast-check";

test("round-trips", () => {
  fc.assert(
    fc.property(fc.record({ id: fc.uuid(), n: fc.integer() }), (v) => {
      expect(parse(format(v))).toEqual(v);
    }),
    { numRuns: 100 },
  );
});
```

Cap `numRuns` (50–200), and pin any discovered counterexample as a plain
`test` beside it so the regression is checked deterministically.

## Coverage

Tool: `@vitest/coverage-v8`. Implement whichever policy the plan approved:

- **Hard gate**: `coverage.thresholds` in `vitest.config.ts`
  (`{ lines: 80, functions: 80 }`), which fails the run below the value.
- **Report only**: `reporter: ["text", "lcov"]`, uploaded as a CI artifact.
- **Ratchet**: `coverage.thresholds.autoUpdate: true` writes the new floor back
  into the config as coverage rises — commit that change in the same PR.

Set `coverage.include` to the source globs. Left at its default, coverage is
computed only over files a test already imports, which flatters an incomplete
suite by ignoring untested modules entirely.

## GitHub Actions template

```yaml
name: tests
on: [push, pull_request]

jobs:
  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"
      - run: npm ci
      - run: npx tsc --noEmit
      - run: npx vitest run --project unit --coverage

  integration:
    # trigger per the approved plan: PRs to main only, nightly schedule, etc.
    if: github.base_ref == 'main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"
      - run: npm ci
      - run: npx vitest run --project integration
```

Swap `npm ci` for `pnpm install --frozen-lockfile` or `yarn install
--immutable` to match the detected package manager, and set `cache`
accordingly.

## Jest instead of Vitest

When the repo already uses Jest, the mapping is direct: `vi` → `jest`,
`projects` in `jest.config.js` for tiering, `testEnvironment` for `environment`,
and `coverageThreshold` for `coverage.thresholds`. Two differences worth
knowing: Jest needs `ts-jest` or Babel to handle TypeScript, and ESM support
still requires `--experimental-vm-modules`. Neither is a reason to migrate an
otherwise healthy suite.

## Existing suites

Everything above yields to conventions the repo already has: keep its runner,
config location, file-naming scheme, tiering mechanism, and CI structure, and
extend them. Only propose changing a convention in the plan, explicitly, with
a reason.
