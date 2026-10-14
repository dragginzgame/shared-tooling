#!/usr/bin/env bash
# Shared companions: docs/verification-helpers.md
set -euo pipefail
[[ $# -le 1 ]] || { echo 'usage: collect-release-changes.sh [BASE]' >&2; exit 2; }
export GIT_OPTIONAL_LOCKS=0
repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"
repository_root="$(pwd -P)"
if [[ -n "${1:-}" ]]; then
    base_ref="$1"
else
    base_ref="$(git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD)"
    if [[ ! "$base_ref" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
        echo "error: release-change base is not a canonical release tag: $base_ref" >&2
        exit 1
    fi
fi
if ! base_commit="$(git rev-parse --verify --quiet "$base_ref^{commit}")"; then
    echo "error: release-change base does not resolve to a commit: $base_ref" >&2
    exit 1
fi
paths="$(mktemp "${TMPDIR:-/tmp}/release-changes.XXXXXX")"
trap 'rm -f -- "$paths"' EXIT
# Publish nothing until both producers succeed; NULs preserve arbitrary filenames.
git diff --no-renames --no-relative --name-only --diff-filter=ACDMRTUXB -z "$base_commit" -- > "$paths"
git ls-files --others --exclude-standard -z >> "$paths"
# Exclude only this fresh, collector-owned scratch file if TMPDIR is in the tree.
# Caller-owned paths, including other files in that directory, stay observable.
scratch_parent="${paths%/*}"
[[ "$scratch_parent" == /* ]] || scratch_parent="$PWD/$scratch_parent"
physical_scratch="$(cd -P "$scratch_parent" && pwd)/${paths##*/}"
while IFS= read -r -d '' path; do
    [[ "$repository_root/$path" == "$physical_scratch" ]] || printf '%s\0' "$path"
done < "$paths"
