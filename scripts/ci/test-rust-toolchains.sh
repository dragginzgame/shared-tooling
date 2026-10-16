#!/usr/bin/env bash
# Shared companions: .github/actions/prepare-rust-toolchains/action.yml scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/rust-toolchains.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Rust toolchain fixture retained"' EXIT

yq -o=json '.' "$root/.github/actions/prepare-rust-toolchains/action.yml" > "$fixture/action.json"
jq -e '.runs.using == "composite" and (.runs.steps | length) == 1 and
    .runs.steps[0].shell == "/bin/bash --noprofile --norc -e -o pipefail {0}" and
    .runs.steps[0].env == {
        "DEVELOPMENT": "${{ inputs.development }}",
        "MINIMUM": "${{ inputs.minimum }}",
        "DEVELOPMENT_TARGET": "${{ inputs.development-target }}",
        "MINIMUM_TARGET": "${{ inputs.minimum-target }}",
        "MINIMUM_COMPONENTS": "${{ inputs.minimum-components }}",
        "ACTION_ROOT": "${{ github.action_path }}"
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
export DEVELOPMENT_TARGET MINIMUM_COMPONENTS='' FAIL_AT=0
export ACTION_ROOT="$root/.github/actions/prepare-rust-toolchains"
run_action() {
    : > "$fixture/actual"
    : > "$fixture/calls"
    status=0
    PATH="$fixture/bin:$PATH" "$BASH" --noprofile --norc -e -o pipefail "$fixture/run.sh" > "$fixture/output" 2>&1 || status=$?
}
# Exact arguments for routine CI and the recovery caller, including boundaries.
for MINIMUM_COMPONENTS in '' clippy,rustfmt; do
for DEVELOPMENT_TARGET in wasm32-unknown-unknown ''; do
    run_action
    [[ "$status" == 0 ]] || exit 1
    {
        printf '%s\0' toolchain install 1.99.0 --profile minimal --component rustfmt --component clippy
        if [[ -n "$DEVELOPMENT_TARGET" ]]; then printf '%s\0' --target wasm32-unknown-unknown; fi
        printf '%s\0' toolchain install 1.88.0 --profile minimal --target wasm32-unknown-unknown
        if [[ -n "$MINIMUM_COMPONENTS" ]]; then printf '%s\0' --component "$MINIMUM_COMPONENTS"; fi
    } > "$fixture/expected"
    cmp "$fixture/expected" "$fixture/actual"
done
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
for input in DEVELOPMENT MINIMUM MINIMUM_TARGET DEVELOPMENT_TARGET MINIMUM_COMPONENTS; do
    saved="${!input}"
    for invalid in '' '--help' 'two words' $'line\nbreak'; do
        [[ ( "$input" != DEVELOPMENT_TARGET && "$input" != MINIMUM_COMPONENTS ) || -n "$invalid" ]] || continue
        printf -v "$input" '%s' "$invalid"
        run_action
        [[ "$status" == 2 && ! -s "$fixture/calls" ]] || exit 1
    done
    printf -v "$input" '%s' "$saved"
done
for MINIMUM_COMPONENTS in ',clippy' 'clippy,' 'clippy,,rustfmt'; do
    run_action
    [[ "$status" == 2 && ! -s "$fixture/calls" ]] || exit 1
done
# Exercise the standalone entrypoint too, including complete admission before
# rustup, optional-free setup and transparent failure status.
for arguments in '1.91.0' '1.91.0 --component clippy --target wasm32-unknown-unknown'; do
    : > "$fixture/calls"
    # Intentional splitting of this fixture's fixed argument sets only.
    # shellcheck disable=SC2086
    PATH="$fixture/bin:$PATH" "$BASH" "$root/scripts/dev/prepare-rust-toolchain.sh" $arguments
    [[ "$(wc -l < "$fixture/calls" | tr -d ' ')" == 1 ]] || exit 1
done
for invalid in missing option value comma trailing; do
    : > "$fixture/calls"
    arguments=(1.91.0)
    case "$invalid" in
        missing) arguments=() ;;
        option) arguments+=(--unknown value) ;;
        value) arguments+=(--component clippy --target) ;;
        comma) arguments+=(--component 'clippy,,rustfmt') ;;
        trailing) arguments+=(--component 'clippy,') ;;
    esac
    status=0
    PATH="$fixture/bin:$PATH" "$BASH" "$root/scripts/dev/prepare-rust-toolchain.sh" ${arguments[@]+"${arguments[@]}"} > "$fixture/output" 2>&1 || status=$?
    [[ "$status" == 2 && ! -s "$fixture/calls" ]] || exit 1
done
mkdir "$fixture/policy files"
cat > "$fixture/policy files/rust-toolchain.toml" <<'TOML'
[toolchain]
channel = '1.99.0' # Literal strings, comments and multiline arrays are TOML.
profile = "minimal"
components = [
  "rustfmt", "clippy",
]
targets = ["wasm32-unknown-unknown"]
TOML
printf '[workspace.package]\nrust-version = "1.91.0"\n' > "$fixture/policy files/Cargo.toml"
for mode in --toolchain-file --workspace-manifest; do
    if [[ "$mode" == --toolchain-file ]]; then
        arguments=("$mode" "$fixture/policy files/rust-toolchain.toml")
        printf '%s\0' toolchain install 1.99.0 --profile minimal --component rustfmt --component clippy --target wasm32-unknown-unknown > "$fixture/expected"
    else
        arguments=("$mode" "$fixture/policy files/Cargo.toml" --target wasm32-unknown-unknown)
        printf '%s\0' toolchain install 1.91.0 --profile minimal --target wasm32-unknown-unknown > "$fixture/expected"
    fi
    for FAIL_AT in 0 1; do
        : > "$fixture/calls"; : > "$fixture/actual"
        status=0
        PATH="$fixture/bin:$PATH" "$BASH" "$root/scripts/dev/prepare-rust-toolchain.sh" "${arguments[@]}" > "$fixture/output" 2>&1 || status=$?
        expected_status=0
        [[ "$FAIL_AT" != 1 ]] || expected_status=49
        [[ "$status" == "$expected_status" ]] || exit 1
        cmp "$fixture/expected" "$fixture/actual"
    done
done
FAIL_AT=0
for invalid in malformed missing-channel option-channel invalid-profile false-profile invalid-component false-components invalid-target newline-target path-toolchain missing-floor invalid-floor extra-argument late-option; do
    arguments=(--toolchain-file "$fixture/invalid.toml")
    case "$invalid" in
        malformed) printf '[toolchain\n' > "$fixture/invalid.toml" ;;
        missing-channel) printf '[toolchain]\nprofile = "minimal"\n' > "$fixture/invalid.toml" ;;
        option-channel) printf '[toolchain]\nchannel = "--help"\n' > "$fixture/invalid.toml" ;;
        invalid-profile) printf '[toolchain]\nchannel = "stable"\nprofile = "unknown"\n' > "$fixture/invalid.toml" ;;
        false-profile) printf '[toolchain]\nchannel = "stable"\nprofile = false\n' > "$fixture/invalid.toml" ;;
        false-components) printf '[toolchain]\nchannel = "stable"\ncomponents = false\n' > "$fixture/invalid.toml" ;;
        newline-target) printf '[toolchain]\nchannel = "stable"\ntargets = ["wasm32-unknown-unknown\\n"]\n' > "$fixture/invalid.toml" ;;
        invalid-component) printf '[toolchain]\nchannel = "stable"\ncomponents = ["two words"]\n' > "$fixture/invalid.toml" ;;
        invalid-target) printf '[toolchain]\nchannel = "stable"\ntargets = "wasm32-unknown-unknown"\n' > "$fixture/invalid.toml" ;;
        path-toolchain) printf '[toolchain]\nchannel = "stable"\npath = "/some/compiler"\n' > "$fixture/invalid.toml" ;;
        missing-floor) arguments=(--workspace-manifest "$fixture/invalid.toml"); printf '[workspace.package]\nversion = "1.0.0"\n' > "$fixture/invalid.toml" ;;
        invalid-floor) arguments=(--workspace-manifest "$fixture/invalid.toml"); printf '[workspace.package]\nrust-version = "--help"\n' > "$fixture/invalid.toml" ;;
        extra-argument) arguments=(--toolchain-file "$fixture/policy files/rust-toolchain.toml" --target other) ;;
        late-option) arguments=(--workspace-manifest "$fixture/policy files/Cargo.toml" --target wasm32-unknown-unknown --unknown value) ;;
    esac
    : > "$fixture/calls"
    status=0
    PATH="$fixture/bin:$PATH" "$BASH" "$root/scripts/dev/prepare-rust-toolchain.sh" "${arguments[@]}" > "$fixture/output" 2>&1 || status=$?
    [[ "$status" != 0 && ! -s "$fixture/calls" ]] || exit 1
done
fixture_complete=true
printf 'Rust toolchain action fixtures passed\n'
