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
# A traversal error must refuse both reporting and removal, without replacing
# age evidence or admitting only the readable portion of the compiler tree.
mkdir "$cache/build/unreadable"
printf 'retained hidden output\n' > "$cache/build/unreadable/object"
cp "$cache/state.json" "$fixture/state-before-refusal.json"
chmod 000 "$cache/build/unreadable"
preview_status=0
finish_status=0
if [[ ! -r "$cache/build/unreadable" ]]; then
    maintain preview > "$fixture/unreadable-preview.json" 2> "$fixture/unreadable-preview.log" || preview_status=$?
    maintain finish 1 > "$fixture/unreadable-finish.json" 2> "$fixture/unreadable-finish.log" || finish_status=$?
    chmod 700 "$cache/build/unreadable"
    [[ "$preview_status" != 0 && "$finish_status" != 0 ]]
    [[ ! -s "$fixture/unreadable-preview.json" && ! -s "$fixture/unreadable-finish.json" ]]
    cmp "$cache/state.json" "$fixture/state-before-refusal.json"
    [[ "$(cat "$cache/build/unreadable/object")" == 'retained hidden output' ]]
else
    chmod 700 "$cache/build/unreadable"
    echo 'Unreadable-tree probe unavailable: runner bypasses directory permissions'
fi
# Missing required inputs also make File::Find warn rather than call wanted.
if perl -I "$root/scripts/dev" -MOwnedTree=inventory -e 'inventory($ARGV[0])' \
    "$fixture/missing-tree" > "$fixture/missing-tree.json" 2> "$fixture/missing-tree.log"; then
    exit 1
fi
[[ ! -s "$fixture/missing-tree.json" ]]
# Scratch symlinks may be unlinked, but never traverse into retained artifacts.
ln -s "$fixture/evidence" "$cache/build/link"
maintain finish 1 > "$fixture/scratch-links.json"
test ! -e "$cache/build"
test -f "$fixture/evidence/server"
maintain prepare > "$fixture/repeated.json"
echo 'Compiler cache budget, age, preview, custody, ownership, redirects and retained evidence passed.'
