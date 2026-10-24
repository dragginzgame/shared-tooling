#!/usr/bin/env bash
# Shared companions: .github/actions/prepare-rust-toolchains/action.yml scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(CDPATH='' cd -P -- "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
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
for invalid in malformed missing-channel option-channel invalid-profile invalid-component invalid-target path-toolchain missing-floor invalid-floor extra-argument late-option boolean-profile boolean-components boolean-targets newline-channel newline-component newline-target newline-floor; do
    arguments=(--toolchain-file "$fixture/invalid.toml")
    case "$invalid" in
        malformed) printf '[toolchain\n' > "$fixture/invalid.toml" ;;
        missing-channel) printf '[toolchain]\nprofile = "minimal"\n' > "$fixture/invalid.toml" ;;
        option-channel) printf '[toolchain]\nchannel = "--help"\n' > "$fixture/invalid.toml" ;;
        invalid-profile) printf '[toolchain]\nchannel = "stable"\nprofile = "unknown"\n' > "$fixture/invalid.toml" ;;
        invalid-component) printf '[toolchain]\nchannel = "stable"\ncomponents = ["two words"]\n' > "$fixture/invalid.toml" ;;
        invalid-target) printf '[toolchain]\nchannel = "stable"\ntargets = "wasm32-unknown-unknown"\n' > "$fixture/invalid.toml" ;;
        path-toolchain) printf '[toolchain]\nchannel = "stable"\npath = "/some/compiler"\n' > "$fixture/invalid.toml" ;;
        missing-floor) arguments=(--workspace-manifest "$fixture/invalid.toml"); printf '[workspace.package]\nversion = "1.0.0"\n' > "$fixture/invalid.toml" ;;
        invalid-floor) arguments=(--workspace-manifest "$fixture/invalid.toml"); printf '[workspace.package]\nrust-version = "--help"\n' > "$fixture/invalid.toml" ;;
        extra-argument) arguments=(--toolchain-file "$fixture/policy files/rust-toolchain.toml" --target other) ;;
        late-option) arguments=(--workspace-manifest "$fixture/policy files/Cargo.toml" --target wasm32-unknown-unknown --unknown value) ;;
        boolean-profile) printf '[toolchain]\nchannel = "stable"\nprofile = false\n' > "$fixture/invalid.toml" ;;
        boolean-components) printf '[toolchain]\nchannel = "stable"\ncomponents = false\n' > "$fixture/invalid.toml" ;;
        boolean-targets) printf '[toolchain]\nchannel = "stable"\ntargets = false\n' > "$fixture/invalid.toml" ;;
        newline-channel) printf '%s\n' '[toolchain]' 'channel = "stable\n"' > "$fixture/invalid.toml" ;;
        newline-component) printf '%s\n' '[toolchain]' 'channel = "stable"' 'components = ["clippy\n"]' > "$fixture/invalid.toml" ;;
        newline-target) printf '%s\n' '[toolchain]' 'channel = "stable"' 'targets = ["wasm32-unknown-unknown\n"]' > "$fixture/invalid.toml" ;;
        newline-floor) arguments=(--workspace-manifest "$fixture/invalid.toml"); printf '%s\n' '[workspace.package]' 'rust-version = "1.91.0\n"' > "$fixture/invalid.toml" ;;
    esac
    : > "$fixture/calls"
    status=0
    PATH="$fixture/bin:$PATH" "$BASH" "$root/scripts/dev/prepare-rust-toolchain.sh" "${arguments[@]}" > "$fixture/output" 2>&1 || status=$?
    [[ "$status" != 0 && ! -s "$fixture/calls" ]] || exit 1
    case "$invalid" in
        boolean-*|newline-*) grep -F 'Rust policy has no valid' "$fixture/output" >/dev/null ;;
    esac
done
# The read-only entrypoint works before Rust/Cargo setup, including relative
# manifests with spaces and an explicitly selected prepared parser.
mkdir "$fixture/parsers"
ln -s "$(command -v yq)" "$fixture/parsers/yq"
ln -s "$(command -v jq)" "$fixture/parsers/jq"
reader="$root/scripts/ci/read-cargo-workspace-rust-version.sh"
for floor in 1.91 1.91.0; do
    printf "[workspace.package]\nrust-version = '%s' # comment\n" "$floor" > "$fixture/policy files/Cargo.toml"
    actual="$(cd "$fixture" && PATH="$fixture/parsers" YQ="$fixture/parsers/yq" "$BASH" "$reader" 'policy files/Cargo.toml')"
    [[ "$actual" == "$floor" ]] || exit 1
done
for invalid in 'false' '1.91' '"1.91.0-nightly"' '" 1.91.0"' '"1.91.0\r"'; do
    printf '[workspace.package]\nrust-version = %s\n' "$invalid" > "$fixture/invalid.toml"
    status=0
    "$BASH" "$reader" "$fixture/invalid.toml" > "$fixture/output" 2> "$fixture/error" || status=$?
    [[ "$status" != 0 && ! -s "$fixture/output" ]] || exit 1
done
for arguments in absent extra; do
    status=0
    if [[ "$arguments" == absent ]]; then
        "$BASH" "$reader" > "$fixture/output" 2>&1 || status=$?
    else
        "$BASH" "$reader" "$fixture/policy files/Cargo.toml" extra > "$fixture/output" 2>&1 || status=$?
    fi
    [[ "$status" == 2 ]] || exit 1
done
# Omitted optional fields use defaults; explicit profiles remain intact.
for profile in omitted default complete; do
    printf '[toolchain]\nchannel = "stable"\n' > "$fixture/valid.toml"
    expected_profile=minimal
    if [[ "$profile" != omitted ]]; then
        printf 'profile = "%s"\ncomponents = []\ntargets = []\n' "$profile" >> "$fixture/valid.toml"
        expected_profile="$profile"
    fi
    : > "$fixture/actual"
    (cd "$fixture" && PATH="$fixture/bin:$PATH" "$BASH" "$root/scripts/dev/prepare-rust-toolchain.sh" --toolchain-file valid.toml)
    printf '%s\0' toolchain install stable --profile "$expected_profile" > "$fixture/expected"
    cmp "$fixture/expected" "$fixture/actual"
done
# Admit literal and resolved policy directories before dispatching rustup.
for suffix in $'\n' $'\r'; do
    bad="$fixture/policy$suffix"
    mkdir "$bad"
    cp "$fixture/policy files/"* "$bad/"
    ln -s "$bad" "$fixture/policy-alias"
    for directory in "$bad" "$fixture/policy-alias"; do
        for mode in --toolchain-file --workspace-manifest; do
            file=rust-toolchain.toml
            [[ "$mode" != --workspace-manifest ]] || file=Cargo.toml
            : > "$fixture/calls"
            status=0
            PATH="$fixture/bin:$PATH" "$BASH" "$root/scripts/dev/prepare-rust-toolchain.sh" "$mode" "$directory/$file" > "$fixture/output" 2>&1 || status=$?
            [[ "$status" == 2 && ! -s "$fixture/calls" ]] || exit 1
            grep -F 'contains CR/LF' "$fixture/output" >/dev/null
        done
    done
    rm "$fixture/policy-alias"
done
# A parser's plausible output cannot hide its failed observation status.
for parser in yq jq; do
    mkdir "$fixture/failing-$parser"
    cat > "$fixture/failing-$parser/$parser" <<'PARSER'
#!/usr/bin/env bash
case "${0##*/}" in
    yq) printf '%s\n' '{"toolchain":{"channel":"stable"},"workspace":{"package":{"rust-version":"1.91.0"}}}' ;;
    jq)
        case "$*" in
            *workspace.package*) printf '%s\n' 1.91.0 ;;
            *) printf '%s\n' stable --profile minimal ;;
        esac
        ;;
esac
exit 37
PARSER
    chmod +x "$fixture/failing-$parser/$parser"
    for mode in --toolchain-file --workspace-manifest; do
        file=rust-toolchain.toml
        [[ "$mode" != --workspace-manifest ]] || file=Cargo.toml
        : > "$fixture/calls"
        status=0
        PATH="$fixture/failing-$parser:$fixture/bin:$PATH" "$BASH" "$root/scripts/dev/prepare-rust-toolchain.sh" "$mode" "$fixture/policy files/$file" > "$fixture/output" 2>&1 || status=$?
        [[ "$status" == 37 && ! -s "$fixture/calls" ]] || exit 1
    done
    status=0
    PATH="$fixture/failing-$parser:$PATH" "$BASH" "$reader" "$fixture/policy files/Cargo.toml" > "$fixture/output" 2> "$fixture/error" || status=$?
    [[ "$status" == 37 && ! -s "$fixture/output" ]] || exit 1
done
# A successful parser observation still has to contain exactly one policy.
# Slurp before selecting so no valid prefix or suffix can authorize setup.
cat > "$fixture/stream-parser" <<'PARSER'
#!/usr/bin/env bash
printf '%s' "$RUST_TEST_POLICY_JSON"
PARSER
chmod +x "$fixture/stream-parser"
IFS= read -r policy <<'JSON'
{"toolchain":{"channel":"1.91.0"},"workspace":{"package":{"rust-version":"1.91.0"}}}
JSON
for stream in empty multiple null-prefix array-suffix malformed-suffix; do
    case "$stream" in
        empty) RUST_TEST_POLICY_JSON='' ;;
        multiple) RUST_TEST_POLICY_JSON="$policy"$'\n'"$policy" ;;
        null-prefix) RUST_TEST_POLICY_JSON=$'null\n'"$policy" ;;
        array-suffix) RUST_TEST_POLICY_JSON="$policy"$'\n[]' ;;
        malformed-suffix) RUST_TEST_POLICY_JSON="$policy"$'\n{' ;;
    esac
    export RUST_TEST_POLICY_JSON
    status=0
    YQ="$fixture/stream-parser" "$BASH" "$reader" "$fixture/policy files/Cargo.toml" \
        > "$fixture/output" 2> "$fixture/error" || status=$?
    [[ "$status" != 0 && ! -s "$fixture/output" ]] || exit 1
    for mode in --toolchain-file --workspace-manifest; do
        file=rust-toolchain.toml
        [[ "$mode" != --workspace-manifest ]] || file=Cargo.toml
        : > "$fixture/calls"
        status=0
        PATH="$fixture/bin:$PATH" YQ="$fixture/stream-parser" "$BASH" \
            "$root/scripts/dev/prepare-rust-toolchain.sh" "$mode" "$fixture/policy files/$file" \
            > "$fixture/output" 2> "$fixture/error" || status=$?
        [[ "$status" != 0 && ! -s "$fixture/output" && ! -s "$fixture/calls" ]] || exit 1
    done
done
echo 'Single Rust policy observation and refusal before setup passed (parser/Rustup substitutes)'
fixture_complete=true
printf 'Rust toolchain action fixtures passed\n'
