# SOTA digest

On demand, this repo surveys the state of the art in agentic development and
writes `docs/sota/<YYYY-Www>.md`: what moved, plus zero to three
recommendations formatted as roadmap items. Repo-local: the skill lives in
`.claude/skills/sota-digest/`, so `install.sh` never installs it elsewhere.

## Run it

```text
/sota-digest          # in a session at this repo's root
```

- Writes only the digest file; never edits the roadmap or status.
- The weekly `sota-digest` job (`docs/vibe-jobs.md`) commits it on
  `jobs/sota-digest` for a draft PR.
- An existing digest for the week is resumed, not overwritten.
- On demand: review the file, then commit it (e.g. `commit-push-pr`).

## Accept or reject a recommendation

- Accept: `add-roadmap-item` promotes it into `PROJECT_ROADMAP.md`.
- Reject: record why in the commit or PR; the next run reads recent digests and
  `PROJECT_STATUS.md` decisions, so a recorded rejection stays rejected.

## Tune it

| Change | File |
| --- | --- |
| Sources and search angles | `.claude/skills/sota-digest/references/sources.md` |
| Recommendation bar, digest structure | `.claude/skills/sota-digest/SKILL.md` |
