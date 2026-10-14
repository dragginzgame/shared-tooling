#!/usr/bin/env bash
# Shared companions: scripts/ci/validate-release-inputs.pl scripts/ci/next-release-version.sh
set -euo pipefail
ROOT="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
helper="$ROOT/scripts/ci/validate-release-inputs.pl"
[[ "$(perl "$helper" version 18446744073709551615.0.17)" == $'18446744073709551615\t0\t17' ]]
for invalid in '' '1.2' '1.2.3.4' '01.2.3' '+1.2.3' '1.2.3-alpha' '1.2.3+meta' '18446744073709551616.0.0' '９.2.3' $'1.2.3\n' $'1.2.3\r'; do
    if perl "$helper" version "$invalid" >/dev/null 2>&1; then exit 1; fi
done
for valid in 0001-01-01 2000-02-29 2024-02-29 2026-10-14 9999-12-31; do
    [[ "$(perl "$helper" date "$valid")" == "$valid" ]]
done
for invalid in 0000-01-01 1900-02-29 2026-02-29 2026-04-31 2026-00-01 2026-13-01 2026-01-00 2026-01-32 2026-1-01 $'2026-01-01\n' $'2026-01-01\r'; do
    if perl "$helper" date "$invalid" >/dev/null 2>&1; then exit 1; fi
done
[[ "$(bash "$ROOT/scripts/ci/next-release-version.sh" 1.2.3 minor)" == 1.3.0 ]]
[[ "$(bash "$ROOT/scripts/ci/next-release-version.sh" 0.0.9223372036854775806 patch)" == 0.0.9223372036854775807 ]]
if bash "$ROOT/scripts/ci/next-release-version.sh" 0.0.9223372036854775807 patch >/dev/null 2>&1; then exit 1; fi
printf '%s\n' 'Exact release version/date admission and increment headroom passed'
