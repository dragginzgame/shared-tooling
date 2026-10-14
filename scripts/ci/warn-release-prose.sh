#!/usr/bin/env bash
# Shared companions: docs/verification-helpers.md
set -uo pipefail

target_version="${1:-}"
status_file="${2:-docs/status/current.md}"

# This check is deliberately advisory. Package identity is enforced elsewhere;
# free-form prose must never strand a release after version mutation.
if [[ -z "${target_version}" ]]; then
    echo "warning: release-prose advisory has no target version; continuing" >&2
    exit 0
fi
if [[ ! -f "${status_file}" ]]; then
    echo "warning: release-prose advisory cannot read ${status_file}; continuing" >&2
    exit 0
fi

matches="$(
    awk -v target="${target_version}" '
        function report(reason) {
            print FNR ":" reason ":" $0
        }
        {
            lower = tolower($0)
            if ($0 ~ /^## /) {
                in_next_action = (lower == "## next action")
            }
            if (index($0, target) > 0 &&
                lower ~ /(candidate|unreleased|after[[:space:]]+(the[[:space:]]+)?release|release[[:space:]]+next|publish)/) {
                report("target-version wording")
            } else if (in_next_action &&
                lower ~ /(after[[:space:]]+(the[[:space:]]+)?release|release[[:space:]]+next|publish)/) {
                report("next-action wording")
            }
        }
    ' "${status_file}"
)"

if [[ -n "${matches}" ]]; then
    echo "warning: compact status prose may become stale when ${target_version} is released:" >&2
    echo "${matches}" >&2
    echo "warning: advisory only; release validation continues" >&2
fi

exit 0
