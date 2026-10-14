#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-timing.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/fixture-timing.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Timing fixture retained"' EXIT
cat > "$fixture/driver.sh" <<'DRIVER'
#!/usr/bin/env bash
set -euo pipefail
source "$1"
FIXTURE="$2"
# A successful predecessor proves failure handling is independent of position.
# Interpreter flags must never become timing labels.
run_fixture first "$BASH" -c 'exit 0'
run_fixture 'selected failure' "$BASH" -c 'printf "retained input\n" > "$1/input"; exit 23' fixture "$FIXTURE"
printf 'must not run\n' > "$FIXTURE/after"
DRIVER
status=0
"$BASH" "$fixture/driver.sh" "$ROOT/scripts/ci/fixture-timing.sh" "$fixture" > "$fixture/output" 2>&1 || status=$?
[[ "$status" == 23 && -f "$fixture/input" && ! -e "$fixture/after" ]] || exit 1
awk -F '\t' '
    NF != 3 || $2 !~ /^[0-9]+$/ {exit 1}
    NR == 1 && ($1 != "first" || $3 != 0) {exit 1}
    NR == 2 && ($1 != "selected failure" || $3 != 23) {exit 1}
    END {if (NR != 2) exit 1}
' "$fixture/timings.tsv"
fixture_complete=true
printf 'Fixture labels, timing, failure status and stop behavior passed\n'
