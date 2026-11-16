---
# roadmap-cleanup in agentic-dev-toolkit. A key here overrides the catalogue; remove a key to keep its default.
# schedule: weekly | daily | monthly
# day: sun
# output: pr | report
# model: sonnet
# timeout: 1h
# after: review | (empty = no review)
# kind: code | gpu
---

- Skip `bats tests/` and the shell lint: the commit changes only markdown.
