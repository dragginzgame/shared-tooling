#!/usr/bin/env bash
# Shared companions: scripts/dev/install-rust-tools.sh scripts/dev/cargo-tool-build.sh scripts/dev/tool-store.sh scripts/ci/cargo-tool-cache-key.sh scripts/ci/select-tool-evidence.sh scripts/ci/archive-evidence.sh .githooks/pre-commit scripts/ci/prepare-script-fixture.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
path_context=false
if [[ "${1:-}" == --path-context && $# == 1 ]]; then path_context=true;
elif [[ $# != 0 ]]; then echo 'usage: fixture [--path-context]' >&2; exit 2; fi
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"; ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/rust-tools-test.XXXXXX")"
export TMPDIR="${fixture%/*}"
fixture_complete=false
owner_setup='' waiter_setup=''
finish() {
    local status=$?
    rm -f "$fixture/hold-install"
    for child in "$owner_setup" "$waiter_setup"; do
        [[ -z "$child" ]] || { kill "$child" 2>/dev/null || :; wait "$child" 2>/dev/null || :; }
    done
    if [[ -s "$fixture/forbidden-git" ]]; then
        cat "$fixture/forbidden-git" >&2 || :
        status=1
    fi
    fixture_finish "$status" "$fixture" 'Failed Rust tool fixture retained'
}
trap finish EXIT
export SHARED_TOOLING_STORE="$fixture/store"
mkdir "$fixture/templates"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TEMPLATE_DIR="$fixture/templates"
mkdir -p "$fixture/compiler/bin" "$fixture/assets" "$fixture/a" "$fixture/b"
# Always exercise BSD-style padded counts, including on Linux.
mkdir "$fixture/commands"
printf '#!%s\nfixture=%q\nreal_git=%q\n' "$BASH" "$fixture" "$(command -v git)" > "$fixture/commands/git"
cat >> "$fixture/commands/git" <<'STUB'
args=("$@")
while [[ $# -gt 0 ]]; do
    case "$1" in
        -C|-c|--git-dir|--work-tree|--namespace) shift 2 ;;
        -*) shift ;;
        *) break ;;
    esac
done
case "${1:-}" in
    commit|commit-tree|tag|push)
        printf 'forbidden fixture Git command: %s\n' "$1" >> "$fixture/forbidden-git"
        exit 79 ;;
esac
exec "$real_git" "${args[@]}"
STUB
printf '#!%s\nreal_wc=%q\n' "$BASH" "$(command -v wc)" > "$fixture/commands/wc"
cat >> "$fixture/commands/wc" <<'STUB'
if [[ "$*" == -l ]]; then
    count="$("$real_wc" "$@")" || exit $?
    printf '%8d\n' "$count"
else exec "$real_wc" "$@"; fi
STUB
for tool in ln perl; do
    printf '#!%s\nfixture=%q\nreal_tool=%q\n' "$BASH" "$fixture" "$(command -v "$tool")" > "$fixture/commands/$tool"
done
cat >> "$fixture/commands/ln" <<'STUB'
destination="${!#}"
# A regressed installer must never get as far as attempting a root write.
[[ "$destination" != /selected ]] || { echo 'blocked root activation' >&2; exit 79; }
if [[ -f "$fixture/fail-reference" && "$destination" == */rust-set.* ]]; then
    echo 'injected reference failure' >&2; exit 77
fi
exec "$real_tool" "$@"
STUB
cat >> "$fixture/commands/perl" <<'STUB'
if [[ "$1" == -e && "$2" == *'rename('* ]]; then
    destination="${!#}"
    for boundary in store local common; do
        [[ -f "$fixture/fail-$boundary-activation" ]] || continue
        case "$boundary:$destination" in
            store:*/current|local:*/rust/selected-*|common:*/rust/common)
                echo "injected $boundary activation failure" >&2; exit 78 ;;
        esac
    done
fi
exec "$real_tool" "$@"
STUB
printf '#!%s\nfixture=%q\nreal_tool=%q\n' "$BASH" "$fixture" "$(command -v uname)" > "$fixture/commands/uname"
cat >> "$fixture/commands/uname" <<'STUB'
"$real_tool" "$@" || exit $?
if [[ "$*" == -srm && -f "$fixture/changed-native" ]]; then cat "$fixture/changed-native"; fi
STUB
chmod +x "$fixture/commands/"*
export PATH="$fixture/commands:$PATH"
printf 'fixture rustc\n' > "$fixture/compiler-version"
printf '#!%s\n' "$BASH" > "$fixture/compiler/bin/rustc"
printf 'fixture=%q\n' "$fixture" >> "$fixture/compiler/bin/rustc"
cat >> "$fixture/compiler/bin/rustc" <<'STUB'
case "$*" in
    '--print sysroot')
        [[ ! -f rust-toolchain.toml ]] || { echo 'unprepared staged compiler' >&2; exit 77; }
        echo "$fixture/compiler" ;;
    *) cat "$fixture/compiler-version"; echo 'host: fixture-host' ;;
esac
STUB
printf '#!%s\nset -euo pipefail\n' "$BASH" > "$fixture/compiler/bin/cargo"
printf 'fixture=%q\njq_bin=%q\n' "$fixture" "$(command -v jq)" >> "$fixture/compiler/bin/cargo"
cat >> "$fixture/compiler/bin/cargo" <<'STUB'
case "$1" in -vV|--version) echo 'cargo fixture'; exit 0 ;; esac
[[ -z "${RUSTFLAGS+x}${RUSTC_WRAPPER+x}${CARGO_ENCODED_RUSTFLAGS+x}${UNMODELLED_SECRET+x}" ]] || exit 71
[[ "$CARGO_HOME" == "$fixture/store/cargo-cache" && "$RUSTC" == "$fixture/compiler/bin/rustc" ]] || exit 72
if [[ "$1" == info ]]; then
    if [[ -f "$fixture/no-info" ]]; then
        printf 'refused\n' >> "$fixture/info-refusals"
        echo 'injected Cargo source acquisition failure' >&2
        exit 91
    fi
    identity="${2/@/-}"
    mkdir -p "$CARGO_HOME/registry/cache/index.crates.io-fixture"
    cp "$fixture/assets/$identity.crate" "$CARGO_HOME/registry/cache/index.crates.io-fixture/"
    exit 0
fi
[[ "$1" == install ]] || exit 73
package="$2"; shift 2
version='' kind='' target='' destination='' profile=release locked=false registry='' jobs='' features=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) version="${2#=}"; shift 2 ;;
        --root) destination="$2"; shift 2 ;;
        --target-dir) build="$2"; shift 2 ;;
        --bin|--example) kind="${1#--}"; target="$2"; shift 2 ;;
        --registry) registry="$2"; shift 2 ;;
        --jobs) jobs="$2"; shift 2 ;;
        --features) features="$2"; shift 2 ;;
        --locked) locked=true; shift ;;
        --debug) profile=debug; shift ;;
        --offline) shift ;;
        *) exit 74 ;;
    esac
done
[[ "$locked:$registry:$jobs" == true:crates-io:2 && "$build" == "$destination/build" && "$PWD" == "$destination/home" && "$HOME" == "$PWD" ]] || exit 75
printf '%s %s %s %s %s\n' "$package" "$version" "$kind" "$target" "$profile" >> "$fixture/builds"
if [[ -f "$fixture/hold-install" ]]; then
    printf '%s\n' "$destination" > "$fixture/install-held"
    while [[ -f "$fixture/hold-install" ]]; do sleep 0.05; done
fi
mkdir -p "$destination/bin" "$build"
printf 'retained compilation\n' > "$build/evidence"
[[ ! -f "$fixture/fail-$package" ]] || exit 23
[[ "$features" != unavailable ]] || exit 24
if [[ -f "$fixture/locked-file" ]]; then
    printf '\n' >> "$(cat "$fixture/locked-file")"
    sed 's/2.0.0/2.0.1/' "$(cat "$fixture/locked-file")" > "$fixture/changed-lock"
    cp "$fixture/changed-lock" "$(cat "$fixture/locked-file")"
fi
printf '#!%s\n' "$BASH" > "$destination/bin/$target"
printf 'printf "probe\\n" >> %q\n' "$fixture/probes" >> "$destination/bin/$target"
case "$package" in
    cargo-sort|cargo-sort-derives)
        printf 'printf "%%s\\n" %q\n' "$package $version" >> "$destination/bin/$target" ;;
    *) echo 'exit 97' >> "$destination/bin/$target" ;;
esac
chmod +x "$destination/bin/$target"
compiler="$("$RUSTC" -vV)"
"$jq_bin" -n --arg identity "$package $version (registry+https://github.com/rust-lang/crates.io-index)" \
    --arg version "=$version" --arg target "$target" --arg profile "$profile" --arg compiler "$compiler" --arg features "$features" \
    '{installs:{($identity):{version_req:$version,bins:[$target],profile:$profile,target:"fixture-host",rustc:$compiler,
      features:($features | if . == "" then [] else split(",") end),no_default_features:false}}}' > "$destination/.crates2.json"
printf 'Cargo receipt\n' > "$destination/.crates.toml"
if [[ -f "$fixture/redirect-observation" ]]; then
    ln -s "$fixture/outside-observation" "$destination/$(cat "$fixture/redirect-observation")"
fi
if [[ -f "$fixture/fail-receipt" ]]; then printf '{"installs":{}}\n' > "$destination/.crates2.json"; fi
if [[ -f "$fixture/change-build" ]]; then
    case "$(cat "$fixture/change-build")" in
        compiler) printf 'changed fixture compiler\n' > "$fixture/compiler-version" ;;
        native) printf 'changed fixture native inventory\n' > "$fixture/changed-native" ;;
        policy) printf '\n# Changed fixture build policy\n' >> "$fixture/tool-source/scripts/dev/cargo-tool-build.sh" ;;
    esac
fi
STUB
chmod +x "$fixture/compiler/bin/"*
export PATH="$fixture/compiler/bin:$PATH"
installer="$ROOT/scripts/dev/install-rust-tools.sh"
cat > "$fixture/versions" <<'PINS'
SHARED_TOOLING_CARGO_SORT_VERSION=99.1.0
SHARED_TOOLING_CARGO_SORT_DERIVES_VERSION=99.2.0
PINS
source_package() {
    local name="$1" version="$2"
    mkdir -p "$fixture/source/$name-$version"
    printf 'version = 3\n[[package]]\nname = "%s"\nversion = "%s"\n' "$name" "$version" > "$fixture/source/$name-$version/Cargo.lock"
    tar -czf "$fixture/assets/$name-$version.crate" -C "$fixture/source" "$name-$version"
}
for pair in 'cargo-sort 99.1.0' 'cargo-sort-derives 99.2.0' 'sample 1.2.3' 'sample 2.0.0'; do
    read -r name version <<< "$pair"; source_package "$name" "$version"
done
refuse() {
    if "$@" > "$fixture/refused.log" 2>&1; then echo 'unexpected Cargo tool admission' >&2; exit 1; fi
}
common() { bash "$installer" --consumer "$consumer" --versions "$fixture/versions" "$@"; }
expect_setup_phase() {
    grep -E '^Cargo tool setup: package=[A-Za-z0-9_-]+ version=[0-9]+[.][0-9]+[.][0-9]+ phase='"$2"' outcome='"$3"' elapsed=[0-9]+s status='"$4"'$' "$1" > /dev/null
}
hook() (cd "$consumer" && bash .githooks/pre-commit)
consumer="$fixture/a"
# Direct compiler identity checks must use the fixture's prepared context too.
# The invoking consumer may select an entirely different Rust toolchain.
cd "$consumer"
common --preflight
[[ ! -e "$SHARED_TOOLING_STORE" && ! -e "$consumer/.tools" ]] || exit 1
refuse common --check
printf 'Explicit setup: bash %q --consumer %q --versions %q\n' "$installer" "$consumer" "$fixture/versions" > "$fixture/expected-hint"
grep -Fx -f "$fixture/expected-hint" "$fixture/refused.log" >/dev/null
[[ ! -e "$SHARED_TOOLING_STORE" && ! -e "$consumer/.tools" ]] || exit 1
# Admit the complete default group before probing the compiler or touching tools.
for value in '' '01.2.3' '1.2.3-beta.1'; do
    sed "s/SHARED_TOOLING_CARGO_SORT_DERIVES_VERSION=.*/SHARED_TOOLING_CARGO_SORT_DERIVES_VERSION=$value/" \
        "$fixture/versions" > "$fixture/invalid-versions"
    refuse common --versions "$fixture/invalid-versions" --preflight
    [[ ! -e "$SHARED_TOOLING_STORE" && ! -e "$consumer/.tools" && ! -e "$fixture/builds" ]] || exit 1
done
for value in '' '01.2.3' '1.2.3-beta.1'; do
    refuse bash "$installer" --consumer "$consumer" --package sample --version "$value" --bin sample --profile release
    [[ ! -e "$SHARED_TOOLING_STORE" && ! -e "$consumer/.tools" && ! -e "$fixture/builds" ]] || exit 1
done
# Invalid feature requests must fail before source acquisition or installation.
for value in '' ',cli' 'cli,' 'cli,,other' '-flag' 'cli other' $'cli\nother' 'dep:cli' 'dep//cli'; do
    status=0
    bash "$installer" --consumer "$consumer" --package sample --version 1.2.3 --bin prepare \
        --profile debug --features "$value" > "$fixture/invalid-features.log" 2>&1 || status=$?
    [[ "$status" == 2 && ! -e "$SHARED_TOOLING_STORE" && ! -e "$consumer/.tools" && ! -e "$fixture/builds" ]] || exit 1
done
refuse common --features cli
refuse common --features cli --preflight
[[ ! -e "$SHARED_TOOLING_STORE" && ! -e "$consumer/.tools" ]] || exit 1
if [[ "$path_context" == true ]]; then
    common
    common --check
    original="$(readlink "$consumer/.tools/rust/common")"
    before="$(wc -l < "$fixture/builds")"
    common
    [[ "$(wc -l < "$fixture/builds")" == "$before" ]] || exit 1
    source_package cargo-sort 99.1.1
    sed 's/99.1.0/99.1.1/' "$fixture/versions" > "$fixture/new-versions"
    cp "$fixture/new-versions" "$fixture/versions"
    touch "$fixture/fail-cargo-sort"
    refuse common
    grep -F 'Cargo tool attempt retained:' "$fixture/refused.log"
    [[ "$(readlink "$consumer/.tools/rust/common")" == "$original" ]] || exit 1
    [[ ! -e "$consumer/.tools/rust/common.lock" && -z "$(find "$SHARED_TOOLING_STORE" -name install.lock)" ]] || exit 1
    [[ -n "$(find "$SHARED_TOOLING_STORE" -path '*/build/evidence' -type f)" ]] || exit 1
    fixture_complete=true
    echo 'Rust path-context install, reuse, check and retained failure passed'
    exit 0
fi
# The CI cache key shares the installer identity and performs no setup. Exercise
# changes in a private copy so no production source is modified by qualification.
mkdir "$fixture/cache-source"
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$fixture/cache-source" scripts/ci/cargo-tool-cache-key.sh
cache_owner="$fixture/cache-source/scripts/ci/cargo-tool-cache-key.sh"
cache_pins="$fixture/cache-source/ci/tool-versions.env"
cp "$fixture/versions" "$cache_pins"
cache_before="$(bash "$cache_owner" "$cache_pins")"
[[ "$cache_before" == key=*$'\n'root="$SHARED_TOOLING_STORE" ]] || exit 1
[[ "$(bash "$cache_owner" "$cache_pins")" == "$cache_before" && ! -e "$SHARED_TOOLING_STORE" && ! -e "$consumer/.tools" ]] || exit 1
printf '\n# Changed pins\n' >> "$cache_pins"
printf 'export SHARED_TOOLING_JQ_VERSION=99.9.9\nexport SHARED_TOOLING_JQ_SHA256_LINUX_AMD64=abc123\n' >> "$cache_pins"
[[ "$(bash "$cache_owner" "$cache_pins")" == "$cache_before" ]] || exit 1
awk '{ rows[NR]=$0 } END { for (i=NR; i>0; i--) print rows[i] }' "$cache_pins" > "$fixture/reordered-pins"
[[ "$(bash "$cache_owner" "$fixture/reordered-pins")" == "$cache_before" ]] || exit 1
# Shell comments need whitespace after an assignment; a glued # is value data.
sed 's/$/ # comment/' "$fixture/versions" > "$cache_pins"
[[ "$(bash "$cache_owner" "$cache_pins")" == "$cache_before" ]] || exit 1
sed 's/$/#suffix/' "$fixture/versions" > "$cache_pins"
refuse bash "$cache_owner" "$cache_pins"
[[ ! -s "$fixture/refused.log" || "$(head -n 1 "$fixture/refused.log")" != key=* ]] || exit 1
# CR in a shell assignment is part of its value, not harmless whitespace.
awk '{ printf "%s\r\n", $0 }' "$fixture/versions" > "$cache_pins"
refuse bash "$cache_owner" "$cache_pins"
for pin in CARGO_SORT CARGO_SORT_DERIVES; do
    sed "s/SHARED_TOOLING_${pin}_VERSION=.*/SHARED_TOOLING_${pin}_VERSION=98.0.0/" "$fixture/versions" > "$cache_pins"
    [[ "$(bash "$cache_owner" "$cache_pins")" != "$cache_before" ]] || exit 1
done
# Refuse executable or ambiguous data before cache output or setup.
# shellcheck disable=SC2016 # Literal shell text must never be evaluated by the cache reader.
for opaque in 'touch "$CACHE_KEY_SIDE_EFFECT"' 'export RUSTUP_TOOLCHAIN=nightly' \
    'export SHARED_TOOLING_CARGO_SORT_VERSION=99.1.0'; do
    cp "$fixture/versions" "$cache_pins"
    printf '%s\n' "$opaque" >> "$cache_pins"
    CACHE_KEY_SIDE_EFFECT="$fixture/unexpected-cache-effect" refuse bash "$cache_owner" "$cache_pins"
    refuse common --versions "$cache_pins" --preflight
    [[ ! -e "$fixture/unexpected-cache-effect" ]] || exit 1
done
cp "$fixture/versions" "$cache_pins"
for file in scripts/dev/cargo-tool-build.sh scripts/dev/install-rust-tools.sh scripts/ci/StableVersion.pm; do
    printf '\n# Changed cache input\n' >> "$fixture/cache-source/$file"
    [[ "$(bash "$cache_owner" "$cache_pins")" != "$cache_before" ]] || exit 1
    cp "$ROOT/$file" "$fixture/cache-source/$file"
done
printf 'changed compiler\n' > "$fixture/compiler-version"
[[ "$(bash "$cache_owner" "$cache_pins")" != "$cache_before" ]] || exit 1
printf 'fixture rustc\n' > "$fixture/compiler-version"
printf 'changed native environment\n' > "$fixture/changed-native"
[[ "$(bash "$cache_owner" "$cache_pins")" != "$cache_before" ]] || exit 1
rm "$fixture/changed-native"
[[ "$(ImageVersion=fixture-changed-image bash "$cache_owner" "$cache_pins")" != "$cache_before" ]] || exit 1
[[ "$(bash "$cache_owner" "$cache_pins")" == "$cache_before" ]] || exit 1
refuse bash "$cache_owner"
rm "$cache_pins"
refuse bash "$cache_owner" "$cache_pins"
[[ ! -e "$SHARED_TOOLING_STORE" && ! -e "$consumer/.tools" && ! -e "$fixture/builds" ]] || exit 1
# User TOML policy retains its boolean type before any source/install dispatch.
# The environment override remains an independent, explicitly selected contract.
(
    # shellcheck disable=SC2030 # This policy override is deliberately subshell-local.
    export CARGO_HOME="$fixture/user-cargo"
    unset CARGO_NET_OFFLINE
    mkdir "$CARGO_HOME"
    for value in '"true"' '"false\n"' 0 1 '[]' '{}' ; do
        printf '[net]\noffline = %s\n' "$value" > "$CARGO_HOME/config.toml"
        refuse common
        [[ ! -e "$SHARED_TOOLING_STORE" && ! -e "$consumer/.tools" && ! -e "$fixture/builds" ]] || exit 1
    done
    # Exercise accepted flags through the same owner, without building tools.
    # shellcheck source=scripts/dev/tool-store.sh
    source "$ROOT/scripts/dev/tool-store.sh"
    # shellcheck source=scripts/dev/cargo-tool-build.sh
    source "$ROOT/scripts/dev/cargo-tool-build.sh"
    for value in missing false true; do
        printf '[net]\n' > "$CARGO_HOME/config.toml"
        [[ "$value" == missing ]] || printf 'offline = %s\n' "$value" >> "$CARGO_HOME/config.toml"
        cargo_build_init
        expected=''; [[ "$value" != true ]] || expected=--offline
        [[ "${offline_args[*]-}" == "$expected" ]] || exit 1
    done
    printf '' > "$CARGO_HOME/config.toml"
    cargo_build_init
    [[ "${#offline_args[@]}" == 0 ]] || exit 1
    # Cargo gives config precedence over config.toml when both exist.
    printf '[net]\noffline = true\n' > "$CARGO_HOME/config.toml"
    printf '[net]\noffline = false\n' > "$CARGO_HOME/config"
    cargo_build_init
    [[ "${#offline_args[@]}" == 0 ]] || exit 1
    printf '[net]\noffline = "invalid"\n' > "$CARGO_HOME/config"
    # shellcheck disable=SC2030 # Offline overrides are intentionally confined to this policy probe.
    for CARGO_NET_OFFLINE in true 1 false 0; do
        export CARGO_NET_OFFLINE
        cargo_build_init
        expected=''
        case "$CARGO_NET_OFFLINE" in true|1) expected=--offline ;; esac
        [[ "${offline_args[*]-}" == "$expected" ]] || exit 1
    done
)
# Cold source preparation is idempotent across packages and takes no installation
# claim. Hold both creators before mkdir so this also exercises a shared cold root.
bootstrap_source() (
    # shellcheck source=scripts/dev/tool-store.sh
    source "$ROOT/scripts/dev/tool-store.sh"
    # shellcheck source=scripts/dev/cargo-tool-build.sh
    source "$ROOT/scripts/dev/cargo-tool-build.sh"
    check_only=false package="$1" selected_version="$2" kind=bin target=prepare profile=debug
    cargo_build_init || exit $?
    mkdir() {
        if [[ "${!#}" == "$cargo_cache" ]]; then
            [[ ! -f "$fixture/bootstrap-denied" ]] || return 13
            touch "$fixture/bootstrap-$package"
            for ((poll=0; poll<200; poll++)); do
                [[ ! -f "$fixture/bootstrap-go" ]] || break
                sleep 0.05
            done
            [[ -f "$fixture/bootstrap-go" ]] || return 76
        fi
        command mkdir "$@"
    }
    cargo_source
)
bootstrap_source cargo-sort 99.1.0 > "$fixture/bootstrap-sort.out" 2> "$fixture/bootstrap-sort.err" & owner_setup=$!
bootstrap_source cargo-sort-derives 99.2.0 > "$fixture/bootstrap-derives.out" 2> "$fixture/bootstrap-derives.err" & waiter_setup=$!
for ((poll=0; poll<200; poll++)); do
    [[ ! -f "$fixture/bootstrap-cargo-sort" || ! -f "$fixture/bootstrap-cargo-sort-derives" ]] || break
    sleep 0.05
done
[[ -f "$fixture/bootstrap-cargo-sort" && -f "$fixture/bootstrap-cargo-sort-derives" ]]
touch "$fixture/bootstrap-go"
wait "$owner_setup"; owner_setup=''
wait "$waiter_setup"; waiter_setup=''
[[ -f "$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-fixture/cargo-sort-99.1.0.crate" &&
   -f "$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-fixture/cargo-sort-derives-99.2.0.crate" ]]
[[ "$(find "$SHARED_TOOLING_STORE" -name 'rust-*' | wc -l)" -eq 0 && ! -e "$fixture/builds" ]]
rm -rf "$SHARED_TOOLING_STORE"
# Existing redirected, non-directory or writable routes and injected config
# refuse before Cargo dispatch; initialization must not follow an outside route.
mkdir "$fixture/bootstrap-outside"
touch "$fixture/no-info"
for route in root-link root-file cache-link cache-file cache-mode config; do
    case "$route" in
        root-link) ln -s "$fixture/bootstrap-outside" "$SHARED_TOOLING_STORE" ;;
        root-file) touch "$SHARED_TOOLING_STORE" ;;
        *)
            (umask 077; mkdir "$SHARED_TOOLING_STORE")
            case "$route" in
                cache-link) ln -s "$fixture/bootstrap-outside" "$SHARED_TOOLING_STORE/cargo-cache" ;;
                cache-file) touch "$SHARED_TOOLING_STORE/cargo-cache" ;;
                cache-mode) mkdir -m 777 "$SHARED_TOOLING_STORE/cargo-cache" ;;
                config) (umask 077; mkdir "$SHARED_TOOLING_STORE/cargo-cache"); touch "$SHARED_TOOLING_STORE/cargo-cache/config.toml" ;;
            esac ;;
    esac
    refuse bootstrap_source cargo-sort 99.1.0
    [[ ! -e "$fixture/info-refusals" && -z "$(find "$fixture/bootstrap-outside" -mindepth 1 -print)" ]]
    rm -rf "$SHARED_TOOLING_STORE"
done
rm "$fixture/no-info"
touch "$fixture/bootstrap-denied"
status=0
bootstrap_source cargo-sort 99.1.0 > "$fixture/bootstrap-denied.log" 2>&1 || status=$?
[[ "$status" == 13 && ! -e "$SHARED_TOOLING_STORE" ]]
rm "$fixture/bootstrap-denied"
# Preserve previous physical installations; adopt new shared references explicitly.
mkdir -p "$consumer/.tools/rust/previous/installed/build"
printf 'old local evidence\n' > "$consumer/.tools/rust/previous/installed/build/payload"
# The retired checkout-local build route is no longer an installer input.
# Neither setup nor offline admission may follow it or modify its old evidence.
mkdir "$fixture/retired-build"
printf 'retained build evidence\n' > "$fixture/retired-build/payload"
ln -s "$fixture/retired-build" "$consumer/.tools/rust/build"
RUSTFLAGS=invalid RUSTC_WRAPPER=/missing UNMODELLED_SECRET=must-not-propagate common
[[ "$(wc -l < "$fixture/builds")" -eq 2 ]] || exit 1
common --check
[[ "$(readlink "$consumer/.tools/rust/build")" == "$fixture/retired-build" &&
   "$(cat "$fixture/retired-build/payload")" == 'retained build evidence' &&
   "$(ls -A "$fixture/retired-build")" == payload ]] || exit 1
first_binary="$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$consumer/.tools/rust/common/bin/cargo-sort")"
# A previously broader bundle remains retained, but cannot keep selecting an
# unrelated tool through the current common PATH. Rebuild only the link set.
previous_common="$(readlink "$consumer/.tools/rust/common")"
ln -s "$first_binary" "$consumer/.tools/rust/$previous_common/bin/previous-extractor"
refuse common --check
common
[[ -L "$consumer/.tools/rust/$previous_common/bin/previous-extractor" &&
   ! -e "$consumer/.tools/rust/common/bin/previous-extractor" &&
   "$(wc -l < "$fixture/builds")" -eq 2 ]] || exit 1
(
    # shellcheck disable=SC2031 # Reapply the override independently for this subshell.
    export CARGO_HOME="$fixture/user-cargo"
    unset CARGO_NET_OFFLINE
    before="$(readlink "$consumer/.tools/rust/common")"
    for mode in setup check; do
        if [[ "$mode" == setup ]]; then refuse common; else refuse common --check; fi
        [[ "$(readlink "$consumer/.tools/rust/common")" == "$before" && ! -e "$consumer/.tools/rust/common.lock" ]] || exit 1
        [[ "$(wc -l < "$fixture/builds")" -eq 2 ]] || exit 1
    done
)
# A real staged hook uses these receipts without installing into its export.
# Cargo/compiler binaries above are substitutes; receipt admission and Git are real.
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$consumer" .githooks/pre-commit scripts/dev/install-rust-tools.sh
cp "$fixture/versions" "$consumer/pins"
printf '.tools/\n' > "$consumer/.gitignore"
printf 'formatted\n' > "$consumer/selected.rs"
cat > "$consumer/Makefile" <<'MAKE'
fmt:
	@bash scripts/dev/install-rust-tools.sh --consumer "$(CURDIR)" --versions pins --check > /dev/null
	@test ! -e .tools
	@printf 'formatted\n' > selected.rs
MAKE
git init -q "$consumer"
# Borrow immutable history; only this disposable repository's refs/index change.
source_commit="$(git -C "$ROOT" rev-parse HEAD)"
source_objects="$(git -C "$ROOT" rev-parse --git-path objects)"
case "$source_objects" in /*) ;; *) source_objects="$ROOT/$source_objects" ;; esac
printf '%s\n' "$source_objects" > "$consumer/.git/objects/info/alternates"
git -C "$consumer" update-ref HEAD "$source_commit"
# Keep only the fixture payload and an unchanged tracked README in its index.
# Other source paths are staged deletions, never formatter inputs.
git -C "$consumer" reset -q HEAD -- README.md
git -C "$consumer" checkout-index -- README.md
git -C "$consumer" add .gitignore .githooks scripts pins README.md selected.rs Makefile
printf 'working-only README\n' > "$consumer/README.md"
printf 'retained evidence\n' > "$consumer/untracked-evidence"
printf 'unformatted\n' > "$consumer/selected.rs"
git -C "$consumer" add selected.rs
# Selected catalog edits must reject partial staging without changing any bytes.
hook_tree="$(git -C "$consumer" write-tree)"
printf 'exit 99\n' > "$consumer/pins"
refuse hook
grep -F 'partially staged file: pins' "$fixture/refused.log" >/dev/null
[[ "$(git -C "$consumer" write-tree)" == "$hook_tree" && "$(cat "$consumer/selected.rs")" == unformatted ]] || exit 1
# Independently admit the staged catalog against the real checkout's receipts;
# unrelated working catalog bytes must never select the exported tools.
mkdir "$fixture/staged-inputs"
git -C "$consumer" checkout-index --all --prefix="$fixture/staged-inputs/"
SHARED_TOOLING_FORMAT_WORKTREE="$fixture/staged-inputs" SHARED_TOOLING_FORMAT_TOOLS_FROM="$consumer" \
    bash "$installer" --consumer "$fixture/staged-inputs" --versions "$fixture/staged-inputs/pins" --check
[[ ! -e "$fixture/staged-inputs/.tools" && "$(cat "$consumer/pins")" == 'exit 99' ]] || exit 1
cp "$fixture/versions" "$consumer/pins"
(cd "$consumer" && bash .githooks/pre-commit) > "$fixture/hook.log" 2>&1
[[ "$(git -C "$consumer" show :selected.rs)" == formatted ]] || exit 1
[[ "$(cat "$consumer/README.md")" == 'working-only README' ]] || exit 1
[[ "$(git -C "$consumer" show :README.md)" == "$(git -C "$consumer" show HEAD:README.md)" ]] || exit 1
printf 'unformatted\n' > "$consumer/selected.rs"
git -C "$consumer" add selected.rs
hook_tree="$(git -C "$consumer" write-tree)"
receipt="${first_binary%/bin/*}/selection.json"
cp "$receipt" "$fixture/receipt.saved"
printf '{}\n' > "$receipt"
refuse hook
cp "$fixture/receipt.saved" "$receipt"
[[ "$(git -C "$consumer" write-tree)" == "$hook_tree" && "$(cat "$consumer/selected.rs")" == unformatted ]] || exit 1
# Changed staged pins and compiler context require fresh explicit preparation.
printf 'SHARED_TOOLING_CARGO_SORT_VERSION=99.9.0\n' >> "$consumer/pins"
git -C "$consumer" add pins
refuse hook
cp "$fixture/versions" "$consumer/pins"
git -C "$consumer" add pins
printf 'changed compiler\n' > "$fixture/compiler-version"
refuse hook
printf 'fixture rustc\n' > "$fixture/compiler-version"
[[ "$(git -C "$consumer" write-tree)" == "$hook_tree" && "$(cat "$consumer/untracked-evidence")" == 'retained evidence' ]] || exit 1
printf 'unprepared staged compiler\n' > "$consumer/rust-toolchain.toml"
git -C "$consumer" add rust-toolchain.toml
refuse hook
grep -F 'unprepared staged compiler' "$fixture/refused.log" >/dev/null
git -C "$consumer" rm -qf rust-toolchain.toml
[[ "$(wc -l < "$fixture/builds")" -eq 2 ]]
mkdir "$fixture/export"
SHARED_TOOLING_FORMAT_WORKTREE="$fixture/export" SHARED_TOOLING_FORMAT_TOOLS_FROM="$consumer" \
    refuse bash "$installer" --consumer "$fixture/export" --versions "$fixture/versions"
[[ ! -e "$fixture/export/.tools" ]]
# An unrelated consumer never borrows a parent hook's selection context.
SHARED_TOOLING_FORMAT_WORKTREE="$fixture/export" SHARED_TOOLING_FORMAT_TOOLS_FROM="$consumer" \
    refuse bash "$installer" --consumer "$fixture/b" --versions "$fixture/versions" --check
printf 'old local evidence\n' | cmp - "$consumer/.tools/rust/previous/installed/build/payload"
# Conditional common setup must preserve a foreign lock and every selection,
# with no build/reference/activation attempt and no successful-path output.
held_slot="${first_binary%/set.*/bin/*}"
mkdir "$held_slot/install.lock"
printf 'foreign owner\n' > "$held_slot/install.lock/owner"
cp "$held_slot/install.lock/owner" "$fixture/foreign-owner"
old_common="$(readlink "$consumer/.tools/rust/common")"
old_current="$(readlink "$held_slot/current")"
find "$consumer/.tools/rust" "$held_slot" -print | sort > "$fixture/before-held"
status=0
common > "$fixture/held.out" 2> "$fixture/held.err" || status=$?
[[ "$status" -ne 0 && ! -s "$fixture/held.out" ]] || { echo 'common setup concealed a held shared lock' >&2; exit 1; }
grep -F "tool store installation locked: $held_slot/install.lock" "$fixture/held.err" >/dev/null
if grep -F 'blocked root activation' "$fixture/held.err"; then exit 1; fi
cmp "$held_slot/install.lock/owner" "$fixture/foreign-owner"
[[ "$(readlink "$consumer/.tools/rust/common")" == "$old_common" && "$(readlink "$held_slot/current")" == "$old_current" ]] || exit 1
[[ "$(wc -l < "$fixture/builds")" -eq 2 ]] || exit 1
find "$consumer/.tools/rust" "$held_slot" -print | sort > "$fixture/after-held"
cmp "$fixture/before-held" "$fixture/after-held"
# A recognized but unreleased claim has a bounded setup refusal, propagated
# through the common aggregate without replacing its previous complete set.
printf 'pid=%s\nconsumer=%s\n' "$$" "$fixture/a" > "$held_slot/install.lock/owner"
cp "$held_slot/install.lock/owner" "$fixture/valid-owner"
status=0
SHARED_TOOLING_SETUP_WAIT_SECONDS=1 common > "$fixture/timeout.out" 2> "$fixture/timeout.err" || status=$?
[[ "$status" == 1 && ! -s "$fixture/timeout.out" ]]
grep -F 'wait timed out' "$fixture/timeout.err" >/dev/null
expect_setup_phase "$fixture/timeout.err" lock-wait failed 1
grep -E 'phase=lock-wait outcome=failed elapsed=[1-9][0-9]*s status=1$' "$fixture/timeout.err" >/dev/null
cmp "$held_slot/install.lock/owner" "$fixture/valid-owner"
[[ "$(readlink "$consumer/.tools/rust/common")" == "$old_common" && "$(readlink "$held_slot/current")" == "$old_current" ]]
[[ "$(wc -l < "$fixture/builds")" -eq 2 ]]
status=0
SHARED_TOOLING_SETUP_WAIT_SECONDS=0 common > "$fixture/no-wait.out" 2> "$fixture/no-wait.err" || status=$?
[[ "$status" != 0 && ! -s "$fixture/no-wait.out" ]]
if grep -F 'Waiting for' "$fixture/no-wait.err"; then exit 1; fi
rm "$held_slot/install.lock/owner"
rmdir "$held_slot/install.lock"
# A CI cache restores physical shared generations, never checkout selections.
# Round-trip all builds/receipts/source bytes before the existing cold-checkout
# reuse control; its no-info/build-count assertions prove no download or rebuild.
(cd "$SHARED_TOOLING_STORE" && tar -czf "$fixture/cargo-tools-cache.tar.gz" cargo-cache rust-*)
mv "$SHARED_TOOLING_STORE" "$fixture/store-before-restore"
(umask 077; mkdir "$SHARED_TOOLING_STORE")
tar -xzf "$fixture/cargo-tools-cache.tar.gz" -C "$SHARED_TOOLING_STORE"
consumer="$fixture/b"
touch "$fixture/no-info"
CARGO_NET_OFFLINE=true common
[[ "$(wc -l < "$fixture/builds")" -eq 2 && "$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$consumer/.tools/rust/common/bin/cargo-sort")" == "$first_binary" ]] || exit 1
[[ -z "$(find "$consumer/.tools" -type f)" ]] || exit 1
common --check
# New compiler identity selects new payloads; the first checkout stays pinned.
printf 'fixture rustc changed\n' > "$fixture/compiler-version"
refuse common --check
common
[[ "$(wc -l < "$fixture/builds")" -eq 4 && "$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$fixture/a/.tools/rust/common/bin/cargo-sort")" == "$first_binary" ]] || exit 1
printf 'fixture rustc\n' > "$fixture/compiler-version"
common
[[ "$(wc -l < "$fixture/builds")" -eq 4 ]] || exit 1
rm "$fixture/no-info"
# Selected product executables are verified without executing them.
selected_args=(--consumer "$consumer" --package sample --version 1.2.3 --example prepare --profile debug)
: > "$fixture/probes"
path="$(bash "$installer" "${selected_args[@]}" 2> "$fixture/selected-setup.err")"
[[ ! -s "$fixture/probes" && -x "$path" ]] || exit 1
for phase in source-preparation lock-wait compilation receipt-admission build-admission; do
    expect_setup_phase "$fixture/selected-setup.err" "$phase" passed 0
done
grep -F 'package=sample version=1.2.3 phase=compilation outcome=started elapsed=0s' "$fixture/selected-setup.err" >/dev/null
CARGO_NET_OFFLINE=true bash "$installer" "${selected_args[@]}" --check > "$fixture/selected-check" 2> "$fixture/selected-check.err"
[[ "$(cat "$fixture/selected-check")" == "$path" && ! -s "$fixture/probes" && ! -s "$fixture/selected-check.err" ]] || exit 1
# Explicit extension setup reports reuse without info/install
# dispatch or executable probes. Another checkout receives the same bytes.
builds_before="$(wc -l < "$fixture/builds")"
touch "$fixture/no-info"
for retry in first second; do
    CARGO_NET_OFFLINE=true bash "$installer" "${selected_args[@]}" > "$fixture/reuse-$retry.out" 2> "$fixture/reuse-$retry.err"
    [[ "$(cat "$fixture/reuse-$retry.out")" == "$path" ]] || exit 1
    expect_setup_phase "$fixture/reuse-$retry.err" source-preparation passed 0
    expect_setup_phase "$fixture/reuse-$retry.err" selection-reuse passed 0
    if grep -F 'phase=compilation' "$fixture/reuse-$retry.err"; then exit 1; fi
done
extension_path="$(CARGO_NET_OFFLINE=true bash "$installer" --consumer "$fixture/a" \
    --package sample --version 1.2.3 --example prepare --profile debug 2> "$fixture/extension-reuse.err")"
[[ "$(wc -l < "$fixture/builds")" == "$builds_before" && ! -s "$fixture/probes" ]] || exit 1
expect_setup_phase "$fixture/extension-reuse.err" cache-reuse passed 0
[[ "$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$extension_path")" == \
   "$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$path")" ]] || exit 1
rm "$fixture/no-info"
# Diagnostic write failures cannot fail an otherwise admitted reuse. Substitute
# only the diagnostic printf; all installer admission and effects remain real.
cat > "$fixture/diagnostic-write-failure.sh" <<'SCRIPT'
printf() {
    case "${1:-}" in 'Cargo tool setup: '*) return 73 ;; esac
    builtin printf "$@"
}
SCRIPT
observed="$(BASH_ENV="$fixture/diagnostic-write-failure.sh" bash "$installer" "${selected_args[@]}")"
[[ "$observed" == "$path" && "$(wc -l < "$fixture/builds")" == "$builds_before" ]] || exit 1
physical="$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$path")"; bundle="${physical%/bin/*}"
# Refused offline admission has no stdout, probes, fetches or builds. Name the
# missing/competing source paths instead of collapsing them into invalid tools.
archive="$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-fixture/sample-1.2.3.crate"
(umask 077; mkdir "$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-other")
for source_failure in missing ambiguous; do
    if [[ "$source_failure" == missing ]]; then mv "$archive" "$fixture/held-source"
    else cp "$archive" "${archive/index.crates.io-fixture/index.crates.io-other}"; fi
    status=0
    bash "$installer" "${selected_args[@]}" --check > "$fixture/admission.out" 2> "$fixture/admission.err" || status=$?
    [[ "$status" == 1 && ! -s "$fixture/admission.out" && ! -s "$fixture/probes" &&
       "$(wc -l < "$fixture/builds")" == "$builds_before" ]] || exit 1
    grep -F "Cargo tool source is $source_failure" "$fixture/admission.err" >/dev/null
    if [[ "$source_failure" == missing ]]; then mv "$fixture/held-source" "$archive"
    else
        for registry in index.crates.io-fixture index.crates.io-other; do
            printf '  %q\n' "${archive/index.crates.io-fixture/$registry}" > "$fixture/expected-source"
            grep -Fx -f "$fixture/expected-source" "$fixture/admission.err" >/dev/null
        done
        rm "${archive/index.crates.io-fixture/index.crates.io-other}"
    fi
done
rmdir "$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-other"
# Lock-selected repair advice retains the lock selection, including spaces,
# rather than substituting a resolved version or emitting an unsafe command.
mkdir "$fixture/hint checkout"
printf 'version = 3\n[[package]]\nname = "sample"\nversion = "1.2.3"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\n' > "$fixture/hint checkout/selection lock"
refuse bash "$installer" --consumer "$fixture/hint checkout" --package sample --lockfile 'selection lock' --example prepare --profile debug --check
printf 'Explicit setup: bash %q --consumer %q --package sample --lockfile %q --example prepare --profile debug\n' \
    "$installer" "$fixture/hint checkout" "$fixture/hint checkout/selection lock" > "$fixture/expected-hint"
grep -Fx -f "$fixture/expected-hint" "$fixture/refused.log" >/dev/null
grep -F 'No prepared Cargo tool selection for the current compiler/build inputs:' "$fixture/refused.log" >/dev/null
chmod -x "$physical"
refuse bash "$installer" "${selected_args[@]}" --check
grep -Fx "Cargo tool executable is missing or not executable: $physical" "$fixture/refused.log" >/dev/null
chmod +x "$physical"
# Missing source must preserve Cargo's status through both installer call shapes,
# without a build, retry, activation or loss of previously retained evidence.
sed 's/SHARED_TOOLING_CARGO_SORT_VERSION=.*/SHARED_TOOLING_CARGO_SORT_VERSION=99.9.9/' "$fixture/versions" > "$fixture/missing-source-versions"
cp -R "$SHARED_TOOLING_STORE" "$fixture/before-source-store"
cp -R "$consumer/.tools" "$fixture/before-source-tools"
source_common="$(readlink "$consumer/.tools/rust/common")"
: > "$fixture/info-refusals"
touch "$fixture/no-info"
attempts=0
for mode in common selected; do
    status=0
    : > "$fixture/probes"
    if [[ "$mode" == common ]]; then
        common --versions "$fixture/missing-source-versions" > "$fixture/source-$mode.out" 2> "$fixture/source-$mode.err" || status=$?
    else
        bash "$installer" "${selected_args[@]}" --version 9.9.9 > "$fixture/source-$mode.out" 2> "$fixture/source-$mode.err" || status=$?
    fi
    attempts=$((attempts + 1))
    [[ "$status" -eq 91 && ! -s "$fixture/source-$mode.out" &&
       "$(wc -l < "$fixture/info-refusals")" -eq "$attempts" &&
       "$(wc -l < "$fixture/builds")" == "$builds_before" &&
       "$(readlink "$consumer/.tools/rust/common")" == "$source_common" &&
       "$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$path")" == "$physical" ]] || exit 1
    grep -Fx 'injected Cargo source acquisition failure' "$fixture/source-$mode.err" >/dev/null
    # Common records can probe an earlier admitted tool before acquisition fails;
    # selected product tools must still never execute during admission.
    [[ "$mode" == common || ! -s "$fixture/probes" ]] || exit 1
    diff -r "$fixture/before-source-store" "$SHARED_TOOLING_STORE"
    diff -r "$fixture/before-source-tools" "$consumer/.tools"
done
rm "$fixture/no-info"
for field in bin/prepare .crates2.json inputs.json selection.json source.crate Cargo.lock; do
    cp "$bundle/$field" "$fixture/saved"
    printf '\nchanged\n' >> "$bundle/$field"
    refuse bash "$installer" "${selected_args[@]}" --check
    [[ ! -s "$fixture/probes" ]] || exit 1
    case "$field" in
        bin/prepare|selection.json) reason='Cargo tool executable/receipt bytes differ or the selection receipt is invalid:'; receipt=selection.json ;;
        .crates2.json) reason='Cargo tool receipt does not match package/version, features, target, profile or compiler:'; receipt="$field" ;;
        inputs.json) reason='Cargo tool build/source inputs differ or their receipt is invalid:'; receipt="$field" ;;
        *) reason='checksum mismatch for'; receipt="$field" ;;
    esac
    grep -F "$reason" "$fixture/refused.log" >/dev/null
    grep -F "$bundle/$receipt" "$fixture/refused.log" >/dev/null
    printf 'Explicit setup: bash %q --consumer %q --package sample --version 1.2.3 --example prepare --profile debug\n' \
        "$installer" "$consumer" > "$fixture/expected-hint"
    grep -Fx -f "$fixture/expected-hint" "$fixture/refused.log" >/dev/null
    cp "$fixture/saved" "$bundle/$field"
done
# A different kind/profile cannot reuse the example selection.
cp "$bundle/.crates2.json" "$fixture/receipt"
cp "$bundle/selection.json" "$fixture/selection"
for field in version_req target profile rustc features no_default_features all_features; do
    jq --arg field "$field" '.installs[][$field]="wrong"' "$fixture/receipt" > "$bundle/.crates2.json"
    digest="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$bundle/.crates2.json")"
    jq --arg digest "$digest" '.receipt_sha256=$digest' "$fixture/selection" > "$bundle/selection.json"
    refuse bash "$installer" "${selected_args[@]}" --check
    grep -Fx "Cargo tool receipt does not match package/version, features, target, profile or compiler: $bundle/.crates2.json" "$fixture/refused.log" >/dev/null
done
cp "$fixture/receipt" "$bundle/.crates2.json"
cp "$fixture/selection" "$bundle/selection.json"
for file in inputs.json selection.json .crates2.json; do
    cp "$bundle/$file" "$fixture/single-json"
    cat "$fixture/single-json" >> "$bundle/$file"
    refuse bash "$installer" "${selected_args[@]}" --check
    cp "$fixture/single-json" "$bundle/$file"
done
[[ ! -s "$fixture/probes" ]] || exit 1
other="$(bash "$installer" --consumer "$consumer" --package sample --version 1.2.3 --bin prepare --profile release)"
[[ "$other" != "$path" ]] || exit 1
slot="${bundle%/*}"
mkdir "$slot/install.lock"
printf 'pid=%s\nconsumer=%s\n' "$$" "$consumer" > "$slot/install.lock/owner"
status=0
bash "$installer" "${selected_args[@]}" --check > "$fixture/refused.log" 2>&1 || status=$?
[[ "$status" == 75 ]]
grep -F "tool store installation locked: $slot/install.lock" "$fixture/refused.log"
rm "$slot/install.lock/owner"
rmdir "$slot/install.lock"
# A failed build keeps the previously selected common set and shared evidence.
source_package cargo-sort 99.1.1
sed 's/SHARED_TOOLING_CARGO_SORT_VERSION=.*/SHARED_TOOLING_CARGO_SORT_VERSION=99.1.1/' "$fixture/versions" > "$fixture/new-versions"
cp "$fixture/new-versions" "$fixture/versions"
before="$(readlink "$consumer/.tools/rust/common")"
touch "$fixture/fail-cargo-sort"
refuse common
[[ "$(readlink "$consumer/.tools/rust/common")" == "$before" ]] || exit 1
grep -F 'Cargo tool attempt retained:' "$fixture/refused.log"
rm "$fixture/fail-cargo-sort"
# Admission, reference and each publication boundary must stop common setup.
# Earlier common tools remain selected; failed candidates/evidence are retained.
for failure in receipt reference store-activation local-activation common-activation; do
    touch "$fixture/fail-$failure"
    status=0
    common > "$fixture/$failure.out" 2> "$fixture/$failure.err" || status=$?
    [[ "$status" -ne 0 && ! -s "$fixture/$failure.out" ]] || { echo "concealed $failure failure" >&2; exit 1; }
    case "$failure" in reference) [[ "$status" -eq 77 ]] ;; *activation) [[ "$status" -eq 78 ]] ;; receipt) [[ "$status" -eq 1 ]] ;; esac
    [[ "$(readlink "$consumer/.tools/rust/common")" == "$before" ]] || exit 1
    [[ "$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$fixture/a/.tools/rust/common/bin/cargo-sort")" == "$first_binary" ]] || exit 1
    [[ ! -e "$consumer/.tools/rust/common.lock" ]] || exit 1
    [[ -z "$(find "$SHARED_TOOLING_STORE" -name install.lock)" ]] || exit 1
    rm "$fixture/fail-$failure"
done
common
[[ "$(readlink "$consumer/.tools/rust/common")" != "$before" ]] || exit 1
# The real selector/archiver includes only this consumer's referenced generations.
mkdir "$fixture/diagnostics"
bash "$ROOT/scripts/ci/select-tool-evidence.sh" full "$consumer" "$fixture/diagnostics" > "$fixture/selections"
inputs=()
while IFS= read -r -d '' root && IFS= read -r -d '' relative; do inputs+=("$root" "$relative"); done < "$fixture/selections"
bash "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/evidence.tar.gz" "${inputs[@]}" > /dev/null
mkdir "$fixture/unpacked"
tar -xzf "$fixture/evidence.tar.gz" -C "$fixture/unpacked"
cmp "$bundle/bin/prepare" "$fixture/unpacked/${bundle#"$SHARED_TOOLING_STORE/"}/bin/prepare"
[[ "$(find "$fixture/unpacked" -name evidence -type f | wc -l)" -gt 0 ]] || exit 1
# Refuse injected global Cargo configuration even on an otherwise reusable set.
printf '[build]\nrustflags=["--bad"]\n' > "$SHARED_TOOLING_STORE/cargo-cache/config.toml"
refuse common --check
rm "$SHARED_TOOLING_STORE/cargo-cache/config.toml"
common --check
mv "$SHARED_TOOLING_STORE/cargo-cache/registry/cache" "$fixture/retained-cache"
ln -s "$fixture/retained-cache" "$SHARED_TOOLING_STORE/cargo-cache/registry/cache"
refuse common
rm "$SHARED_TOOLING_STORE/cargo-cache/registry/cache"
mv "$fixture/retained-cache" "$SHARED_TOOLING_STORE/cargo-cache/registry/cache"
# Lock-selected package changes during compilation must prevent activation.
mkdir "$fixture/locked"
cat > "$fixture/locked/Cargo.lock" <<'LOCK'
version = 3
[[package]]
name = "sample"
version = "2.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
LOCK
printf '%s\n' "$fixture/locked/Cargo.lock" > "$fixture/locked-file"
refuse bash "$installer" --consumer "$fixture/locked" --package sample --lockfile Cargo.lock --bin prepare --profile release
grep -F 'Cargo tool lock selection changed' "$fixture/refused.log"
[[ -z "$(find "$fixture/locked/.tools/rust" -name 'selected-*')" ]] || exit 1
rm "$fixture/locked-file"
# Redirected local/store paths never become installation destinations.
mkdir "$fixture/redirected" "$fixture/outside"
ln -s "$fixture/outside" "$fixture/redirected/.tools"
refuse bash "$installer" --consumer "$fixture/redirected" --versions "$fixture/versions"
[[ -z "$(ls -A "$fixture/outside")" ]] || exit 1
ln -s "$SHARED_TOOLING_STORE" "$fixture/store-link"
SHARED_TOOLING_STORE="$fixture/store-link" refuse common --check
# Change each build identity input after the substitute Cargo writes its receipt.
# Mutate only disposable sources; the real admission, retention and activation run.
mkdir "$fixture/tool-source"
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$fixture/tool-source" scripts/dev/install-rust-tools.sh
cp "$fixture/compiler-version" "$fixture/original-compiler"
before="$(readlink "$consumer/.tools/rust/common")"
source_package cargo-sort 99.1.2
sed 's/SHARED_TOOLING_CARGO_SORT_VERSION=.*/SHARED_TOOLING_CARGO_SORT_VERSION=99.1.2/' "$fixture/versions" > "$fixture/new-versions"
cp "$fixture/new-versions" "$fixture/versions"
for change in compiler native policy; do
    printf '%s\n' "$change" > "$fixture/change-build"
    status=0
    UNMODELLED_SECRET=must-not-retain bash "$fixture/tool-source/scripts/dev/install-rust-tools.sh" \
        --consumer "$consumer" --versions "$fixture/versions" > "$fixture/$change.out" 2> "$fixture/$change.err" || status=$?
    [[ "$status" -eq 1 && ! -s "$fixture/$change.out" ]] || exit 1
    field="$change"; [[ "$change" != policy ]] || field=policy_sha256
    grep -Fx "Cargo tool build environment changed: $field" "$fixture/$change.err"
    attempt="$(sed -n 's/^Cargo tool attempt retained: //p' "$fixture/$change.err")"
    [[ -f "$attempt/build/evidence" && -f "$attempt/install.log" && ! -e "$attempt/selection.json" && ! -e "${attempt%/*}/current" ]] || exit 1
    jq -e --arg field "$field" --slurpfile observed "$attempt/build-identity.observed.json" \
        '.build[$field] != $observed[0][$field] and (.build | del(.[$field])) == ($observed[0] | del(.[$field]))' "$attempt/inputs.json" > /dev/null
    bash "$ROOT/scripts/ci/verify-file-checksum.sh" sha256 "$(jq -r .build.native "$attempt/inputs.json")" "$attempt/native-environment.txt"
    bash "$ROOT/scripts/ci/verify-file-checksum.sh" sha256 "$(jq -r .native "$attempt/build-identity.observed.json")" "$attempt/native-environment.observed.txt"
    if grep -F must-not-retain "$attempt/"*.json "$attempt/"*.txt "$fixture/$change.err"; then exit 1; fi
    [[ "$(readlink "$consumer/.tools/rust/common")" == "$before" ]] || exit 1
    [[ ! -e "$consumer/.tools/rust/common.lock" && -z "$(find "$SHARED_TOOLING_STORE" -name install.lock)" ]] || exit 1
    # The standard evidence selector must retain both observations, even though
    # this generation was never activated.
    mkdir "$fixture/$change-diagnostics"
    bash "$ROOT/scripts/ci/select-tool-evidence.sh" full "$consumer" "$fixture/$change-diagnostics" > "$fixture/$change-selections"
    inputs=()
    while IFS= read -r -d '' root && IFS= read -r -d '' relative; do inputs+=("$root" "$relative"); done < "$fixture/$change-selections"
    bash "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/$change-evidence.tar.gz" "${inputs[@]}" > /dev/null
    mkdir "$fixture/$change-unpacked"
    tar -xzf "$fixture/$change-evidence.tar.gz" -C "$fixture/$change-unpacked"
    for evidence in inputs.json native-environment.txt build-identity.observed.json native-environment.observed.txt; do
        cmp "$attempt/$evidence" "$fixture/$change-unpacked/${attempt#"$SHARED_TOOLING_STORE/"}/$evidence"
    done
    rm "$fixture/change-build"
    cp "$fixture/original-compiler" "$fixture/compiler-version"
    rm -f "$fixture/changed-native"
    cp "$ROOT/scripts/dev/cargo-tool-build.sh" "$fixture/tool-source/scripts/dev/"
done
for leaf in build-identity.observed.json native-environment.observed.txt; do
    printf '%s\n' "$leaf" > "$fixture/redirect-observation"
    printf 'outside evidence must remain intact\n' > "$fixture/outside-observation"
    cp "$fixture/outside-observation" "$fixture/expected-observation"
    printf 'compiler\n' > "$fixture/change-build"
    refuse bash "$installer" --consumer "$consumer" --versions "$fixture/versions"
    attempt="$(sed -n 's/^Cargo tool attempt retained: //p' "$fixture/refused.log")"
    [[ -L "$attempt/$leaf" && -f "$attempt/build/evidence" && -f "$attempt/install.log" ]]
    [[ ! -e "$attempt/selection.json" && ! -e "${attempt%/*}/current" ]]
    cmp "$fixture/expected-observation" "$fixture/outside-observation"
    [[ "$(readlink "$consumer/.tools/rust/common")" == "$before" ]]
    [[ ! -e "$consumer/.tools/rust/common.lock" && -z "$(find "$SHARED_TOOLING_STORE" -name install.lock)" ]]
    [[ -z "$(find "$consumer/.tools/rust" -name '.selected-*.lock')" ]]
    mkdir "$fixture/$leaf-diagnostics"
    bash "$ROOT/scripts/ci/select-tool-evidence.sh" full "$consumer" "$fixture/$leaf-diagnostics" > "$fixture/$leaf-selections"
    inputs=()
    while IFS= read -r -d '' root && IFS= read -r -d '' relative; do inputs+=("$root" "$relative"); done < "$fixture/$leaf-selections"
    bash "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/$leaf.tar.gz" "${inputs[@]}" > /dev/null
    # Extract only this retained leaf: it must still be a link, not target bytes.
    mkdir "$fixture/$leaf-unpacked"
    relative="${attempt#"$SHARED_TOOLING_STORE/"}/$leaf"
    tar -xzf "$fixture/$leaf.tar.gz" -C "$fixture/$leaf-unpacked" "./$relative"
    [[ -L "$fixture/$leaf-unpacked/$relative" ]]
    cmp "$fixture/expected-observation" "$fixture/outside-observation"
    rm "$fixture/redirect-observation" "$fixture/change-build"
    cp "$fixture/original-compiler" "$fixture/compiler-version"
done
# Explicit features are one canonical requested set, separate from featureless
# selections. Checks must not install, repair receipts or execute product tools.
feature_args=(--consumer "$consumer" --package sample --version 1.2.3 --bin prepare --profile debug)
plain_path="$(bash "$installer" "${feature_args[@]}")"
plain_bundle="$(perl -MCwd=abs_path -e 'print abs_path(shift)' "${plain_path%/bin/*}")"
jq -e 'has("features") | not' "$plain_bundle/inputs.json" >/dev/null
builds_before="$(wc -l < "$fixture/builds")"
: > "$fixture/probes"
refuse bash "$installer" "${feature_args[@]}" --features cli --check
grep -F -- '--profile debug --features cli' "$fixture/refused.log" >/dev/null
[[ "$(wc -l < "$fixture/builds")" == "$builds_before" && ! -s "$fixture/probes" ]] || exit 1
cli_path="$(bash "$installer" "${feature_args[@]}" --features cli)"
[[ "$cli_path" != "$plain_path" ]] || exit 1
cli_bundle="$(perl -MCwd=abs_path -e 'print abs_path(shift)' "${cli_path%/bin/*}")"
jq -e '.features == ["cli"]' "$cli_bundle/inputs.json" >/dev/null
combined="$(bash "$installer" "${feature_args[@]}" --features cli,alpha --features cli)"
[[ "$combined" != "$cli_path" && "$combined" != "$plain_path" ]] || exit 1
builds_before="$(wc -l < "$fixture/builds")"
for mode in setup check; do
    options=(); [[ "$mode" != check ]] || options=(--check)
    observed="$(CARGO_NET_OFFLINE=true bash "$installer" "${feature_args[@]}" \
        --features alpha --features cli ${options[@]+"${options[@]}"})"
    [[ "$observed" == "$combined" && "$(wc -l < "$fixture/builds")" == "$builds_before" && ! -s "$fixture/probes" ]] || exit 1
done
# Re-sign byte receipts after changing valid Cargo feature fields: semantic
# feature admission must still reject the otherwise matching installation.
cp "$cli_bundle/.crates2.json" "$fixture/feature-receipt"
cp "$cli_bundle/selection.json" "$fixture/feature-selection"
for change in missing other duplicate null false no-default all; do
    case "$change" in
        missing) expression='.installs[].features = []' ;;
        other) expression='.installs[].features = ["alpha"]' ;;
        duplicate) expression='.installs[].features = ["cli", "cli"]' ;;
        null) expression='.installs[].features = null' ;;
        false) expression='.installs[].features = false' ;;
        no-default) expression='.installs[].no_default_features = true' ;;
        all) expression='.installs[].all_features = true' ;;
    esac
    jq "$expression" "$fixture/feature-receipt" > "$cli_bundle/.crates2.json"
    digest="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$cli_bundle/.crates2.json")"
    jq --arg digest "$digest" '.receipt_sha256=$digest' "$fixture/feature-selection" > "$cli_bundle/selection.json"
    refuse bash "$installer" "${feature_args[@]}" --features cli --check
    [[ "$(wc -l < "$fixture/builds")" == "$builds_before" && ! -s "$fixture/probes" ]] || exit 1
done
cp "$fixture/feature-receipt" "$cli_bundle/.crates2.json"
cp "$fixture/feature-selection" "$cli_bundle/selection.json"
bash "$installer" "${feature_args[@]}" --features cli --check > "$fixture/feature-check"
[[ "$(cat "$fixture/feature-check")" == "$cli_path" ]] || exit 1
printf 'version = 3\n[[package]]\nname = "sample"\nversion = "1.2.3"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\n' > "$fixture/feature.lock"
observed="$(bash "$installer" --consumer "$consumer" --package sample --lockfile "$fixture/feature.lock" \
    --bin prepare --profile debug --features cli --check)"
[[ "$observed" == "$cli_path" && "$(wc -l < "$fixture/builds")" == "$builds_before" ]] || exit 1
# Cargo owns unknown-feature diagnostics. Preserve its status/log and do not
# activate the failed attempt or disturb any earlier feature selection.
status=0
bash "$installer" "${feature_args[@]}" --features unavailable > "$fixture/feature-failure.out" \
    2> "$fixture/feature-failure.err" || status=$?
[[ "$status" == 24 && ! -s "$fixture/feature-failure.out" ]] || exit 1
expect_setup_phase "$fixture/feature-failure.err" compilation failed 24
attempt="$(sed -n 's/^Cargo tool attempt retained: //p' "$fixture/feature-failure.err")"
[[ -f "$attempt/install.log" && -f "$attempt/build/evidence" && ! -e "${attempt%/*}/current" && ! -e "$attempt/selection.json" ]] || exit 1
[[ "$(bash "$installer" "${feature_args[@]}" --features cli --check)" == "$cli_path" ]] || exit 1
[[ "$(git -C "$fixture/a" rev-parse HEAD)" == "$source_commit" && ! -s "$fixture/forbidden-git" ]] || exit 1
# Admission waits use separate real owner/check processes against an already
# valid selected CLI. Cargo effects above are substitutes; none may run here.
mkdir "$fixture/admission-readonly"
export ADMISSION_EFFECTS="$fixture/admission-effects"
for command in mkdir rmdir rm cp mv ln curl; do
    cat > "$fixture/admission-readonly/$command" <<'DENY'
#!/usr/bin/env bash
printf '%s\n' "$0 $*" >> "$ADMISSION_EFFECTS"
echo 'unexpected mutation in read-only admission' >&2
exit 99
DENY
    chmod +x "$fixture/admission-readonly/$command"
done
cat > "$fixture/admission-owner.sh" <<'OWNER'
#!/usr/bin/env bash
set -euo pipefail
source "$1"
consumer="$2"
tool_store_init rust "$(cat "$3")"
tool_store_acquire
trap tool_store_release EXIT
trap 'exit 143' TERM
: > "$4"
while [[ ! -f "$5" ]]; do sleep 0.05; done
OWNER
cp "$cli_bundle/bin/prepare" "$fixture/admission-binary"
cp "$cli_bundle/.crates2.json" "$fixture/admission-receipt"
cp "$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-fixture/sample-1.2.3.crate" "$fixture/admission-source"
cp "$fixture/compiler-version" "$fixture/admission-compiler"
cp "$fixture/feature.lock" "$fixture/admission-lock"
: > "$fixture/admission-common-versions"
for command in cargo-sort cargo-sort-derives; do
    common_binary="$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$consumer/.tools/rust/common/bin/$command")"
    version="$(jq -r .version "${common_binary%/bin/*}/inputs.json")"
    catalog_name="$(printf '%s' "$command" | tr '[:lower:]-' '[:upper:]_')"
    printf 'SHARED_TOOLING_%s_VERSION=%s\n' "$catalog_name" "$version" >> "$fixture/admission-common-versions"
done
bash "$installer" --consumer "$consumer" --versions "$fixture/admission-common-versions" --check > "$fixture/admission-common-check"
cp "$fixture/admission-common-versions" "$fixture/admission-common-before"
admission_active="${cli_path%/bin/*}"
admission_reference="$(readlink "$admission_active")"
admission_slot="${cli_bundle%/set.*}"
admission_builds="$(wc -l < "$fixture/builds")"
admission_probes="$(wc -l < "$fixture/probes")"
admission_args=(--consumer "$consumer" --package sample --lockfile "$fixture/feature.lock" --bin prepare --profile debug --features cli --check)
for scenario in reuse timeout unknown-owner changed-compiler changed-source changed-lock changed-catalog changed-selection changed-features corrupt-binary; do
    rm -f "$fixture/admission-ready" "$fixture/admission-release"
    check_args=("${admission_args[@]}")
    owner_bundle="$cli_bundle"
    if [[ "$scenario" == changed-catalog ]]; then
        common_binary="$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$consumer/.tools/rust/common/bin/cargo-sort")"
        owner_bundle="${common_binary%/bin/*}"
        check_args=(--consumer "$consumer" --versions "$fixture/admission-common-versions" --check)
    fi
    admission_slot="${owner_bundle%/set.*}"
    bash "$fixture/admission-owner.sh" "$ROOT/scripts/dev/tool-store.sh" "$fixture/b" \
        "$owner_bundle/inputs.json" "$fixture/admission-ready" "$fixture/admission-release" \
        > "$fixture/admission-owner.log" 2>&1 & owner_setup=$!
    for ((poll=0; poll<200; poll++)); do
        [[ ! -f "$fixture/admission-ready" ]] || break
        sleep 0.05
    done
    [[ -f "$fixture/admission-ready" ]] || { cat "$fixture/admission-owner.log"; exit 1; }
    cp "$admission_slot/install.lock/owner" "$fixture/admission-owner.before"
    if [[ "$scenario" == reuse ]]; then
        # The default check is immediate, with a typed busy result and no hint
        # to install an already valid product. No selected binary is executed.
        status=0
        PATH="$fixture/admission-readonly:$PATH" bash "$installer" "${admission_args[@]}" > "$fixture/admission-busy.out" 2> "$fixture/admission-busy.err" || status=$?
        [[ "$status" == 75 && ! -s "$fixture/admission-busy.out" ]]
        if grep -E 'missing or invalid|Explicit setup:|Waiting for' "$fixture/admission-busy.err"; then exit 1; fi
    elif [[ "$scenario" == unknown-owner ]]; then
        printf 'unknown claim\n' > "$admission_slot/install.lock/owner"
        status=0
        PATH="$fixture/admission-readonly:$PATH" bash "$installer" "${admission_args[@]}" --wait-seconds 1 > "$fixture/admission-check.out" 2> "$fixture/admission-check.err" || status=$?
        [[ "$status" == 1 && ! -s "$fixture/admission-check.out" ]]
        if grep -F 'Waiting for' "$fixture/admission-check.err"; then exit 1; fi
        cp "$fixture/admission-owner.before" "$admission_slot/install.lock/owner"
    fi
    if [[ "$scenario" != unknown-owner ]]; then
        budget=15
        [[ "$scenario" != timeout ]] || budget=1
        # Clear the previous scenario before starting the asynchronous checker;
        # otherwise polling could mistake an old wait line for this process.
        : > "$fixture/admission-check.err"
        : > "$fixture/admission-check.out"
        PATH="$fixture/admission-readonly:$PATH" bash "$installer" "${check_args[@]}" --wait-seconds "$budget" \
            > "$fixture/admission-check.out" 2> "$fixture/admission-check.err" & waiter_setup=$!
        for ((poll=0; poll<200; poll++)); do
            if grep -qF 'Waiting for tool installation slot:' "$fixture/admission-check.err"; then break; fi
            sleep 0.05
        done
        grep -F 'Waiting for tool installation slot:' "$fixture/admission-check.err" >/dev/null
        case "$scenario" in
            changed-compiler) printf 'changed admission compiler\n' > "$fixture/compiler-version" ;;
            changed-source) printf '\n' >> "$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-fixture/sample-1.2.3.crate" ;;
            changed-lock) printf '\n# changed saved source lock\n' >> "$fixture/feature.lock" ;;
            changed-catalog) printf '\n# changed catalog input\n' >> "$fixture/admission-common-versions" ;;
            changed-selection)
                ln -s "$cli_bundle" "${admission_active%/*}/rust-set.admission"
                rm "$admission_active"
                ln -s rust-set.admission "$admission_active" ;;
            changed-features) jq '.installs[].features = []' "$fixture/admission-receipt" > "$cli_bundle/.crates2.json" ;;
            corrupt-binary) printf '\n# changed executable bytes\n' >> "$cli_bundle/bin/prepare" ;;
        esac
        if [[ "$scenario" == timeout ]]; then
            status=0
            wait "$waiter_setup" || status=$?; waiter_setup=''
            [[ "$status" == 75 && ! -s "$fixture/admission-check.out" ]]
            grep -F 'wait timed out' "$fixture/admission-check.err" >/dev/null
            cmp "$fixture/admission-owner.before" "$admission_slot/install.lock/owner"
        fi
    fi
    : > "$fixture/admission-release"
    wait "$owner_setup"; owner_setup=''
    if [[ -n "$waiter_setup" ]]; then
        status=0
        wait "$waiter_setup" || status=$?; waiter_setup=''
        if [[ "$scenario" == reuse ]]; then
            [[ "$status" == 0 && "$(cat "$fixture/admission-check.out")" == "$cli_path" ]]
        else
            [[ "$status" == 1 && ! -s "$fixture/admission-check.out" ]]
        fi
    fi
    [[ ! -e "$admission_slot/install.lock" ]]
    [[ ! -e "$ADMISSION_EFFECTS" ]]
    [[ "$(wc -l < "$fixture/builds")" == "$admission_builds" && "$(wc -l < "$fixture/probes")" == "$admission_probes" ]]
    cp "$fixture/admission-binary" "$cli_bundle/bin/prepare"
    cp "$fixture/admission-receipt" "$cli_bundle/.crates2.json"
    cp "$fixture/admission-source" "$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-fixture/sample-1.2.3.crate"
    cp "$fixture/admission-compiler" "$fixture/compiler-version"
    cp "$fixture/admission-lock" "$fixture/feature.lock"
    cp "$fixture/admission-common-before" "$fixture/admission-common-versions"
    if [[ "$scenario" == changed-selection ]]; then
        rm "$admission_active" "${admission_active%/*}/rust-set.admission"
        ln -s "$admission_reference" "$admission_active"
    fi
    [[ "$(readlink "$admission_active")" == "$admission_reference" ]]
    echo "Read-only admission: $scenario passed"
done
for invalid in -1 01 301 1.5; do
    status=0
    bash "$installer" "${admission_args[@]}" --wait-seconds "$invalid" > "$fixture/admission-invalid.log" 2>&1 || status=$?
    [[ "$status" == 2 ]]
done
refuse bash "$installer" "${feature_args[@]}" --features cli --wait-seconds 1
refuse bash "$installer" "${admission_args[@]}" --wait-seconds 1 --wait-seconds 1

# Two real installer processes share one exact payload, with Cargo effects
# substituted. Synchronize on the held build and the wait diagnostic, not time.
for scenario in reuse changed-compiler changed-source redirected-source; do
    case "$scenario" in reuse) version=8.0.0 ;; changed-compiler) version=8.0.1 ;; changed-source) version=8.0.2 ;; redirected-source) version=8.0.3 ;; esac
    source_package sample "$version"
    mkdir "$fixture/$scenario-owner" "$fixture/$scenario-waiter"
    contention_args=(--package sample --version "$version" --bin prepare --profile debug)
    cp "$fixture/compiler-version" "$fixture/compiler-before-contention"
    rm -f "$fixture/install-held"
    touch "$fixture/hold-install"
    bash "$installer" --consumer "$fixture/$scenario-owner" "${contention_args[@]}" \
        > "$fixture/owner.out" 2> "$fixture/owner.err" & owner_setup=$!
    for ((poll=0; poll<200; poll++)); do
        [[ ! -s "$fixture/install-held" ]] || break
        sleep 0.05
    done
    [[ -s "$fixture/install-held" ]] || { cat "$fixture/owner.err"; exit 1; }
    SHARED_TOOLING_SETUP_WAIT_SECONDS=20 bash "$installer" --consumer "$fixture/$scenario-waiter" \
        "${contention_args[@]}" > "$fixture/waiter.out" 2> "$fixture/waiter.err" & waiter_setup=$!
    for ((poll=0; poll<200; poll++)); do
        if grep -qF 'Waiting for tool installation slot:' "$fixture/waiter.err"; then break; fi
        sleep 0.05
    done
    grep -F 'Waiting for tool installation slot:' "$fixture/waiter.err" >/dev/null
    grep -F "package=sample version=$version phase=lock-wait outcome=started elapsed=0s" "$fixture/waiter.err" >/dev/null
    # An offline check never waits, even with the setup budget configured.
    status=0
    SHARED_TOOLING_SETUP_WAIT_SECONDS=300 bash "$installer" --consumer "$fixture/$scenario-owner" \
        "${contention_args[@]}" --check > "$fixture/contended-check.out" 2> "$fixture/contended-check.err" || status=$?
    [[ "$status" != 0 && ! -s "$fixture/contended-check.out" ]]
    if grep -F 'Waiting for' "$fixture/contended-check.err"; then exit 1; fi
    [[ "$scenario" != changed-compiler ]] || echo compiler > "$fixture/change-build"
    if [[ "$scenario" == changed-source ]]; then
        printf '\n' >> "$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-fixture/sample-$version.crate"
    elif [[ "$scenario" == redirected-source ]]; then
        rm "$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-fixture/sample-$version.crate"
        ln -s "$fixture/assets/sample-$version.crate" "$SHARED_TOOLING_STORE/cargo-cache/registry/cache/index.crates.io-fixture/sample-$version.crate"
    fi
    rm "$fixture/hold-install"
    owner_status=0; waiter_status=0
    wait "$owner_setup" || owner_status=$?; owner_setup=''
    wait "$waiter_setup" || waiter_status=$?; waiter_setup=''
    [[ "$(grep -c "^sample $version bin prepare debug$" "$fixture/builds")" == 1 ]]
    if [[ "$scenario" == reuse ]]; then
        [[ "$owner_status:$waiter_status" == 0:0 ]]
        expect_setup_phase "$fixture/waiter.err" lock-wait passed 0
        expect_setup_phase "$fixture/waiter.err" cache-reuse passed 0
        if grep -F 'phase=compilation' "$fixture/waiter.err"; then exit 1; fi
        owner_path="$(cat "$fixture/owner.out")"; waiter_path="$(cat "$fixture/waiter.out")"
        [[ "$(cd -P "${owner_path%/*}" && pwd)" == "$(cd -P "${waiter_path%/*}" && pwd)" ]]
        bash "$installer" --consumer "$fixture/$scenario-waiter" "${contention_args[@]}" --check > "$fixture/reuse-check.out"
        cmp "$fixture/waiter.out" "$fixture/reuse-check.out"
    else
        [[ "$owner_status:$waiter_status" == 1:1 && ! -s "$fixture/waiter.out" ]]
        if [[ "$scenario" == changed-compiler ]]; then
            grep -F 'Cargo tool build environment changed:' "$fixture/waiter.err" >/dev/null
            rm "$fixture/change-build"
            cp "$fixture/compiler-before-contention" "$fixture/compiler-version"
        elif [[ "$scenario" == changed-source ]]; then
            grep -F 'checksum mismatch' "$fixture/waiter.err" >/dev/null
        else
            grep -F 'source must be a regular non-symlink archive' "$fixture/waiter.err" >/dev/null
        fi
        [[ -z "$(find "$fixture/$scenario-waiter/.tools/rust" -name 'selected-*')" ]]
    fi
done
SHARED_TOOLING_SETUP_WAIT_SECONDS=invalid bash "$installer" "${feature_args[@]}" --features cli --check \
    > "$fixture/check-ignores-wait.out"
[[ "$(cat "$fixture/check-ignores-wait.out")" == "$cli_path" ]]
SHARED_TOOLING_SETUP_WAIT_SECONDS=invalid bash "$installer" --consumer "$consumer" --preflight
for invalid in -1 01 301 1.5; do
    status=0
    SHARED_TOOLING_SETUP_WAIT_SECONDS="$invalid" bash "$installer" --consumer "$consumer" \
        "${feature_args[@]:2}" > "$fixture/invalid-wait.out" 2> "$fixture/invalid-wait.err" || status=$?
    [[ "$status" == 2 && ! -s "$fixture/invalid-wait.out" ]]
    grep -F 'SHARED_TOOLING_SETUP_WAIT_SECONDS must be' "$fixture/invalid-wait.err" >/dev/null
done
echo 'Shared Cargo installation, standard environment, identities, retention, contention and offline checks passed'
fixture_complete=true
