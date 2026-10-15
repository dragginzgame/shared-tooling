#!/usr/bin/env bash
set -euo pipefail
# Archive a caller-owned native evidence tree verbatim, including hidden Git
# recovery state. This is not the sanitized diagnostic/tool-candidate exporter.
[[ $# == 2 ]] || { echo 'usage: collect-native-evidence.sh EVIDENCE OUTPUT' >&2; exit 2; }
evidence="$1" output="$2"
[[ -d "$evidence" && ! -L "$evidence" && -n "$output" && "$output" != */ ]] || exit 2
# Do not archive our own output or replace an earlier attempt's evidence.
evidence_physical="$(cd -P "$evidence" && printf '%s/.' "$PWD")"
evidence_physical="${evidence_physical%/.}"
[[ "$evidence_physical" != / ]] || exit 2
output_parent=.
[[ "$output" != */* ]] || output_parent="${output%/*}"
[[ -n "$output_parent" ]] || output_parent=/
output_parent="$(cd -P "$output_parent" && printf '%s/.' "$PWD")"
output_parent="${output_parent%/.}"
case "$output_parent/" in "$evidence_physical/"*) echo 'archive output must be outside evidence' >&2; exit 2 ;; esac
for path in "$output" "$output.sha256"; do
    [[ ! -e "$path" && ! -L "$path" ]] || { echo "evidence output already exists: $path" >&2; exit 2; }
done
finish() {
    local status=$?
    if [[ "$status" != 0 ]]; then
        printf 'Native evidence collection failed; inputs and partial output retained: %s %s\n' "$evidence" "$output" >&2 || :
    fi
    exit "$status"
}
trap finish EXIT
# Keep the caller's path spelling so inventory verification works after replay
# beneath the same relative evidence root. Nested and hidden files stay in tar.
[[ ! -L "$evidence/artifact-sha256.txt" ]] || exit 2
# shellcheck disable=SC2094 # The generated inventory is explicitly excluded.
for file in "$evidence"/*; do
    if [[ -f "$file" && "$file" != "$evidence/artifact-sha256.txt" ]]; then
        shasum -a 256 "$file"
    fi
done > "$evidence/artifact-sha256.txt"
# Noclobber also refuses an output created after admission. Never clean up a
# partial archive: readable diagnostics and original recovery inputs survive.
(set -C; tar -czf - -C "$evidence" . > "$output")
(set -C; shasum -a 256 "$output" > "$output.sha256")
