#!/usr/bin/env bash
# Shared companions: scripts/ci/release-receipts.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd -P "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/ci/release-receipts.sh
source "$root/scripts/ci/release-receipts.sh"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/release-receipts.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Release receipt fixtures retained"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
cd "$fixture"
git init -q
git config user.name Fixture
git config user.email fixture@example.invalid
printf 'source\n' > 'selected file'
git add -- 'selected file'
git commit -qm fixture
git remote add origin https://example.invalid/fixture.git
export RELEASE_SOURCE RELEASE_PREVIOUS=0.1.0 RELEASE_VERSION=0.1.1 RELEASE_DATE=2026-10-17 RELEASE_REMOTE=origin RELEASE_BRANCH=main
RELEASE_SOURCE="$(git rev-parse HEAD)"
refuse() { if "$@"; then echo 'unexpected receipt admission' >&2; exit 1; fi; }
refuse release_receipt_check validated release_receipt_identity
release_receipt_write validated release_receipt_identity
release_receipt_check validated release_receipt_identity
git remote set-url --push origin https://example.invalid/other.git
refuse release_receipt_check validated release_receipt_identity
git remote set-url --push origin https://example.invalid/fixture.git
release_receipt_check validated release_receipt_identity
printf '\n' >> validated
refuse release_receipt_check validated release_receipt_identity
release_receipt_write validated release_receipt_identity
cp validated original
refuse release_receipt_write validated false
cmp validated original
rm validated
ln -s original validated
refuse release_receipt_check validated release_receipt_identity
refuse release_receipt_write validated release_receipt_identity
release_receipt_write prepared release_receipt_payload '' 'selected file'
release_receipt_check prepared release_receipt_payload "$RELEASE_SOURCE" 'selected file'
printf 'changed\n' >> 'selected file'
refuse release_receipt_check prepared release_receipt_payload '' 'selected file'
release_receipt_check prepared release_receipt_payload "$RELEASE_SOURCE" 'selected file'
refuse release_receipt_write prepared release_receipt_payload '' 'missing file'
release_receipt_check prepared release_receipt_payload "$RELEASE_SOURCE" 'selected file'
fixture_complete=true
printf 'Release receipt fixtures passed\n'
