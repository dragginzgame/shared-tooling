#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-workflow-steps.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/fixture-workflow-steps.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Workflow execution fixture retained"' EXIT
# shellcheck source=scripts/ci/fixture-workflow-steps.sh
source "$root/scripts/ci/fixture-workflow-steps.sh"
mkdir -p "$fixture/commands with spaces" "$fixture/logs"
export FIXTURE_STEP_EVENTS="$fixture/events" FIXTURE_STEP_FAILURE=''
for step in first middle last; do
    cat > "$fixture/commands with spaces/$step.sh" <<'SH'
step="${0##*/}"
step="${step%.sh}"
printf '%s\n' "$step" >> "$FIXTURE_STEP_EVENTS"
printf 'stdout %s\n' "$step"
printf 'stderr %s\n' "$step" >&2
if [[ "$FIXTURE_STEP_FAILURE" == "$step" ]]; then exit 43; fi
if [[ "$step" == middle ]]; then [[ "$FIRST_OUTCOME" == success ]]; fi
SH
done
for failure in none first middle last; do
    mkdir "$fixture/logs/$failure"
    : > "$FIXTURE_STEP_EVENTS"
    FIXTURE_STEP_FAILURE="$failure"
    status=0
    fixture_run_steps "$BASH" "$fixture/commands with spaces" "$fixture/logs/$failure" \
        first FIRST_OUTCOME middle MIDDLE_OUTCOME last LAST_OUTCOME || status=$?
    expected_status=0
    [[ "$failure" == none ]] || expected_status=43
    [[ "$status" == "$expected_status" ]] || exit 1
    : > "$fixture/expected-events"
    reached=true
    for step in first middle last; do
        case "$step" in
            first) outcome="$FIRST_OUTCOME" ;;
            middle) outcome="$MIDDLE_OUTCOME" ;;
            last) outcome="$LAST_OUTCOME" ;;
        esac
        if [[ "$reached" == true ]]; then
            printf '%s\n' "$step" >> "$fixture/expected-events"
            printf 'stdout %s\nstderr %s\n' "$step" "$step" > "$fixture/expected-log"
            cmp "$fixture/expected-log" "$fixture/logs/$failure/$step.log"
            if [[ "$step" == "$failure" ]]; then
                [[ "$outcome" == failure ]] || exit 1
                reached=false
            else
                [[ "$outcome" == success ]] || exit 1
            fi
        else
            [[ "$outcome" == skipped && ! -e "$fixture/logs/$failure/$step.log" ]] || exit 1
        fi
    done
    cmp "$fixture/expected-events" "$FIXTURE_STEP_EVENTS"
done
# Real shell semantics: pipeline failure and errexit must stop the child body
# even though the caller captures the helper's status through an OR-list.
# shellcheck disable=SC2016 # The event path is expanded by the child script.
printf 'false | true\nprintf "unexpected\\n" >> "$FIXTURE_STEP_EVENTS"\n' > "$fixture/commands with spaces/pipeline.sh"
# shellcheck disable=SC2016 # The event path is expanded by the child script.
printf 'false\nprintf "unexpected\\n" >> "$FIXTURE_STEP_EVENTS"\n' > "$fixture/commands with spaces/errexit.sh"
for step in pipeline errexit; do
    : > "$FIXTURE_STEP_EVENTS"
    status=0
    fixture_run_steps "$BASH" "$fixture/commands with spaces" "$fixture/logs" \
        "$step" CHECK_OUTCOME last LAST_OUTCOME || status=$?
    [[ "$status" == 1 && "$CHECK_OUTCOME" == failure && "$LAST_OUTCOME" == skipped &&
       ! -s "$FIXTURE_STEP_EVENTS" ]] || exit 1
done
# Invalid call shapes/names refuse before outcomes, logs or scripts change.
for invalid in missing-pair incomplete invalid-step invalid-variable missing-directory; do
    FIRST_OUTCOME=untouched
    : > "$FIXTURE_STEP_EVENTS"
    arguments=("$BASH" "$fixture/commands with spaces" "$fixture/logs")
    case "$invalid" in
        missing-pair) ;;
        incomplete) arguments+=(first FIRST_OUTCOME last) ;;
        invalid-step) arguments+=(first FIRST_OUTCOME ../last LAST_OUTCOME) ;;
        invalid-variable) arguments+=(first FIRST_OUTCOME last 'BAD-NAME') ;;
        missing-directory) arguments=("$BASH" "$fixture/missing" "$fixture/logs" first FIRST_OUTCOME) ;;
    esac
    status=0
    fixture_run_steps "${arguments[@]}" || status=$?
    [[ "$status" == 2 && "$FIRST_OUTCOME" == untouched && ! -s "$FIXTURE_STEP_EVENTS" ]] || exit 1
done
fixture_complete=true
echo 'Ordered shell fixture execution, exported outcomes and failure boundaries passed'
