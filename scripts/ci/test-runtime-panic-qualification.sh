#!/usr/bin/env bash
# Shared companions: scripts/ci/qualify-runtime-panics.sh scripts/ci/fixture-lifecycle.sh scripts/ci/extract-workflow-step.sh .github/workflows/ci.yml
set -euo pipefail
ROOT="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/runtime-qualification.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Runtime qualification fixture retained"' EXIT
mkdir "$fixture/bin"
cat > "$fixture/bin/rustup" <<'RUSTUP'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$QUALIFICATION_EVENTS"
[[ "$1" == run ]] || exit 99
shift 2
case "$1 ${2:-}" in
    'cargo --version') [[ "$QUALIFICATION_CASE" != unprepared ]] || exit 37 ;;
    'rustc --version') [[ "$QUALIFICATION_CASE" != compiler ]] || exit 41 ;;
    'rustfmt --edition') [[ "$QUALIFICATION_CASE" != rustfmt ]] || exit 43 ;;
    'cargo build')
        [[ "$QUALIFICATION_CASE" != build ]] || exit 47
        while [[ $# -gt 0 && "$1" != --target-dir ]]; do shift; done
        [[ $# == 2 ]] || exit 99
        mkdir -p "$2/debug"
        # A deliberately failing producer is not scanner qualification. The
        # real semantic fixture must reject it and preserve its own diagnostics.
        printf '#!/bin/sh\nexit 23\n' > "$2/debug/shared-runtime-scanner"
        chmod +x "$2/debug/shared-runtime-scanner" ;;
    'cargo clippy') [[ "$QUALIFICATION_CASE" != clippy ]] || exit 49 ;;
    *) exit 99 ;;
esac
printf 'substituted compiler output\n'
RUSTUP
chmod +x "$fixture/bin/rustup"
export PATH="$fixture/bin:$PATH" QUALIFICATION_EVENTS="$fixture/events"
for scenario in unprepared compiler rustfmt build clippy semantics; do
    : > "$QUALIFICATION_EVENTS"
    expected=1
    case "$scenario" in
        unprepared) expected=37 ;; compiler) expected=41 ;; rustfmt) expected=43 ;;
        build) expected=47 ;; clippy) expected=49 ;;
    esac
    status=0
    QUALIFICATION_CASE="$scenario" "$BASH" "$ROOT/scripts/ci/qualify-runtime-panics.sh" fixture-compiler "$fixture/$scenario" \
        > "$fixture/$scenario.log" 2>&1 || status=$?
    [[ "$status" == "$expected" ]] || exit 1
    if [[ "$scenario" == unprepared ]]; then
        [[ ! -e "$fixture/$scenario" && "$(wc -l < "$QUALIFICATION_EVENTS")" -eq 1 ]] || exit 1
    else
        cmp "$ROOT/scripts/ci/check-runtime-panics.rs" "$fixture/$scenario/workspace/crates/scanner/src/main.rs"
        cmp "$ROOT/ci/runtime-panics/Cargo.lock.in" "$fixture/$scenario/workspace/Cargo.lock"
        grep -F "Runtime scanner qualification evidence: $fixture/$scenario" "$fixture/$scenario.log" > /dev/null
        if [[ "$scenario" == semantics ]]; then
            grep -F 'Fixture no-input: expected 2, got 23' "$fixture/$scenario/semantics.log" > /dev/null
        fi
    fi
done
mkdir "$fixture/existing" "$fixture/forbidden"$'\n'
printf 'preserved\n' > "$fixture/existing/input"
ln -s "$fixture/forbidden"$'\n' "$fixture/alias"
for selected in "$fixture/existing" relative "$fixture/raw"$'\n' "$fixture/alias/new"; do
    : > "$QUALIFICATION_EVENTS"
    status=0
    QUALIFICATION_CASE=unprepared "$BASH" "$ROOT/scripts/ci/qualify-runtime-panics.sh" fixture-compiler "$selected" \
        > "$fixture/invalid.log" 2>&1 || status=$?
    [[ "$status" == 2 && ! -s "$QUALIFICATION_EVENTS" ]] || exit 1
done
[[ "$(cat "$fixture/existing/input")" == preserved && ! -e "$fixture/alias/new" ]] || exit 1

# Execute the actual hosted caller with a refusing compiler. Neither a typo in
# dispatch nor a pipeline that masks its failure can qualify this boundary.
yq -o json '.jobs."portable-regression".steps' "$ROOT/.github/workflows/ci.yml" > "$fixture/steps.json"
bash "$ROOT/scripts/ci/extract-workflow-step.sh" "$fixture/steps.json" runtime-scanner > "$fixture/caller.sh"
mkdir -p "$fixture/runner/portable-fixtures"
: > "$QUALIFICATION_EVENTS"
status=0
(cd "$ROOT" && QUALIFICATION_CASE=unprepared RUNNER_TEMP="$fixture/runner" \
    "$BASH" --noprofile --norc -e -o pipefail "$fixture/caller.sh") > "$fixture/caller.log" 2>&1 || status=$?
[[ "$status" == 37 && ! -e "$fixture/runner/portable-fixtures/runtime-scanner" ]] || exit 1
printf 'run 1.88.0 cargo --version\n' > "$fixture/expected-events"
cmp "$fixture/expected-events" "$QUALIFICATION_EVENTS"
fixture_complete=true
echo 'Native scanner caller admission, retained failures and refusal-before-effects passed'
