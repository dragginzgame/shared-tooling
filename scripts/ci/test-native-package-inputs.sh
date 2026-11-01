#!/usr/bin/env bash
# Shared companions: scripts/dev/native-package-inputs.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
mkdir -p "$root/target/tmp"
fixture="$(fixture_create "$root/target/tmp/native-package-inputs.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Native input fixture retained"' EXIT
mkdir "$fixture/info"
printf '/usr/include/stdio.h\n/lib/x86_64-linux-gnu/libc.so.6\n' > "$fixture/info/libc6-dev.list"
printf '/usr/lib/gcc/x86_64-linux-gnu/14/cc1\n' > "$fixture/info/gcc-14.list"
printf '/usr/bin/browser\n/usr/lib/browser/libprivate.so\n' > "$fixture/info/browser.list"
printf '/usr/bin/editor\n/usr/share/editor/data\n' > "$fixture/info/editor.list"
printf 'libc6-dev\t1\ngcc-14\t1\nbrowser\t1\n' > "$fixture/old"
printf 'libc6-dev\t1\ngcc-14\t1\nbrowser\t2\neditor\t1\n' > "$fixture/apps"
observe() { perl "$root/scripts/dev/native-package-inputs.pl" dpkg "$fixture/info" < "$1"; }
observe "$fixture/old" > "$fixture/before"
observe "$fixture/apps" > "$fixture/after"
cmp "$fixture/before" "$fixture/after"
awk -F '\t' 'BEGIN {OFS="\t"} $1=="libc6-dev" {$2="2"} {print}' "$fixture/apps" > "$fixture/native"
observe "$fixture/native" > "$fixture/changed"
if cmp -s "$fixture/before" "$fixture/changed"; then exit 1; fi
printf 'PACKAGE\tlibc\t1\n/usr/lib64/libc.so.6\nPACKAGE\tbrowser\t2\n/usr/bin/browser\n/usr/lib/browser/libprivate.so\n' |
    perl "$root/scripts/dev/native-package-inputs.pl" rpm > "$fixture/rpm"
printf 'libc=1\n' | cmp - "$fixture/rpm"
if printf 'missing\t1\n' | perl "$root/scripts/dev/native-package-inputs.pl" dpkg "$fixture/info" > "$fixture/refused" 2>&1; then exit 1; fi
if printf 'broken\n' | perl "$root/scripts/dev/native-package-inputs.pl" rpm > "$fixture/refused" 2>&1; then exit 1; fi
fixture_complete=true
echo 'Native input inventory retains headers/libraries/tools and excludes application updates'
