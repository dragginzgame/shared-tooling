#!/usr/bin/env bash
# Shared companions: scripts/ci/warn-release-prose.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
checker="${repository_root}/scripts/ci/warn-release-prose.sh"
fixture_root="$(mktemp -d)"
status_file="${fixture_root}/current.md"
# Bash 3.2 can report zero on nounset; cleanup also requires completion.
fixture_complete=false
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$repository_root/scripts/ci/fixture-lifecycle.sh"
trap 'fixture_finish "$?" "$fixture_root" "Failed release-prose fixture retained"' EXIT

printf '%s\n' \
    '# Current status' \
    '' \
    'Read Cargo for package identity.' \
    '' \
    '## Next action' \
    '' \
    'Review the bounded hygiene patch.' > "${status_file}"
clean_output="$(bash "${checker}" 0.3.7 "${status_file}" 2>&1)"
if [[ -n "${clean_output}" ]]; then
    echo "error: advisory warned about clean status prose" >&2
    echo "${clean_output}" >&2
    exit 1
fi

printf '%s\n' \
    '# Current status' \
    '' \
    'Version 0.3.7 remains a candidate.' > "${status_file}"
candidate_output="$(bash "${checker}" 0.3.7 "${status_file}" 2>&1)"
if [[ "${candidate_output}" != *"advisory only; release validation continues"* ]]; then
    echo "error: advisory missed target-version candidate wording" >&2
    exit 1
fi

printf '%s\n' \
    '# Current status' \
    '' \
    '## Next action' \
    '' \
    'Publish after release.' > "${status_file}"
next_action_output="$(bash "${checker}" 0.3.7 "${status_file}" 2>&1)"
if [[ "${next_action_output}" != *"next-action wording"* ]]; then
    echo "error: advisory missed stale next-action wording" >&2
    exit 1
fi

missing_output="$(bash "${checker}" 0.3.7 "${fixture_root}/missing.md" 2>&1)"
if [[ "${missing_output}" != *"continuing"* ]]; then
    echo "error: advisory did not fail open for a missing status file" >&2
    exit 1
fi

missing_target_output="$(bash "${checker}" '' "${status_file}" 2>&1)"
[[ "$missing_target_output" == *"no target version; continuing"* ]] || exit 1
# A failure of the prose reader also stays advisory, independently of heuristics.
mkdir "$fixture_root/bin"
printf '#!/usr/bin/env bash\nexit 73\n' > "$fixture_root/bin/awk"
chmod +x "$fixture_root/bin/awk"
PATH="$fixture_root/bin:$PATH" bash "$checker" 0.3.7 "$status_file"

fixture_complete=true
echo "Release-prose advisory checks passed"
