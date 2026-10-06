#!/usr/bin/env bash
set -euo pipefail
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

operation="${1:-}"
[[ $# -eq 1 ]] || exit 2
version() {
    local file="${1:-VERSION}" value
    [[ -f "$file" && ! -L "$file" ]] || { echo "missing regular version file: $file" >&2; return 1; }
    value="$(cat "$file")" || return 1
    [[ "$value" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
        echo "invalid version file: $file" >&2; return 1;
    }
    printf '%s\n' "$value"
}
admit_files() (
    paths="$(mktemp "${TMPDIR:-/tmp}/shared-release-paths.XXXXXX")"
    trap 'rm -f "$paths"' EXIT
    # HEAD-to-worktree alone hides staged edits reverted only in the worktree.
    git diff --cached --name-only -z HEAD -- > "$paths"
    git diff --name-only -z -- >> "$paths"
    git ls-files --others --exclude-standard -z >> "$paths"
    while IFS= read -r -d '' path; do
        [[ "$path" == CHANGELOG.md || "$path" == VERSION ]] || {
            printf 'uncommitted non-release path: %q\n' "$path" >&2; exit 1;
        }
    done < "$paths"
)
finalize_notes() {
    awk -v version="${RELEASE_VERSION:?}" -v previous="${RELEASE_PREVIOUS:?}" \
        -v date="${RELEASE_DATE:?}" -v allow_finalized=1 \
        -f "$SCRIPT_ROOT/scripts/ci/finalize-release-changelog.awk" "$1"
}
case "$operation" in
    version) version ;;
    preflight|prepare)
        [[ "$(version)" == "${RELEASE_PREVIOUS:?}" ]]
        admit_files
        [[ -f CHANGELOG.md && ! -L CHANGELOG.md ]]
        # Git-owned scratch cannot become an unrelated untracked release input
        # if the process is killed before cleanup. VERSION is replaced last.
        temporary="$(mktemp -d "$(git rev-parse --git-dir)/release-metadata.XXXXXX")"
        trap 'rm -rf "$temporary"' EXIT
        cp -p CHANGELOG.md "$temporary/CHANGELOG.md"
        finalize_notes CHANGELOG.md > "$temporary/CHANGELOG.md"
        if [[ "$operation" == prepare ]]; then
            cp -p VERSION "$temporary/VERSION"
            printf '%s\n' "${RELEASE_VERSION:?}" > "$temporary/VERSION"
            version "$temporary/VERSION" > /dev/null
            mv "$temporary/CHANGELOG.md" CHANGELOG.md
            # If interrupted here, the saved attempt can safely repeat preparation:
            # finalization accepts only these exact already-prepared notes.
            mv "$temporary/VERSION" VERSION
        fi
        ;;
    check|commit-check)
        admit_files
        temporary="$(mktemp -d "${TMPDIR:-/tmp}/shared-release-metadata.XXXXXX")"
        trap 'rm -rf "$temporary"' EXIT
        notes=CHANGELOG.md
        selected_version=VERSION
        if [[ -n "${RELEASE_COMMIT:-}" ]]; then
            notes="$temporary/CHANGELOG.md"
            selected_version="$temporary/VERSION"
            git show "$RELEASE_COMMIT:CHANGELOG.md" > "$notes"
            git show "$RELEASE_COMMIT:VERSION" > "$selected_version"
        fi
        [[ -f "$notes" && ! -L "$notes" ]]
        [[ "$(version "$selected_version")" == "${RELEASE_VERSION:?}" ]]
        finalize_notes "$notes" > "$temporary/finalized"
        cmp -s "$notes" "$temporary/finalized"
        if [[ "$operation" == commit-check ]]; then
            # Both index entries must contain the exact prepared metadata.
            git diff --quiet -- CHANGELOG.md VERSION
            for path in CHANGELOG.md VERSION; do
                git cat-file -e ":$path"
            done
        fi
        ;;
    *) echo 'usage: metadata.sh version|preflight|prepare|check|commit-check' >&2; exit 2 ;;
esac
