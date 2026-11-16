---
name: lean-review
description: "Reviews one change for bugs, security holes, real load, missing tests, speed and code that should not exist, reading the connected code and not only the diff. Lists findings in plain English and changes no code. Use when the user types /lean-review, says 'lean review' or 'is this over-engineered', or asks what a change can delete."
disable-model-invocation: true
argument-hint: "[<branch> | <PR> | <files>]"
---

# Lean review

Review a change like the senior developer who will be paged when it breaks.
Order of importance: correct, safe, holds under load, tested, fast, lean.
Lean still matters: every extra line must be read, tested and fixed later.

## Hard boundaries — never do these

- **Never change code.** This skill lists findings; the reader picks what to fix.
- **Never report a finding without a concrete case:** "this input or situation leads to this wrong result".
- **Never report style taste, a "consider" or a vague worry.**
- **Never propose layers, frameworks or config the problem does not need.**

## Phase 1 — Understand

- Review what the user names: uncommitted or staged changes, a branch, a PR link, or files.
  Nothing named: the uncommitted changes, or the last commit if there are none.
- Read the diff, then the code it touches: callers of every changed function, the functions it calls, the tests, the README.
- Trace the real flow: where data comes in, what is stored, what goes out.
- A change can break code it does not touch. When a signature, return value or behavior changes, grep every caller.
- Find the expected load in the repo (README, deploy config): one person running a script, or many users and processes at once.
  Judge scale against that, and say which load you assumed.

## Phase 2 — Look for

1. **Bug:** wrong result, crash, missed edge case (empty, zero, last item, rounding, time zones), a caller broken by the change, a fix applied in one caller while the shared function stays broken.
2. **Risk:** security holes (injection, weak randomness, secrets, missing checks on input from users), data loss (errors swallowed, writes in the wrong order, no transaction).
3. **Scale:** fine for one user, wrong for many: check-then-write races, the same work done by every process, memory or lists that only grow, a query per item, O(n^2) on big input, per-process state that must be shared.
4. **Missing test:** risky new logic (a branch, a parser, money, security, data writes, a bug fix) with no test that fails when it breaks. One good test, not coverage.
5. **Speed:** big slowdowns are problems. Small wins (work repeated in a hot loop) are suggestions.
6. **Lean:** code that should not exist or should be smaller.
   - delete: dead code, unused options, speculative features
   - reuse: the repo already has this helper (name the path)
   - stdlib / native: the standard library or platform already does it; a new dependency for a few lines
   - yagni: abstraction with one implementation, config nobody sets
   - merge: near-copies that must change together
   - split: one function doing several unrelated jobs. Split by job, never by line count, and never into helpers that exist only to make a function shorter.

## Phase 3 — Check before you report

- Re-read the lines and confirm: the caller exists, the value can really be empty, the code really is unused.
- A `shortcut:` comment that names its limit is a decision, not a finding, unless the expected load already crosses it.
- Propose the smallest fix that works. Prefer fixes that delete code.

## Phase 4 — Report

Use very simple English: short sentences, everyday words. Explain a technical term the first time you use it.
The reader may never have seen this code.

Start with `What this change does:` in two or three sentences.

Then the findings in three groups; skip empty groups:

- **Must fix:** bug, security, data loss, breaks at the expected load.
- **Should fix:** risky code without a test, real slowness, duplication, a function that mixes jobs, code that should not exist.
- **Nice to have:** small speed-ups, shorter forms.

Number findings across all groups, so the user can say "fix 2 and 5".
Every finding has all four parts, each one or two short sentences:

```
2. **Orders land on the wrong day** (`billing/close_day.py:L40-52`)
   - **What this is:** At midnight this job closes the day and bills all orders of that day.
   - **Problem:** It takes "today" from the server clock, which runs in UTC. An order placed
     at 00:30 in Berlin is billed on the day before.
   - **Fix:** Compute the day once in the shop's time zone:
     `datetime.now(ZoneInfo("Europe/Berlin")).date()`. One line, nothing else changes.
   - **If we skip it:** Late orders show the wrong date, and accounting fixes them by hand.
```

End with:

- `Verdict: Ship.` or `Verdict: fix 1 and 3 first.`
- `Lean: -<N> lines possible.` when lean findings exist.
- `Not checked:` one line, if something mattered and you could not check it.

Nothing found: `What this change does:`, then `Looks good. Ship.` and one line on what you checked.

Done when the verdict is out. Stop there; a fix is a separate request.

## License

Adapted from `ponytail-review` in [ponytail](https://github.com/DietrichGebert/ponytail) at `96608e0`.
MIT, `Copyright (c) 2026 DietrichGebert`: [`LICENSE`](LICENSE).
