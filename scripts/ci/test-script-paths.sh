#!/usr/bin/env bash
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/script-paths-test.XXXXXX")"
# Bash 3.2 can enter EXIT with status zero after nounset; require completion too.
fixture_complete=false
finish() {
    local status=$?
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$fixture"
    else printf "Script path fixture retained: %s\n" "$fixture" >&2; fi
    exit "$status"
}
trap finish EXIT
checkout="$fixture/checkout"$'\n'
mkdir -p "$checkout/scripts/ci" "$checkout/scripts/dev" "$fixture/decoy/scripts/ci"
for script in check-dependency-pins verify-shared-tooling-snapshot install-actionlint install-shellcheck install-yq install-ci-tool; do
    cp "$ROOT/scripts/ci/$script.sh" "$checkout/scripts/ci/"
done
for script in install-host-tools install-ic-tools; do cp "$ROOT/scripts/dev/$script.sh" "$checkout/scripts/dev/"; done
# Initial help admission must not resolve a relative script against CDPATH or
# trim a newline from its physical checkout. No setup or Git effects are invoked.
for path in "$checkout"/scripts/ci/*.sh "$checkout"/scripts/dev/*.sh; do
    relative="${path#"$checkout/"}"
    arguments=(--help)
    [[ "${path##*/}" != install-ci-tool.sh ]] || arguments=(shellcheck --help)
    (cd "$checkout"; CDPATH="$fixture/decoy:$checkout" "$BASH" "$relative" "${arguments[@]}") > "$fixture/help.log" 2>&1
    (cd "$fixture"; CDPATH="$checkout" "$BASH" "$path" "${arguments[@]}") >> "$fixture/help.log" 2>&1
done
cp "$ROOT/scripts/ci/test-evidence-archive.sh" "$ROOT/scripts/ci/archive-evidence.sh" "$checkout/scripts/ci/"
(cd "$checkout"; CDPATH="$fixture/decoy:$checkout" bash scripts/ci/test-evidence-archive.sh) > "$fixture/archive.log" 2>&1
echo 'Relative/absolute entry points, inherited CDPATH and newline checkout bootstrap passed'
fixture_complete=true
