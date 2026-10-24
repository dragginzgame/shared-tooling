#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(CDPATH='' cd -P -- "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/fixture-allocation.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Allocation fixture retained"' EXIT
mkdir "$fixture/physical root"
ln -s "$fixture/physical root" "$fixture/alias"
allocated="$(CDPATH=/ fixture_create "$fixture/alias/child.XXXXXX")"
[[ "$allocated" == "$fixture/physical root/child."* && -d "$allocated" ]] || exit 1
(
    cd "$fixture/physical root"
    relative="$(fixture_create 'relative.XXXXXX')"
    [[ "$relative" == "$PWD/relative."* && -d "$relative" ]] || exit 1
    rm -r "$relative"
)
status=0
fixture_create > "$fixture/no-input" 2>&1 || status=$?
[[ "$status" == 2 && ! -s "$fixture/no-input" ]] || exit 1
for invalid in '' '--help' "$fixture/line"$'\n'"break.XXXXXX" "$fixture/line"$'\r'"break.XXXXXX"; do
    status=0
    fixture_create "$invalid" > "$fixture/invalid" 2>&1 || status=$?
    [[ "$status" == 2 && ! -s "$fixture/invalid" ]] || exit 1
done
# A safe alias must not hide a forbidden physical parent. Retain any allocation;
# never normalize the path by deleting the offending byte.
mkdir "$fixture/physical"$'\n'"parent"
ln -s "$fixture/physical"$'\n'"parent" "$fixture/bad-alias"
status=0
fixture_create "$fixture/bad-alias/child.XXXXXX" > "$fixture/physical-output" 2> "$fixture/physical-error" || status=$?
[[ "$status" == 2 && ! -s "$fixture/physical-output" ]] || exit 1
set -- "$fixture/bad-alias"/child.*
[[ $# == 1 && -d "$1" ]] || exit 1
grep -F 'allocation retained:' "$fixture/physical-error" >/dev/null
# A failing allocator cannot trigger normalization or lose its exact status.
status=0
(
    # shellcheck disable=SC2329 # Called indirectly by fixture_create.
    mktemp() { printf 'allocator-detail\n' >&2; return 49; }
    # shellcheck disable=SC2329 # Called indirectly by fixture_create.
    cd() { printf 'normalization-dispatched\n' >&2; return 51; }
    fixture_create "$fixture/unused.XXXXXX"
) > "$fixture/allocate-failure" 2>&1 || status=$?
[[ "$status" == 49 ]] || exit 1
grep -Fx 'allocator-detail' "$fixture/allocate-failure" >/dev/null
! grep -F 'normalization-dispatched' "$fixture/allocate-failure" >/dev/null || exit 1
# Allocation succeeded but normalization failed: bytes/path remain caller-owned.
retained="$(mktemp -d "$fixture/retained.XXXXXX")"
printf 'original evidence\n' > "$retained/evidence"
status=0
(
    # shellcheck disable=SC2329 # Called indirectly by fixture_create.
    mktemp() { printf '%s\n' "$retained"; }
    # shellcheck disable=SC2329 # Called indirectly by fixture_create.
    cd() { return 37; }
    fixture_create "$fixture/unused.XXXXXX"
) > "$fixture/normalize-failure" 2>&1 || status=$?
[[ "$status" == 37 && -d "$retained" ]] || exit 1
grep -Fx "Fixture allocation retained: $retained" "$fixture/normalize-failure" >/dev/null
grep -Fx 'original evidence' "$retained/evidence" >/dev/null
# The selected directory stays anchored after the caller changes cwd.
(
    cd /
    [[ -d "$allocated" ]] || exit 1
)
fixture_complete=true
printf 'Fixture allocation and failure custody checks passed\n'
