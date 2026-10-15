#!/usr/bin/env bash
# Shared companions: scripts/ci/qualify-hosted-failure.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/hosted-failure.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Hosted failure fixture retained"' EXIT
mkdir "$fixture/consumer" "$fixture/evidence"
helper="$ROOT/scripts/ci/qualify-hosted-failure.sh"
for stage in early late; do
    evidence="$fixture/missing $stage/nested"
    status=0
    GITHUB_ACTIONS=true GITHUB_EVENT_NAME=workflow_dispatch GITHUB_WORKSPACE="$fixture/consumer" \
        RUNNER_TEMP="$fixture/evidence" bash "$helper" "$stage" "$fixture/consumer" \
        "$evidence" "$ROOT/ci/tool-versions.env" "$fixture/logs" \
        > "$fixture/$stage.log" 2>&1 || status=$?
    expected=22
    [[ "$stage" != late ]] || expected=2
    [[ "$status" == "$expected" ]] || { cat "$fixture/$stage.log" >&2; exit 1; }
    scenarios=("$evidence/hosted-$stage."*)
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
# Relative paths, spaces and aliases retain a physically anchored scenario.
mkdir "$fixture/physical parent"
ln -s "$fixture/physical parent" "$fixture/alias"
status=0
(cd "$fixture" && GITHUB_ACTIONS=true GITHUB_EVENT_NAME=workflow_dispatch \
    GITHUB_WORKSPACE="$fixture/consumer" RUNNER_TEMP="$fixture/evidence" \
    "$BASH" "$helper" late "$fixture/consumer" alias/child \
    "$ROOT/ci/tool-versions.env" "$fixture/alias-logs") > "$fixture/alias.log" 2>&1 || status=$?
[[ "$status" == 2 ]] || exit 1
scenarios=("$fixture/physical parent/child/hosted-late."*)
[[ "${#scenarios[@]}" == 1 ]] || exit 1
grep -Fxq "Qualification scenario retained: ${scenarios[0]}" "$fixture/alias.log"
# Refusal must precede creation of even the missing evidence parent.
ln -s "$ROOT/ci/tool-versions.env" "$fixture/catalog-alias"
for refused in stage arguments manual event workspace catalog linked-catalog relative-catalog logs runner empty-runner empty-parent; do
    status=0
    (
        export GITHUB_ACTIONS=true GITHUB_EVENT_NAME=workflow_dispatch
        export GITHUB_WORKSPACE="$fixture/consumer" RUNNER_TEMP="$fixture/evidence"
        arguments=(early "$fixture/consumer" "$fixture/refused-$refused/missing" \
            "$ROOT/ci/tool-versions.env" "$fixture/refused-logs")
        case "$refused" in
            stage) arguments[0]=unsupported ;;
            arguments) arguments+=(extra) ;;
            manual) GITHUB_ACTIONS=false ;;
            event) GITHUB_EVENT_NAME=push ;;
            workspace) GITHUB_WORKSPACE="$fixture" ;;
            catalog) arguments[3]="$fixture/missing-catalog" ;;
            linked-catalog) arguments[3]="$fixture/catalog-alias" ;;
            relative-catalog) arguments[3]=ci/tool-versions.env ;;
            logs) arguments[4]=relative-logs ;;
            runner) unset RUNNER_TEMP ;;
            empty-runner) RUNNER_TEMP='' ;;
            empty-parent) arguments[2]='' ;;
        esac
        "$BASH" "$helper" "${arguments[@]}"
    ) > "$fixture/refused-$refused.log" 2>&1 || status=$?
    [[ "$status" != 0 && ! -e "$fixture/refused-$refused" && ! -e "$fixture/refused-logs" ]] || exit 1
done
fixture_complete=true
echo 'Explicit hosted early/late failure stages preserve exact statuses and inputs'
