#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo 'usage: prepare-rust-toolchain.sh TOOLCHAIN [--component NAME[,NAME]...] [--target TARGET]...' >&2
    echo '       prepare-rust-toolchain.sh --toolchain-file FILE' >&2
    echo '       prepare-rust-toolchain.sh --workspace-manifest FILE [--component NAME[,NAME]...] [--target TARGET]...' >&2
    exit 2
}

if [[ "${1:-}" == --toolchain-file || "${1:-}" == --workspace-manifest ]]; then
    [[ $# -ge 2 && -f "$2" ]] || usage
    mode="$1" file="$2"
    shift 2
    # Use prepared TOML/JSON parsers, not a second interpretation of TOML.
    # All parsing and argument admission finish before the first rustup effect.
    document="$(yq -p toml -o json '.' "$file")"
    if [[ "$mode" == --toolchain-file ]]; then
        [[ $# == 0 ]] || usage
        selection="$(printf '%s' "$document" | jq -er '
            def token: type == "string" and test("\\A[A-Za-z0-9][A-Za-z0-9_.+-]*\\z");
            .toolchain | select(type == "object") |
            select(.channel | token) |
            select((if has("profile") then .profile else "minimal" end) | IN("minimal", "default", "complete")) |
            select((has("path") | not)) |
            select((if has("components") then .components else [] end) | type == "array" and all(.[]; token)) |
            select((if has("targets") then .targets else [] end) | type == "array" and all(.[]; token)) |
            .channel, "--profile", (.profile // "minimal"),
            ((.components // [])[] | "--component", .),
            ((.targets // [])[] | "--target", .)
        ')"
        arguments=(toolchain install)
        while IFS= read -r argument; do arguments+=("$argument"); done <<< "$selection"
        exec rustup "${arguments[@]}"
    fi
    version="$(printf '%s' "$document" | jq -er '
        .workspace.package."rust-version" |
        select(type == "string" and test("\\A[0-9]+\\.[0-9]+(\\.[0-9]+)?\\z"))
    ')"
    set -- "$version" "$@"
fi

[[ $# -ge 1 && -n "$1" && "$1" != -* && "$1" != *[[:space:]]* ]] || usage
arguments=(toolchain install "$1" --profile minimal)
shift
while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 && -n "$2" && "$2" != -* && "$2" != *[[:space:]]* ]] || usage
    case "$1" in
        --component)
            [[ "$2" != ,* && "$2" != *, && "$2" != *,,* ]] || usage
            ;;
        --target) ;;
        *) usage ;;
    esac
    arguments+=("$1" "$2")
    shift 2
done
# Admit the complete request before performing any installation. Never change
# the default toolchain or turn a missing validation prerequisite into setup.
exec rustup "${arguments[@]}"
