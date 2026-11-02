#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd -P)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/compiler-cache.XXXXXX")"
fixture="$(cd "$fixture" && pwd -P)"
trap 'printf "Compiler cache evidence: %s\n" "$fixture"' EXIT
mkdir "$fixture/consumer" "$fixture/consumer/target" "$fixture/evidence"
printf '%s\n' "$$" > "$fixture/assembly.lock"
helper="$root/scripts/dev/compiler-cache-maintenance.pl"
cache="$fixture/consumer/target/cache"
maintain() { perl "$helper" "$1" "$cache" "$fixture/consumer" "$fixture/assembly.lock" "$$" "${2:-1048576}" 604800; }
maintain prepare > "$fixture/prepare.json"
mkdir "$cache/build"
printf 'compiler output\n' > "$cache/build/object"
printf 'selected executable\n' > "$fixture/evidence/server"
printf 'immutable receipt\n' > "$fixture/evidence/receipt"
maintain finish > "$fixture/retained.json"
test -f "$cache/build/object"
maintain preview 1 > "$fixture/preview.json"
test -f "$cache/build/object"
maintain finish 1 > "$fixture/trim.json"
test ! -e "$cache/build"
test -f "$fixture/evidence/server"
test -f "$fixture/evidence/receipt"
mkdir "$cache/build"
printf 'old scratch\n' > "$cache/build/object"
printf '{"schema":1,"last_used":1}\n' > "$cache/state.json"
maintain prepare > "$fixture/aged.json"
test ! -e "$cache/build"
# Redirects and missing/unowned roots must not gain maintenance authority.
ln -s "$fixture/evidence" "$cache/build"
if maintain finish 1 > "$fixture/redirect.log" 2>&1; then exit 1; fi
test -f "$fixture/evidence/server"
rm "$cache/build"
mkdir "$cache/build"
printf 'keep\n' > "$cache/build/object"
printf '1\n' > "$fixture/assembly.lock"
if maintain finish 1 > "$fixture/custody.log" 2>&1; then exit 1; fi
test -f "$cache/build/object"
printf '%s\n' "$$" > "$fixture/assembly.lock"
mv "$cache/owner.json" "$fixture/owner.json"
if maintain finish 1 > "$fixture/unowned.log" 2>&1; then exit 1; fi
test -f "$cache/build/object"
mv "$fixture/owner.json" "$cache/owner.json"
# Scratch symlinks may be unlinked, but never traverse into retained artifacts.
ln -s "$fixture/evidence" "$cache/build/link"
maintain finish 1 > "$fixture/scratch-links.json"
test ! -e "$cache/build"
test -f "$fixture/evidence/server"
maintain prepare > "$fixture/repeated.json"
echo 'Compiler cache budget, age, preview, custody, ownership, redirects and retained evidence passed.'
