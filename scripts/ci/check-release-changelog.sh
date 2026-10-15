#!/usr/bin/env bash
# Shared companions: scripts/ci/finalize-release-changelog.awk
set -euo pipefail

# Admit a candidate before setup or mutation. Preparation remains the sole writer.
[[ $# == 4 ]] || { echo 'usage: check-release-changelog.sh VERSION PREVIOUS DATE CHANGELOG' >&2; exit 2; }
version="$1" previous="$2" date="$3" changelog="$4"
stable='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
[[ "$version" =~ $stable && "$previous" =~ $stable && "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || exit 2
[[ -f "$changelog" && ! -L "$changelog" ]] || { echo 'changelog must be a regular file' >&2; exit 1; }
root="${BASH_SOURCE[0]%/*}"
# pipefail preserves a failed reader even if its partial output is admissible.
cat -- "$changelog" | awk -v version="$version" -v previous="$previous" -v date="$date" \
    -f "$root/finalize-release-changelog.awk" > /dev/null
