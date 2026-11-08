#!/usr/bin/env bash
# Shared companions: scripts/ci/shared-package-version.pl scripts/ci/verify-shared-tooling-snapshot.sh
set -euo pipefail

# Parse the whole operation before refresh can replace this installed script.
main() {
    local mode="${1:-}" consumer="$PWD" source='' manifest=.shared-tooling.snapshot version=''
    local script_root records installed_version=unrecorded installed_revision='' installed_source=''
    local record first rest remote latest selected selected_version revision current
    local lock_record='' lock_source='' lock_version='' lock_revision='' lock_origin=''
    local lock_json=''
    case "$mode" in status|update|install|check) shift ;; *) echo 'usage: shared-tooling.sh status|update|install|check [--consumer DIR] [--source DIR] [--manifest PATH] [--version X.Y.Z]' >&2; return 2 ;; esac
    while [[ $# -gt 0 ]]; do
        [[ $# -ge 2 && -n "$2" ]] || return 2
        case "$1" in
            --consumer) consumer="$2" ;;
            --source) source="$2" ;;
            --manifest) manifest="$2" ;;
            --version) version="$2" ;;
            *) echo "unknown option: $1" >&2; return 2 ;;
        esac
        shift 2
    done
    [[ -z "$version" || "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'expected version X.Y.Z' >&2; return 2; }
    case "/$manifest/" in *'/../'*|*'/./'*|*'//'*) echo 'manifest must be a canonical relative path' >&2; return 2 ;; esac
    case "$consumer$source$manifest" in *$'\n'*|*$'\r'*) echo 'paths must not contain line breaks' >&2; return 2 ;; esac
    consumer="$(cd -P "$consumer" && pwd)"
    script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
    [[ -f "$consumer/$manifest" && ! -L "$consumer/$manifest" ]] || {
        echo 'No installed snapshot: perform initial adoption with refresh-consumer.sh and explicit entrypoints.' >&2; return 1;
    }
    records="$(bash "$script_root/scripts/ci/verify-shared-tooling-snapshot.sh" --read-manifest "$consumer/$manifest")" || return 1
    while IFS=$'\t' read -r record first rest; do
        case "$record" in
            '# version') installed_version="$first" ;;
            revision) installed_revision="$first" ;;
            source) installed_source="$first" ;;
        esac
    done <<< "$records"
    export PATH="$consumer/.tools/host/bin:$PATH"
    if [[ "$mode" == check ]]; then
        [[ -f "$consumer/Cargo.lock" ]] || return 0
        lock_json="$(yq -p toml -o json '.' "$consumer/Cargo.lock")" || return 1
        lock_record="$(printf '%s' "$lock_json" | jq -c '[.package[] | select(.name == "toko-tooling")] | if length==0 then null elif length==1 then .[0] else error("multiple toko-tooling selections") end')" || return 1
        [[ "$lock_record" != null ]] || return 0
        lock_source="$(printf '%s' "$lock_record" | jq -er .source)" || return 1
        lock_version="$(printf '%s' "$lock_record" | jq -er .version)" || return 1
        lock_origin="${lock_source#git+}"; lock_origin="${lock_origin%%#*}"; lock_origin="${lock_origin%%\?*}"; lock_origin="${lock_origin#file://}"
        if [[ "$lock_source" != git+*\#* || "${lock_source##*#}" != "$installed_revision" ||
              "$lock_version" != "$installed_version" || "${lock_origin%.git}" != "${installed_source%.git}" ]]; then
            echo 'Cargo selected different toko-tooling bytes. Run make shared-tooling-install before using or deploying this snapshot.' >&2
            return 1
        fi
        echo 'Cargo-selected toko-tooling matches installed snapshot.'
        return 0
    fi
    source="${source:-${consumer%/*}/shared-tooling}"
    source="$(cd -P "$source" && pwd)" || { echo 'Select the normal Shared Tooling checkout with SHARED_TOOLING_SOURCE or --source.' >&2; return 1; }
    [[ "$consumer" != "$source" ]] || { echo 'Run this in a consumer, not Shared Tooling itself.' >&2; return 1; }
    export GIT_NO_REPLACE_OBJECTS=1
    [[ "$(git -C "$source" rev-parse --show-toplevel)" == "$source" ]] || { echo 'source must be its checkout root' >&2; return 1; }
    remote="$(git -C "$source" remote get-url origin)"
    [[ "$remote" == "$installed_source" ]] || { echo 'Shared source origin differs from the installed snapshot; review the source selection.' >&2; return 1; }
    # Fetch objects/tracking only: never switch, reset, stash or edit the source checkout.
    git -C "$source" fetch --quiet --no-tags origin refs/heads/main:refs/remotes/origin/main
    source_version() {
        if git -C "$source" cat-file -e "$1:Cargo.toml" 2>/dev/null; then
            git -C "$source" show "$1:Cargo.toml" | perl "$script_root/scripts/ci/shared-package-version.pl" -
        else
            git -C "$source" show "$1:VERSION"
        fi
    }
    latest="$(git -C "$source" rev-parse --verify "refs/remotes/origin/main^{commit}")"
    # Cargo's resolved package identity owns installation once the marker is adopted.
    if [[ -f "$consumer/Cargo.lock" ]]; then
        lock_json="$(yq -p toml -o json '.' "$consumer/Cargo.lock")" || return 1
        lock_record="$(printf '%s' "$lock_json" | jq -cer '
            [.package[] | select(.name == "toko-tooling")] |
            if length == 0 then empty elif length == 1 then .[0]
            else error("multiple toko-tooling selections") end' )" || {
            [[ "$(printf '%s' "$lock_json" | jq '[.package[] | select(.name == "toko-tooling")] | length')" == 0 ]] || return 1
        }
    fi
    if [[ -n "$lock_record" ]]; then
        [[ -z "$version" ]] || { echo 'Cargo owns this selection; use cargo update -p toko-tooling --precise COMMIT, then make shared-tooling-install.' >&2; return 2; }
        if [[ "$mode" == update ]]; then
            (cd "$consumer" && cargo update --package toko-tooling)
            lock_record="$(yq -p toml -o json '.' "$consumer/Cargo.lock" | jq -ce '[.package[] | select(.name == "toko-tooling")] | if length == 1 then .[0] else error("expected one toko-tooling") end')"
        fi
        lock_source="$(printf '%s' "$lock_record" | jq -er .source)" || return 1
        lock_version="$(printf '%s' "$lock_record" | jq -er .version)" || return 1
        [[ "$lock_source" == git+*\#* ]] || { echo 'Expected a Git toko-tooling dependency; registry installation is not configured.' >&2; return 1; }
        lock_revision="${lock_source##*#}"
        [[ "$lock_revision" =~ ^[0-9a-f]{40}$ ]] || return 1
        lock_origin="${lock_source#git+}"; lock_origin="${lock_origin%%#*}"; lock_origin="${lock_origin%%\?*}"
        lock_origin="${lock_origin#file://}"
        [[ "${lock_origin%.git}" == "${remote%.git}" ]] || { echo 'Cargo selection origin differs from Shared Tooling source.' >&2; return 1; }
    elif [[ "$mode" == install && -f "$consumer/Cargo.toml" ]]; then
        echo 'Resolve the toko-tooling dev-dependency with cargo update before installation.' >&2; return 1
    fi
    selected="${lock_revision:-$latest}"
    if [[ -n "$version" ]]; then
        selected=''
        # Select the newest main-line commit carrying the requested version,
        # including fixes pushed under the same version, without relying on tags.
        while IFS= read -r revision; do
            current="$(source_version "$revision" 2>/dev/null)" || continue
            if [[ "$current" == "$version" ]]; then selected="$revision"; break; fi
        done < <(git -C "$source" rev-list --first-parent "$latest")
        [[ -n "$selected" ]] || { echo "No pushed main-line version $version found." >&2; return 1; }
    fi
    selected_version="$(source_version "$selected")"
    [[ -z "$lock_version" || "$lock_version" == "$selected_version" ]] || { echo 'Cargo version differs from selected source package.version.' >&2; return 1; }
    [[ "$selected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Selected source has an invalid package.version.' >&2; return 1; }
    printf 'Installed: %s (%s)\n' "$installed_version" "$installed_revision"
    printf 'Latest pushed: %s (%s)\n' "$(source_version "$latest")" "$latest"
    printf 'Selected: %s (%s)\n' "$selected_version" "$selected"
    if [[ "$mode" == status ]]; then
        if bash "$script_root/scripts/ci/verify-shared-tooling-snapshot.sh" --consumer "$consumer" --manifest "$manifest"; then
            echo 'Snapshot integrity: clean'
        else
            echo 'Snapshot integrity: modified or incomplete' >&2
            return 1
        fi
        if [[ "$installed_revision" == "$selected" ]]; then echo 'Snapshot: current'; else echo 'Snapshot: update available'; fi
        return 0
    fi
    bash "$source/scripts/distribution/refresh-consumer.sh" --source "$source" --revision "$selected" \
        --consumer "$consumer" --manifest "$manifest"
    # The exporter verifies committed provenance and refuses overwritten local edits.
    # Setup is separate from snapshot publication: on failure, retain the new
    # snapshot and report incomplete admission rather than claiming full adoption.
    if ! make --no-print-directory -C "$consumer" install-tools ||
       ! make --no-print-directory -C "$consumer" tools-check; then
        echo 'Snapshot installed, but tool setup/admission failed. Run make install-tools && make tools-check before using it.' >&2
        return 1
    fi
    main check --consumer "$consumer" --manifest "$manifest" || return 1
    printf 'Shared Tooling %s installed and tools admitted. No commit, release or deployment performed.\n' "$selected_version"
}
main "$@"
