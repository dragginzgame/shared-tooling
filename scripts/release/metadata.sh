#!/usr/bin/env bash
# Shared companions: scripts/ci/shared-package-version.pl scripts/ci/check-release-source.sh scripts/ci/finalize-release-changelog.awk scripts/release/work-version.pl
set -euo pipefail
SCRIPT_ROOT="${BASH_SOURCE[0]}"
[[ "$SCRIPT_ROOT" == /* ]] || SCRIPT_ROOT="$PWD/$SCRIPT_ROOT"
SCRIPT_ROOT="$(cd -P "${SCRIPT_ROOT%/*}/../.." && printf '%s/.' "$PWD")"
SCRIPT_ROOT="${SCRIPT_ROOT%/.}"

operation="${1:-}"
[[ $# -eq 1 ]] || exit 2
prepare_tools="${SHARED_RELEASE_PREPARE_TOOLS:-0}"
unset SHARED_RELEASE_PREPARE_TOOLS
[[ "$prepare_tools" == 0 || "$prepare_tools" == 1 ]] || exit 2
version() {
    perl "$SCRIPT_ROOT/scripts/ci/shared-package-version.pl" "${1:-Cargo.toml}"
}
finalize_notes() {
    awk -v version="${RELEASE_VERSION:?}" -v previous="${RELEASE_PREVIOUS:?}" \
        -v date="${RELEASE_DATE:?}" -v allow_finalized=1 \
        -f "$SCRIPT_ROOT/scripts/ci/finalize-release-changelog.awk" "$1"
}
release_tools() {
    if [[ "$1" == fresh && "$prepare_tools" == 1 ]]; then
        "${RELEASE_MAKE:-make}" --no-print-directory install-tools || return "$?"
    fi
    "${RELEASE_MAKE:-make}" --no-print-directory tools-check
}
metadata_complete=false
# shellcheck disable=SC2329 # Invoked by the EXIT traps after scratch allocation.
finish_metadata() {
    local status=$?
    [[ "$metadata_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then
        rm -rf -- "$temporary" || status=$?
        [[ ! -e "$temporary" && ! -L "$temporary" ]] || { [[ "$status" != 0 ]] || status=1; }
    fi
    if [[ "$status" != 0 ]]; then
        printf 'Shared release metadata evidence retained: %s\n' "$temporary" >&2 || :
    fi
    exit "$status"
}
case "$operation" in
    version) version ;;
    preflight|prepare)
        observed_version="$(version)" || exit 1
        [[ "$observed_version" == "${RELEASE_PREVIOUS:?}" || "$observed_version" == "${RELEASE_VERSION:?}" ]] || exit 1
        bash "$SCRIPT_ROOT/scripts/ci/check-release-source.sh" --allow CHANGELOG.md --allow Cargo.toml
        [[ -f CHANGELOG.md && ! -L CHANGELOG.md ]] || exit 1
        # Git-owned scratch cannot become an unrelated untracked release input
        # if the process is killed before cleanup. Cargo.toml is replaced last.
        temporary="$(mktemp -d "$(git rev-parse --git-dir)/release-metadata.XXXXXX")"
        [[ "$temporary" == /* ]] || temporary="$PWD/$temporary"
        trap finish_metadata EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        mkdir "$temporary/original" "$temporary/candidate"
        cp -p CHANGELOG.md Cargo.toml "$temporary/original/"
        cp -p "$temporary/original/CHANGELOG.md" "$temporary/candidate/CHANGELOG.md"
        finalize_notes "$temporary/original/CHANGELOG.md" > "$temporary/candidate/CHANGELOG.md"
        if [[ "$operation" == preflight ]]; then
            # The runner saves intent before preparation and calls preflight
            # again when reconciling that phase. Never install during that check
            # or after an interrupted notes replacement, even with an old Cargo.toml.
            state="$(git rev-parse --git-path release-state)"
            if [[ "${RELEASE_DELIVERY:-direct}" == pr ]]; then
                state="$(git rev-parse --git-common-dir)/release-state"
            fi
            tool_phase=check
            if [[ ! -e "$state/$RELEASE_VERSION.plan" && ! -L "$state/$RELEASE_VERSION.plan" ]]; then
                if cmp -s CHANGELOG.md "$temporary/candidate/CHANGELOG.md"; then :; else
                    comparison_status=$?
                    [[ "$comparison_status" == 1 ]] || {
                        echo 'cannot compare release notes before tool preparation' >&2
                        exit "$comparison_status"
                    }
                    tool_phase=fresh
                fi
            fi
            release_tools "$tool_phase"
        fi
        if [[ "$operation" == prepare ]]; then
            cp -p "$temporary/original/Cargo.toml" "$temporary/candidate/Cargo.toml"
            perl "$SCRIPT_ROOT/scripts/ci/shared-package-version.pl" --set "${RELEASE_VERSION:?}" \
                "$temporary/original/Cargo.toml" > "$temporary/candidate/Cargo.toml"
            version "$temporary/candidate/Cargo.toml" > /dev/null
            # Publish separate copies so even a failed second rename retains
            # both complete candidates as well as the pre-attempt originals.
            cp -p "$temporary/candidate/CHANGELOG.md" "$temporary/CHANGELOG.md"
            cp -p "$temporary/candidate/Cargo.toml" "$temporary/Cargo.toml"
            mv "$temporary/CHANGELOG.md" CHANGELOG.md
            # If interrupted here, the saved attempt can safely repeat preparation:
            # finalization accepts only these exact already-prepared notes.
            mv "$temporary/Cargo.toml" Cargo.toml
        fi
        metadata_complete=true
        ;;
    check|commit-check|merged-preflight)
        bash "$SCRIPT_ROOT/scripts/ci/check-release-source.sh" --allow CHANGELOG.md --allow Cargo.toml
        temporary="$(mktemp -d "${TMPDIR:-/tmp}/shared-release-metadata.XXXXXX")"
        [[ "$temporary" == /* ]] || temporary="$PWD/$temporary"
        trap finish_metadata EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        notes=CHANGELOG.md
        selected_version=Cargo.toml
        if [[ -n "${RELEASE_COMMIT:-}" ]]; then
            notes="$temporary/CHANGELOG.md"
            selected_version="$temporary/Cargo.toml"
            git show "$RELEASE_COMMIT:CHANGELOG.md" > "$notes"
            git show "$RELEASE_COMMIT:Cargo.toml" > "$selected_version"
        fi
        [[ -f "$notes" && ! -L "$notes" ]] || exit 1
        observed_version="$(version "$selected_version")" || exit 1
        [[ "$observed_version" == "${RELEASE_VERSION:?}" ]] || exit 1
        finalize_notes "$notes" > "$temporary/finalized"
        cmp -s "$notes" "$temporary/finalized"
        if [[ "$operation" == merged-preflight ]]; then
            observed_commit="$(git rev-parse --verify HEAD)"
            [[ "$observed_commit" == "${RELEASE_COMMIT:?}" ]] || exit 1
            release_tools fresh
        fi
        if [[ "$operation" == commit-check ]]; then
            # Both index entries must contain the exact prepared metadata.
            git diff --quiet -- CHANGELOG.md Cargo.toml
            for path in CHANGELOG.md Cargo.toml; do
                git cat-file -e ":$path"
            done
        fi
        metadata_complete=true
        ;;
    *) echo 'usage: metadata.sh version|preflight|prepare|check|commit-check|merged-preflight' >&2; exit 2 ;;
esac
