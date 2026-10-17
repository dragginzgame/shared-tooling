#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/fixture-log-replay.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Log replay fixture retained"' EXIT
mkdir "$fixture/directory" "$fixture/bin"
first="$fixture/first log"
last="$fixture/last"$'\n'"log"
printf 'first without newline' > "$first"
printf 'last\n' > "$last"
cat "$first" "$last" > "$fixture/expected"
fixture_replay_logs "$fixture/missing" "$first" "$fixture/directory" "$last" \
    > "$fixture/stdout" 2> "$fixture/stderr"
[[ ! -s "$fixture/stdout" ]] || exit 1
cmp "$fixture/expected" "$fixture/stderr"
fixture_replay_logs > "$fixture/empty-out" 2> "$fixture/empty-err"
[[ ! -s "$fixture/empty-out" && ! -s "$fixture/empty-err" ]] || exit 1

# A failed reader must not mask a caller's saved status or stop later readback.
real_cat="$(command -v cat)"
export REPLAY_REAL_CAT="$real_cat" REPLAY_FAILED_LOG="$first"
printf '#!%s\n' "$BASH" > "$fixture/bin/cat"
cat >> "$fixture/bin/cat" <<'CAT'
if [[ "$2" == "$REPLAY_FAILED_LOG" ]]; then
    printf 'partial diagnostic\n'
    exit 43
fi
exec "$REPLAY_REAL_CAT" "$@"
CAT
chmod +x "$fixture/bin/cat"
printf 'partial diagnostic\n' > "$fixture/failed-expected"
cat "$last" >> "$fixture/failed-expected"
PATH="$fixture/bin:$PATH" fixture_replay_logs "$first" "$last" \
    > "$fixture/failed-out" 2> "$fixture/failed-err"
[[ ! -s "$fixture/failed-out" ]] || exit 1
cmp "$fixture/failed-expected" "$fixture/failed-err"
status=0
(
    saved=0
    export PATH="$fixture/bin:$PATH"
    trap 'saved=$?; fixture_replay_logs "$REPLAY_FAILED_LOG"; exit "$saved"' EXIT
    exit 49
) > "$fixture/trap-out" 2> "$fixture/trap-err" || status=$?
[[ "$status" == 49 && ! -s "$fixture/trap-out" ]] || exit 1
printf 'partial diagnostic\n' > "$fixture/trap-expected"
cmp "$fixture/trap-expected" "$fixture/trap-err"
(exec 2>&-; fixture_replay_logs "$first")
[[ -f "$first" && -f "$last" && -d "$fixture/directory" ]] || exit 1
fixture_complete=true
echo 'Selected log replay, reader failure and saved-status preservation passed'
