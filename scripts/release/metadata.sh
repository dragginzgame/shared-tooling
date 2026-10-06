#!/usr/bin/env bash
set -euo pipefail

operation="${1:-}"
[[ $# -eq 1 ]] || exit 2
version() {
    awk '/^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]+-[0-9]+-[0-9]+$/ {
        print substr($2, 2, length($2)-2); found=1; exit
    } END { if (!found) exit 2 }' "${1:-CHANGELOG.md}"
}
admit_files() {
    paths="$(mktemp "${TMPDIR:-/tmp}/shared-release-paths.XXXXXX")"
    trap 'rm -f "$paths"' EXIT
    # HEAD-to-worktree alone hides staged edits reverted only in the worktree.
    git diff --cached --name-only -z HEAD -- > "$paths"
    git diff --name-only -z -- >> "$paths"
    git ls-files --others --exclude-standard -z >> "$paths"
    while IFS= read -r -d '' path; do
        [[ "$path" == CHANGELOG.md ]] || { printf 'uncommitted non-release path: %q\n' "$path" >&2; exit 1; }
    done < "$paths"
    rm -f "$paths"
    trap - EXIT
}
case "$operation" in
    version) version ;;
    preflight)
        [[ "$(version)" == "${RELEASE_PREVIOUS:?}" ]]
        admit_files
        [[ -f CHANGELOG.md && ! -L CHANGELOG.md ]]
        # Exercise the same selection check before validation or saved intent.
        awk -v version="${RELEASE_VERSION:?}" -v date="${RELEASE_DATE:?}" \
            -f scripts/ci/finalize-release-changelog.awk CHANGELOG.md > /dev/null
        ;;
    prepare)
        [[ "$(version)" == "${RELEASE_PREVIOUS:?}" ]]
        [[ -f CHANGELOG.md && ! -L CHANGELOG.md ]]
        temporary="$(mktemp CHANGELOG.md.release.XXXXXX)"
        trap 'rm -f "$temporary"' EXIT
        cp -p CHANGELOG.md "$temporary"
        awk -v version="${RELEASE_VERSION:?}" -v date="${RELEASE_DATE:?}" \
            -f scripts/ci/finalize-release-changelog.awk CHANGELOG.md > "$temporary"
        mv "$temporary" CHANGELOG.md
        trap - EXIT
        ;;
    check|commit-check)
        notes=CHANGELOG.md
        if [[ -n "${RELEASE_COMMIT:-}" ]]; then
            notes="$(mktemp "${TMPDIR:-/tmp}/shared-release-notes.XXXXXX")"
            trap 'rm -f "$notes"' EXIT
            git show "$RELEASE_COMMIT:CHANGELOG.md" > "$notes"
        fi
        checked_version="$(version "$notes")"
        [[ "$checked_version" == "${RELEASE_VERSION:?}" ]]
        awk -v heading="## [$RELEASE_VERSION] - ${RELEASE_DATE:?}" \
            '$0 == heading { count++ } END { if (count != 1) exit 1 }' "$notes"
        if [[ "$notes" != CHANGELOG.md ]]; then rm -f "$notes"; trap - EXIT; fi
        admit_files
        if [[ "$operation" == commit-check ]]; then
            # Staging must contain the exact prepared metadata that was checked.
            git diff --quiet -- CHANGELOG.md
        fi
        ;;
    *) echo 'usage: metadata.sh version|preflight|prepare|check|commit-check' >&2; exit 2 ;;
esac
