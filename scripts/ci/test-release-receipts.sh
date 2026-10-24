#!/usr/bin/env bash
# Shared companions: scripts/ci/release-receipts.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(CDPATH='' cd -P -- "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/release-receipts.sh
source "$root/scripts/ci/release-receipts.sh"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/release-receipts.XXXXXX")"
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
mkdir attempts
release_receipt_archive "$fixture/attempts/archive.XXXXXX" prepared original absent
archive=("$fixture"/attempts/archive.*)
cmp prepared "${archive[0]}/prepared"
cmp original "${archive[0]}/original"
refuse release_receipt_archive "$fixture/attempts/refused.XXXXXX" prepared validated
[[ "$(find attempts -name 'refused.*' -print)" == '' ]] || exit 1
mkdir nested
cp original nested/original
refuse release_receipt_archive "$fixture/attempts/collision.XXXXXX" original nested/original
[[ "$(find attempts -name 'collision.*' -print)" == '' ]] || exit 1
# No prior attempt means no archive directory or synthetic empty evidence.
release_receipt_archive "$fixture/attempts/absent.XXXXXX" absent missing
[[ "$(find attempts -name 'absent.*' -print)" == '' ]] || exit 1
# A failed second copy must remain failed even after producing plausible bytes;
# retain both the active receipts and the already copied archive evidence.
mkdir bin
export RECEIPT_REAL_CP
RECEIPT_REAL_CP="$(command -v cp)"
cat > bin/cp <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
"$RECEIPT_REAL_CP" "$@"
for argument in "$@"; do
    [[ "$argument" != original ]] || exit 41
done
STUB
chmod +x bin/cp
status=0
PATH="$fixture/bin:$PATH" release_receipt_archive "$fixture/attempts/failed.XXXXXX" prepared original || status=$?
[[ "$status" == 41 ]] || exit 1
failed_archive=("$fixture"/attempts/failed.*)
[[ "${#failed_archive[@]}" == 1 && -d "${failed_archive[0]}" ]] || exit 1
cmp prepared "${failed_archive[0]}/prepared"
cmp original "${failed_archive[0]}/original"
cmp "${archive[0]}/prepared" prepared
cmp "${archive[0]}/original" original
release_receipt_check prepared release_receipt_payload "$RELEASE_SOURCE" 'selected file'
fixture_complete=true
printf 'Release receipt fixtures passed\n'
