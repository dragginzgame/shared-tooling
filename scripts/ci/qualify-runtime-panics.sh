#!/usr/bin/env bash
# Shared companions: scripts/ci/check-runtime-panics.rs scripts/ci/test-runtime-panics.sh scripts/ci/verify-file-checksum.sh scripts/ci/verify-evidence-checksums.sh ci/runtime-panics/workspace.toml.in ci/runtime-panics/scanner.toml.in ci/runtime-panics/Cargo.lock.in
set -euo pipefail

# Producer-only native qualification. Rust is explicitly prepared by the caller;
# Cargo may fetch the selected locked sources unless the caller selects offline.
[[ $# == 2 && -n "$1" && "$1" != -* && "$1" != *[[:space:]]* &&
   "$2" == /* && "$2" != *$'\n'* && "$2" != *$'\r'* &&
   ! -e "$2" && ! -L "$2" ]] || {
    echo 'usage: qualify-runtime-panics.sh PREPARED-TOOLCHAIN NEW-ABSOLUTE-EVIDENCE-DIRECTORY' >&2
    exit 2
}
compiler="$1"
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
case "$ROOT" in *$'\n'*|*$'\r'*) echo 'source path contains CR/LF' >&2; exit 2 ;; esac
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
parent="$(cd -P "${2%/*}/" && printf '%s/.' "$PWD")"
parent="${parent%/.}"
case "$ROOT$parent" in *$'\n'*|*$'\r'*) echo 'resolved source or evidence parent contains CR/LF' >&2; exit 2 ;; esac
evidence="$parent/${2##*/}"
# Unlike `cargo +TOOLCHAIN`, rustup run refuses an unprepared compiler without
# installing it. Refuse before creating an evidence directory or fetching crates.
rustup run "$compiler" cargo --version > /dev/null
mkdir "$evidence"
complete=false
finish() {
    local status=$?
    [[ "$complete" == true || "$status" != 0 ]] || status=1
    printf 'Runtime scanner qualification evidence: %s\n' "$evidence" >&2 || :
    exit "$status"
}
trap finish EXIT
mkdir -p "$evidence/workspace/crates/scanner/src"
cp "$ROOT/ci/runtime-panics/workspace.toml.in" "$evidence/workspace/Cargo.toml"
cp "$ROOT/ci/runtime-panics/scanner.toml.in" "$evidence/workspace/crates/scanner/Cargo.toml"
cp "$ROOT/ci/runtime-panics/Cargo.lock.in" "$evidence/workspace/Cargo.lock"
cp "$ROOT/scripts/ci/check-runtime-panics.rs" "$evidence/workspace/crates/scanner/src/main.rs"
cp "$ROOT/scripts/ci/test-runtime-panics.sh" "$evidence/semantic-fixture.sh"
cp "$ROOT/scripts/ci/qualify-runtime-panics.sh" "$evidence/qualifier.sh"
(
    cd "$evidence"
    for file in workspace/Cargo.toml workspace/crates/scanner/Cargo.toml \
        workspace/Cargo.lock workspace/crates/scanner/src/main.rs semantic-fixture.sh qualifier.sh; do
        digest="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$file")"
        printf '%s  %s\n' "$digest" "$file"
    done
) > "$evidence/inputs.sha256"

run_logged() {
    local log="$1" status
    shift
    printf '%q ' "$@" >> "$evidence/commands.log"
    printf '\n' >> "$evidence/commands.log"
    "$@" > "$evidence/$log" 2>&1 || {
        status=$?
        cat "$evidence/$log" >&2 || :
        return "$status"
    }
}

run_logged compiler.log rustup run "$compiler" rustc --version --verbose
run_logged cargo.log rustup run "$compiler" cargo --version
run_logged rustfmt.log rustup run "$compiler" rustfmt --edition 2024 --check \
    "$evidence/workspace/crates/scanner/src/main.rs"
run_logged build.log rustup run "$compiler" cargo build --locked \
    --manifest-path "$evidence/workspace/Cargo.toml" --target-dir "$evidence/target"
run_logged clippy.log rustup run "$compiler" cargo clippy --locked \
    --manifest-path "$evidence/workspace/Cargo.toml" --target-dir "$evidence/target" -- -D warnings
run_logged semantics.log "$BASH" "$evidence/semantic-fixture.sh" "$evidence/target/debug/shared-runtime-scanner"
cat "$evidence/semantics.log"
(cd "$evidence" && bash "$ROOT/scripts/ci/verify-evidence-checksums.sh" inputs.sha256)
complete=true
