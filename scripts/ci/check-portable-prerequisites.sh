#!/usr/bin/env bash
# Shared companions: scripts/ci/tool-catalog-records.pl scripts/ci/check-format-tools.sh ci/tool-versions.env
set -euo pipefail

# Repository-local suite setup; consumer validation owns its own prerequisites.
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
[[ $# == 0 ]] || { echo 'usage: check-portable-prerequisites.sh' >&2; exit 2; }
missing=0
for tool in bash git make curl tar gzip xz zip unzip perl shasum cargo jq yq rg cloc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Missing portable-test prerequisite: %s\n' "$tool" >&2
        missing=1
    fi
done
if [[ "$missing" == 1 ]]; then
    echo 'See docs/local-setup.md: install bootstrap packages, prepare local host tools and select their bin directory on PATH.' >&2
    exit 1
fi
# Prepared archive-license qualification uses the maintained Perl tar parser.
if ! perl -MArchive::Tar -e 'exit 0'; then
    echo 'Portable tests require Perl Archive::Tar; install the documented system Perl modules.' >&2
    exit 1
fi
# Reuse the exact formatter pin and offline toolchain admission owner.
record="$(perl "$ROOT/scripts/ci/tool-catalog-records.pl" rust "$ROOT/ci/tool-versions.env" CARGO_SORT)"
IFS=$'\t' read -r _ sort_version _ _ <<< "$record"
if ! bash "$ROOT/scripts/ci/check-format-tools.sh" "$sort_version"; then
    echo 'See docs/local-setup.md for explicit Cargo/rustfmt/cargo-sort setup; no tools were installed.' >&2
    exit 1
fi
