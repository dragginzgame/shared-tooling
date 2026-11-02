#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/ci/run-validation-targets.sh
set -euo pipefail
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
mkdir -p "$root/target"
fixture="$(fixture_create "$root/target/release-validation-plan.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Release validation plan fixture retained"' EXIT
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
unset VALIDATION_INPUT_ROOT VALIDATION_INPUT_BASELINE VALIDATION_RUNNER_SNAPSHOT_PATH GITHUB_STEP_SUMMARY
mkdir -p "$fixture/source/ci" "$fixture/logs"
cd "$fixture/source"
git init -q
git config user.name Fixture
git config user.email fixture@example.invalid
cat > Makefile <<'MAKE'
.PHONY: lint client runtime
lint:
	@echo lint >> trace
	@if test -f drift; then echo changed >> configuration; fi
	@if test -f drift-plan; then echo ' ' >> plan.json; fi
	@if test -f drift-policy; then echo ' ' >> ci/validation.json; fi
	@if test -f move-source; then git -c core.hooksPath=/dev/null commit --allow-empty -qm moved; fi
	@if test -f interrupt; then kill -TERM $$PPID; fi
client:
	@echo client >> trace
	@test ! -f fail-client
runtime:
	@echo runtime >> trace
	@test ! -f fail-runtime
MAKE
printf 'client-only\n' > configuration
jq -cnS '{schema:1,groups:["client","runtime"],stages:["lint","client","runtime"]}' > ci/validation.json
git add Makefile configuration ci/validation.json
git -c core.hooksPath=/dev/null commit -qm fixture
export RELEASE_SOURCE RELEASE_GROUP=client
RELEASE_SOURCE="$(git rev-parse HEAD)"
export VALIDATION_REPOSITORY_ROOT="$PWD" VALIDATION_LOG_DIR="$fixture/logs" VALIDATION_FAILURE_LOG_DIR="$fixture/failures"
plan() {
    # Example consumer selector: shared configuration broadens to the full roster.
    local scope=group
    [[ "$(cat configuration)" == client-only ]] || scope=workspace
    jq -cnS --arg source "$RELEASE_SOURCE" --arg group "$RELEASE_GROUP" --arg scope "$scope" \
        '{schema:1,source:$source,group:$group,scope:$scope,policy:"ci/validation.json",
        inputs:["Makefile","configuration"],stages:[
        {target:"lint",required:true,reason:"common policy"},
        {target:"client",required:($scope == "workspace" or $group == "client"),reason:"client boundary"},
        {target:"runtime",required:($scope == "workspace" or $group == "runtime"),reason:"runtime boundary"}]}' > plan.json
}
run() { bash "$root/scripts/ci/run-validation-targets.sh" --plan plan.json > "$fixture/latest.log" 2>&1; }
refuse() { if run; then echo 'unexpected plan success' >&2; exit 1; fi; }
edit_plan() { jq -cS "$1" plan.json > candidate.json; mv candidate.json plan.json; }
plan
: > fail-runtime
run
[[ "$(cat trace)" == $'lint\nclient' ]]
rg -q $'runtime\tnot-applicable' "$fixture/logs"
snapshots=("$fixture/logs"/validation.*/parsed-inputs.json.plan.json)
jq -e --arg source "$RELEASE_SOURCE" '.source == $source and .group == "client"' "${snapshots[0]}" > /dev/null
# A required failure blocks later work; unrelated failed targets were never run.
: > fail-client
refuse
rg -q $'client\tFAIL' "$fixture/logs"
rm fail-client fail-runtime trace
# Select the other group and broaden when shared configuration changes.
RELEASE_GROUP=runtime plan
RELEASE_GROUP=runtime run
[[ "$(cat trace)" == $'lint\nruntime' ]]
rm trace
printf 'shared-change\n' > configuration
plan
run
[[ "$(cat trace)" == $'lint\nclient\nruntime' ]]
# Same-source synthetic full gate: all commands match the broad plan's roster.
cp trace "$fixture/broad-trace"
rm trace
bash "$root/scripts/ci/run-validation-targets.sh" --fail-fast lint client runtime > "$fixture/full.log" 2>&1
cmp trace "$fixture/broad-trace"
printf 'client-only\n' > configuration
# Every malformed plan must refuse before dispatch.
for mutation in '.source="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' '.group="unknown"' \
    '.schema=2' '.schema="1"' '.extra=true' '.stages |= .[:-1]' \
    '.stages += [.stages[0]]' '.stages[0].target="unlisted"' \
    '.stages[0].required="true"' '.stages[0].reason=""' '.scope="workspace"' \
    '.inputs=["../escape"]'; do
    plan; edit_plan "$mutation"; rm -f trace; refuse; [[ ! -e trace ]]
done
# Unknown admitted group, missing inputs, redirected policy and duplicate JSON keys.
RELEASE_GROUP=unknown plan
RELEASE_GROUP=unknown refuse
plan; edit_plan '.inputs += ["missing"]'; refuse
mv ci/validation.json ci/original.json
ln -s original.json ci/validation.json
plan; refuse
rm ci/validation.json
mv ci/original.json ci/validation.json
plan
perl -pi -e 's/"schema":1/"schema":1,"schema":1/' plan.json
refuse
# Drift halts dispatch, and an interrupted run is not a successful receipt.
plan; : > drift; rm -f trace; refuse
[[ "$(cat trace)" == lint ]]
rm drift
printf 'client-only\n' > configuration
for marker in drift-plan drift-policy; do
    cp ci/validation.json "$fixture/policy.saved"
    plan; : > "$marker"; rm -f trace; refuse
    [[ "$(cat trace)" == lint ]]
    rm "$marker"
    cp "$fixture/policy.saved" ci/validation.json
done
plan; : > interrupt; rm trace; refuse
[[ "$(cat trace)" == lint ]]
rm interrupt
# Moving HEAD invalidates the selected source even if declared files stay equal.
plan; : > move-source; rm trace; refuse
[[ "$(cat trace)" == lint ]]
rm move-source
rm trace
refuse
[[ ! -e trace ]]
# Fresh source and plan recover; old attempt logs are retained.
RELEASE_SOURCE="$(git rev-parse HEAD)"
plan; run
[[ "$(cat trace)" == $'lint\nclient' ]]
fixture_complete=true
printf 'Release validation plan fixtures passed\n'
