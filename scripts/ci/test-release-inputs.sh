#!/usr/bin/env bash
# Shared companions: scripts/ci/validate-release-inputs.pl scripts/ci/next-release-version.sh
set -euo pipefail
ROOT="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
helper="$ROOT/scripts/ci/validate-release-inputs.pl"
(cd "$ROOT/scripts/ci"; [[ "$(bash next-release-version.sh 1.2.3 patch)" == 1.2.4 ]])
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
for row in \
    '1.2.3 patch 1.2.4' '1.2.3 minor 1.3.0' '1.2.3 major 2.0.0' \
    '0.0.9999999999999999999 patch 0.0.10000000000000000000' \
    '0.0.9223372036854775807 patch 0.0.9223372036854775808' \
    '9223372036854775807.0.0 patch 9223372036854775807.0.1' \
    '0.0.18446744073709551614 patch 0.0.18446744073709551615' \
    '0.18446744073709551614.17 minor 0.18446744073709551615.0' \
    '18446744073709551614.17.19 major 18446744073709551615.0.0' \
    '18446744073709551615.0.0 patch 18446744073709551615.0.1' \
    '0.18446744073709551615.18446744073709551615 major 1.0.0'; do
    read -r version kind expected <<< "$row"
    [[ "$(perl "$helper" next-version "$version" "$kind")" == "$expected" ]] || exit 1
    [[ "$(bash "$ROOT/scripts/ci/next-release-version.sh" "$version" "$kind")" == "$expected" ]] || exit 1
done
for row in '0.0.18446744073709551615 patch' '0.18446744073709551615.0 minor' \
    '18446744073709551615.0.0 major' '18446744073709551616.0.0 patch' \
    '1.2.3 unknown' '01.2.3 patch' '1.2.3-alpha patch'; do
    read -r version kind <<< "$row"
    if output="$(perl "$helper" next-version "$version" "$kind" 2>/dev/null)"; then exit 1; fi
    [[ -z "$output" ]] || exit 1
    status=0
    output="$(bash "$ROOT/scripts/ci/next-release-version.sh" "$version" "$kind" 2>/dev/null)" || status=$?
    [[ "$status" == 2 && -z "$output" ]] || exit 1
done
if perl "$helper" next-version 1.2.3 >/dev/null 2>&1; then exit 1; fi
if perl "$helper" next-version 1.2.3 patch extra >/dev/null 2>&1; then exit 1; fi
for count in 0 1 3; do
    args=()
    while [[ "${#args[@]}" -lt "$count" ]]; do args+=(1.2.3); done
    status=0
    output="$(bash "$ROOT/scripts/ci/next-release-version.sh" ${args[@]+"${args[@]}"} 2>/dev/null)" || status=$?
    [[ "$status" == 2 && -z "$output" ]] || exit 1
done
printf '%s\n' 'Exact release version/date admission and u64 increment headroom passed'
