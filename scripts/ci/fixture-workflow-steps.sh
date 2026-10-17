#!/usr/bin/env bash

# Source this helper. Callers own extracted scripts/action substitutes, step
# selection, environment, assertions and evidence retention. No YAML/if evaluator.
# Arguments: BASH COMMAND_DIRECTORY LOG_DIRECTORY STEP OUTCOME_VARIABLE ...
# Publish success/failure/skipped as exported variables; return the first failed
# child's exact status. Later steps never execute or create logs after a failure.
fixture_run_steps() {
    [[ $# -ge 5 && $((($# - 3) % 2)) == 0 ]] || return 2
    local _fixture_steps_bash="$1" _fixture_steps_commands="$2" _fixture_steps_logs="$3"
    shift 3
    local _fixture_steps_pairs=("$@") _fixture_steps_id _fixture_steps_variable _fixture_steps_status
    [[ -x "$_fixture_steps_bash" && -d "$_fixture_steps_commands" && -d "$_fixture_steps_logs" ]] || return 2
    while [[ $# != 0 ]]; do
        [[ "$1" != *[!a-zA-Z0-9_]* && "$1" == [a-zA-Z_]* &&
           "$2" != *[!A-Z0-9_]* && "$2" == [A-Z_]* ]] || return 2
        shift 2
    done
    set -- "${_fixture_steps_pairs[@]}"
    while [[ $# != 0 ]]; do
        export "$2=skipped"
        shift 2
    done
    set -- "${_fixture_steps_pairs[@]}"
    while [[ $# != 0 ]]; do
        _fixture_steps_id="$1" _fixture_steps_variable="$2"
        if "$_fixture_steps_bash" --noprofile --norc -e -o pipefail \
            "$_fixture_steps_commands/$_fixture_steps_id.sh" \
            > "$_fixture_steps_logs/$_fixture_steps_id.log" 2>&1; then
            export "$_fixture_steps_variable=success"
        else
            _fixture_steps_status=$?
            export "$_fixture_steps_variable=failure"
            return "$_fixture_steps_status"
        fi
        shift 2
    done
}
