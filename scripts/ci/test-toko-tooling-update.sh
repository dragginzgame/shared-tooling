#!/usr/bin/env bash
# Shared companions: scripts/dev/toko-tooling.sh scripts/ci/prepare-script-fixture.sh scripts/ci/fixture-lifecycle.sh make/consumer.mk
set -euo pipefail
ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
mkdir -p "$ROOT/target/tmp"
fixture="$(mktemp -d "$ROOT/target/tmp/registry-update.XXXXXX")"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Registry update fixture retained"' EXIT
case "${1:-all}" in all|prerequisites|selection) ;; *) exit 2 ;; esac
prereq="$ROOT/scripts/ci/check-tooling-prerequisites.sh"
real_bash="$(command -v bash)"
mkdir "$fixture/prerequisites"
for tool in perl jq; do ln -s "$(command -v "$tool")" "$fixture/prerequisites/$tool"; done
if PATH="$fixture/prerequisites" "$real_bash" "$prereq" archive > "$fixture/prerequisites.log" 2>&1; then exit 1; fi
grep -F 'requires yq' "$fixture/prerequisites.log" >/dev/null
printf '#!/bin/sh\nexit 1\n' > "$fixture/prerequisites/yq"
chmod +x "$fixture/prerequisites/yq"
if PATH="$fixture/prerequisites" "$real_bash" "$prereq" archive > "$fixture/prerequisites.log" 2>&1; then exit 1; fi
grep -F 'Mike Farah yq v4' "$fixture/prerequisites.log" >/dev/null
rm "$fixture/prerequisites/yq" "$fixture/prerequisites/perl"
ln -s "$(command -v yq)" "$fixture/prerequisites/yq"
printf '#!/bin/sh\nexit 1\n' > "$fixture/prerequisites/perl"
chmod +x "$fixture/prerequisites/perl"
if PATH="$fixture/prerequisites" "$real_bash" "$prereq" archive > "$fixture/prerequisites.log" 2>&1; then exit 1; fi
grep -F 'Perl module Archive::Tar' "$fixture/prerequisites.log" >/dev/null
if [[ "${1:-all}" == prerequisites ]]; then
    echo 'Missing prerequisite diagnostics passed'
    fixture_complete=true
    exit 0
fi
unset TOKO_TOOLING_DOWNLOAD_CACHE
export CARGO_NET_OFFLINE=true RUSTUP_AUTO_INSTALL=0
export REGISTRY_FIXTURE="$fixture"
real_make="$(command -v make)"
mkdir -p "$fixture/source" "$fixture/crates" "$fixture/vendor" "$fixture/bin"
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$fixture/source" scripts/dev/toko-tooling.sh make/consumer.mk
[[ ! -e "$fixture/source/docs" && ! -e "$fixture/source/audits" && ! -e "$fixture/source/tasks" ]]
archive() {
    local version="$1" source="$fixture/input/toko-tooling-$1" digest
    mkdir -p "$source/src"
    cp -Rp "$fixture/source/." "$source/"
    printf '[package]\nname = "toko-tooling"\nversion = "%s"\nedition = "2024"\n[lib]\npath = "src/lib.rs"\n' "$version" > "$source/Cargo.toml"
    printf '#![no_std]\n' > "$source/src/lib.rs"
    printf '# payload %s\n' "$version" > "$source/sample.sh"
    if [[ "$version" == 0.36.0 ]]; then
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
archive 0.36.0
archive 0.36.1
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
mkdir -p "$consumer/crates/one/src" "$consumer/crates/two/src" "$consumer/.cargo"
git init -q "$consumer"
printf '[workspace]\nmembers = ["crates/*"]\ndefault-members = ["crates/one"]\nresolver = "3"\n[workspace.dependencies]\ntoko-tooling = "=0.36.0"\n' > "$consumer/Cargo.toml"
for name in one two; do
    printf '[package]\nname="%s"\nversion="0.1.0"\nedition="2024"\n[dev-dependencies]\ntoko-tooling.workspace=true\n' "$name" > "$consumer/crates/$name/Cargo.toml"
    printf 'pub fn source() {}\n' > "$consumer/crates/$name/src/lib.rs"
done
printf '[source.crates-io]\nreplace-with="fixture"\n[source.fixture]\ndirectory="%s"\n' "$fixture/vendor" > "$consumer/.cargo/config.toml"
refresh_lock() { (cd "$consumer" && cargo update -p toko-tooling --offline); }
(cd "$consumer" && cargo generate-lockfile --offline)
run() { bash "$ROOT/scripts/dev/toko-tooling.sh" "$1" --consumer "$consumer" "${@:2}"; }
must_fail() { if "$@" > "$fixture/rejection.log" 2>&1; then echo 'registry fixture unexpectedly passed' >&2; exit 1; fi; }
if [[ "${1:-all}" == selection ]]; then
    run_cargo() { (cd "$consumer" && cargo "$@"); }
    # Real Cargo regression: a binary's tests lint an unused unconditional marker.
    printf '\n[workspace.lints.cargo]\nunused_dependencies="deny"\nunused_workspace_dependencies="deny"\n' >> "$consumer/Cargo.toml"
    for name in one two; do printf '\n[lints]\nworkspace=true\n' >> "$consumer/crates/$name/Cargo.toml"; done
    rm "$consumer/crates/one/src/lib.rs"
    printf 'fn main() {}\n#[test]\nfn smoke() { assert_eq!(2 + 2, 4); }\n' > "$consumer/crates/one/src/main.rs"
    (cd "$consumer" && cargo test --locked --offline -p two) > "$fixture/library.log" 2>&1
    must_fail run_cargo test --locked --offline -p one
    grep -F "unused dependency \`toko-tooling\`" "$fixture/rejection.log" > /dev/null
    perl -pi -e "s/^\\[dev-dependencies\\]/[target.'cfg(any())'.dev-dependencies]/" "$consumer/crates/one/Cargo.toml"
    perl "$ROOT/scripts/dev/tooling-lock.pl" "$consumer" > "$fixture/marker-selection.json"
    for warmth in cold warm; do
        run_cargo test --locked --offline -p one > "$fixture/binary-$warmth.log" 2>&1
    done
    cp "$consumer/crates/one/Cargo.toml" "$fixture/marker.toml"
    # This form must not weaken ordinary unused-dependency refusal.
    printf '\n[dependencies]\ntwo={path="../two"}\n' >> "$consumer/crates/one/Cargo.toml"
    (cd "$consumer" && cargo generate-lockfile --offline)
    must_fail run_cargo test --locked --offline -p one
    grep -F "unused dependency \`two\`" "$fixture/rejection.log" > /dev/null
    cp "$fixture/marker.toml" "$consumer/crates/one/Cargo.toml"
    for fault in missing duplicate conditional normal override; do
        cp "$fixture/marker.toml" "$consumer/crates/one/Cargo.toml"
        case "$fault" in
            missing) perl -ni -e 'print unless /toko-tooling/' "$consumer/crates/one/Cargo.toml" ;;
            duplicate) printf '\n[dev-dependencies]\ntoko-tooling.workspace=true\n' >> "$consumer/crates/one/Cargo.toml" ;;
            conditional) perl -pi -e 's/cfg\(any\(\)\)/cfg(unix)/' "$consumer/crates/one/Cargo.toml" ;;
            normal) perl -pi -e 's/dev-dependencies/dependencies/' "$consumer/crates/one/Cargo.toml" ;;
            override) perl -pi -e 's/toko-tooling.workspace=true/toko-tooling="=0.36.0"/' "$consumer/crates/one/Cargo.toml" ;;
        esac
        must_fail perl "$ROOT/scripts/dev/tooling-lock.pl" "$consumer"
    done
    cp "$fixture/marker.toml" "$consumer/crates/one/Cargo.toml"
    (cd "$consumer" && cargo generate-lockfile --offline)
    perl "$ROOT/scripts/dev/tooling-lock.pl" "$consumer" > "$fixture/restored.json"
    standalone="$fixture/standalone"
    mkdir -p "$standalone/src"
    cp -Rp "$consumer/.cargo" "$standalone/"
    printf '[package]\nname="standalone"\nversion="0.0.0"\nedition="2024"\n[target.'"'"'cfg(any())'"'"'.dev-dependencies]\ntoko-tooling="=0.36.0"\n[lints.cargo]\nunused_dependencies="deny"\n' > "$standalone/Cargo.toml"
    cp "$consumer/crates/one/src/main.rs" "$standalone/src/main.rs"
    (cd "$standalone" && cargo generate-lockfile --offline && cargo test --locked --offline) > "$fixture/standalone.log" 2>&1
    perl "$ROOT/scripts/dev/tooling-lock.pl" "$standalone" > "$fixture/standalone.json"
    run install --snapshot-only --entrypoint sample.sh --entrypoint scripts/dev/toko-tooling.sh > "$fixture/marker-install.log"
    run check > "$fixture/marker-check.log"
    echo 'Cargo-visible source-only markers pass binary tests; unused code dependencies and malformed selections refuse.'
    fixture_complete=true
    exit 0
fi
cp "$consumer/Cargo.lock" "$fixture/original.lock"
TMPDIR=/tmp run update --preview --entrypoint sample.sh --entrypoint scripts/dev/toko-tooling.sh > "$fixture/initial-preview.log"
[[ ! -e "$consumer/sample.sh" && ! -e "$consumer/.toko-tooling.snapshot" && ! -e "$consumer/target" && ! -e "$fixture/setup" ]]
cmp "$consumer/Cargo.lock" "$fixture/original.lock"
CORRUPT_DOWNLOAD=1 must_fail run update --entrypoint sample.sh --entrypoint scripts/dev/toko-tooling.sh
[[ ! -e "$consumer/sample.sh" && ! -e "$consumer/.toko-tooling.snapshot" && ! -e "$fixture/setup" ]]
run install --entrypoint sample.sh --entrypoint scripts/dev/toko-tooling.sh > "$fixture/install.log"
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
cp "$fixture/input/toko-tooling-0.36.0/sample.sh" "$consumer/sample.sh"
git -C "$consumer" add sample.sh
# Cargo selection drift is detected offline before any release or install.
perl -pi -e 's/0\.36\.0/0.36.1/' "$consumer/Cargo.toml"
must_fail run check
must_fail run install
refresh_lock
must_fail run update
[[ -f "$consumer/retired.txt" ]]
git -C "$consumer" reset -q -- sample.sh
cp "$consumer/.toko-tooling.snapshot" "$fixture/before-preview.snapshot"
setup_calls="$(wc -l < "$fixture/setup")"
TMPDIR=/tmp run update --preview > "$fixture/update-preview.log"
cmp "$consumer/.toko-tooling.snapshot" "$fixture/before-preview.snapshot"
[[ -f "$consumer/retired.txt" && "$(wc -l < "$fixture/setup")" == "$setup_calls" ]]
run update --snapshot-only > "$fixture/update.log"
[[ "$(wc -l < "$fixture/setup")" == "$setup_calls" ]]
grep -F '0.36.1' "$consumer/sample.sh" >/dev/null
[[ ! -e "$consumer/retired.txt" ]]
run check > "$fixture/new-check.log"
"$real_make" --no-print-directory -C "$consumer" -f "$ROOT/make/consumer.mk" toko-tooling-install \
    TOKO_TOOLING_ROOT="$ROOT" > "$fixture/make-install.log"
setup_calls="$(wc -l < "$fixture/setup")"
"$real_make" --no-print-directory -C "$consumer" -f "$ROOT/make/consumer.mk" toko-tooling-install \
    TOKO_TOOLING_ROOT="$ROOT" TOKO_TOOLING_INSTALL_TOOLS=0 > "$fixture/make-snapshot.log"
TMPDIR=/tmp "$real_make" --no-print-directory -C "$consumer" -f "$ROOT/make/consumer.mk" toko-tooling-preview \
    TOKO_TOOLING_ROOT="$ROOT" > "$fixture/make-preview.log"
[[ "$(wc -l < "$fixture/setup")" == "$setup_calls" ]]
perl -pi -e 's/0\.36\.1/0.36.0/' "$consumer/Cargo.toml"
refresh_lock
run update --version 0.36.0 > "$fixture/downgrade.log"
[[ -f "$consumer/retired.txt" ]]
perl -pi -e 's/0\.36\.0/0.36.1/' "$consumer/Cargo.toml"
refresh_lock
SETUP_FAIL=1 must_fail run update
grep -F 'Snapshot installed, but tool setup/admission failed' "$fixture/rejection.log" >/dev/null
grep -F '0.36.1' "$consumer/sample.sh" >/dev/null
run check > "$fixture/setup-failure-check.log"
# Invalid selections and forged previous ownership never authorize replacement.
cp "$consumer/Cargo.lock" "$fixture/current.lock"
perl -pi -e 's{registry\+https://github.com/rust-lang/crates.io-index}{git+https://github.com/dragginzgame/toko-tooling#0123456789012345678901234567890123456789}' "$consumer/Cargo.lock"
must_fail run install
cp "$fixture/current.lock" "$consumer/Cargo.lock"
cp "$consumer/.toko-tooling.snapshot" "$fixture/receipt"
perl -pi -e 's/^(file\t)[0-9a-f]{64}(\t.\tsample.sh)$/${1}.("0" x 64).$2/e' "$consumer/.toko-tooling.snapshot"
perl -pi -e 's/0\.36\.1/0.36.0/' "$consumer/Cargo.toml"
refresh_lock
must_fail run update --version 0.36.0
cp "$fixture/receipt" "$consumer/.toko-tooling.snapshot"
# A Git receipt needs independently readable historical bytes exactly once.
old_source="$fixture/old-source"
cp -Rp "$fixture/input/toko-tooling-0.36.0" "$old_source"
printf '#!/bin/sh\necho "Legacy installer accepts Git selections only" >&2\nexit 1\n' > "$old_source/scripts/dev/toko-tooling.sh"
git -C "$old_source" init -q
git -C "$old_source" remote add origin https://github.com/dragginzgame/toko-tooling
git -C "$old_source" add .
git -C "$old_source" -c user.name=Fixture -c user.email=fixture@example.invalid -c core.hooksPath=/dev/null commit -qm initial
old_consumer="$fixture/old-consumer"
mkdir "$old_consumer"; git -C "$old_consumer" init -q
bash "$old_source/scripts/distribution/refresh-consumer.sh" --source "$old_source" --consumer "$old_consumer" \
    --entrypoint sample.sh --entrypoint scripts/dev/toko-tooling.sh > "$fixture/old-install.log"
cp "$consumer/Cargo.toml" "$old_consumer/Cargo.toml"
cp "$consumer/Cargo.lock" "$old_consumer/Cargo.lock"
cp -Rp "$consumer/crates" "$consumer/.cargo" "$old_consumer/"
must_fail bash "$old_consumer/scripts/dev/toko-tooling.sh" install --consumer "$old_consumer"
must_fail bash "$ROOT/scripts/dev/toko-tooling.sh" install --consumer "$old_consumer"
bash "$ROOT/scripts/dev/toko-tooling.sh" install --consumer "$old_consumer" --source "$old_source" > "$fixture/migrate.log"
# Every member participates, independent of default-members and package removal.
perl -pi -e 's/0\.36\.0/0.36.1/' "$consumer/Cargo.toml"
refresh_lock
run check > "$fixture/restored-check.log"
"$real_make" --no-print-directory -C "$consumer" -f "$ROOT/make/consumer.mk" ci TOKO_TOOLING_ROOT="$ROOT" > "$fixture/ci.log"
cp "$consumer/Cargo.toml" "$fixture/root-manifest"
cp "$consumer/crates/two/Cargo.toml" "$fixture/member-manifest"
cp "$consumer/Cargo.lock" "$fixture/valid-cargo.lock"
perl -ni -e 'print unless /toko-tooling/' "$consumer/crates/two/Cargo.toml"
must_fail run check
grep -F 'every workspace package' "$fixture/rejection.log" >/dev/null
must_fail "$real_make" --no-print-directory -C "$consumer" -f "$ROOT/make/consumer.mk" ci TOKO_TOOLING_ROOT="$ROOT"
must_fail "$real_make" --no-print-directory -C "$consumer" -f "$ROOT/make/consumer.mk" release-preflight TOKO_TOOLING_ROOT="$ROOT"
cp "$fixture/member-manifest" "$consumer/crates/two/Cargo.toml"
# A locally pinned member cannot drift from inherited selection, even at the same version.
perl -pi -e 's/toko-tooling.workspace=true/toko-tooling="=0.36.1"/' "$consumer/crates/two/Cargo.toml"
must_fail run check
cp "$fixture/member-manifest" "$consumer/crates/two/Cargo.toml"
perl -pi -e 's/dev-dependencies/dependencies/' "$consumer/crates/two/Cargo.toml"
must_fail run check
cp "$fixture/member-manifest" "$consumer/crates/two/Cargo.toml"
# Removing any one package leaves the remaining packages and selected tooling intact.
mv "$consumer/crates/two" "$fixture/removed-member"
run check > "$fixture/removed-member.log"
mv "$fixture/removed-member" "$consumer/crates/two"
# Lock removal, aliases, checksum drift and source overrides refuse offline.
rm "$consumer/Cargo.lock"
must_fail run check
ln -s "$fixture/valid-cargo.lock" "$consumer/Cargo.lock"
must_fail run check
rm "$consumer/Cargo.lock"
cp "$fixture/valid-cargo.lock" "$consumer/Cargo.lock"
perl -pi -e 's/checksum = "[0-9a-f]+"/checksum = "bad"/' "$consumer/Cargo.lock"
must_fail run check
cp "$fixture/valid-cargo.lock" "$consumer/Cargo.lock"
perl -pi -e 's/checksum = "[0-9a-f]+"/"checksum = \"" . ("0" x 64) . "\""/e' "$consumer/Cargo.lock"
must_fail run check
grep -F 'Cargo.lock selects different' "$fixture/rejection.log" >/dev/null
cp "$fixture/valid-cargo.lock" "$consumer/Cargo.lock"
printf '\n[[package]]\nname="toko-tooling"\nversion="0.36.0"\nsource="registry+https://github.com/rust-lang/crates.io-index"\nchecksum="%s"\n' "$(cat "$fixture/crates/0.36.0.sha256")" >> "$consumer/Cargo.lock"
must_fail run check
cp "$fixture/valid-cargo.lock" "$consumer/Cargo.lock"
perl -pi -e 's/=0\.36\.1/0.36.1/' "$consumer/Cargo.toml"
must_fail run check
cp "$fixture/root-manifest" "$consumer/Cargo.toml"
printf '\n[patch.crates-io]\ntoko-tooling={path="../../vendor/toko-tooling-0.36.1"}\n' >> "$consumer/Cargo.toml"
must_fail run check
cp "$fixture/root-manifest" "$consumer/Cargo.toml"
printf '\n[workspace.metadata.toko-tooling]\nversion="0.36.1"\n' >> "$consumer/Cargo.toml"
must_fail run check
cp "$fixture/root-manifest" "$consumer/Cargo.toml"
printf '{}' > "$consumer/toko-tooling.lock"
must_fail run check
rm "$consumer/toko-tooling.lock"
# Standalone root packages select directly without a synthetic workspace/helper.
standalone="$fixture/standalone"
mkdir -p "$standalone/src"
printf '[package]\nname="standalone"\nversion="0.1.0"\nedition="2024"\n[dev-dependencies]\ntoko-tooling="=0.36.1"\n' > "$standalone/Cargo.toml"
printf '' > "$standalone/src/lib.rs"
cp -Rp "$consumer/.cargo" "$standalone/"
printf '\n[package.metadata.toko-tooling.loc]\nrole="fixture"\n' >> "$standalone/Cargo.toml"
(cd "$standalone" && cargo generate-lockfile --offline)
perl "$ROOT/scripts/dev/tooling-lock.pl" "$standalone" > "$fixture/standalone.json"
jq -e '.version == "0.36.1"' "$fixture/standalone.json" >/dev/null
# A root package in a workspace must inherit too.
printf '\n[workspace]\n[workspace.dependencies]\ntoko-tooling="=0.36.1"\n' >> "$standalone/Cargo.toml"
must_fail perl "$ROOT/scripts/dev/tooling-lock.pl" "$standalone"
perl -0pi -e 's/\[dev-dependencies\]\ntoko-tooling="=0.36.1"/[dev-dependencies]\ntoko-tooling.workspace=true/' "$standalone/Cargo.toml"
perl "$ROOT/scripts/dev/tooling-lock.pl" "$standalone" > "$fixture/root-package.json"
grep -F $'source\thttps://crates.io/crates/toko-tooling' "$old_consumer/.toko-tooling.snapshot" >/dev/null
echo 'Cargo-visible per-member selection, lock/snapshot drift, authenticated installation, retirement and migration passed'
fixture_complete=true
