#!/usr/bin/env bash
# Shared companions: scripts/ci/qualify-hosted-failure.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/hosted-failure.XXXXXX")"
fixture_complete=false
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
trap 'fixture_finish "$?" "$fixture" "Hosted failure fixture retained"' EXIT
mkdir "$fixture/consumer" "$fixture/evidence"
helper="$ROOT/scripts/ci/qualify-hosted-failure.sh"
for stage in early late; do
    status=0
    GITHUB_ACTIONS=true GITHUB_EVENT_NAME=workflow_dispatch GITHUB_WORKSPACE="$fixture/consumer" \
        RUNNER_TEMP="$fixture/evidence" bash "$helper" "$stage" "$fixture/consumer" \
        "$fixture/evidence" "$ROOT/ci/tool-versions.env" "$fixture/logs" \
        > "$fixture/$stage.log" 2>&1 || status=$?
    expected=22
    [[ "$stage" != late ]] || expected=2
    [[ "$status" == "$expected" ]] || { cat "$fixture/$stage.log" >&2; exit 1; }
    scenarios=("$fixture/evidence/hosted-$stage."*)
    [[ "${#scenarios[@]}" == 1 ]] || exit 1
    scenario="${scenarios[0]}"
    cmp "$scenario/before.txt" "$scenario/after.txt"
    grep -Fqx "status=$expected" "$scenario/status.txt"
    if [[ "$stage" == early ]]; then
        payloads=("$scenario/tool-store"/host-*/set.*/bin/jq)
        [[ "${#payloads[@]}" == 1 ]] || exit 1
        grep -Fqx 'controlled rejected download bytes' "${payloads[0]}"
    else
        grep -Fqx 'error: controlled late validation failure' "$fixture/logs/latest.log"
    fi
done
if GITHUB_ACTIONS=false bash "$helper" early "$fixture/consumer" "$fixture/evidence" \
    "$ROOT/ci/tool-versions.env" "$fixture/logs" >/dev/null 2>&1; then exit 1; fi
fixture_complete=true
echo 'Explicit hosted early/late failure stages preserve exact statuses and inputs'
