#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/ci/prepare-script-fixture.sh scripts/distribution/refresh-consumer.sh scripts/ci/check-documentation-links.pl scripts/ci/verify-file-checksum.sh scripts/ci/verify-toko-tooling-snapshot.sh .githooks/pre-commit make/consumer.mk make/release.mk
set -euo pipefail
case "${1:-}" in ''|--baseline-only|--consumer-only) ;; *) exit 2 ;; esac
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/exported-doc-links.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Exported documentation fixture retained"' EXIT
consumer="$fixture/consumer"
source_fixture="$fixture/source"
mkdir -p "$consumer/docs" "$source_fixture"
git -C "$consumer" init -q
printf '# Consumer instructions\n' > "$consumer/AGENTS.md"
printf '[Product](docs/product.md)\n' > "$consumer/README.md"
printf '# Product guide\n' > "$consumer/docs/product.md"
entrypoints=(TOKO-TOOLING.md)
if [[ "${1:-}" != --baseline-only ]]; then entrypoints+=(make/consumer.mk .githooks/pre-commit make/release.mk); fi
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$source_fixture" \
    Cargo.toml scripts/distribution/refresh-consumer.sh scripts/ci/verify-file-checksum.sh \
    scripts/ci/verify-toko-tooling-snapshot.sh "${entrypoints[@]}"
git -C "$source_fixture" init -q
git -C "$source_fixture" remote add origin https://github.com/dragginzgame/toko-tooling
git -C "$source_fixture" add .
git -C "$source_fixture" -c core.hooksPath=/dev/null -c commit.gpgsign=false \
    -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
arguments=(--source "$source_fixture" --consumer "$consumer")
for path in "${entrypoints[@]}"; do arguments+=(--entrypoint "$path"); done
bash "$source_fixture/scripts/distribution/refresh-consumer.sh" "${arguments[@]}" > "$fixture/export.log" 2>&1
[[ ! -e "$consumer/vendor/toko-tooling/docs" && ! -e "$consumer/rules" && ! -e "$consumer/tasks" ]]
[[ "$(awk -F '\t' '$1 == "file" && $4 ~ /[.]md$/ {print $4}' "$consumer/.toko-tooling.snapshot")" == TOKO-TOOLING.md ]]
perl "$root/scripts/ci/check-documentation-links.pl" --root "$consumer" TOKO-TOOLING.md AGENTS.md README.md docs/product.md
if [[ "${1:-}" == --baseline-only ]]; then
    [[ "$(awk -F '\t' '$1 == "file" {n++} END {print n}' "$consumer/.toko-tooling.snapshot")" == 3 ]]
else
    printf 'include vendor/toko-tooling/make/consumer.mk\npatch:\n\t@echo consumer-release\n' > "$consumer/Makefile"
    make -C "$consumer" patch > "$fixture/local-release.log" 2>&1
    grep -Fq consumer-release "$fixture/local-release.log"
    if make -C "$consumer" -n release-patch > "$fixture/shared-release.log" 2>&1; then exit 1; fi
    printf 'TOKO_TOOLING_RELEASE := 1\ninclude vendor/toko-tooling/make/consumer.mk\n' > "$consumer/Makefile"
    if make -C "$consumer" RELEASE_FROZEN_GROUPS=alpha release-preflight > "$fixture/make-refusal.log" 2>&1; then exit 1; fi
    if RELEASE_FROZEN_GROUPS=alpha perl "$consumer/vendor/toko-tooling/scripts/ci/run-release-batch.pl" --root "$consumer" --groups alpha > "$fixture/perl-refusal.log" 2>&1; then exit 1; fi
    guide_pattern='https://github.com/dragginzgame/toko-tooling/blob/[0-9a-f]{40}/docs/releases/release-batches[.]md'
    [[ "$(grep -Eo "$guide_pattern" "$fixture/make-refusal.log")" == "$(grep -Eo "$guide_pattern" "$fixture/perl-refusal.log")" ]]
    grep -Eq "$guide_pattern" "$fixture/make-refusal.log"
fi
mv "$consumer/docs/product.md" "$fixture/product.md"
if perl "$root/scripts/ci/check-documentation-links.pl" --root "$consumer" README.md > "$fixture/missing-target.log" 2>&1; then exit 1; fi
fixture_complete=true
printf 'Vendor export keeps references online, preserves product docs and rejects missing native links.\n'
