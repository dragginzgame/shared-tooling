#!/usr/bin/env bash
# Shared companions: scripts/ci/run-formatting.sh scripts/ci/select-rust-formatting-sources.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd -P)"
mkdir -p "$root/target/tmp"
fixture=$(mktemp -d "$root/target/tmp/scratch-ownership.XXXXXX")
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Scratch ownership evidence retained"' EXIT
mkdir "$fixture/consumer with spaces"
cd "$fixture/consumer with spaces"
unset TMPDIR RUNNER_TEMP
for selection in default tmp runner; do
    unset TMPDIR RUNNER_TEMP
    expected="$PWD/target/tmp"
    if [[ "$selection" == tmp ]]; then export TMPDIR='relative temp'; expected="$PWD/$TMPDIR"; fi
    if [[ "$selection" == runner ]]; then
        export TMPDIR='unused temp' RUNNER_TEMP='relative runner'; expected="$PWD/$RUNNER_TEMP"
    fi
    status=0
    bash "$root/scripts/ci/run-formatting.sh" --check bash -c 'echo diagnostic; exit 43' > "$fixture/$selection.log" 2>&1 || status=$?
    [[ "$status" == 43 ]]
    logs=("$expected"/formatting.*)
    [[ ${#logs[@]} == 1 ]]
    grep -qx diagnostic "${logs[0]}"
    bash "$root/scripts/ci/run-formatting.sh" --write true > /dev/null
    [[ -f "${logs[0]}" ]]
done
unset TMPDIR RUNNER_TEMP
# Early Git failure retains evidence under the explicitly selected consumer.
status=0
GIT_CEILING_DIRECTORIES="$fixture" bash "$root/scripts/ci/select-rust-formatting-sources.sh" "$PWD" > "$fixture/list" 2> "$fixture/error" || status=$?
[[ "$status" != 0 && ! -s "$fixture/list" ]]
grep -F "$PWD/target/tmp/rust-formatting-sources." "$fixture/error"
fixture_complete=true
echo 'Consumer scratch defaults, relative overrides and failure custody passed'
