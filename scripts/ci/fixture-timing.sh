#!/usr/bin/env bash
# Sourced by the portable suite and its focused timing/stop regression.
run_fixture() {
    local label="$1" start="$SECONDS" status=0
    shift
    "$@" || status=$?
    printf '%s\t%s\t%s\n' "$label" "$((SECONDS - start))" "$status" >> "$FIXTURE/timings.tsv"
    return "$status"
}
