#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/evidence-archive.XXXXXX")"
trap 'if [[ $? == 0 ]]; then rm -rf "$fixture"; else printf "Archive fixture retained: %s\n" "$fixture" >&2; fi' EXIT
mkdir -p "$fixture/source/fixtures/.git" "$fixture/other" "$fixture/unpacked"
printf 'private Git configuration\n' > "$fixture/source/fixtures/.git/config"
printf 'retained input\n' > "$fixture/source/fixtures/"$'line\nbreak:payload'
chmod 640 "$fixture/source/fixtures/"$'line\nbreak:payload'
printf '#!/bin/sh\nexit 0\n' > "$fixture/source/fixtures/executable"
chmod 755 "$fixture/source/fixtures/executable"
printf 'outside selection\n' > "$fixture/source/outside"
ln -s ../outside "$fixture/source/fixtures/link"
ln -s fixtures "$fixture/source/alias"
printf 'original_status=23\n' > "$fixture/other/outcome.txt"
bash "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/evidence.tar.gz" \
    "$fixture/source" fixtures "$fixture/other" outcome.txt > "$fixture/archive-path"
tar -xzf "$fixture/evidence.tar.gz" -C "$fixture/unpacked"
cmp "$fixture/source/fixtures/"$'line\nbreak:payload' "$fixture/unpacked/fixtures/"$'line\nbreak:payload'
[[ "$(perl -e 'printf "%o", (stat($ARGV[0]))[2] & 0777' "$fixture/unpacked/fixtures/"$'line\nbreak:payload')" == 640 ]]
[[ -x "$fixture/unpacked/fixtures/executable" && -L "$fixture/unpacked/fixtures/link" ]]
[[ "$(readlink "$fixture/unpacked/fixtures/link")" == ../outside && ! -e "$fixture/unpacked/fixtures/link" ]]
[[ ! -e "$fixture/unpacked/fixtures/.git" && ! -e "$fixture/unpacked/outside" ]]
cmp "$fixture/other/outcome.txt" "$fixture/unpacked/outcome.txt"
cp "$fixture/evidence.tar.gz" "$fixture/before.tar.gz"
if bash "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/evidence.tar.gz" "$fixture/source" fixtures; then exit 1; fi
cmp "$fixture/before.tar.gz" "$fixture/evidence.tar.gz"
for path in missing ../outside /outside alias/executable; do
    if bash "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/rejected.tar.gz" "$fixture/source" "$path"; then exit 1; fi
    [[ ! -e "$fixture/rejected.tar.gz" ]]
done
if bash "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/rejected.tar.gz" \
    "$fixture/source" fixtures "$fixture/source" fixtures/executable; then exit 1; fi
if bash "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/source/fixtures/self.tar.gz" "$fixture/source" fixtures; then exit 1; fi
[[ ! -e "$fixture/rejected.tar.gz" && ! -e "$fixture/source/fixtures/self.tar.gz" ]]
# Output symlinks cannot redirect writes, and failed writers retain diagnostics.
ln -s "$fixture/absent" "$fixture/output-link"
if bash "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/output-link" "$fixture/source" fixtures; then exit 1; fi
[[ ! -e "$fixture/absent" && -L "$fixture/output-link" ]]
mkdir "$fixture/bin"
printf '#!%s\nprintf "partial archive"\nexit 23\n' "$BASH" > "$fixture/bin/tar"
chmod +x "$fixture/bin/tar"
if PATH="$fixture/bin:$PATH" bash "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/partial.tar.gz" "$fixture/source" fixtures; then exit 1; fi
[[ "$(cat "$fixture/partial.tar.gz")" == 'partial archive' && -f "$fixture/source/fixtures/executable" ]]
echo 'Evidence archive bytes, modes, links, selection and failure retention passed'
