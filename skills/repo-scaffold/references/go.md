# Go

## Detection markers

`go.mod`.

## Templates

- Gitignore: `templates/gitignore/go.gitignore`
- CI: `templates/ci/go.yml`

## Adapting the CI template

- **Toolchain version** — `go-version: stable` installs the latest stable Go
  and does **not** read `go.mod`; it ignores the `toolchain` directive
  (`toolchain` can upgrade at run time but never pins CI to an older
  release). To honour the repo's pin, use `go-version-file: go.mod` instead of
  `go-version: stable` — otherwise CI can run a newer Go than the repo targets
  and a build/vet divergence gets debugged as a code bug. Only hardcode an
  explicit version when the repo has no pin to read.
- **Vendoring** — if `vendor/` is committed, leave the gitignore's vendor
  line commented out and add `-mod=vendor` where the repo's docs require it.
  Also scope the Format step out of `vendor/`: `gofmt -l .` descends into it
  and flags third-party files the repo must not reformat. Run
  `gofmt -l $(go list -f '{{.Dir}}' ./...)` (which skips `vendor/`) instead.
- **golangci-lint** — substitute it for the `gofmt`/`go vet` steps only when
  the repo already carries a `.golangci.yml`; do not introduce the config
  as a side effect of scaffolding.
- **No packages yet** — `go vet ./...` and `go test ./...` pass on an empty
  module, so the template is safe to land before code exists.
