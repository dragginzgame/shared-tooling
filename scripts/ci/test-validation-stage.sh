#!/usr/bin/env bash
# Shared companions: scripts/ci/run-validation-stage.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/validation-stage.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Validation stage fixture retained"' EXIT
mkdir -p "$fixture/source with spaces/inputs" "$fixture/home"
cd "$fixture/source with spaces"
printf 'source\n' > inputs/source
printf '{"features":"default","native":"fixture"}\n' > configuration.json
jq -cnS --arg path "$PATH" --arg home "$fixture/home" '{PATH:$path,HOME:$home,LC_ALL:"C"}' > environment.json
cat > observe.sh <<'SH'
#!/usr/bin/env bash
# Deliberate fault injection below qualifies mechanisms, not a reusable contract.
set -euo pipefail
phase=0
[[ ! -f observation-count ]] || phase="$(cat observation-count)"
phase=$((phase+1))
printf '%s\n' "$phase" > observation-count
if [[ -f drift-admission && "$phase" == 2 ]]; then printf 'drift\n' >> inputs/source; fi
if [[ -f corrupt-proof && "$phase" == 2 ]]; then printf '\n' >> "$(cat corrupt-proof)"; fi
jq -cnS --argjson files "$(printf '%s\n' inputs/* command.sh configuration.json | jq -Rsc 'split("\n")[:-1]')" \
    --slurpfile config configuration.json '{schema:1,files:$files,configuration:$config[0]}'
[[ ! -f fail-observation ]] || exit 29
SH
cat > command.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
count=0
[[ ! -f execution-count ]] || count="$(cat execution-count)"
printf '%s\n' "$((count+1))" > execution-count
printf 'plausible successful validation output\n'
SH
chmod +x observe.sh command.sh
cp command.sh "$fixture/command.original"
state="$fixture/state"
source_a=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
source_b=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
source_c=cccccccccccccccccccccccccccccccccccccccc
run_stage() {
    printf '0\n' > observation-count
    perl "$root/scripts/ci/run-validation-stage.pl" --state "$state" --stage fixture --contract fixture/1 \
        --source "${SOURCE:-$source_a}" --group "${GROUP:-core}" --observe observe.sh \
        --environment environment.json --max-bytes 33554432 -- bash command.sh
}
refuse() {
    if run_stage > "$fixture/refused.stdout" 2> "$fixture/refused.stderr"; then echo 'unexpected stage admission' >&2; exit 1; fi
}
admission_count() { find "$state/attempts" -name admission.json | wc -l | tr -d ' '; }
run_stage > "$fixture/first.log" 2>&1
[[ "$(cat execution-count)" == 1 && "$(admission_count)" == 1 ]]
proofs=("$state"/proofs/*.json)
original_proof="${proofs[0]}"
cp "$original_proof" "$fixture/proof.original"
SOURCE="$source_b" GROUP=metrics run_stage > "$fixture/reused.log" 2>&1
SOURCE="$source_c" GROUP=logging run_stage > "$fixture/reused-again.log" 2>&1
[[ "$(cat execution-count)" == 1 && "$(admission_count)" == 3 ]]
cmp "$original_proof" "$fixture/proof.original"
jq -se --arg source "$source_a" 'all(.[]; .kind == "release-stage-execution" and .origin.source == $source and .origin.group == "core")' "$original_proof" > /dev/null
find "$state/attempts" -name admission.json -exec cat {} + | jq -se '
    (map(.group) | sort) == ["core","logging","metrics"] and
    ([.[] | select(.mode == "reused")] | length) == 2 and
    (map(.execution_proof_sha256) | unique | length) == 1' > /dev/null
# A fresh complete inventory detects newly introduced files as well as bytes,
# feature/native configuration, command changes and the bounded environment.
printf 'changed\n' >> inputs/source
run_stage > "$fixture/changed.log" 2>&1
printf 'new input\n' > inputs/new
run_stage > "$fixture/new-input.log" 2>&1
printf '{"features":"other","native":"another-host-configuration"}\n' > configuration.json
run_stage > "$fixture/configuration.log" 2>&1
printf '\n# command revision\n' >> command.sh
run_stage > "$fixture/command.log" 2>&1
jq -cS '.LC_ALL="POSIX"' environment.json > "$fixture/environment.next"
cp "$fixture/environment.next" environment.json
run_stage > "$fixture/environment.log" 2>&1
[[ "$(cat execution-count)" == 6 ]]
perl -e 'print "large selected input\n" x 10000' > inputs/large
run_stage > "$fixture/large-input.log" 2>&1
printf 'changed end of input\n' >> inputs/large
run_stage > "$fixture/large-input-drift.log" 2>&1
[[ "$(cat execution-count)" == 8 ]]
before="$(admission_count)"
printf '\nexit 37\n' >> command.sh
status=0
run_stage > "$fixture/failed.log" 2>&1 || status=$?
[[ "$status" == 37 && "$(admission_count)" == "$before" ]]
grep -F 'plausible successful validation output' "$fixture/failed.log" > /dev/null
cp "$fixture/command.original" command.sh
touch fail-observation
status=0
run_stage > "$fixture/observation-failed.log" 2>&1 || status=$?
[[ "$status" == 29 && "$(admission_count)" == "$before" ]]
mv fail-observation "$fixture/fail-observation.retained"
# A successful child that mutates declared inputs cannot create a stage proof.
printf '\nprintf "drift\\n" >> inputs/source\n' >> command.sh
refuse
[[ "$(admission_count)" == "$before" ]]
cp "$fixture/command.original" command.sh
run_stage > "$fixture/after-drift.log" 2>&1
before="$(admission_count)"
count="$(cat execution-count)"
touch drift-admission
refuse
[[ "$(cat execution-count)" == "$count" && "$(admission_count)" == "$before" ]]
mv drift-admission "$fixture/drift-admission.retained"
# Unknown formats and missing original logs execute normally, retaining the
# original immutable record and all failures, rather than rebinding old receipts.
run_stage > "$fixture/recovered.log" 2>&1
# Select the actual matching proof from the successful invocation's admission.
latest_admission="$(sed -n 's/^Validation stage fixture: .*; admission //p' "$fixture/recovered.log")"
latest="$(jq -r .execution_proof "$latest_admission")"
jq -cS '.schema=99' "$latest" > "$fixture/unknown.json"
cp "$fixture/unknown.json" "$latest"
count="$(cat execution-count)"
run_stage > "$fixture/unknown-schema.log" 2>&1
[[ "$(cat execution-count)" == "$((count+1))" ]]
cmp "$fixture/unknown.json" "$latest"
latest_admission="$(sed -n 's/^Validation stage fixture: .*; admission //p' "$fixture/unknown-schema.log")"
latest="$(jq -r .execution_proof "$latest_admission")"
log="$(jq -r .logs.stdout.path "$latest")"
mv "$log" "$log.retained"
count="$(cat execution-count)"
run_stage > "$fixture/missing-log.log" 2>&1
[[ "$(cat execution-count)" == "$((count+1))" && -f "$log.retained" ]]
latest_admission="$(sed -n 's/^Validation stage fixture: .*; admission //p' "$fixture/missing-log.log")"
latest="$(jq -r .execution_proof "$latest_admission")"
printf '%s\n' "$latest" > corrupt-proof
before="$(admission_count)"
refuse
[[ "$(admission_count)" == "$before" ]]
mv corrupt-proof "$fixture/corrupt-proof.retained"
# Interruption retains partial output and admits no successful stage. Retry uses
# the ordinary execution path; no release/Git operation is part of these tests.
state="$fixture/interruption-state"
cat >> command.sh <<'SH'
touch started
trap 'exit 143' TERM
while :; do sleep 0.05; done
SH
run_stage > "$fixture/interrupted.log" 2>&1 &
stage_pid=$!
for ((i=0;i<100;i++)); do [[ ! -f started ]] || break; sleep 0.05; done
[[ -f started ]]
# Kill the Perl supervisor, not this fixture's shell-function wrapper.
child_pid="$(pgrep -P "$stage_pid" -f run-validation-stage.pl)"
kill -TERM "$child_pid"
wait "$stage_pid" && exit 1
[[ "$(admission_count)" == 0 ]]
cp "$fixture/command.original" command.sh
run_stage > "$fixture/resumed.log" 2>&1
[[ "$(admission_count)" == 1 ]]
ln -s "$state" "$fixture/unsafe-state"
state="$fixture/unsafe-state"
refuse
# A retention failure cannot hide the failed child's primary status. Its raw
# logs and earlier receipts remain available for explicit recovery.
state="$fixture/retention-state"
cat >> command.sh <<'SH'
attempt="$(find ../retention-state/attempts -name context.json)"
chmod a-w "${attempt%/*}"
exit 41
SH
status=0
run_stage > "$fixture/retention.log" 2>&1 || status=$?
[[ "$status" == 41 && "$(admission_count)" == 0 ]]
grep -F 'evidence publication also failed' "$fixture/retention.log" > /dev/null
find "$state/attempts" -type d -exec chmod u+w {} +
fixture_complete=true
echo 'Exact stage reuse, fresh group admission, drift, failures, unknown evidence and interruption passed'
