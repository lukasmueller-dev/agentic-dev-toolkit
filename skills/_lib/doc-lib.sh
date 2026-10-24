# shellcheck shell=bash
#
# doc-lib.sh — seeds a document from templates/ into a target repo's docs dir; never overwrites.
# Callers source lib.sh first (die, render_template, TEMPLATE_DIR).

# docs_dir REPO — an existing doc/ or documentation/ wins; else docs/ is created.
docs_dir() {
  local repo="$1" d
  for d in docs doc documentation; do
    if [ -d "$repo/$d" ]; then
      echo "$repo/$d"
      return 0
    fi
  done
  mkdir -p "$repo/docs"
  echo "$repo/docs"
}

# seed_doc TEMPLATE DIR RELPATH [TOKEN VALUE]... — render TEMPLATE (relative to
# TEMPLATE_DIR) to <docs>/RELPATH in DIR's repo; prints created:/exists:.
seed_doc() {
  local tpl="$TEMPLATE_DIR/$1" dir="$2" rel="$3" root out commit
  shift 3
  [ -d "$dir" ] || die "not a directory: $dir"
  root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die "not inside a git repository: $dir"
  [ -f "$tpl" ] || die "template not found: $tpl"
  out="$(docs_dir "$root")/$rel"
  if [ -e "$out" ]; then
    echo "exists: $out"
    return 0
  fi
  # A dirty tree is recorded as such: a re-run diffs against this commit.
  commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  if [ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ]; then
    commit="$commit-dirty"
  fi
  mkdir -p "$(dirname "$out")"
  render_template "$tpl" \
    '<repo>' "$(basename "$root")" \
    '<date>' "$(date '+%Y-%m-%d')" \
    '<commit>' "$commit" "$@" >"$out"
  echo "created: $out"
}
