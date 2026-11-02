---
schedule: monthly
output: pr
model: sonnet
timeout: 1h
---

Check every `.bib` file (`git ls-files '*.bib'`, skip `vendor/`) against arXiv and doi.org.

- arXiv IDs: `eprint`, an `arxiv.org/abs/` URL, or `arXiv:` in `journal`/`note`. Strip the version, then query 50 IDs a call, 3 s apart:
  `curl -sS 'https://export.arxiv.org/api/query?id_list=<id>,<id>&max_results=50'`
- Each `<entry>` has the latest version in `<id>` (`…v7`), and `<arxiv:doi>` and `<arxiv:journal_ref>` once the paper is published. An ID with no `<entry>` does not exist.
- DOIs: each `doi` field, as `curl -sS -o /dev/null -w '%{http_code}' https://doi.org/api/handles/<doi>`. `404` is dead. Any other non-`200` (timeout, 429, 5xx) is "not checked". Never follow the redirect to the publisher.
- The sandbox denies `export.arxiv.org` or `doi.org`: stop. `result` is `blocked: sandbox denies <host>; add it to allowedDomains in claude/vibe-job-settings.json`.

Findings: one line each, `file:line key — what`. A dead DOI is `Needs you`.

- A dead DOI; an arXiv ID that does not exist.
- A `journal_ref` on arXiv while the entry still names arXiv as its venue: quote the `journal_ref`.
- A `doi` that differs from the one arXiv lists.
- The number of DOIs not checked.

May become a commit, one for all files:

- A version pinned in the entry (`v1` in `eprint` or the URL) older than the latest: set the latest.
- No `doi` in the entry, and arXiv lists one: add it.

Everything else is a finding. Never change an entry type, key, title, authors or year. Never remove an entry.
