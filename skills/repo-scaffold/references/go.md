# Go

## Detection markers

`go.mod`.

## Templates

- Gitignore: `templates/gitignore/go.gitignore`
- CI: `templates/ci/go.yml`

## Adapting the CI template

- **Toolchain version** — `go-version: stable` respects the `toolchain`
  directive in `go.mod`; pin an explicit version only if the repo already
  does.
- **Vendoring** — if `vendor/` is committed, leave the gitignore's vendor
  line commented out and add `-mod=vendor` where the repo's docs require it.
- **golangci-lint** — substitute it for the `gofmt`/`go vet` steps only when
  the repo already carries a `.golangci.yml`; do not introduce the config
  as a side effect of scaffolding.
- **No packages yet** — `go vet ./...` and `go test ./...` pass on an empty
  module, so the template is safe to land before code exists.
