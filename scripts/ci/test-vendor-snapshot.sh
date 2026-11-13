#!/usr/bin/env bash
# Shared companions: scripts/distribution/refresh-consumer.sh scripts/ci/prepare-script-fixture.sh scripts/ci/fixture-lifecycle.sh make/consumer.mk make/release.mk make/cargo-publication.mk .githooks/pre-commit
set -euo pipefail
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/vendor-snapshot.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Vendor snapshot fixture retained"' EXIT
source_root="$fixture/source"
consumer="$fixture/consumer with spaces"
mkdir -p "$source_root" "$consumer"
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$source_root" make/consumer.mk make/release.mk make/cargo-publication.mk .githooks/pre-commit
for repo in "$source_root" "$consumer"; do
    git -C "$repo" init -q
    git -C "$repo" config user.name Fixture
    git -C "$repo" config user.email fixture@example.invalid
    git -C "$repo" config commit.gpgsign false
    git -C "$repo" config core.hooksPath /dev/null
done
git -C "$source_root" remote add origin https://example.invalid/toko-tooling
printf '0.41.1\n' > "$source_root/VERSION"
printf '# Baseline\n' > "$source_root/TOKO-TOOLING.md"
git -C "$source_root" add .
git -C "$source_root" commit -qm old
refresh() { bash "$root/scripts/distribution/refresh-consumer.sh" --source "$source_root" --consumer "$consumer" "$@"; }
reject() { if refresh "$@" > "$fixture/refusal.log" 2>&1; then echo 'unexpected refresh success' >&2; exit 1; fi; }
refresh --entrypoint make/consumer.mk --entrypoint TOKO-TOOLING.md --entrypoint .githooks/pre-commit > "$fixture/old.log"
mkdir -p "$consumer/scripts/local"
printf 'consumer-owned\n' > "$consumer/scripts/local/keep.sh"
git -C "$consumer" add .
git -C "$consumer" commit -qm old-installation
printf '0.42.0\n' > "$source_root/VERSION"
git -C "$source_root" add VERSION
git -C "$source_root" commit -qm vendor
cp "$consumer/.toko-tooling.snapshot" "$fixture/old.snapshot"
refresh --impact > "$fixture/preview.log"
cmp "$fixture/old.snapshot" "$consumer/.toko-tooling.snapshot"
[[ ! -e "$consumer/vendor" ]]
grep -F $'REMOVE\tobsolete\tmake/consumer.mk' "$fixture/preview.log"
# An edited old payload, even committed, must not be retired by migration.
printf '# native edit\n' >> "$consumer/scripts/ci/check-make-execution.sh"
git -C "$consumer" add .
git -C "$consumer" commit -qm edited
reject
grep -F 'retirement has local changes' "$fixture/refusal.log"
git -C "$consumer" checkout HEAD~1 -- scripts/ci/check-make-execution.sh
git -C "$consumer" commit -qm restored
refresh > "$fixture/migrated.log"
[[ -f "$consumer/vendor/toko-tooling/make/consumer.mk" && ! -e "$consumer/make/consumer.mk" ]]
[[ ! -e "$consumer/.githooks/pre-commit" && -f "$consumer/vendor/toko-tooling/.githooks/pre-commit" ]]
[[ "$(cat "$consumer/scripts/local/keep.sh")" == consumer-owned ]]
bash "$root/scripts/ci/verify-toko-tooling-snapshot.sh" --consumer "$consumer" --source "$source_root" --revision "$(git -C "$source_root" rev-parse HEAD)"
refresh > "$fixture/retry.log"
# A changed owned root document must refuse, even after the consumer commits it.
git -C "$consumer" add .
git -C "$consumer" commit -qm migrated
printf '# consumer edit\n' >> "$consumer/TOKO-TOOLING.md"
git -C "$consumer" add TOKO-TOOLING.md
git -C "$consumer" commit -qm modified-root
reject
grep -F 'consumer destination has local changes' "$fixture/refusal.log"
git -C "$consumer" checkout HEAD~1 -- TOKO-TOOLING.md
git -C "$consumer" commit -qm restored-root
mkdir -p "$consumer/vendor/toko-tooling/make"
printf '# Native collision\n' > "$consumer/vendor/toko-tooling/make/release.mk"
git -C "$consumer" add .
git -C "$consumer" commit -qm native-collision
reject --add-entrypoint make/release.mk
grep -F 'not an unchanged owned snapshot file' "$fixture/refusal.log"
git -C "$consumer" rm -q vendor/toko-tooling/make/release.mk
git -C "$consumer" commit -qm explicit-removal
refresh --add-entrypoint make/release.mk --add-entrypoint make/cargo-publication.mk > "$fixture/optional.log"
[[ -f "$consumer/vendor/toko-tooling/make/release.mk" && -f "$consumer/vendor/toko-tooling/make/cargo-publication.mk" ]]
printf '0.42.1\n' > "$source_root/VERSION"
printf '\n# updated source\n' >> "$source_root/scripts/ci/check-make-execution.sh"
git -C "$source_root" add .
git -C "$source_root" commit -qm next-vendor-release
refresh > "$fixture/vendor-update.log"
cmp "$source_root/scripts/ci/check-make-execution.sh" "$consumer/vendor/toko-tooling/scripts/ci/check-make-execution.sh"
reject --add-entrypoint docs/reference.md
grep -F 'consumer payload excludes' "$fixture/refusal.log"
reject --add-entrypoint scripts/ci/test-producer.sh
grep -F 'consumer payload excludes' "$fixture/refusal.log"
printf 'Vendor migration, preview, retry, ownership refusals and optional components passed.\n'
fixture_complete=true
