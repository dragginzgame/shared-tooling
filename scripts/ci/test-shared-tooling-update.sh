#!/usr/bin/env bash
# Shared companions: scripts/dev/shared-tooling.sh scripts/distribution/refresh-consumer.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
mkdir -p "$ROOT/target/tmp"
fixture="$(mktemp -d "$ROOT/target/tmp/shared-update.XXXXXX")"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Shared update fixture retained"' EXIT
source_root="$fixture/source"
consumer="$fixture/consumer"
mkdir -p "$source_root/scripts/dev" "$source_root/scripts/ci" "$source_root/scripts/distribution" "$consumer" "$fixture/bin"
git init -q --bare "$fixture/remote"
git init -q -b main "$source_root"
git -C "$source_root" config user.name Fixture
git -C "$source_root" config user.email fixture@example.invalid
git -C "$source_root" config commit.gpgsign false
git -C "$source_root" config core.hooksPath /dev/null
git -C "$source_root" remote add origin "$fixture/remote"
for path in scripts/ci/shared-package-version.pl scripts/dev/shared-tooling.sh scripts/distribution/refresh-consumer.sh scripts/ci/shared-companions.sh scripts/ci/verify-file-checksum.sh scripts/ci/verify-shared-tooling-snapshot.sh; do
    cp -p "$ROOT/$path" "$source_root/$path"
done
mkdir -p "$source_root/src"
printf '[package]\nname = "toko-tooling"\nversion = "0.1.0"\n' > "$source_root/Cargo.toml"
printf '#![no_std]\n' > "$source_root/src/lib.rs"
printf 'old\n' > "$source_root/sample.txt"
git -C "$source_root" add scripts Cargo.toml src sample.txt
git -C "$source_root" commit -qm old
old="$(git -C "$source_root" rev-parse HEAD)"
git -C "$source_root" push -q origin main
git init -q "$consumer"
bash "$source_root/scripts/distribution/refresh-consumer.sh" --source "$source_root" --consumer "$consumer" \
    --entrypoint sample.txt --entrypoint scripts/dev/shared-tooling.sh > "$fixture/initial.log"
printf '[package]\nname = "toko-tooling"\nversion = "0.2.0"\n' > "$source_root/Cargo.toml"
printf 'new\n' > "$source_root/sample.txt"
git -C "$source_root" add Cargo.toml sample.txt
git -C "$source_root" commit -qm new
git -C "$source_root" push -q origin main
new="$(git -C "$source_root" rev-parse HEAD)"
# Dirty source payload must not change the pushed selection.
printf 'unpublished local edit\n' > "$source_root/sample.txt"
cat > "$fixture/bin/make" <<'MAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$UPDATE_CALLS"
[[ "${SETUP_FAIL:-0}" == 0 ]]
MAKE
chmod +x "$fixture/bin/make"
real_make="$(command -v make)"
export CARGO_HOME="$fixture/cargo-home"
export PATH="$fixture/bin:$ROOT/.tools/host/bin:$PATH" UPDATE_CALLS="$fixture/calls"
run() { bash "$consumer/scripts/dev/shared-tooling.sh" "$1" --consumer "$consumer" --source "$source_root" "${@:2}"; }
run status > "$fixture/status.log"
grep -F "Installed: 0.1.0 ($old)" "$fixture/status.log"
grep -F "Latest pushed: 0.2.0 ($new)" "$fixture/status.log"
[[ ! -e "$UPDATE_CALLS" && "$(cat "$consumer/sample.txt")" == old ]]
printf 'consumer edit\n' > "$consumer/sample.txt"
if run status > "$fixture/drift.log" 2>&1; then exit 1; fi
if run update > "$fixture/conflict.log" 2>&1; then exit 1; fi
[[ ! -e "$UPDATE_CALLS" && "$(cat "$consumer/sample.txt")" == 'consumer edit' ]]
printf 'old\n' > "$consumer/sample.txt"
run update > "$fixture/update.log"
[[ "$(cat "$consumer/sample.txt")" == new ]]
[[ "$(wc -l < "$UPDATE_CALLS" | tr -d ' ')" == 2 ]]
grep -F 'install-tools' "$UPDATE_CALLS"
grep -F 'tools-check' "$UPDATE_CALLS"
run update --version 0.1.0 > "$fixture/pinned.log"
[[ "$(cat "$consumer/sample.txt")" == old ]]
if run update --version 9.9.9 > "$fixture/missing.log" 2>&1; then exit 1; fi
[[ "$(cat "$consumer/sample.txt")" == old ]]
if SETUP_FAIL=1 run update > "$fixture/setup-failure.log" 2>&1; then exit 1; fi
grep -F 'Snapshot installed, but tool setup/admission failed' "$fixture/setup-failure.log"
[[ "$(cat "$consumer/sample.txt")" == new && "$(cat "$source_root/sample.txt")" == 'unpublished local edit' ]]
[[ "$(git -C "$source_root" rev-parse HEAD)" == "$new" ]]
# The public Make interface forwards source, manifest and version without installing on status.
"$real_make" --no-print-directory -C "$consumer" -f "$ROOT/make/consumer.mk" shared-tooling-update \
    SHARED_TOOLING_ROOT="$ROOT" SHARED_TOOLING_SOURCE="$source_root" SHARED_TOOLING_VERSION=0.1.0 > "$fixture/make-update"
grep -F "Selected: 0.1.0 ($old)" "$fixture/make-update"
[[ "$(cat "$consumer/sample.txt")" == old ]]
"$real_make" --no-print-directory -C "$consumer" -f "$ROOT/make/consumer.mk" shared-tooling-status \
    SHARED_TOOLING_ROOT="$ROOT" SHARED_TOOLING_SOURCE="$source_root" > "$fixture/make-status"
grep -F "Installed: 0.1.0 ($old)" "$fixture/make-status"
# Actual Cargo resolution pins a Git commit; install must not drift to newer main.
mkdir -p "$consumer/src"
printf '' > "$consumer/src/lib.rs"
printf '[package]\nname = "consumer"\nversion = "0.1.0"\n[dev-dependencies]\ntoko-tooling = { git = "file://%s", branch = "main" }\n' "$fixture/remote" > "$consumer/Cargo.toml"
run update > "$fixture/pre-cargo-latest.log"
(cd "$consumer" && cargo update -p toko-tooling --precise "$old") > "$fixture/cargo-update.log" 2>&1
if run check > "$fixture/cargo-mismatch.log" 2>&1; then exit 1; fi
run install > "$fixture/cargo-install.log"
run check > "$fixture/cargo-match.log"
[[ "$(cat "$consumer/sample.txt")" == old ]]
run status > "$fixture/cargo-status.log"
grep -F "Selected: 0.1.0 ($old)" "$fixture/cargo-status.log"
run update > "$fixture/cargo-latest.log" 2>&1
[[ "$(cat "$consumer/sample.txt")" == new ]]
fixture_complete=true
echo 'Shared update status, pinned selection, conflict custody, setup and failure reporting passed'
