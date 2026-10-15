#!/usr/bin/env bash
# Shared companions: scripts/ci/select-rust-formatting-sources.sh
set -euo pipefail
ROOT="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/rust-source-selection-test.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Rust source selection test retained"' EXIT
mkdir "$fixture/source with spaces"
repo="$fixture/source with spaces"
git init -q "$repo"
mkdir -p "$repo/crates/old/src" "$repo/apps/new/src"
printf 'root manifest\n' > "$repo/Cargo.toml"
printf 'old manifest\n' > "$repo/crates/old/Cargo.toml"
printf 'old source\n' > "$repo/crates/old/src/lib.rs"
printf 'ignored source\n' > "$repo/ignored.rs"
printf 'ignored.rs\n' > "$repo/.gitignore"
git -C "$repo" add Cargo.toml crates .gitignore
rm "$repo/crates/old/src/lib.rs"
printf 'new manifest\n' > "$repo/apps/new/Cargo.toml"
printf 'new source\n' > "$repo/apps/new/src/main.rs"
printf 'newline source\n' > "$repo/apps/new/src/line"$'\n'"break.rs"
printf 'unrelated\n' > "$repo/report.txt"
cp "$repo/.git/index" "$fixture/index-before"
bash "$ROOT/scripts/ci/select-rust-formatting-sources.sh" "$repo" > "$fixture/actual"
printf '%s\0' apps/new/Cargo.toml apps/new/src/line$'\n'break.rs apps/new/src/main.rs \
    Cargo.toml crates/old/Cargo.toml crates/old/src/lib.rs > "$fixture/expected"
cmp "$fixture/expected" "$fixture/actual"
cmp "$fixture/index-before" "$repo/.git/index"
ln -s report.txt "$repo/bad.rs"
status=0
bash "$ROOT/scripts/ci/select-rust-formatting-sources.sh" "$repo" > "$fixture/symlink-output" 2> "$fixture/symlink-error" || status=$?
[[ "$status" == 2 && ! -s "$fixture/symlink-output" ]] || exit 1
rm "$repo/bad.rs"
mkdir "$repo/crates/old/src/lib.rs"
status=0
bash "$ROOT/scripts/ci/select-rust-formatting-sources.sh" "$repo" > "$fixture/directory-output" 2> "$fixture/directory-error" || status=$?
[[ "$status" == 2 && ! -s "$fixture/directory-output" ]] || exit 1
rmdir "$repo/crates/old/src/lib.rs"
mv "$repo/crates/old/src" "$fixture/saved-src"
mkdir "$fixture/outside"
printf 'outside source\n' > "$fixture/outside/lib.rs"
ln -s "$fixture/outside" "$repo/crates/old/src"
status=0
bash "$ROOT/scripts/ci/select-rust-formatting-sources.sh" "$repo" > "$fixture/escape-output" 2> "$fixture/escape-error" || status=$?
[[ "$status" == 2 && ! -s "$fixture/escape-output" ]] || exit 1
rm "$repo/crates/old/src"
mv "$fixture/saved-src" "$repo/crates/old/src"
mkdir "$fixture/bin"
cat > "$fixture/bin/git" <<'STUB'
#!/usr/bin/env bash
printf 'Cargo.toml\0plausible.rs\0'
exit 49
STUB
chmod +x "$fixture/bin/git"
status=0
PATH="$fixture/bin:$PATH" bash "$ROOT/scripts/ci/select-rust-formatting-sources.sh" "$repo" > "$fixture/git-output" 2> "$fixture/git-error" || status=$?
[[ "$status" == 49 && ! -s "$fixture/git-output" ]] || exit 1
cmp "$fixture/index-before" "$repo/.git/index"
fixture_complete=true
echo 'Rust formatting source discovery and failure preservation passed'
