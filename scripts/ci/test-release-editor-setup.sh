#!/usr/bin/env bash
# Shared companions: Makefile make/consumer.mk scripts/ci/prepare-script-fixture.sh scripts/ci/fixture-lifecycle.sh scripts/ci/extract-workflow-step.sh .github/workflows/ci.yml
# Shared-only qualification of this repository's Make policy and CI caller.
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(CDPATH='' cd -P -- "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/release-editor-setup.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Release editor setup fixtures retained"' EXIT
consumer="$fixture/consumer space"
mkdir "$consumer"
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$consumer" Makefile make/consumer.mk
export EDITOR_SETUP_EVENTS="$fixture/events" EDITOR_SETUP_PATH="$fixture/admitted editor"
mkdir -p "$consumer/scripts/ci"
cat > "$fixture/installer" <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail
name="${0##*/}"
printf '%s %s\n' "$name" "$*" >> "$EDITOR_SETUP_EVENTS"
case "$*" in
    *--package\ ic-build*)
        [[ "$*" == *'--version '*' --bin ic-build-release-metadata --profile debug'* ]] || exit 91
        printf '%s\n' "$EDITOR_SETUP_PATH"
        case "${EDITOR_SETUP_FAILURE:-}" in
            check) [[ "$*" != *--check* ]] || exit 37 ;;
            install) [[ "$*" == *--check* ]] || exit 41 ;;
        esac ;;
esac
INSTALLER
for installer in install-host-tools.sh install-rust-tools.sh install-ic-tools.sh; do
    cp "$fixture/installer" "$consumer/scripts/dev/$installer"
done
cat > "$consumer/scripts/ci/test-portable-tools.sh" <<'PORTABLE'
#!/usr/bin/env bash
set -euo pipefail
[[ "$CARGO_RELEASE_METADATA_EDITOR" == "$EDITOR_SETUP_PATH" && "$CARGO_RELEASE_METADATA_MAX_BYTES" == 8388608 ]] || exit 91
printf 'fixture-dispatched\n' >> "$EDITOR_SETUP_EVENTS"
exit "${EDITOR_FIXTURE_STATUS:-0}"
PORTABLE
: > "$EDITOR_SETUP_EVENTS"
make --no-print-directory -C "$consumer" install-tools > "$fixture/install.log" 2>&1
[[ "$(wc -l < "$EDITOR_SETUP_EVENTS")" -eq 5 ]] || exit 1
[[ "$(sed -n '1p' "$EDITOR_SETUP_EVENTS")" == install-rust-tools.sh*--preflight ]] || exit 1
[[ "$(sed -n '2p' "$EDITOR_SETUP_EVENTS")" == install-host-tools.sh* ]] || exit 1
[[ "$(sed -n '3p' "$EDITOR_SETUP_EVENTS")" == install-rust-tools.sh*--versions* ]] || exit 1
[[ "$(sed -n '4p' "$EDITOR_SETUP_EVENTS")" == install-ic-tools.sh* ]] || exit 1
[[ "$(sed -n '5p' "$EDITOR_SETUP_EVENTS")" == install-rust-tools.sh*--package\ ic-build* ]] || exit 1
: > "$EDITOR_SETUP_EVENTS"
make --no-print-directory -C "$consumer" tools-check > "$fixture/check.log" 2>&1
[[ "$(wc -l < "$EDITOR_SETUP_EVENTS")" -eq 4 ]] || exit 1
[[ "$(tail -n 1 "$EDITOR_SETUP_EVENTS")" == install-rust-tools.sh*--package\ ic-build*--check ]] || exit 1
status=0
EDITOR_SETUP_FAILURE=install make --no-print-directory -C "$consumer" install-release-editor \
    > "$fixture/install-failure.log" 2>&1 || status=$?
[[ "$status" != 0 ]] || exit 1
for mode in success check fixture; do
    : > "$EDITOR_SETUP_EVENTS"
    status=0
    failure='' fixture_status=0
    case "$mode" in check) failure=check ;; fixture) fixture_status=43 ;; esac
    EDITOR_SETUP_FAILURE="$failure" EDITOR_FIXTURE_STATUS="$fixture_status" \
        make --no-print-directory -C "$consumer" test-portable > "$fixture/$mode.log" 2>&1 || status=$?
    if [[ "$mode" == success ]]; then [[ "$status" == 0 ]] || exit 1; else [[ "$status" != 0 ]] || exit 1; fi
    [[ "$(head -n 1 "$EDITOR_SETUP_EVENTS")" == install-rust-tools.sh*--package\ ic-build*--check ]] || exit 1
    if [[ "$mode" == check ]]; then
        [[ "$(wc -l < "$EDITOR_SETUP_EVENTS")" -eq 1 ]] || exit 1
    else
        [[ "$(tail -n 1 "$EDITOR_SETUP_EVENTS")" == fixture-dispatched ]] || exit 1
    fi
done
# Execute the actual hosted gate with the fixture Makefile and real tee. A
# failed fixture must fail the pipeline while retaining its native gate log.
yq -o json '.jobs."portable-regression".steps' "$ROOT/.github/workflows/ci.yml" > "$fixture/steps.json"
bash "$ROOT/scripts/ci/extract-workflow-step.sh" "$fixture/steps.json" portable-tests > "$fixture/caller.sh"
mkdir "$fixture/runner"
status=0
(cd "$consumer" && RUNNER_TEMP="$fixture/runner" TMPDIR="$fixture/runner/scratch" EDITOR_FIXTURE_STATUS=43 \
    "$BASH" --noprofile --norc -e -o pipefail "$fixture/caller.sh") > "$fixture/caller.log" 2>&1 || status=$?
[[ "$status" != 0 && -s "$fixture/runner/portable-regression.log" ]] || exit 1
grep -F 'Error 43' "$fixture/runner/portable-regression.log" > /dev/null
fixture_complete=true
echo 'Shared editor setup/check, early refusal and native gate failure propagation passed'
