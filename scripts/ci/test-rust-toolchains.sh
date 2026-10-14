#!/usr/bin/env bash
# Shared companions: .github/actions/prepare-rust-toolchains/action.yml scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/rust-toolchains.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Rust toolchain fixture retained"' EXIT

yq -o=json '.' "$root/.github/actions/prepare-rust-toolchains/action.yml" > "$fixture/action.json"
jq -e '.runs.using == "composite" and (.runs.steps | length) == 1 and
    .runs.steps[0].shell == "/bin/bash --noprofile --norc -e -o pipefail {0}" and
    .runs.steps[0].env == {
        "DEVELOPMENT": "${{ inputs.development }}",
        "MINIMUM": "${{ inputs.minimum }}",
        "DEVELOPMENT_TARGET": "${{ inputs.development-target }}",
        "MINIMUM_TARGET": "${{ inputs.minimum-target }}"
    } and .inputs."development-target".default == "" and
    .inputs.development.required and .inputs.minimum.required and
    .inputs."minimum-target".required' "$fixture/action.json" >/dev/null
jq -r '.runs.steps[0].run' "$fixture/action.json" > "$fixture/run.sh"
mkdir "$fixture/bin"
cat > "$fixture/bin/rustup" <<'STUB'
#!/bin/bash
set -eu
printf '%s\0' "$@" >> "$TOOLCHAIN_FIXTURE/actual"
printf '\n' >> "$TOOLCHAIN_FIXTURE/calls"
if [[ "$(wc -l < "$TOOLCHAIN_FIXTURE/calls" | tr -d ' ')" == "$FAIL_AT" ]]; then
    echo 'installation failed' >&2
    exit 49
fi
STUB
chmod +x "$fixture/bin/rustup"
export TOOLCHAIN_FIXTURE="$fixture"
export DEVELOPMENT=1.99.0 MINIMUM=1.88.0 MINIMUM_TARGET=wasm32-unknown-unknown
export DEVELOPMENT_TARGET FAIL_AT=0
run_action() {
    : > "$fixture/actual"
    : > "$fixture/calls"
    status=0
    PATH="$fixture/bin:$PATH" /bin/bash --noprofile --norc -e -o pipefail "$fixture/run.sh" > "$fixture/output" 2>&1 || status=$?
}
# Exact arguments for routine CI and the recovery caller, including boundaries.
for DEVELOPMENT_TARGET in wasm32-unknown-unknown ''; do
    run_action
    [[ "$status" == 0 ]] || exit 1
    {
        printf '%s\0' toolchain install 1.99.0 --profile minimal --component rustfmt --component clippy
        if [[ -n "$DEVELOPMENT_TARGET" ]]; then printf '%s\0' --target wasm32-unknown-unknown; fi
        printf '%s\0' toolchain install 1.88.0 --profile minimal --target wasm32-unknown-unknown
    } > "$fixture/expected"
    cmp "$fixture/expected" "$fixture/actual"
done
# Neither installation failure can be hidden or run subsequent setup.
for FAIL_AT in 1 2; do
    run_action
    [[ "$status" == 49 ]] || exit 1
    [[ "$(wc -l < "$fixture/calls" | tr -d ' ')" == "$FAIL_AT" ]] || exit 1
    grep -Fx 'installation failed' "$fixture/output" >/dev/null
done
FAIL_AT=0
# Reject malformed explicit selections before either install, including the
# second toolchain's input. Empty optional development target remains valid.
for input in DEVELOPMENT MINIMUM MINIMUM_TARGET DEVELOPMENT_TARGET; do
    saved="${!input}"
    for invalid in '' '--help' 'two words' $'line\nbreak'; do
        [[ "$input" != DEVELOPMENT_TARGET || -n "$invalid" ]] || continue
        printf -v "$input" '%s' "$invalid"
        run_action
        [[ "$status" == 2 && ! -s "$fixture/calls" ]] || exit 1
    done
    printf -v "$input" '%s' "$saved"
done
fixture_complete=true
printf 'Rust toolchain action fixtures passed\n'
