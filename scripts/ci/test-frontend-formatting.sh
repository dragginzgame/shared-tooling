#!/usr/bin/env bash
set -euo pipefail

# Explicit npm ci preparation is separate; this test only uses installed tools.
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
[[ "$(node --version)" == "v$(jq -er '.engines.node' "$ROOT/ci/frontend/package.json")" ]]
export PRETTIER_BIN="$ROOT/ci/frontend/node_modules/.bin/prettier"
export PRETTIER_VERSION
PRETTIER_VERSION="$(jq -er '.packages["node_modules/prettier"].version' "$ROOT/ci/frontend/package-lock.json")"
[[ "$("$PRETTIER_BIN" --version)" == "$PRETTIER_VERSION" ]]
# shellcheck source=/dev/null
source "$ROOT/ci/tool-versions.env"
bash "$ROOT/scripts/ci/check-format-tools.sh" "$SHARED_TOOLING_CARGO_SORT_VERSION"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/frontend-format-test.XXXXXX")"
fixture="$(cd "$fixture" && pwd -P)"
# Bash 3.2 can enter EXIT with status zero after nounset; require completion too.
fixture_complete=false
finish() {
    local status=$?
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf -- "$fixture"
    else echo "Frontend fixture retained: $fixture" >&2; fi
    exit "$status"
}
trap finish EXIT
mkdir "$fixture/templates" "$fixture/repo"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TEMPLATE_DIR="$fixture/templates"
objects="$(git -C "$ROOT" rev-parse --git-path objects)"
case "$objects" in /*) ;; *) objects="$ROOT/$objects" ;; esac
cd "$fixture/repo"
git init --quiet
mkdir -p .git/objects/info
printf '%s\n' "$objects" > .git/objects/info/alternates
git update-ref HEAD "$(git -C "$ROOT" rev-parse HEAD)"
git read-tree HEAD
git checkout-index --all
cp "$ROOT/.githooks/pre-commit" .githooks/pre-commit
cp "$ROOT/scripts/ci/check-make-execution.sh" scripts/ci/check-make-execution.sh
cp "$ROOT/scripts/dev/format-frontend.sh" scripts/dev/format-frontend.sh
# docs/ supplies existing tracked, unselected files without fixture commits.
cat > Makefile <<'MAKE'
.PHONY: fmt fmt-check
PRETTIER_VERSION = $(shell jq -er '.packages["node_modules/prettier"].version' package-lock.json)
fmt:
	cargo sort --workspace
	cargo fmt --all
	PRETTIER_VERSION="$(PRETTIER_VERSION)" bash scripts/dev/format-frontend.sh --write docs
fmt-check:
	cargo sort --workspace --check
	cargo fmt --all -- --check
	PRETTIER_VERSION="$(PRETTIER_VERSION)" bash scripts/dev/format-frontend.sh --check docs
MAKE
cat > Cargo.toml <<'CARGO'
[workspace]
members = ["crates/example"]
resolver = "2"
[workspace.package]
version = "0.0.0"
edition = "2021"
CARGO
mkdir -p crates/example/src
cat > crates/example/Cargo.toml <<'CARGO'
[package]
name = "frontend-hook-example"
version.workspace = true
edition.workspace = true
CARGO
printf 'pub fn example( ){}\n' > crates/example/src/lib.rs
cp "$ROOT/ci/frontend/"package*.json .
printf '{"semi": false, "singleQuote": true}\n' > .prettierrc.json
printf 'docs/generated.ts\n' > .prettierignore
selected=$'docs/selected [1]\nname.ts'
printf 'const value={text:"selected"};\n' > "$selected"
printf 'export const view=()=> <div title="example">hello</div>;\n' > docs/view.tsx
printf '{"ok":true,"items":[1,2]}\n' > docs/data.json
printf 'not valid TypeScript: {\n' > docs/generated.ts
cp docs/generated.ts "$fixture/ignored-before"
git add Makefile Cargo.toml crates package.json package-lock.json .prettierrc.json .prettierignore \
    scripts/ci/check-make-execution.sh scripts/dev/format-frontend.sh \
    "$selected" docs/view.tsx docs/data.json docs/generated.ts
cp package-lock.json "$fixture/lock-before"
# A closer untracked config must neither control snapshot formatting nor get staged.
printf '{"semi": true, "singleQuote": false}\n' > docs/.prettierrc.json
printf 'unselected working edit\n' > docs/ic-tools.md
cp docs/ic-tools.md "$fixture/unselected-before"
printf 'const untracked={leave:"alone"};\n' > docs/untracked.ts
cp docs/untracked.ts "$fixture/untracked-before"
bash .githooks/pre-commit > "$fixture/format.log" 2>&1
[[ "$(cat "$selected")" == "const value = { text: 'selected' }" ]]
[[ "$(git show ":$selected")" == "$(cat "$selected")" ]]
[[ "$(git show :crates/example/src/lib.rs)" == 'pub fn example() {}' ]]
[[ "$(git show :docs/ic-tools.md)" == "$(git show HEAD:docs/ic-tools.md)" ]]
cmp docs/ic-tools.md "$fixture/unselected-before"
cmp docs/untracked.ts "$fixture/untracked-before"
cmp docs/generated.ts "$fixture/ignored-before"
cmp package-lock.json "$fixture/lock-before"
[[ -z "$(git ls-files -- docs/.prettierrc.json docs/untracked.ts)" ]]
[[ "$(cat docs/.prettierrc.json)" == '{"semi": true, "singleQuote": false}' ]]
tree="$(git write-tree)"
bash .githooks/pre-commit >> "$fixture/format.log" 2>&1
[[ "$(git write-tree)" == "$tree" ]]

expect_failure() {
    if "$@" > "$fixture/refusal.log" 2>&1; then
        echo 'Real frontend formatter unexpectedly accepted a failing input' >&2; exit 1
    fi
}
# Formatting must fail atomically even if rustfmt already changed its snapshot.
printf 'pub fn example( ){}\n' > crates/example/src/lib.rs
printf 'const broken = {\n' > "$selected"
git add crates/example/src/lib.rs "$selected"
tree="$(git write-tree)"
cp "$selected" "$fixture/broken-before"
expect_failure bash .githooks/pre-commit
[[ "$(git write-tree)" == "$tree" && "$(cat crates/example/src/lib.rs)" == 'pub fn example( ){}' ]]
cmp "$selected" "$fixture/broken-before"
# Partial source and configuration selections refuse before any index refresh.
printf 'unstaged edit\n' >> "$selected"
cp "$selected" "$fixture/partial-before"
expect_failure bash .githooks/pre-commit
[[ "$(git write-tree)" == "$tree" ]]
cmp "$selected" "$fixture/partial-before"
cp "$fixture/broken-before" "$selected"
printf '{"semi": true}\n' > .prettierrc.json
expect_failure bash .githooks/pre-commit
[[ "$(git write-tree)" == "$tree" ]]
git show :.prettierrc.json > .prettierrc.json
# A successful real --check and a failed full-scope --check use the same adapter.
rm docs/.prettierrc.json
printf 'const value = 1\n' > "$selected"
git add "$selected"
bash .githooks/pre-commit >> "$fixture/format.log" 2>&1
# Limit the explicit scope to the selected TSX fixture for a clean check, then
# exercise full tracked scope with an unselected formatting error.
mkdir docs/checked
mv docs/view.tsx docs/checked/view.tsx
git add docs/view.tsx docs/checked/view.tsx
bash scripts/dev/format-frontend.sh --check docs/checked >> "$fixture/format.log" 2>&1
printf 'const value={text:"not formatted"};\n' > docs/checked/view.tsx
tree="$(git write-tree)"
cp docs/checked/view.tsx "$fixture/check-before"
expect_failure bash scripts/dev/format-frontend.sh --check docs/checked
[[ "$(git write-tree)" == "$tree" ]]
cmp docs/checked/view.tsx "$fixture/check-before"
cmp package-lock.json "$fixture/lock-before"
echo "Real Prettier $PRETTIER_VERSION and Rust hook preservation checks passed ($(node --version))"
fixture_complete=true
