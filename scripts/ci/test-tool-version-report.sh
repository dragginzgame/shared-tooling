#!/usr/bin/env bash
# Shared companions: scripts/ci/report-tool-versions.sh scripts/ci/fixture-lifecycle.sh scripts/ci/prepare-script-fixture.sh
set -euo pipefail
root="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/tool-version-report.XXXXXX")"
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Failed tool report fixture retained"' EXIT
snapshot="$fixture/snapshot with spaces"
consumer="$fixture/consumer with spaces"
mkdir -p "$snapshot" "$consumer"
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$snapshot" scripts/ci/report-tool-versions.sh
export REPORT_CONSUMER="$consumer" REPORT_EVENTS="$fixture/events" REPORT_FAILURE=''
for kind in host rust ic; do
    mkdir -p "$consumer/$kind bin"
    cat > "$snapshot/scripts/dev/install-$kind-tools.sh" <<'INSTALL'
#!/usr/bin/env bash
set -eu
[[ "$1" == --consumer && "$2" == "$REPORT_CONSUMER" && "${!#}" == --check ]]
kind="${0##*/install-}"; kind="${kind%-tools.sh}"
[[ "$3" == --versions || ( "$kind" == ic && "$3" == --pins ) ]]
if [[ "$kind" == ic ]]; then
    shift 4
    [[ $# -ge 3 && $(( ($# - 1) % 2 )) == 0 ]]
    while [[ $# -gt 1 ]]; do [[ "$1" == --tool ]]; shift 2; done
else [[ $# == 5 ]]; fi
printf 'admit %s\n' "$kind" >> "$REPORT_EVENTS"
printf 'admission stderr %s\n' "$kind" >&2
if [[ "$REPORT_FAILURE" == "admit-$kind" ]]; then echo partial-admission; exit 37; fi
printf '%s/%s bin\n' "$REPORT_CONSUMER" "$kind"
INSTALL
    catalog="$snapshot/ci/tool-versions.env"
    [[ "$kind" != ic ]] || catalog="$snapshot/ci/ic-tools.tsv"
    records="$(perl "$snapshot/scripts/ci/tool-catalog-records.pl" "$kind" "$catalog")"
    previous=''
    while IFS=$'\t' read -r tool _; do
        [[ "$tool" != "$previous" ]] || continue
        previous="$tool"
        case "$tool" in RIPGREP) command=rg ;; *) command="$(printf '%s' "$tool" | tr '[:upper:]_' '[:lower:]-')" ;; esac
        cat > "$consumer/$kind bin/$command" <<'TOOL'
#!/usr/bin/env bash
set -eu
name="${0##*/}"
if [[ "$name" == cargo-sort-derives ]]; then
    [[ "$*" == 'sort-derives --version' ]]
else
    [[ "$*" == --version ]]
fi
printf 'probe %s\n' "$name" >> "$REPORT_EVENTS"
printf 'observed %s\n' "$name"
printf 'probe stderr %s\n' "$name" >&2
[[ "$REPORT_FAILURE" != "$name" ]] || exit 43
TOOL
        chmod +x "$consumer/$kind bin/$command"
    done <<< "$records"
done
# A PATH impostor must never supply the observations.
mkdir "$fixture/impostor"
printf '#!/bin/sh\nexit 99\n' > "$fixture/impostor/jq"
chmod +x "$fixture/impostor/jq"
PATH="$fixture/impostor:$PATH" bash "$snapshot/scripts/ci/report-tool-versions.sh" "$consumer" > "$fixture/report" 2> "$fixture/errors"
[[ "$(grep -c '^admit ' "$REPORT_EVENTS")" == 2 ]]
[[ "$(grep -c '^probe ' "$REPORT_EVENTS")" == 6 ]]
if grep -q '^admit ic$' "$REPORT_EVENTS"; then exit 1; fi
# A host/Rust-only report neither reads an IC catalog nor admits its executables.
mv "$snapshot/ci/ic-tools.tsv" "$snapshot/ci/ic-tools.saved"
: > "$REPORT_EVENTS"
bash "$snapshot/scripts/ci/report-tool-versions.sh" "$consumer" "$snapshot/ci/tool-versions.env" > "$fixture/common-only-report" 2> "$fixture/common-only-errors"
[[ "$(grep -c '^admit ' "$REPORT_EVENTS")" == 2 ]]
if grep -q '^admit ic$' "$REPORT_EVENTS"; then exit 1; fi
mv "$snapshot/ci/ic-tools.saved" "$snapshot/ci/ic-tools.tsv"
: > "$REPORT_EVENTS"
PATH="$fixture/impostor:$PATH" bash "$snapshot/scripts/ci/report-tool-versions.sh" "$consumer" \
    "$snapshot/ci/tool-versions.env" "$snapshot/ci/ic-tools.tsv" 'didc ic-wasm icp quill wasm-opt' > "$fixture/report" 2> "$fixture/errors"
[[ "$(grep -c '^admit ' "$REPORT_EVENTS")" == 3 ]]
[[ "$(grep -c '^probe ' "$REPORT_EVENTS")" == 11 ]]
for tool in jq yq rg cloc cargo-sort cargo-sort-derives icp didc ic-wasm quill wasm-opt; do
    [[ "$(grep -c "^probe $tool$" "$REPORT_EVENTS")" == 1 ]]
done
: > "$REPORT_EVENTS"
bash "$snapshot/scripts/ci/report-tool-versions.sh" "$consumer" \
    "$snapshot/ci/tool-versions.env" "$snapshot/ci/ic-tools.tsv" 'wasm-opt wasm-opt' > "$fixture/subset" 2> "$fixture/subset.err"
[[ "$(grep -c '^probe ' "$REPORT_EVENTS")" == 7 && "$(grep -c '^probe wasm-opt$' "$REPORT_EVENTS")" == 1 ]]
for tool in didc ic-wasm icp quill; do
    if grep -q "^probe $tool$" "$REPORT_EVENTS"; then exit 1; fi
done
for invalid in '' unknown; do
    : > "$REPORT_EVENTS"
    status=0
    bash "$snapshot/scripts/ci/report-tool-versions.sh" "$consumer" \
        "$snapshot/ci/tool-versions.env" "$snapshot/ci/ic-tools.tsv" "$invalid" > "$fixture/invalid.out" 2>&1 || status=$?
    [[ "$status" == 2 && ! -s "$REPORT_EVENTS" ]] || exit 1
done
digest="$(bash "$snapshot/scripts/ci/verify-file-checksum.sh" --print sha256 "$consumer/host bin/jq")"
grep -F "sha256=$digest" "$fixture/report" > /dev/null
for failure in admit-host admit-rust admit-ic jq cloc cargo-sort-derives wasm-opt; do
    : > "$REPORT_EVENTS"
    status=0
    REPORT_FAILURE="$failure" bash "$snapshot/scripts/ci/report-tool-versions.sh" "$consumer" "$snapshot/ci/tool-versions.env" "$snapshot/ci/ic-tools.tsv" 'didc ic-wasm icp quill wasm-opt' > "$fixture/$failure.out" 2> "$fixture/$failure.err" || status=$?
    case "$failure" in
        admit-*) [[ "$status" == 37 ]]; grep -Fx partial-admission "$fixture/$failure.out" > /dev/null ;;
        *) [[ "$status" == 43 ]]; grep -Fx "observed $failure" "$fixture/$failure.out" > /dev/null; grep -Fx "probe stderr $failure" "$fixture/$failure.err" > /dev/null ;;
    esac
    case "$failure" in admit-host|jq|cloc) ! grep -q 'admit rust' "$REPORT_EVENTS" ;; admit-rust|cargo-sort-derives) ! grep -q 'admit ic' "$REPORT_EVENTS" ;; esac
done
# Invalid catalogs refuse before admission; no implicit preparation is allowed.
# shellcheck disable=SC2016 # Invalid literal catalog must never execute.
printf 'export SHARED_TOOLING_JQ_VERSION=$(exit 99)\n' > "$snapshot/ci/tool-versions.env"
: > "$REPORT_EVENTS"
if bash "$snapshot/scripts/ci/report-tool-versions.sh" "$consumer" > "$fixture/catalog.out" 2> "$fixture/catalog.err"; then exit 1; fi
[[ ! -s "$REPORT_EVENTS" ]]
fixture_complete=true
echo 'common version report passed (admission and probes substituted)'
