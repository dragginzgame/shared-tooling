#!/usr/bin/env bash
# Shared companions: .github/actions/prepare-common-tools/action.yml .github/workflows/ci.yml scripts/ci/fixture-lifecycle.sh scripts/ci/extract-workflow-step.sh scripts/ci/prepare-script-fixture.sh scripts/ci/tool-catalog-records.pl ci/tool-versions.env make/tools.mk
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
unset VALIDATION_REPOSITORY_ROOT VALIDATION_RUNNER_SNAPSHOT_PATH
ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/prepare-common-tools.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Common tool preparation fixture retained"' EXIT
yq -o json '.' "$ROOT/.github/actions/prepare-common-tools/action.yml" > "$fixture/prepare-action.json"
jq -e '
    .runs.using == "composite" and (.runs.steps | length) == 1 and
    .runs.steps[0].shell == "/bin/bash --noprofile --norc -e -o pipefail {0}"
' "$fixture/prepare-action.json" > /dev/null
jq -e '.runs.steps' "$fixture/prepare-action.json" > "$fixture/prepare-steps.json"
bash "$ROOT/scripts/ci/extract-workflow-step.sh" "$fixture/prepare-steps.json" prepare-tools > "$fixture/prepare-action.sh"
mkdir -p "$fixture/prepare-bin" "$fixture/prepare runner" "$fixture/prepare checkout"
cat > "$fixture/prepare-bin/make" <<'MAKE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$PREPARE_CALLS"
printf '%s stdout\n' "$*"
printf '%s stderr\n' "$*" >&2
case "$*" in
    install-tools) exit "$PREPARE_INSTALL_STATUS" ;;
    tools-check) exit "$PREPARE_CHECK_STATUS" ;;
    *) exit 99 ;;
esac
MAKE
chmod +x "$fixture/prepare-bin/make"
for failure in success install check; do
    install_status=0 check_status=0 expected=0
    case "$failure" in
        install) install_status=37 expected=37 ;;
        check) check_status=41 expected=41 ;;
    esac
    rm -f "$fixture/prepare runner/tools-install.log" "$fixture/prepare runner/tools-check.log"
    : > "$fixture/prepare-calls"
    printf 'existing PATH entry\n' > "$fixture/prepare-path"
    prepare_status=0
    PATH="$fixture/prepare-bin:$PATH" PREPARE_CALLS="$fixture/prepare-calls" \
        PREPARE_INSTALL_STATUS="$install_status" PREPARE_CHECK_STATUS="$check_status" \
        RUNNER_TEMP="$fixture/prepare runner" GITHUB_WORKSPACE="$fixture/prepare checkout" \
        GITHUB_PATH="$fixture/prepare-path" \
        "$BASH" --noprofile --norc -e -o pipefail "$fixture/prepare-action.sh" \
        > "$fixture/prepare-$failure.log" 2>&1 || prepare_status=$?
    [[ "$prepare_status" == "$expected" ]] || exit 1
    printf 'install-tools stdout\ninstall-tools stderr\n' > "$fixture/expected-install.log"
    cmp "$fixture/expected-install.log" "$fixture/prepare runner/tools-install.log"
    printf 'install-tools\n' > "$fixture/expected-calls"
    printf 'existing PATH entry\n' > "$fixture/expected-path"
    if [[ "$failure" == install ]]; then
        [[ ! -e "$fixture/prepare runner/tools-check.log" ]] || exit 1
    else
        printf 'tools-check\n' >> "$fixture/expected-calls"
        printf 'tools-check stdout\ntools-check stderr\n' > "$fixture/expected-check.log"
        cmp "$fixture/expected-check.log" "$fixture/prepare runner/tools-check.log"
    fi
    if [[ "$failure" == success ]]; then
        printf '%s\n' "$fixture/prepare checkout/.tools/host/bin" \
            "$fixture/prepare checkout/.tools/rust/common/bin" \
            >> "$fixture/expected-path"
    fi
    cmp "$fixture/expected-calls" "$fixture/prepare-calls"
    cmp "$fixture/expected-path" "$fixture/prepare-path"
done
# Exercise the real shared Make aggregate beneath the action. Only installer
# leaves are substituted; no download, store mutation or Cargo build is selected.
aggregate="$fixture/aggregate checkout"
mkdir -p "$aggregate/scripts/dev"
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$aggregate" make/tools.mk
# shellcheck disable=SC2016 # Make expands its own checkout path.
printf 'override SHARED_TOOLING_ROOT := $(CURDIR)\ninclude make/tools.mk\n' > "$aggregate/Makefile"
for tool in host ic rust; do
    cat > "$aggregate/scripts/dev/install-$tool-tools.sh" <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail
phase="${0##*/}"
phase="${phase%.sh}"
case "${!#}" in
    --preflight) phase="$phase-preflight" ;;
    --check) phase="${phase#install-}"; phase="${phase%-tools}-tools-check" ;;
esac
printf '%s\n' "$phase" >> "$PREPARE_CALLS"
printf '%s stdout\n' "$phase"
printf '%s stderr\n' "$phase" >&2
[[ "$phase" != "$PREPARE_FAILURE" ]] || exit 43
INSTALLER
done
export PREPARE_REAL_MAKE
PREPARE_REAL_MAKE="$(command -v make)"
cat > "$fixture/prepare-bin/make" <<'MAKE'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == --no-print-directory ]]; then shift; fi
case "$*" in install-tools|tools-check) printf '%s\n' "$*" >> "$PREPARE_CALLS" ;; esac
exec "$PREPARE_REAL_MAKE" --no-print-directory "$@" "MAKE=$0" "MAKE_COMMAND=$PREPARE_REAL_MAKE"
MAKE
for selection in common ic; do
    unset LOCAL_TOOL_INSTALL_TARGETS LOCAL_TOOL_CHECK_TARGETS
    phases=(install-tools install-rust-tools-preflight install-host-tools install-rust-tools
            tools-check host-tools-check rust-tools-check)
    failures=(success install-rust-tools-preflight install-host-tools install-rust-tools
              host-tools-check rust-tools-check)
    if [[ "$selection" == ic ]]; then
        export LOCAL_TOOL_INSTALL_TARGETS=install-ic-tools LOCAL_TOOL_CHECK_TARGETS=ic-tools-check
        phases=(install-tools install-rust-tools-preflight install-host-tools install-rust-tools install-ic-tools
                tools-check host-tools-check rust-tools-check ic-tools-check)
        failures+=(install-ic-tools ic-tools-check)
    fi
    for failure in "${failures[@]}"; do
        rm -f "$fixture/prepare runner/tools-install.log" "$fixture/prepare runner/tools-check.log"
        : > "$fixture/prepare-calls"
        printf 'existing PATH entry\n' > "$fixture/prepare-path"
        prepare_status=0
        (cd "$aggregate" && PATH="$fixture/prepare-bin:$PATH" \
            PREPARE_CALLS="$fixture/prepare-calls" PREPARE_FAILURE="$failure" \
            RUNNER_TEMP="$fixture/prepare runner" GITHUB_WORKSPACE="$aggregate" \
            GITHUB_PATH="$fixture/prepare-path" \
            "$BASH" --noprofile --norc -e -o pipefail "$fixture/prepare-action.sh") \
            > "$fixture/aggregate-$failure.log" 2>&1 || prepare_status=$?
        expected=2
        [[ "$failure" != success ]] || expected=0
        [[ "$prepare_status" == "$expected" ]] || exit 1
        : > "$fixture/expected-calls"
        log=tools-install.log
        for phase in "${phases[@]}"; do
            printf '%s\n' "$phase" >> "$fixture/expected-calls"
            if [[ "$phase" == tools-check ]]; then log=tools-check.log; fi
            case "$phase" in
                install-tools|tools-check) ;;
                *) grep -Fx "$phase stdout" "$fixture/prepare runner/$log" > /dev/null
                   grep -Fx "$phase stderr" "$fixture/prepare runner/$log" > /dev/null ;;
            esac
            if [[ "$phase" == "$failure" ]]; then break; fi
        done
        cmp "$fixture/expected-calls" "$fixture/prepare-calls"
        if [[ "$log" == tools-install.log ]]; then
            [[ ! -e "$fixture/prepare runner/tools-check.log" ]] || exit 1
        fi
        printf 'existing PATH entry\n' > "$fixture/expected-path"
        if [[ "$failure" == success ]]; then
            printf '%s\n' "$aggregate/.tools/host/bin" \
                "$aggregate/.tools/rust/common/bin" >> "$fixture/expected-path"
        fi
        cmp "$fixture/expected-path" "$fixture/prepare-path"
    done
done
unset LOCAL_TOOL_INSTALL_TARGETS LOCAL_TOOL_CHECK_TARGETS
# Reject forbidden raw and resolved directories before publishing any payload.
mkdir "$fixture/clean-output"
for suffix in $'\n' $'\r' $'\r\n'; do
    forbidden="$fixture/forbidden$suffix"
    mkdir "$forbidden"
    ln -s "$forbidden" "$fixture/directory-alias"
    for selected in "$forbidden" "$fixture/directory-alias"; do
        status=0
        bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$selected" make/tools.mk \
            > "$fixture/rejected-output.log" 2>&1 || status=$?
        [[ "$status" == 2 && ! -e "$forbidden/make" && ! -e "$forbidden/scripts" ]] || exit 1
    done
    # A complete source distinguishes path rejection from missing-input refusal.
    mkdir -p "$forbidden/scripts/ci"
    cp -Rp "$ROOT/make" "$forbidden/"
    cp -p "$ROOT/scripts/ci/check-make-execution.sh" "$ROOT/scripts/ci/run-formatting.sh" "$forbidden/scripts/ci/"
    for selected in "$forbidden" "$fixture/directory-alias"; do
        status=0
        bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$selected" "$fixture/clean-output" make/tools.mk \
            > "$fixture/rejected-source.log" 2>&1 || status=$?
        [[ "$status" == 2 && ! -e "$fixture/clean-output/make" ]] || exit 1
    done
    rm "$fixture/directory-alias"
done
# Execute the native CI reuse caller with substitute installers and real path
# observations. Missing tools in both checkouts must not compare as equal.
reuse="$fixture/reuse checkout"
mkdir -p "$reuse/scripts/dev" "$reuse/native-store/host" "$reuse/native-store/ic" \
    "$reuse/native-store/rust/bin" "$reuse/different/bin" "$reuse/.tools/rust/common"
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$reuse" \
    scripts/ci/tool-catalog-records.pl ci/tool-versions.env
records="$(perl "$ROOT/scripts/ci/tool-catalog-records.pl" rust "$ROOT/ci/tool-versions.env")"
selected_tool=''
while IFS=$'\t' read -r name _; do
    tool="$(printf '%s' "$name" | tr '[:upper:]_' '[:lower:]-')"
    [[ -n "$selected_tool" ]] || selected_tool="$tool"
    printf '#!/bin/sh\nexit 0\n' > "$reuse/native-store/rust/bin/$tool"
    chmod +x "$reuse/native-store/rust/bin/$tool"
done <<< "$records"
cp -Rp "$reuse/native-store/rust/bin/." "$reuse/different/bin/"
ln -s "$reuse/native-store/host" "$reuse/.tools/host"
ln -s "$reuse/native-store/ic" "$reuse/.tools/ic"
ln -s "$reuse/native-store/rust/bin" "$reuse/.tools/rust/common/bin"
for kind in host ic rust; do
    cat > "$reuse/scripts/dev/install-$kind-tools.sh" <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail
kind="${0##*/install-}"; kind="${kind%-tools.sh}"
consumer="$2"
[[ "$1" == --consumer && "$consumer" == "$RUNNER_TEMP/portable-fixtures/shared-tools/consumer" ]] || exit 99
if [[ "${!#}" == --check ]]; then
    if [[ "$kind" == rust ]]; then
        case "$NATIVE_REUSE_CASE" in
            missing) rm "$NATIVE_REUSE_STORE/rust/bin/$NATIVE_REUSE_TOOL" ;;
            dangling) rm "$NATIVE_REUSE_STORE/rust/bin/$NATIVE_REUSE_TOOL"
                      ln -s missing "$NATIVE_REUSE_STORE/rust/bin/$NATIVE_REUSE_TOOL" ;;
            nonexecutable) chmod -x "$NATIVE_REUSE_STORE/rust/bin/$NATIVE_REUSE_TOOL" ;;
            different) rm "$consumer/.tools/rust/common/bin"
                       ln -s "$GITHUB_WORKSPACE/different/bin" "$consumer/.tools/rust/common/bin" ;;
            check-failure) exit 37 ;;
        esac
    fi
else
    mkdir -p "$consumer/.tools"
    if [[ "$kind" == rust ]]; then
        mkdir -p "$consumer/.tools/rust/common"
        ln -s "$NATIVE_REUSE_STORE/rust/bin" "$consumer/.tools/rust/common/bin"
    else ln -s "$NATIVE_REUSE_STORE/$kind" "$consumer/.tools/$kind"; fi
fi
INSTALLER
done
yq -o json '.' "$ROOT/.github/workflows/ci.yml" | jq -e '[.jobs[].steps[]]' > "$fixture/native-steps.json"
bash "$ROOT/scripts/ci/extract-workflow-step.sh" "$fixture/native-steps.json" native-tool-reuse > "$fixture/native-reuse.sh"
for scenario in success missing dangling nonexecutable different check-failure invalid-catalog; do
    attempt="$fixture/reuse-$scenario"
    mkdir "$attempt"
    cp -p "$reuse/different/bin/$selected_tool" "$reuse/native-store/rust/bin/$selected_tool"
    cp -p "$ROOT/ci/tool-versions.env" "$reuse/ci/tool-versions.env"
    if [[ "$scenario" == invalid-catalog ]]; then printf 'not a catalog\n' > "$reuse/ci/tool-versions.env"; fi
    status=0
    (cd "$reuse" && NATIVE_REUSE_CASE="$scenario" NATIVE_REUSE_STORE="$reuse/native-store" \
        NATIVE_REUSE_TOOL="$selected_tool" RUNNER_TEMP="$attempt" GITHUB_WORKSPACE="$reuse" \
        "$BASH" --noprofile --norc -e -o pipefail "$fixture/native-reuse.sh") \
        > "$fixture/reuse-$scenario.log" 2>&1 || status=$?
    case "$scenario" in
        success) [[ "$status" == 0 ]] || exit 1 ;;
        check-failure) [[ "$status" == 37 ]] || exit 1 ;;
        *) [[ "$status" != 0 ]] || exit 1 ;;
    esac
    # A failed symlink observation is retained; restore only this fixture's input.
    rm -f "$reuse/native-store/rust/bin/$selected_tool"
done
fixture_complete=true
printf 'Common preparation ordering, status, logs, PATH and native reuse checks passed\n'
