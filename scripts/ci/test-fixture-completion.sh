#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/fixture-completion.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Completion fixture retained"' EXIT
for complete in false true; do
    for original in 0 1 37 49 137 255; do
        expected="$original"
        [[ "$complete" == true || "$original" != 0 ]] || expected=1
        actual=0
        fixture_completion_status "$original" "$complete" || actual=$?
        [[ "$actual" == "$expected" ]] || exit 1
    done
done
for invalid in '' -1 256 512 01 invalid 999999999999999999999; do
    actual=0
    fixture_completion_status "$invalid" true || actual=$?
    [[ "$actual" == 2 ]] || exit 1
done
actual=0
fixture_completion_status || actual=$?
[[ "$actual" == 2 ]] || exit 1
# Execute the EXIT contract with no cleanup, including function-level nounset.
cat > "$fixture/runner.sh" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
source "$COMPLETION_SOURCE/scripts/ci/fixture-lifecycle.sh"
complete=false
status=0
trap 'status=$?; fixture_completion_status "$status" "$complete" || status=$?; exit "$status"' EXIT
printf 'retained live evidence\n' > "$COMPLETION_EVIDENCE"
case "$1" in
    success) complete=true ;;
    incomplete) exit 0 ;;
    failed) exit 49 ;;
    completed-failed) complete=true; exit 37 ;;
    nounset) incomplete_function() { printf '%s\n' "$MISSING_COMPLETION_VARIABLE"; }; incomplete_function ;;
esac
RUNNER
unset MISSING_COMPLETION_VARIABLE
export COMPLETION_SOURCE="$ROOT" COMPLETION_EVIDENCE="$fixture/evidence"
for scenario in success incomplete failed completed-failed nounset; do
    expected=1
    case "$scenario" in success) expected=0 ;; failed) expected=49 ;; completed-failed) expected=37 ;; esac
    status=0
    "$BASH" "$fixture/runner.sh" "$scenario" > "$fixture/$scenario.log" 2>&1 || status=$?
    [[ "$status" == "$expected" ]] || exit 1
    grep -Fx 'retained live evidence' "$COMPLETION_EVIDENCE" >/dev/null
done
fixture_complete=true
printf 'Completion admission without cleanup passed\n'
