#!/usr/bin/env bash
# Shared companions: scripts/ci/run-rust-formatting.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$root/scripts/ci/fixture-lifecycle.sh"
mkdir -p "$root/target/tmp"
fixture="$(fixture_create "$root/target/tmp/format-ownership.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Formatting ownership fixture retained"' EXIT
export CARGO_NET_OFFLINE=true RUSTUP_AUTO_INSTALL=0
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
real_cargo="$(command -v cargo)"
export real_cargo
mkdir -p "$fixture/consumer/src" "$fixture/sibling/src" "$fixture/consumer/extra/src"
for entry in consumer:owner sibling:dep consumer/extra:dep; do
    path=${entry%:*}; name=${entry##*:}
    printf '[package]\nname = "%s"\nversion = "0.1.0"\nedition = "2024"\n\n[workspace]\n' "$name" > "$fixture/$path/Cargo.toml"
    printf 'pub fn value( )->u8 { 1 }\n' > "$fixture/$path/src/lib.rs"
done
printf '\n[dependencies]\nalias = { package = "dep", path = "../sibling" }\n' >> "$fixture/consumer/Cargo.toml"
# Real metadata and rustfmt, with only manifest sorting substituted. The extra
# workspace deliberately shares a package name with the external dependency.
cat > "$fixture/cargo-wrapper" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == sort ]]; then echo 'sort fixture'; exit 0; fi
exec "$real_cargo" "$@"
WRAPPER
chmod +x "$fixture/cargo-wrapper"
for path in consumer sibling consumer/extra; do
    (cd "$fixture/$path" && cargo generate-lockfile --offline)
done
git -C "$fixture/sibling" init -q
git -C "$fixture/sibling" add .
cp "$fixture/sibling/.git/index" "$fixture/index"
cp "$fixture/sibling/Cargo.lock" "$fixture/lock"
cp -p "$fixture/sibling/src/lib.rs" "$fixture/sibling-source"
mode_before=$(perl -e 'printf "%o", (stat($ARGV[0]))[2]' "$fixture/sibling/src/lib.rs")
cd "$fixture/consumer"
driver="$root/scripts/ci/run-rust-formatting.pl"
run() { perl "$driver" "$@" --cargo "$fixture/cargo-wrapper" > "$fixture/output" 2>&1; }
if run --check --extra-workspace extra; then echo 'missed owned drift' >&2; exit 1; fi
run --write --extra-workspace extra
run --check --extra-workspace extra
grep -q '^pub fn value() -> u8 {' src/lib.rs
grep -q '^pub fn value() -> u8 {' extra/src/lib.rs
cmp "$fixture/sibling-source" "$fixture/sibling/src/lib.rs"
cmp "$fixture/index" "$fixture/sibling/.git/index"
cmp "$fixture/lock" "$fixture/sibling/Cargo.lock"
[[ $mode_before == "$(perl -e 'printf "%o", (stat($ARGV[0]))[2]' "$fixture/sibling/src/lib.rs")" ]]
# External source drift does not invalidate an owned-source receipt or fail
# checks, while a member edit does. Verify both with actual Cargo/rustfmt.
printf 'pub fn untouched( ){ }\n' >> "$fixture/sibling/src/lib.rs"
run --check --extra-workspace extra
grep -q 'unchanged' "$fixture/output"
printf 'pub fn changed( ){ }\n' >> src/lib.rs
if run --check --extra-workspace extra; then echo 'cached changed member' >&2; exit 1; fi
fixture_complete=true
echo 'Real Cargo formatting preserves sibling bytes, mode, index and lock; extra owners and cache scope passed'
