---
name: implement-test-suite
description: "Stand up or extend a repository's automated test suite — the test code itself plus the infrastructure around it (test-runner config, fixtures, CI wiring). Works plan-first: analyzes the repo, proposes a test plan with per-repo policy choices, and implements only after the user approves the plan. Delivers on a separate branch as a PR whose description doubles as the report."
disable-model-invocation: true
argument-hint: "[scope path — default: whole repo]"
---

# Implement Test Suite

Set up a proper automated test suite for a repository, or extend an existing
one. This skill covers **test code** and **test infrastructure** (runner
config, shared fixtures, markers, CI workflow). It is the counterpart to the
codebase-healthiness skill: that skill checks code quality and defers
functionality to tests — this skill builds those tests.

**Hard boundaries — never do these as part of this skill:**

- Never change the behavior of production code. No testability refactors
  (introducing seams, dependency injection, splitting functions) — if code is
  hard to test without refactoring, test what is testable and **flag** the
  refactor need in the final report instead.
- No standalone coverage-report deliverable. Coverage numbers appear inside
  the plan and the PR report, not as a separate artifact.
- Never merge the PR yourself.

## Phase 0 — Detect

1. **Scope**: use the path given in `$ARGUMENTS`; if none, the whole repo.
2. **Language**: detect the primary language of the scope. Then read the
   matching reference file `references/<language>.md` for framework-specific
   guidance. Currently supported: `python`. If the language has no reference
   file, tell the user it is not yet supported by this skill and stop.
3. **Starting state** (auto-detect, both are supported):
   - *Greenfield*: no test suite exists.
   - *Existing suite*: detect the framework, test layout, naming conventions,
     registered markers, coverage setup, and CI workflow. Adopt and extend the
     repo's existing conventions — do not rewrite them to match this skill's
     defaults.
4. **Baseline**: if a suite exists, run it once and record the result
   (pass/fail counts, runtime, coverage if configured). Fix nothing yet.

## Phase 1 — Plan (no code changes)

Write a test plan and present it to the user. The plan must contain:

1. **Inventory** — what the scope contains, what is currently tested, what is
   not; the public API / entry points of the scope.
2. **Per-repo policy proposals** — these three are deliberately *not*
   hardcoded in this skill. Propose a sensible default for *this* repo with a
   one-line rationale each, and let the user confirm or override all three in
   a single interaction:
   - *Prioritization*: public API surface first / risk-based critical paths /
     coverage target across the scope.
   - *Coverage policy in CI*: hard gate (fail below threshold) / report only /
     ratchet (coverage may never drop).
   - *Pre-existing failing tests* (existing suites only): fix them as part of
     this run / quarantine and flag them / stop and report first.
3. **Test list** — per module: planned unit tests (mocked, fast) and
   integration tests (real dependencies, marked). Name the fixtures and fakes
   that will be shared. Propose property-based tests **only** where they
   clearly pay off (numeric/geometric invariants, round-trips) — they are
   opt-in via the plan, never a default.
4. **Infrastructure changes** — runner config, shared fixture layout, marker
   registration, CI workflow file(s).

**Wait for explicit approval.** Apply any overrides to the plan, then move on.
If the user rejects the plan, revise it; never start implementing without an
approved plan.

## Phase 2 — Implement (only after approval)

1. Create a branch: `test-suite/<scope-or-repo-name>`.
2. Infrastructure first (config, shared fixtures, markers, CI workflow), then
   tests, module by module in the plan's priority order.
3. **Layout**: the test tree mirrors the source tree
   (`src/pkg/module.py` → `tests/pkg/test_module.py`). Unit and integration
   tests are distinguished by **markers**, not by separate directories.
4. **Heavy dependencies** (simulators, GPU, network, large I/O) — hybrid
   strategy, always:
   - Unit tests mock or fake the heavy dependency and must run fast on any
     machine with no special hardware.
   - Integration tests use the real dependency and are marked `slow`, `gpu`,
     or `sim` as appropriate. Register every marker in the config.
   - CI runs the fast tier on every push/PR; the marked tiers run as the plan
     specifies (separate job, PR-to-main only, or nightly).
5. Run the suite continuously while implementing. Every test you add must
   pass before the work is done — except pre-existing failures handled per
   the approved policy (quarantined tests get a marker and a tracking note).
6. Respect the language reference file for all framework specifics
   (config format, fixture patterns, mocking approach, CI template).

## Phase 3 — Deliver

Push the branch and open a PR. **The PR description is the report** — there
is no separate report file. It must state:

- What was added/changed, grouped by module; baseline vs. resulting suite
  size and coverage.
- The three policies that were applied (as approved in the plan).
- Quarantined pre-existing failures, if any, with reasons.
- Testability problems that were flagged but deliberately not fixed
  (candidates for the codebase-healthiness skill).
- How to run each tier locally, and what CI runs when.

Stop after opening the PR. The user reviews and merges.

## Language support

Language-specific knowledge is pluggable. `SKILL.md` holds only the
language-agnostic workflow above; everything framework-specific lives in
`references/<language>.md`. To add a language, add a reference file — the
workflow does not change.

- `references/python.md` — pytest, fixtures, markers, mocking sim/GPU code,
  hypothesis guidance, coverage tooling, GitHub Actions template.
