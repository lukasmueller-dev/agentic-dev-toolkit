# Rust

## Detection markers

`Cargo.toml` (a workspace root also counts — `[workspace]` with member
crates).

## Templates

- Gitignore: `templates/gitignore/rust.gitignore`
- CI: `templates/ci/rust.yml`

## Adapting the CI template

- **Library vs binary** — for a library, uncomment the `Cargo.lock` line in
  the gitignore; binaries and applications keep the lockfile committed.
- **Workspace** — the cargo commands already cover all members; add
  `--workspace` explicitly if the root crate is not the whole story.
- **clippy `-D warnings`** — on an existing repo with standing warnings this
  makes the first run red. Offer the choice: fix the warnings now, or drop
  `-D warnings` and tighten later. Do not silently pick one.
- **Long builds** — add `Swatinem/rust-cache` when compile time becomes the
  bottleneck; the template omits it to stay minimal.
