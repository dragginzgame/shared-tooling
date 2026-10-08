#!/usr/bin/env bash
set -euo pipefail

# Repository-local suite setup; consumer validation owns its own prerequisites.
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
[[ $# == 0 ]] || { echo 'usage: check-portable-prerequisites.sh' >&2; exit 2; }
missing=0
for tool in bash git make curl tar gzip xz perl shasum cargo jq yq rg cloc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Missing portable-test prerequisite: %s\n' "$tool" >&2
        missing=1
    fi
done
if [[ "$missing" == 1 ]]; then
    echo 'See docs/local-setup.md: install bootstrap packages, prepare local host tools and select their bin directory on PATH.' >&2
    exit 1
fi
# Reuse the exact formatter pin and offline toolchain admission owner.
# shellcheck source=/dev/null
source "$ROOT/ci/tool-versions.env"
if ! bash "$ROOT/scripts/ci/check-format-tools.sh" "$SHARED_TOOLING_CARGO_SORT_VERSION"; then
    echo 'See docs/local-setup.md for explicit Cargo/rustfmt/cargo-sort setup; no tools were installed.' >&2
    exit 1
fi
