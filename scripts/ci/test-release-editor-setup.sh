#!/usr/bin/env bash
# Shared companions: Makefile make/consumer.mk scripts/release/metadata.sh scripts/ci/prepare-script-fixture.sh scripts/ci/fixture-lifecycle.sh scripts/ci/extract-workflow-step.sh .github/workflows/ci.yml
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
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$consumer" Makefile make/consumer.mk scripts/release/metadata.sh
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
# Qualify the actual release entrypoint, runner, metadata adapter and ordered
# aggregates. Only installers and the expensive validation gate are substitutes.
unset SHARED_RELEASE_PREPARE_TOOLS RELEASE_MAKE RELEASE_DELIVERY
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
cat > "$consumer/scripts/ci/run-validation-targets.sh" <<'GATE'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == ci && -z "${SHARED_RELEASE_PREPARE_TOOLS+x}" ]] || exit 91
printf 'release-gate\n' >> "$EDITOR_SETUP_EVENTS"
exit "${EDITOR_RELEASE_GATE_STATUS:-43}"
GATE
cp "$consumer/scripts/release/metadata.sh" "$consumer/scripts/release/fixture-metadata.sh"
cat > "$consumer/scripts/release/metadata.sh" <<'METADATA'
#!/usr/bin/env bash
set -euo pipefail
# Leave exact intent at prepare without changing metadata or delivering a ref.
[[ "$1" != prepare ]] || exit 59
exec bash "${BASH_SOURCE[0]%/*}/fixture-metadata.sh" "$@"
METADATA
printf '0.1.0\n' > "$consumer/VERSION"
printf '# Changelog\n\n## [0.1.1]\n\n- Fixture release.\n' > "$consumer/CHANGELOG.md"
git init --quiet "$consumer"
git -C "$consumer" symbolic-ref HEAD refs/heads/main
git -C "$consumer" -c core.hooksPath=/dev/null add -- .
git -C "$consumer" -c user.name=Fixture -c user.email=fixture@example.invalid \
    -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --quiet -m 'Fixture release inputs'
git init --quiet --bare "$fixture/destination.git"
git -C "$consumer" remote add origin "$fixture/destination.git"
source_commit="$(git -C "$consumer" rev-parse HEAD)"
for refusal in source candidate; do
    : > "$EDITOR_SETUP_EVENTS"
    target=release-minor
    if [[ "$refusal" == source ]]; then
        target=release-patch
        printf 'unrelated input\n' > "$consumer/unrelated"
    fi
    status=0
    make --no-print-directory -C "$consumer" "$target" > "$fixture/refuse-$refusal.log" 2>&1 || status=$?
    [[ "$status" != 0 && ! -s "$EDITOR_SETUP_EVENTS" ]] || exit 1
    [[ "$refusal" != source ]] || rm "$consumer/unrelated"
done
mkdir "$fixture/compare-failure-bin"
printf '#!/bin/sh\nexit 37\n' > "$fixture/compare-failure-bin/cmp"
chmod +x "$fixture/compare-failure-bin/cmp"
: > "$EDITOR_SETUP_EVENTS"
status=0
PATH="$fixture/compare-failure-bin:$PATH" make --no-print-directory -C "$consumer" release-patch \
    > "$fixture/compare-failure.log" 2>&1 || status=$?
[[ "$status" != 0 && ! -s "$EDITOR_SETUP_EVENTS" ]] || exit 1
for mode in install check success; do
    : > "$EDITOR_SETUP_EVENTS"
    status=0
    failure="$mode"; [[ "$mode" != success ]] || failure=''
    EDITOR_SETUP_FAILURE="$failure" make --no-print-directory -j2 -C "$consumer" release-patch \
        > "$fixture/release-$mode.log" 2>&1 || status=$?
    [[ "$status" != 0 ]] || exit 1
    [[ "$(sed -n '1p' "$EDITOR_SETUP_EVENTS")" == install-rust-tools.sh*--preflight ]] || exit 1
    if [[ "$mode" == success ]]; then
        [[ "$(tail -n 1 "$EDITOR_SETUP_EVENTS")" == release-gate ]] || exit 1
        [[ "$(wc -l < "$EDITOR_SETUP_EVENTS")" -eq 10 ]] || exit 1
    else
        if grep -F 'release-gate' "$EDITOR_SETUP_EVENTS" >/dev/null; then exit 1; fi
    fi
    [[ "$(git -C "$consumer" rev-parse HEAD)" == "$source_commit" &&
       "$(cat "$consumer/VERSION")" == 0.1.0 && -z "$(git -C "$consumer" tag --list)" ]] || exit 1
done
# Standalone preflight admits only; no preparation authority escapes the adapter.
: > "$EDITOR_SETUP_EVENTS"
make --no-print-directory -C "$consumer" release-preflight RELEASE_PREVIOUS=0.1.0 \
    RELEASE_VERSION=0.1.1 RELEASE_DATE=2026-10-19 > "$fixture/standalone-preflight.log" 2>&1
[[ "$(wc -l < "$EDITOR_SETUP_EVENTS")" -eq 4 ]] || exit 1
if grep -F -- --preflight "$EDITOR_SETUP_EVENTS" >/dev/null; then exit 1; fi
# A passing substitute gate creates real saved intent. Both the same invocation's
# second preflight and its retry must remain check-only at preparation recovery.
: > "$EDITOR_SETUP_EVENTS"
status=0
EDITOR_RELEASE_GATE_STATUS=0 make --no-print-directory -C "$consumer" release-patch \
    > "$fixture/prepare-stop.log" 2>&1 || status=$?
[[ "$status" != 0 && -f "$consumer/.git/release-state/0.1.1.plan" ]] || exit 1
[[ "$(tail -n 1 "$consumer/.git/release-state/0.1.1.plan")" == prepare ]] || exit 1
[[ "$(wc -l < "$EDITOR_SETUP_EVENTS")" -eq 14 ]] || exit 1
: > "$EDITOR_SETUP_EVENTS"
status=0
make --no-print-directory -C "$consumer" release-resume VERSION=0.1.1 \
    > "$fixture/prepare-retry.log" 2>&1 || status=$?
[[ "$status" != 0 && "$(wc -l < "$EDITOR_SETUP_EVENTS")" -eq 4 ]] || exit 1
[[ "$(git -C "$consumer" rev-parse HEAD)" == "$source_commit" &&
   "$(cat "$consumer/VERSION")" == 0.1.0 && -z "$(git -C "$consumer" tag --list)" ]] || exit 1
[[ -z "$(git --git-dir="$fixture/destination.git" for-each-ref --format='%(refname)')" ]] || exit 1
# PR qualification prepares the exact merged source before its new gate. The
# standalone form only checks; a selected old commit must not prepare tools.
printf '0.1.1\n' > "$consumer/VERSION"
printf '# Changelog\n\n## [0.1.1] - 2026-10-19\n\n- Fixture release.\n' > "$consumer/CHANGELOG.md"
git -C "$consumer" add -- VERSION CHANGELOG.md
git -C "$consumer" -c user.name=Fixture -c user.email=fixture@example.invalid \
    -c core.hooksPath=/dev/null -c commit.gpgSign=false commit --quiet -m 'Fixture merged metadata'
merged_commit="$(git -C "$consumer" rev-parse HEAD)"
for authority in 0 1; do
    : > "$EDITOR_SETUP_EVENTS"
    SHARED_RELEASE_PREPARE_TOOLS="$authority" make --no-print-directory -C "$consumer" release-merged-preflight \
        RELEASE_PREVIOUS=0.1.0 RELEASE_VERSION=0.1.1 RELEASE_DATE=2026-10-19 RELEASE_COMMIT="$merged_commit" \
        > "$fixture/merged-$authority.log" 2>&1
    expected=4; [[ "$authority" != 1 ]] || expected=9
    [[ "$(wc -l < "$EDITOR_SETUP_EVENTS")" -eq "$expected" ]] || exit 1
done
: > "$EDITOR_SETUP_EVENTS"
status=0
SHARED_RELEASE_PREPARE_TOOLS=1 make --no-print-directory -C "$consumer" release-merged-preflight \
    RELEASE_PREVIOUS=0.1.0 RELEASE_VERSION=0.1.1 RELEASE_DATE=2026-10-19 RELEASE_COMMIT="$source_commit" \
    > "$fixture/merged-wrong-source.log" 2>&1 || status=$?
[[ "$status" != 0 && ! -s "$EDITOR_SETUP_EVENTS" ]] || exit 1
# Even without intent, finalized notes plus old VERSION indicate interrupted
# preparation. Preserve the saved plan while qualifying that conservative check.
mv "$consumer/.git/release-state/0.1.1.plan" "$fixture/original.plan"
printf '0.1.0\n' > "$consumer/VERSION"
: > "$EDITOR_SETUP_EVENTS"
SHARED_RELEASE_PREPARE_TOOLS=1 make --no-print-directory -C "$consumer" release-preflight \
    RELEASE_PREVIOUS=0.1.0 RELEASE_VERSION=0.1.1 RELEASE_DATE=2026-10-19 \
    > "$fixture/finalized-notes.log" 2>&1
[[ "$(wc -l < "$EDITOR_SETUP_EVENTS")" -eq 4 ]] || exit 1
fixture_complete=true
echo 'Shared editor setup, release preflight/recovery and native gate failure propagation passed'
