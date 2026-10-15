#!/usr/bin/env bash
# Shared companions: scripts/ci/extract-workflow-step.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/workflow-step.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Workflow step fixture retained"' EXIT
cat > "$fixture/input with spaces.json" <<'JSON'
[{"id":"checkout","uses":"actions/checkout@fixture"},
 {"id":"build","run":"printf 'selected\\n'\nprintf 'second\\n'"}]
JSON
cat > "$fixture/expected.sh" <<'SH'
printf 'selected\n'
printf 'second\n'
SH
bash "$root/scripts/ci/extract-workflow-step.sh" "$fixture/input with spaces.json" build > "$fixture/selected.sh"
cmp "$fixture/expected.sh" "$fixture/selected.sh"
bash "$fixture/selected.sh" > "$fixture/result"
printf 'selected\nsecond\n' > "$fixture/expected-result"
cmp "$fixture/expected-result" "$fixture/result"
cp "$fixture/input with spaces.json" "$fixture/original"
for kind in missing duplicate action mixed empty whitespace number object scalar malformed multiple trailing; do
    case "$kind" in
        missing) printf '[{"id":"other","run":"echo other"}]' ;;
        duplicate) printf '[{"id":"build","run":"echo one"},{"id":"build","run":"echo two"}]' ;;
        action) printf '[{"id":"build","uses":"owner/action@fixture"}]' ;;
        mixed) printf '[{"id":"build","uses":"owner/action@fixture","run":"echo mixed"}]' ;;
        empty) printf '[{"id":"build","run":""}]' ;;
        whitespace) printf '[{"id":"build","run":" \\n\\t"}]' ;;
        number) printf '[{"id":"build","run":42}]' ;;
        object) printf '{"id":"build","run":"echo object"}' ;;
        scalar) printf '[42,{"id":"build","run":"echo selected"}]' ;;
        malformed) printf '[' ;;
        multiple) cat "$fixture/original"; printf '\n[]' ;;
        trailing) cat "$fixture/original"; printf '\n{' ;;
    esac > "$fixture/$kind.json"
    status=0
    bash "$root/scripts/ci/extract-workflow-step.sh" "$fixture/$kind.json" build \
        > "$fixture/$kind.out" 2> "$fixture/$kind.log" || status=$?
    [[ "$status" != 0 && ! -s "$fixture/$kind.out" ]] || exit 1
done
status=0
bash "$root/scripts/ci/extract-workflow-step.sh" "$fixture/original" '' \
    > "$fixture/invalid.out" 2> "$fixture/invalid.log" || status=$?
[[ "$status" == 2 && ! -s "$fixture/invalid.out" ]] || exit 1
cmp "$fixture/original" "$fixture/input with spaces.json"
fixture_complete=true
echo 'Unique workflow run extraction and complete-input refusal passed'
