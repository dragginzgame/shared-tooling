#!/usr/bin/env bash
# Shared companions: scripts/dev/shared-tooling.sh scripts/ci/prepare-script-fixture.sh scripts/ci/fixture-lifecycle.sh make/consumer.mk
set -euo pipefail
ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
mkdir -p "$ROOT/target/tmp"
fixture="$(mktemp -d "$ROOT/target/tmp/registry-update.XXXXXX")"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Registry update fixture retained"' EXIT
unset SHARED_TOOLING_DOWNLOAD_CACHE
export CARGO_HOME="$fixture/cargo-home" CARGO_NET_OFFLINE=true RUSTUP_AUTO_INSTALL=0
export REGISTRY_FIXTURE="$fixture"
real_make="$(command -v make)"
mkdir -p "$fixture/source" "$fixture/crates" "$fixture/vendor" "$fixture/bin"
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$fixture/source" scripts/dev/shared-tooling.sh make/consumer.mk
archive() {
    local version="$1" source="$fixture/input/toko-tooling-$1" digest
    mkdir -p "$source/src"
    cp -Rp "$fixture/source/." "$source/"
    printf '[package]\nname = "toko-tooling"\nversion = "%s"\nedition = "2024"\n[lib]\npath = "src/lib.rs"\n' "$version" > "$source/Cargo.toml"
    printf '#![no_std]\n' > "$source/src/lib.rs"
    printf '# payload %s\n' "$version" > "$source/sample.sh"
    if [[ "$version" == 0.33.0 ]]; then
        printf '# Shared companions: retired.txt\n' >> "$source/sample.sh"
        printf 'owned old file\n' > "$source/retired.txt"
    fi
    tar -czf "$fixture/crates/$version.crate" -C "$fixture/input" "toko-tooling-$version"
    digest="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$fixture/crates/$version.crate")"
    printf '%s\n' "$digest" > "$fixture/crates/$version.sha256"
    perl "$ROOT/scripts/distribution/registry-package.pl" extract "$fixture/crates/$version.crate" "$digest" "$version" "$fixture/vendor/toko-tooling-$version"
    jq '{files: (.files | map_values(.checksum)), package: .checksum}' \
        "$fixture/vendor/toko-tooling-$version/.toko-tooling.files.json" > "$fixture/vendor/toko-tooling-$version/.cargo-checksum.json"
    rm "$fixture/vendor/toko-tooling-$version/.toko-tooling.files.json"
}
export PATH="$ROOT/.tools/host/bin:$PATH"
archive 0.33.0
archive 0.33.1
mv "$fixture/vendor/toko-tooling-0.33.1" "$fixture/newer-vendor"
cat > "$fixture/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
output='' url=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) output="$2"; shift 2 ;;
        https://static.crates.io/crates/toko-tooling/toko-tooling-*.crate) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ -n "$output" && -n "$url" ]]
version="${url##*/toko-tooling-}"; version="${version%.crate}"
printf '%s\n' "$url" >> "$REGISTRY_FIXTURE/downloads"
cp "$REGISTRY_FIXTURE/crates/$version.crate" "$output"
[[ "${CORRUPT_DOWNLOAD:-0}" == 0 ]] || printf corrupt >> "$output"
CURL
cat > "$fixture/bin/make" <<'MAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$REGISTRY_FIXTURE/setup"
[[ "${SETUP_FAIL:-0}" == 0 ]]
MAKE
chmod +x "$fixture/bin/curl" "$fixture/bin/make"
export PATH="$fixture/bin:$PATH"
consumer="$fixture/consumer with spaces"
mkdir -p "$consumer/src" "$consumer/.cargo"
git init -q "$consumer"
printf '#![no_std]\n' > "$consumer/src/lib.rs"
printf '[package]\nname = "consumer"\nversion = "0.1.0"\nedition = "2024"\n[dev-dependencies]\ntoko-tooling = "0.33"\n' > "$consumer/Cargo.toml"
printf '[source.crates-io]\nreplace-with = "fixture"\n[source.fixture]\ndirectory = "%s"\n' "$fixture/vendor" > "$consumer/.cargo/config.toml"
(cd "$consumer" && cargo generate-lockfile --offline) > "$fixture/cargo.log" 2>&1
run() { bash "$ROOT/scripts/dev/shared-tooling.sh" "$1" --consumer "$consumer" "${@:2}"; }
must_fail() { if "$@" > "$fixture/rejection.log" 2>&1; then echo 'registry fixture unexpectedly passed' >&2; exit 1; fi; }
cp "$consumer/Cargo.lock" "$fixture/original.lock"
CORRUPT_DOWNLOAD=1 must_fail run install --entrypoint sample.sh --entrypoint scripts/dev/shared-tooling.sh
[[ ! -e "$consumer/sample.sh" && ! -e "$consumer/.shared-tooling.snapshot" && ! -e "$fixture/setup" ]]
run install --entrypoint sample.sh --entrypoint scripts/dev/shared-tooling.sh > "$fixture/install.log"
cmp "$consumer/Cargo.lock" "$fixture/original.lock"
[[ -f "$consumer/retired.txt" && "$(wc -l < "$fixture/setup" | tr -d ' ')" == 2 ]]
run check > "$fixture/check.log"
downloads="$(wc -l < "$fixture/downloads")"
run status > "$fixture/status.log"
[[ "$(wc -l < "$fixture/downloads")" == "$downloads" ]]
printf 'local working edit\n' >> "$consumer/sample.sh"
must_fail run check
must_fail run install
grep -F 'local working edit' "$consumer/sample.sh" >/dev/null
cp "$fixture/input/toko-tooling-0.33.0/sample.sh" "$consumer/sample.sh"
git -C "$consumer" add sample.sh
mv "$fixture/newer-vendor" "$fixture/vendor/toko-tooling-0.33.1"
must_fail run update
[[ -f "$consumer/retired.txt" ]]
git -C "$consumer" reset -q -- sample.sh
run update > "$fixture/update.log"
grep -F '0.33.1' "$consumer/sample.sh" >/dev/null
[[ ! -e "$consumer/retired.txt" ]]
run check > "$fixture/new-check.log"
"$real_make" --no-print-directory -C "$consumer" -f "$ROOT/make/consumer.mk" shared-tooling-install \
    SHARED_TOOLING_ROOT="$ROOT" > "$fixture/make-install.log"
perl -pi -e 's/"0.33"/"=0.33.0"/' "$consumer/Cargo.toml"
run update --version 0.33.0 > "$fixture/downgrade.log"
[[ -f "$consumer/retired.txt" ]]
perl -pi -e 's/"=0.33.0"/"0.33"/' "$consumer/Cargo.toml"
SETUP_FAIL=1 must_fail run update
grep -F 'Snapshot installed, but tool setup/admission failed' "$fixture/rejection.log" >/dev/null
grep -F '0.33.1' "$consumer/sample.sh" >/dev/null
run check > "$fixture/setup-failure-check.log"
# Invalid selections and forged previous ownership never authorize replacement.
cp "$consumer/Cargo.lock" "$fixture/current.lock"
perl -pi -e 's{registry\+https://github.com/rust-lang/crates.io-index}{git+https://github.com/dragginzgame/toko-tooling#0123456789012345678901234567890123456789}' "$consumer/Cargo.lock"
must_fail run install
cp "$fixture/current.lock" "$consumer/Cargo.lock"
cp "$consumer/.shared-tooling.snapshot" "$fixture/receipt"
perl -pi -e 's/^(file\t)[0-9a-f]{64}(\t.\tsample.sh)$/${1}.("0" x 64).$2/e' "$consumer/.shared-tooling.snapshot"
perl -pi -e 's/"0.33"/"=0.33.0"/' "$consumer/Cargo.toml"
must_fail run update --version 0.33.0
cp "$fixture/receipt" "$consumer/.shared-tooling.snapshot"
# A Git receipt needs independently readable historical bytes exactly once.
old_source="$fixture/old-source"
cp -Rp "$fixture/input/toko-tooling-0.33.0" "$old_source"
printf '#!/bin/sh\necho "Legacy installer accepts Git selections only" >&2\nexit 1\n' > "$old_source/scripts/dev/shared-tooling.sh"
git -C "$old_source" init -q
git -C "$old_source" remote add origin https://github.com/dragginzgame/shared-tooling
git -C "$old_source" add .
git -C "$old_source" -c user.name=Fixture -c user.email=fixture@example.invalid -c core.hooksPath=/dev/null commit -qm initial
old_consumer="$fixture/old-consumer"
mkdir "$old_consumer"; git -C "$old_consumer" init -q
bash "$old_source/scripts/distribution/refresh-consumer.sh" --source "$old_source" --consumer "$old_consumer" \
    --entrypoint sample.sh --entrypoint scripts/dev/shared-tooling.sh > "$fixture/old-install.log"
cp "$consumer/Cargo.lock" "$old_consumer/Cargo.lock"
mkdir -p "$old_consumer/src" "$old_consumer/.cargo"
cp "$consumer/Cargo.toml" "$old_consumer/Cargo.toml"
cp "$consumer/src/lib.rs" "$old_consumer/src/lib.rs"
cp "$consumer/.cargo/config.toml" "$old_consumer/.cargo/config.toml"
must_fail bash "$old_consumer/scripts/dev/shared-tooling.sh" install --consumer "$old_consumer"
must_fail bash "$ROOT/scripts/dev/shared-tooling.sh" install --consumer "$old_consumer"
tooling_manifest="$(cd "$old_consumer" && cargo metadata --locked --offline --format-version 1 | jq -er '
    [.packages[] | select(.name == "toko-tooling" and .source == "registry+https://github.com/rust-lang/crates.io-index")] |
    if length == 1 then .[0].manifest_path else error("expected one registry selection") end')"
bash "${tooling_manifest%/Cargo.toml}/scripts/dev/shared-tooling.sh" install --consumer "$old_consumer" --source "$old_source" > "$fixture/migrate.log"
grep -F $'source\thttps://crates.io/crates/toko-tooling' "$old_consumer/.shared-tooling.snapshot" >/dev/null
echo 'Registry archive authentication, real Cargo lock/update, install, downgrade, retirement, local edits, setup failure and Git migration passed'
fixture_complete=true
