#!/usr/bin/env bash
set -euo pipefail
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/portable-prerequisites-test.XXXXXX")"
# Bash 3.2 can enter EXIT with status zero after nounset; require completion too.
fixture_complete=false
finish() {
    local status=$?
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$fixture"
    else echo "Prerequisite fixtures retained: $fixture" >&2; fi
    exit "$status"
}
trap finish EXIT
mkdir "$fixture/missing" "$fixture/formatter"
ln -s "$BASH" "$fixture/missing/bash"
ln -s "$(command -v dirname)" "$fixture/missing/dirname"
cat > "$fixture/missing/mktemp" <<'SCRIPT'
#!/usr/bin/env bash
echo 'fixture started before prerequisite admission' >&2
exit 97
SCRIPT
chmod +x "$fixture/missing/mktemp"
status=0
PATH="$fixture/missing" "$BASH" "$ROOT/scripts/ci/test-portable-tools.sh" > "$fixture/missing.log" 2>&1 || status=$?
[[ "$status" == 1 ]]
grep -Fx 'Missing portable-test prerequisite: cloc' "$fixture/missing.log"
grep -Fx 'Missing portable-test prerequisite: yq' "$fixture/missing.log"
grep -F 'docs/local-setup.md' "$fixture/missing.log"
if grep -F 'fixture started' "$fixture/missing.log"; then exit 1; fi

# Real available tools plus an unprepared formatter must fail offline before tests.
cat > "$fixture/formatter/cargo" <<'SCRIPT'
#!/usr/bin/env bash
[[ "$CARGO_NET_OFFLINE" == true && "$RUSTUP_AUTO_INSTALL" == 0 ]] || exit 90
[[ "$*" == 'sort --version' ]] || exit 91
echo 'cargo-sort 0.0.0'
SCRIPT
chmod +x "$fixture/formatter/cargo"
status=0
PATH="$fixture/formatter:$PATH" bash "$ROOT/scripts/ci/check-portable-prerequisites.sh" > "$fixture/formatter.log" 2>&1 || status=$?
[[ "$status" == 1 ]]
grep -F 'Formatting requires prepared cargo-sort' "$fixture/formatter.log"
grep -F 'no tools were installed' "$fixture/formatter.log"
echo 'Portable prerequisite early-refusal tests passed'
fixture_complete=true
