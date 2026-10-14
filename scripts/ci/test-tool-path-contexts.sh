#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/ci/test-tool-commands.sh scripts/ci/test-rust-tools.sh scripts/ci/test-host-tools.sh scripts/ci/test-tag-maintenance.pl
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/tool-path-contexts.XXXXXX")"
fixture="$(cd -P "$fixture" && pwd)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Tool path-context evidence retained"' EXIT
mkdir "$fixture/physical"
ln -s "$fixture/physical" "$fixture/alias"
for context in trailing-slash directory-alias; do
    case "$context" in
        trailing-slash) selected_tmp="$fixture/physical/" ;;
        directory-alias) selected_tmp="$fixture/alias" ;;
    esac
    for script in test-tool-commands.sh test-rust-tools.sh test-host-tools.sh test-tag-maintenance.pl; do
        runner=bash
        [[ "$script" != *.pl ]] || runner=perl
        TMPDIR="$selected_tmp" "$runner" "$ROOT/scripts/ci/$script" --path-context \
            > "$fixture/$script-$context.log" 2>&1
        # Successful probes remove their disposable roots, including via aliases.
        [[ -z "$(ls -A "$fixture/physical")" ]] || { echo "context cleanup failed: $script" >&2; exit 1; }
    done
done
fixture_complete=true
echo 'Focused tool and tag path contexts passed (substitute tools; no live effects)'
