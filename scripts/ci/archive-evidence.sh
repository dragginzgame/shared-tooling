#!/usr/bin/env bash
set -euo pipefail

# Archive explicit evidence selections without following links. Callers own
# selection, identity/outcome records, upload and retention. Requires tar/gzip.
[[ $# -ge 3 && $(( ($# - 1) % 2 )) == 0 ]] || {
    echo 'usage: archive-evidence.sh NEW-ARCHIVE ROOT RELATIVE-PATH [ROOT RELATIVE-PATH]...' >&2
    exit 2
}
output="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
shift
arguments=()
paths=()
while [[ $# -gt 0 ]]; do
    root="$(cd "$1" && pwd -P)"
    path="$2"
    shift 2
    case "/$path/" in
        //|//*|*'/../'*|*'/./'*|*'//'*)
            [[ "$path" == . ]] || { echo 'evidence paths must be canonical and relative' >&2; exit 2; } ;;
    esac
    [[ -e "$root/$path" || -L "$root/$path" ]] || {
        printf 'evidence input is missing: %s/%s\n' "$root" "$path" >&2; exit 1;
    }
    parent="$(dirname "$path")"
    while [[ "$parent" != . ]]; do
        [[ ! -L "$root/$parent" ]] || { echo 'evidence input traverses a symlink' >&2; exit 1; }
        parent="$(dirname "$parent")"
    done
    # Disallow duplicate/overlapping archive names even across different roots.
    # Preserve final symlinks themselves; tar must never dereference their targets.
    for prior in ${paths[@]+"${paths[@]}"}; do
        if [[ "$path" == . || "$prior" == . || "$path/" == "$prior/"* || "$prior/" == "$path/"* ]]; then
            echo 'evidence selections have overlapping archive paths' >&2; exit 1;
        fi
    done
    input="$root/$path"
    [[ "$path" != . ]] || input="$root"
    [[ "$output" != "$input" && "$output" != "$input/"* ]] || {
        echo 'archive output must be outside selected inputs' >&2; exit 1;
    }
    paths+=("$path")
    arguments+=(-C "$root" "./$path")
done
# noclobber admits one new output, including when another writer wins the race.
# Keep a partially written archive and all original evidence on any tar failure.
if ! (set -C; tar -czf - --exclude=.git --exclude='*/.git' --exclude='*/.git/*' \
    "${arguments[@]}" > "$output"); then
    printf 'Evidence archive failed; original inputs and any partial output retained: %s\n' "$output" >&2
    exit 1
fi
printf '%s\n' "$output"
