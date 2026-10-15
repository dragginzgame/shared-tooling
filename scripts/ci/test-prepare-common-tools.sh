#!/usr/bin/env bash
# Shared companions: .github/actions/prepare-common-tools/action.yml scripts/ci/fixture-lifecycle.sh scripts/ci/extract-workflow-step.sh
set -euo pipefail
ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/prepare-common-tools.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Common tool preparation fixture retained"' EXIT
yq -o json '.' "$ROOT/.github/actions/prepare-common-tools/action.yml" > "$fixture/prepare-action.json"
jq -e '
    .runs.using == "composite" and (.runs.steps | length) == 1 and
    .runs.steps[0].shell == "/bin/bash --noprofile --norc -e -o pipefail {0}"
' "$fixture/prepare-action.json" > /dev/null
jq -e '.runs.steps' "$fixture/prepare-action.json" > "$fixture/prepare-steps.json"
bash "$ROOT/scripts/ci/extract-workflow-step.sh" "$fixture/prepare-steps.json" prepare-tools > "$fixture/prepare-action.sh"
mkdir -p "$fixture/prepare-bin" "$fixture/prepare runner" "$fixture/prepare checkout"
cat > "$fixture/prepare-bin/make" <<'MAKE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$PREPARE_CALLS"
printf '%s stdout\n' "$*"
printf '%s stderr\n' "$*" >&2
case "$*" in
    install-tools) exit "$PREPARE_INSTALL_STATUS" ;;
    tools-check) exit "$PREPARE_CHECK_STATUS" ;;
    *) exit 99 ;;
esac
MAKE
chmod +x "$fixture/prepare-bin/make"
for failure in success install check; do
    install_status=0 check_status=0 expected=0
    case "$failure" in
        install) install_status=37 expected=37 ;;
        check) check_status=41 expected=41 ;;
    esac
    rm -f "$fixture/prepare runner/tools-install.log" "$fixture/prepare runner/tools-check.log"
    : > "$fixture/prepare-calls"
    printf 'existing PATH entry\n' > "$fixture/prepare-path"
    prepare_status=0
    PATH="$fixture/prepare-bin:$PATH" PREPARE_CALLS="$fixture/prepare-calls" \
        PREPARE_INSTALL_STATUS="$install_status" PREPARE_CHECK_STATUS="$check_status" \
        RUNNER_TEMP="$fixture/prepare runner" GITHUB_WORKSPACE="$fixture/prepare checkout" \
        GITHUB_PATH="$fixture/prepare-path" \
        "$BASH" --noprofile --norc -e -o pipefail "$fixture/prepare-action.sh" \
        > "$fixture/prepare-$failure.log" 2>&1 || prepare_status=$?
    [[ "$prepare_status" == "$expected" ]] || exit 1
    printf 'install-tools stdout\ninstall-tools stderr\n' > "$fixture/expected-install.log"
    cmp "$fixture/expected-install.log" "$fixture/prepare runner/tools-install.log"
    printf 'install-tools\n' > "$fixture/expected-calls"
    printf 'existing PATH entry\n' > "$fixture/expected-path"
    if [[ "$failure" == install ]]; then
        [[ ! -e "$fixture/prepare runner/tools-check.log" ]] || exit 1
    else
        printf 'tools-check\n' >> "$fixture/expected-calls"
        printf 'tools-check stdout\ntools-check stderr\n' > "$fixture/expected-check.log"
        cmp "$fixture/expected-check.log" "$fixture/prepare runner/tools-check.log"
    fi
    if [[ "$failure" == success ]]; then
        printf '%s\n' "$fixture/prepare checkout/.tools/host/bin" \
            "$fixture/prepare checkout/.tools/ic/bin" "$fixture/prepare checkout/.tools/rust/common/bin" \
            >> "$fixture/expected-path"
    fi
    cmp "$fixture/expected-calls" "$fixture/prepare-calls"
    cmp "$fixture/expected-path" "$fixture/prepare-path"
done
fixture_complete=true
printf 'Common tool preparation ordering, status, logs and PATH checks passed\n'
