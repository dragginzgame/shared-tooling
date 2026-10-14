#!/usr/bin/env bash
# Shared companions: scripts/dev/install-host-tools.sh scripts/ci/run-validation-targets.sh
set -euo pipefail

# Deliberately fail a manually selected hosted job through maintained owners.
# Do not select this driver in ordinary CI or in release commands.
[[ $# == 5 && ( "$1" == early || "$1" == late ) ]] || {
    echo 'usage: qualify-hosted-failure.sh early|late CONSUMER EVIDENCE_PARENT HOST_CATALOG FAILURE_LOG_ROOT' >&2; exit 2;
}
[[ "${GITHUB_ACTIONS:-}" == true && "${GITHUB_EVENT_NAME:-}" == workflow_dispatch ]] || {
    echo 'failure qualification requires an explicit manual CI dispatch' >&2; exit 2;
}
: "${GITHUB_WORKSPACE:?qualification requires GITHUB_WORKSPACE}"
: "${RUNNER_TEMP:?qualification requires RUNNER_TEMP}"
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
workspace="$2"
[[ "$workspace" == /* ]] || workspace="$PWD/$workspace"
workspace="$(cd -P "$workspace" && printf '%s/.' "$PWD")"
workspace="${workspace%/.}"
selected_workspace="$(cd -P "$GITHUB_WORKSPACE" && printf '%s/.' "$PWD")"
selected_workspace="${selected_workspace%/.}"
[[ "$workspace" == "$selected_workspace" ]] || {
    echo 'qualification must use the selected CI checkout' >&2; exit 2;
}
stage="$1"
temporary="$3"
[[ "$temporary" == /* ]] || temporary="$PWD/$temporary"
temporary="$(cd -P "$temporary" && printf '%s/.' "$PWD")"
temporary="${temporary%/.}"
host_catalog="$4"
failure_logs="$5"
[[ -f "$host_catalog" && ! -L "$host_catalog" && "$host_catalog" == /* && "$failure_logs" == /* ]] || exit 2
export TMPDIR="$temporary"
scenario="$(mktemp -d "$temporary/hosted-${stage}.XXXXXX")"
printf 'Qualification scenario retained: %s\n' "$scenario"
mkdir -p "$scenario/consumer" "$scenario/bin"
printf 'controlled %s input\n' "$stage" > "$scenario/consumer/input.txt"
chmod 0640 "$scenario/consumer/input.txt"
cp -p "$scenario/consumer/input.txt" "$scenario/before.txt"
status=0

case "$stage" in
    early)
        # Fail the real installer after it creates its candidate, without a
        # network request or changes to the checkout's active tool bundle.
        cat > "$scenario/bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
output=''
while [[ $# -gt 0 ]]; do
    if [[ "$1" == -o ]]; then output="$2"; shift; fi
    shift
done
[[ -n "$output" ]] || exit 2
printf 'controlled rejected download bytes\n' > "$output"
echo 'error: controlled early installer download failure' >&2
exit 22
SCRIPT
        chmod 0755 "$scenario/bin/curl"
        # A previously cached real bundle must not bypass the controlled download
        # failure. Keep this scenario's store inside its retained scratch root.
        SHARED_TOOLING_STORE="$scenario/tool-store" PATH="$scenario/bin:$PATH" \
            bash "$root/scripts/dev/install-host-tools.sh" \
            --consumer "$scenario/consumer" --versions "$host_catalog" \
            > "$scenario/scenario.log" 2>&1 || status=$?
        expected=22
        ;;
    late)
        # Exercise the actual logger's raw/combined failure retention. The
        # workflow reaches this step only after its last normal gate succeeds.
        cat > "$scenario/consumer/Makefile" <<'MAKE'
.PHONY: evidence-failure
evidence-failure:
	@echo 'error: controlled late validation failure'
	@exit 23
MAKE
        VALIDATION_REPOSITORY_ROOT="$scenario/consumer" \
            VALIDATION_FAILURE_LOG_DIR="$failure_logs" \
            VALIDATION_RUNNER_DEPTH=0 GITHUB_STEP_SUMMARY='' \
            bash "$root/scripts/ci/run-validation-targets.sh" evidence-failure \
            > "$scenario/scenario.log" 2>&1 || status=$?
        # GNU Make preserves the failed recipe as a failed command with status 2.
        expected=2
        ;;
esac
cp -p "$scenario/consumer/input.txt" "$scenario/after.txt"
cmp "$scenario/before.txt" "$scenario/after.txt"
printf 'stage=%s\nstatus=%s\nexpected=%s\n' "$stage" "$status" "$expected" > "$scenario/status.txt"
cat "$scenario/scenario.log"
[[ "$status" == "$expected" ]] || {
    echo "error: ${stage} qualification did not reach its controlled failure" >&2; exit 1;
}
printf 'Controlled %s failure reached; preserving status %s for collection.\n' "$stage" "$status"
exit "$status"
