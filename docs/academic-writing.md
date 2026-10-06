# Academic writing skills

Vendored from github.com/JakobThumm (MIT) by `bin/plug`; see `plugins.conf`.

| Skill | Does |
| --- | --- |
| `proofread` | Checklist proofread of a paper; reads PDF annotations |
| `writing-simple-style` | Section-by-section plain-language style review |
| `writing-assistance` | Writing rules for drafting text (no frontmatter: loads by dir name) |
| `literature-review` | Systematic search across scholarly databases; citation check |

## Requirements

Nothing is installed by the toolkit. Install what a skill needs:

| Skill | Needs |
| --- | --- |
| `proofread` | `pip install 'pymupdf>=1.24'` (annotations); `pandoc` + LaTeX (`fontawesome5`, `mdframed`, `titlesec`) for the PDF report |
| `writing-simple-style` | Python 3.10+; `pandoc` + `pdflatex` (`fvextra`, `ulem`, `microtype`, `mdframed`); optional MCP server [`iso-obp`](https://github.com/JakobThumm/iso-obp-mcp) |
| `writing-assistance` | — |
| `literature-review` | `pip install requests`; `pandoc` + `xelatex`; network to arXiv, Semantic Scholar, IEEE, OpenReview, ACM, doi.org, crossref |

## Known risks (security-sweep, 2026-10-06)

- `proofread`, `writing-simple-style`, `literature-review` set `allowed-tools: Bash` → no prompt for any command while active; the sandbox still applies.
- `proofread`, `writing-simple-style` build a PDF unasked; pass `--no-pdf` (simple-style) or decline. proofread's build path names `proofreading/`, not `proofread/` → it fails.
- `writing-simple-style` writes paragraphs to a fixed `/tmp/paras.json`.
- `literature-review/scripts/verify_citations.py` on a non-`.md` input overwrites the input with JSON.
- literature-review sends search queries from your topic/abstract to the databases above.
- `editor-review` is **not vendored**: it runs `latexmk` (executes a project `.latexmkrc` as Perl) under pre-approved Bash and fans out ~16 full-tool agents over downloaded PDFs. Re-add after upstream fixes, with a fresh sweep.

## Zeroshot pipeline (not vendored)

`zeroshot-academic-writing` is a Zeroshot graph, not a skill. It embeds its own checklists and does not load the skills above.

```bash
npm install -g @the-open-engine-company/zeroshot
git clone https://github.com/JakobThumm/zeroshot-academic-writing ~/git/zeroshot-academic-writing
ZS=~/git/zeroshot-academic-writing
# in the paper repo: fill $ZS/plan-template.md, add % zeroshot:begin / % zeroshot:end to the .tex, copy input.example.json → input.json
zeroshot run --title "Write method section" --graph "$ZS/academic-writing.graph.json" \
  --input input.json --uniform-runtime-config "$ZS/runtime.claude.json" --validate-only
```

Drop `--validate-only` to run. Agents edit the target `.tex` in place: commit first. Full steps: the upstream README.
