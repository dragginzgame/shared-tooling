#!/usr/bin/env bash
# Shared companions: scripts/ci/check-retained-state.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/retained-state.XXXXXX")"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE_ROOT" "Failed retention fixture retained"' EXIT
guard() { perl "$ROOT/scripts/ci/check-retained-state.pl" --root "$FIXTURE_ROOT/state" "$@"; }
refuse() {
    if guard "$@" > "$FIXTURE_ROOT/output" 2>&1; then
        echo 'unexpected retention admission' >&2; exit 1
    fi
}
guard
mkdir "$FIXTURE_ROOT/state"
printf 'receipt' > "$FIXTURE_ROOT/state/receipt"
guard --max-bytes 7 --max-file-bytes 7
refuse --max-bytes 6
refuse --max-file-bytes 6
[[ "$(cat "$FIXTURE_ROOT/state/receipt")" == receipt ]]
ln "$FIXTURE_ROOT/state/receipt" "$FIXTURE_ROOT/state/hardlink"
guard --max-bytes 7 --root "$FIXTURE_ROOT/state"
ln -s "$FIXTURE_ROOT/output" "$FIXTURE_ROOT/state/link"
refuse
rm "$FIXTURE_ROOT/state/link"
for name in target .tools node_modules .git; do
    mkdir "$FIXTURE_ROOT/state/$name"
    refuse
    rmdir "$FIXTURE_ROOT/state/$name"
done
perl -e 'open my $f, ">", $ARGV[0] or die $!; truncate $f, 1048576 or die $!; close $f; utime(time-31*86400, time-31*86400, @ARGV) == @ARGV or die $!' \
    "$FIXTURE_ROOT/state/bulk" "$FIXTURE_ROOT/state/receipt"
refuse
grep -q 'bulk evidence older' "$FIXTURE_ROOT/output"
[[ -f "$FIXTURE_ROOT/state/bulk" ]]
rm "$FIXTURE_ROOT/state/bulk"
guard
echo 'retained-state budget, preservation and recovery checks passed'
fixture_complete=true
