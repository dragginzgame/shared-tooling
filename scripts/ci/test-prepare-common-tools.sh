#!/usr/bin/env bash
# Shared companions: .github/actions/prepare-common-tools/action.yml scripts/ci/fixture-lifecycle.sh scripts/ci/extract-workflow-step.sh scripts/ci/prepare-make-fixture.sh
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
bash "$ROOT/scripts/ci/prepare-make-fixture.sh" "$ROOT" "$aggregate"
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
        bash "$ROOT/scripts/ci/prepare-make-fixture.sh" "$ROOT" "$selected" \
            > "$fixture/rejected-output.log" 2>&1 || status=$?
        [[ "$status" == 2 && ! -e "$forbidden/make" && ! -e "$forbidden/scripts" ]] || exit 1
    done
    # A complete source distinguishes path rejection from missing-input refusal.
    mkdir -p "$forbidden/scripts/ci"
    cp -Rp "$ROOT/make" "$forbidden/"
    cp -p "$ROOT/scripts/ci/check-make-execution.sh" "$ROOT/scripts/ci/run-formatting.sh" "$forbidden/scripts/ci/"
    for selected in "$forbidden" "$fixture/directory-alias"; do
        status=0
        bash "$ROOT/scripts/ci/prepare-make-fixture.sh" "$selected" "$fixture/clean-output" \
            > "$fixture/rejected-source.log" 2>&1 || status=$?
        [[ "$status" == 2 && ! -e "$fixture/clean-output/make" ]] || exit 1
    done
    rm "$fixture/directory-alias"
done
fixture_complete=true
printf 'Common tool preparation ordering, status, logs and PATH checks passed\n'
