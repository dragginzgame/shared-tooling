#!/usr/bin/env bash
# Shared companions: scripts/dev/cloc.sh scripts/ci/fixture-lifecycle.sh scripts/ci/test-cloc-workspaces.sh scripts/ci/test-cloc-table.sh scripts/ci/test-cloc-launcher.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
export PATH="$ROOT/.tools/host/bin:$PATH"
unset CARGO_TARGET_DIR
case "${1:-}" in
    '') scopes_only=false; metadata_only=false; bash "$ROOT/scripts/ci/test-cloc-launcher.sh"; bash "$ROOT/scripts/ci/test-cloc-table.sh"; bash "$ROOT/scripts/ci/test-cloc-workspaces.sh" ;;
    --launcher-only) exec bash "$ROOT/scripts/ci/test-cloc-launcher.sh" ;;
    --table-only) exec bash "$ROOT/scripts/ci/test-cloc-table.sh" ;;
    --workspaces-only) exec bash "$ROOT/scripts/ci/test-cloc-workspaces.sh" ;;
    --scopes-only) scopes_only=true; metadata_only=false ;;
    --metadata-only) scopes_only=false; metadata_only=true ;;
    *) echo 'usage: test-cloc.sh [--launcher-only|--table-only|--scopes-only|--metadata-only|--workspaces-only]' >&2; exit 2 ;;
esac
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-cloc-test.XXXXXX")"
FIXTURE="$(cd "$FIXTURE" && pwd -P)"
git init -q "$FIXTURE"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE" "Failed LOC fixture retained"' EXIT
if [[ "$scopes_only" == false ]]; then
    mkdir -p "$FIXTURE/policy/src"
    printf '[package]\nname="policy"\nversion="0.1.0"\n[workspace]\n' > "$FIXTURE/policy/Cargo.toml"
    printf 'pub fn fixture() {}\n' > "$FIXTURE/policy/src/lib.rs"
    (cd "$FIXTURE/policy" && cargo generate-lockfile --offline)
    cp "$FIXTURE/policy/Cargo.toml" "$FIXTURE/policy-base.toml"
    cp "$FIXTURE/policy/Cargo.lock" "$FIXTURE/policy.lock"
    for declaration in misplaced both empty; do
        cp "$FIXTURE/policy-base.toml" "$FIXTURE/policy/Cargo.toml"
        printf '\n[package.metadata.other-tooling.loc]\ncategory="tests"\n' >> "$FIXTURE/policy/Cargo.toml"
        if [[ "$declaration" == both ]]; then
            printf '\n[package.metadata.toko-tooling.loc]\ncategory="tests"\n' >> "$FIXTURE/policy/Cargo.toml"
        elif [[ "$declaration" == empty ]]; then
            # Even an empty obsolete table declares a policy, not an absent one.
            sed '/category=/d' "$FIXTURE/policy/Cargo.toml" > "$FIXTURE/policy-empty.toml"
            cp "$FIXTURE/policy-empty.toml" "$FIXTURE/policy/Cargo.toml"
        fi
        if bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/policy/Cargo.toml" "$FIXTURE/policy" > "$FIXTURE/policy.json" 2> "$FIXTURE/policy.err"; then exit 1; fi
        [[ ! -s "$FIXTURE/policy.json" ]]
        grep -F "$FIXTURE/policy/Cargo.toml: unsupported LOC metadata" "$FIXTURE/policy.err" >/dev/null
        grep -F 'package.metadata.toko-tooling.loc' "$FIXTURE/policy.err" >/dev/null
        cmp "$FIXTURE/policy.lock" "$FIXTURE/policy/Cargo.lock"
    done
    cp "$FIXTURE/policy-base.toml" "$FIXTURE/policy/Cargo.toml"
    printf '\n[package.metadata.toko-tooling.loc]\ncategory="tests"\n[package.metadata.unrelated]\nlabel="retained"\n' >> "$FIXTURE/policy/Cargo.toml"
    bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/policy/Cargo.toml" "$FIXTURE/policy" > "$FIXTURE/policy.json"
    jq -e '.totals.tests == 1 and .totals.library_app == 0 and .totals.total == 1' "$FIXTURE/policy.json" >/dev/null
    if [[ "$metadata_only" == true ]]; then
        echo 'LOC metadata admission and migrated fixture classification passed'
        fixture_complete=true
        exit 0
    fi
fi
mkdir -p "$FIXTURE/scopes/src"
printf '[package]\nname="scopes"\nversion="0.1.0"\n[workspace]\n' > "$FIXTURE/scopes/Cargo.toml"
cat > "$FIXTURE/scopes/src/lib.rs" <<'RUST'
pub fn bind() {
    RUNTIME.with(|runtime| {
        #[cfg(test)]
        if take_fault() {
            return Err(handle);
        }
        runtime.bind(handle)
    })
}
pub fn finish() {
    let completed = with_registry_mut(|registry| {
        #[cfg(test)]
        {
            if take_fault() {
                return Err(error);
            }
        }
        registry.complete()
    });
    finish_transition(completed);
}
pub mod controls;
RUST
cat > "$FIXTURE/scopes/src/controls.rs" <<'RUST'
pub fn controls() {
    call((move || {
        #[cfg(any(test, feature = "production"))]
        {
            production();
        }
        #[cfg_attr(feature = "conditional", test)]
        fn conditional() {}
        emit!(#[cfg(test)] { not_expanded(); });
        emit! { #[cfg(test)] { not_expanded(); } }
        "#[cfg(test)] { string(); }"
    }))
}
pub fn nested() {
    call([outer(inner(|| {
        #[cfg(all(test, feature = "fixture"))]
        {
            test_hook();
        }
        production();
    }))]);
}
pub fn mixed() { call(|| { #[cfg(test)] { test_hook(); } production(); }); }
#[cfg(test)]
mod inline {
    fn helper() { call(|| { test_hook(); }); }
}
RUST
(cd "$FIXTURE/scopes" && cargo generate-lockfile --offline)
cp "$FIXTURE/scopes/Cargo.lock" "$FIXTURE/scopes.lock"
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/scopes/Cargo.toml" "$FIXTURE/scopes" > "$FIXTURE/scopes.json"
jq -e '
  (.files | length) == 2 and .totals.unclassified == 0 and
  ([.files[] | select(.path | endswith("/src/lib.rs"))][0].counts.tests == 10) and
  ([.files[] | select(.path | endswith("/src/controls.rs"))][0].counts.tests == 8) and
  ([.diagnostics[] | select(.reason | startswith("conditional attributes"))] | length == 1) and
  ([.diagnostics[] | select(.reason | startswith("mixed-category"))] | length == 1)
' "$FIXTURE/scopes.json" >/dev/null
cloc --json --skip-uniqueness "$FIXTURE/scopes/src" > "$FIXTURE/scopes-cloc.json"
[[ "$(jq '.SUM.code' "$FIXTURE/scopes-cloc.json")" == "$(jq '.totals.total' "$FIXTURE/scopes.json")" ]]
cmp "$FIXTURE/scopes.lock" "$FIXTURE/scopes/Cargo.lock"
if [[ "$scopes_only" == true ]]; then
    echo 'Nested closure/block LOC classification passed'
    fixture_complete=true
    exit 0
fi
mkdir -p "$FIXTURE/crates/app/src/tests" "$FIXTURE/crates/app/examples" "$FIXTURE/crates/app/benches" \
    "$FIXTURE/crates/app/tests" "$FIXTURE/crates/fixture/src" "$FIXTURE/.cargo"
cat > "$FIXTURE/Cargo.toml" <<'TOML'
[workspace]
members = ["crates/*"]
resolver = "2"
TOML
printf '[build]\ntarget-dir="crates/app/output"\n' > "$FIXTURE/.cargo/config.toml"
cat > "$FIXTURE/crates/app/Cargo.toml" <<'TOML'
[package]
name = "app"
version = "0.1.0"
edition = "2021"
[package.metadata.toko-tooling.loc]
generated = ["src/generated.rs"]
[package.metadata.toko-tooling.loc.paths]
"generator.rs" = "build_tooling"
[[example]]
name = "same_source"
path = "src/shared.rs"
[[bench]]
name = "measure"
harness = false
TOML
cat > "$FIXTURE/crates/fixture/Cargo.toml" <<'TOML'
[package]
name = "opaque-name"
version = "0.1.0"
edition = "2021"
publish = false
[package.metadata.toko-tooling.loc]
category = "tests"
TOML
printf 'pub fn fixture() {}\n' > "$FIXTURE/crates/fixture/src/lib.rs"
cat > "$FIXTURE/crates/app/src/lib.rs" <<'RUST'
pub mod shared;
mod generated;
#[cfg(test)]
mod tests;
pub fn app() {}
// #[cfg(test)] mod fake { }
/* nested /* #[cfg(test)] mod fake2 {} */ comment */
pub const RAW: &str = r###"#[cfg(test)] mod imaginary { }"###;
#[cfg(test)]
mod inline {
    // Test comment is not LOC.
    #[test]
    fn unit() {
        assert_eq!("}", "}");
    }
}
#[cfg(any(test, feature = "public"))]
mod public {
    pub fn still_library() {}
}
#[cfg(all(test, feature = "fixture"))]
mod conditional {
    pub fn helper() {}
}
RUST
printf 'pub fn shared() {}\n' > "$FIXTURE/crates/app/src/shared.rs"
printf 'pub fn generated() {}\n' > "$FIXTURE/crates/app/src/generated.rs"
printf '#[test]\nfn external_unit() {}\n' > "$FIXTURE/crates/app/src/tests/mod.rs"
printf 'fn main() {}\n' > "$FIXTURE/crates/app/examples/demo.rs"
printf 'fn main() {}\n' > "$FIXTURE/crates/app/benches/measure.rs"
printf 'fn main() {}\n' > "$FIXTURE/crates/app/build.rs"
printf 'pub fn generator() {}\n' > "$FIXTURE/crates/app/generator.rs"
printf 'pub fn orphan() {}\n' > "$FIXTURE/crates/app/src/orphan.rs"
printf '#[test]\nfn integration() {}\n' > "$FIXTURE/crates/app/tests/integration.rs"
(cd "$FIXTURE" && cargo generate-lockfile --offline)
cp "$FIXTURE/Cargo.lock" "$FIXTURE/original.lock"
report() { bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/Cargo.toml" "$FIXTURE"; }
report > "$FIXTURE/report.json"
# A clean checkout (or cargo clean) must not require a prior build for scratch.
rm -rf "$FIXTURE/crates/app/output"
(unset TMPDIR RUNNER_TEMP; report) > "$FIXTURE/default-scratch.json"
cmp "$FIXTURE/report.json" "$FIXTURE/default-scratch.json"
[[ -d "$FIXTURE/crates/app/output/tmp" ]]
(TMPDIR="$FIXTURE/new scratch/child" report) > "$FIXTURE/new-scratch.json"
cmp "$FIXTURE/report.json" "$FIXTURE/new-scratch.json"
jq -e '
  .schema == 2 and
  .totals.examples == 1 and .totals.benchmarks == 1 and .totals.build_tooling == 2 and
  .totals.unclassified == 1 and .totals.tests > 10 and .totals.library_app > 0 and
  (.totals.total == (.totals | del(.total) | add)) and
  ([.files[].counts.total] | add) == .totals.total and
  ([.files[] | select(.path | endswith("/src/shared.rs"))][0] | .shared and .counts.total == 1 and .counts.library_app == 1) and
  ([.files[] | select(.path | endswith("/src/generated.rs"))][0].generated) and
  ([.crates[] | select(.crate=="opaque-name")][0].counts.tests == 1) and
  ([.files[] | select(.path | endswith("/src/lib.rs")) | select(.crate=="app")][0].counts.tests > 5)
' "$FIXTURE/report.json" >/dev/null
# The category partition must exactly preserve independent cloc's source total.
find "$FIXTURE/crates" -name '*.rs' -type f > "$FIXTURE/source-list"
cloc --list-file="$FIXTURE/source-list" --skip-uniqueness --json > "$FIXTURE/original.json"
[[ "$(jq '.SUM.code' "$FIXTURE/original.json")" == "$(jq '.totals.total' "$FIXTURE/report.json")" ]]
# Generated Cargo output, duplicate bytes and nested members retain path identity.
mkdir -p "$FIXTURE/crates/app/output/tests"
printf 'pub fn never_count() {}\n' > "$FIXTURE/crates/app/output/tests/generated.rs"
report > "$FIXTURE/after.json"
cmp "$FIXTURE/report.json" "$FIXTURE/after.json"
# Root packages must not count installed tools or frontend dependency sources.
for cache in .tools node_modules .tmp .cache build dist coverage vendor recovery-evidence; do
    mkdir -p "$FIXTURE/crates/app/$cache/nested"
    printf 'pub fn never_count() {}\n' > "$FIXTURE/crates/app/$cache/nested/cache.rs"
done
report > "$FIXTURE/caches.json"
cmp "$FIXTURE/report.json" "$FIXTURE/caches.json"
# Respect custom ignored output; retain tracked
# source matched by ignore rules and ordinary new untracked source.
printf 'old-output/\n*.retained.rs\n' > "$FIXTURE/.gitignore"
mkdir -p "$FIXTURE/crates/app/old-output/nested/target"
printf 'pub fn stale() {}\n' > "$FIXTURE/crates/app/old-output/nested/target/stale.rs"
report > "$FIXTURE/ignored.json"
cmp "$FIXTURE/report.json" "$FIXTURE/ignored.json"
printf 'pub fn retained() {}\n' > "$FIXTURE/crates/app/src/code.retained.rs"
git -C "$FIXTURE" add -f crates/app/src/code.retained.rs
report > "$FIXTURE/tracked-ignored.json"
jq -e --slurpfile before "$FIXTURE/report.json" '.totals.total == $before[0].totals.total + 1' "$FIXTURE/tracked-ignored.json" >/dev/null
git -C "$FIXTURE" rm -q -f crates/app/src/code.retained.rs
# Source archives beneath ignored scratch still work without a Git inventory.
archive="$FIXTURE/archive"
mkdir -p "$archive/src" "$archive/.tmp" "$archive/target" "$archive/build"
printf 'archive/\n' >> "$FIXTURE/.gitignore"
printf '[package]\nname="archive"\nversion="0.1.0"\n[workspace]\n' > "$archive/Cargo.toml"
printf 'pub fn source() {}\n' > "$archive/src/lib.rs"
for cache in .tmp target build; do
    printf 'pub fn stale() {}\n' > "$archive/$cache/stale.rs"
done
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$archive/Cargo.toml" "$archive" > "$FIXTURE/archive.json"
jq -e '.totals.total == 1 and (.files | length) == 1' "$FIXTURE/archive.json" >/dev/null
# Neither explicit module paths nor Cargo targets may re-admit excluded output.
admission="$FIXTURE/admission"
mkdir -p "$admission/src" "$admission/.tmp" "$admission/old-output"
printf '[package]\nname="admission"\nversion="0.1.0"\n[workspace]\n[[bin]]\nname="stale"\npath="old-output/main.rs"\n' > "$admission/Cargo.toml"
printf '#[path="../old-output/hidden.rs"] mod hidden;\n#[path="../.tmp/hidden.rs"] mod scratch;\n' > "$admission/src/lib.rs"
printf 'pub fn hidden() {}\n' > "$admission/old-output/hidden.rs"
printf 'pub fn hidden() {}\n' > "$admission/.tmp/hidden.rs"
printf 'fn main() {}\n' > "$admission/old-output/main.rs"
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$admission/Cargo.toml" "$admission" > "$FIXTURE/admission.json"
jq -e '.totals.total == 2 and (.files | length) == 1 and (.files[0].path | endswith("/src/lib.rs"))' "$FIXTURE/admission.json" >/dev/null
cp "$FIXTURE/crates/app/tests/integration.rs" "$FIXTURE/crates/app/tests/duplicate.rs"
report > "$FIXTURE/duplicates.json"
jq -e --slurpfile before "$FIXTURE/report.json" '.totals.tests == $before[0].totals.tests + 2 and .totals.total == $before[0].totals.total + 2' "$FIXTURE/duplicates.json" >/dev/null
# Legacy paths are measured as tests but flagged for the hard cut.
mkdir "$FIXTURE/crates/app/test"
printf 'pub fn helper() {}\n' > "$FIXTURE/crates/app/test/helper.rs"
report > "$FIXTURE/legacy.json"
jq -e '[.diagnostics[] | select(.reason | startswith("legacy"))] | length == 1' "$FIXTURE/legacy.json" >/dev/null
# Compile-fail fixtures may deliberately contain unbalanced tokens. Preserve
# their footprint and role, while unclassified malformed source stays visible.
printf 'pub fn broken( {\n' > "$FIXTURE/crates/app/src/broken.rs"
cp "$FIXTURE/crates/app/src/broken.rs" "$FIXTURE/crates/app/tests/broken.rs"
report > "$FIXTURE/malformed.json"
jq -e '[.files[] | select(.path | endswith("/src/broken.rs"))][0].counts.unclassified == 1 and
  ([.files[] | select(.path | endswith("/tests/broken.rs"))][0].counts.tests == 1) and
  ([.diagnostics[] | select(.reason | startswith("Rust token classification unavailable"))] | length == 2)' "$FIXTURE/malformed.json" >/dev/null
rm "$FIXTURE/crates/app/src/broken.rs"
rm "$FIXTURE/crates/app/tests/broken.rs"
# Single physical mixed-category lines count once and carry an explicit warning.
printf 'pub fn live() {} #[cfg(test)] mod tests { fn helper() {} }\n' > "$FIXTURE/crates/app/src/mixed.rs"
report > "$FIXTURE/mixed.json"
jq -e '[.diagnostics[] | select(.reason | startswith("mixed-category"))] | length == 1' "$FIXTURE/mixed.json" >/dev/null
# No compilation, lock changes or source rewrites.
cmp "$FIXTURE/Cargo.lock" "$FIXTURE/original.lock"
[[ ! -e "$FIXTURE/crates/app/output/debug" ]]
# Read-only reporting honors independently selected workspace target directories.
mkdir -p "$FIXTURE/independent/src" "$FIXTURE/independent/.cargo"
printf '[package]\nname="independent"\nversion="0.1.0"\n[workspace]\n' > "$FIXTURE/independent/Cargo.toml"
printf 'pub fn independent() {}\n' > "$FIXTURE/independent/src/lib.rs"
printf '[build]\ntarget-dir="output"\n' > "$FIXTURE/independent/.cargo/config.toml"
mkdir "$FIXTURE/independent/output"
printf 'pub fn ignored() {}\n' > "$FIXTURE/independent/output/ignored.rs"
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/independent/Cargo.toml" "$FIXTURE" > "$FIXTURE/independent.json"
jq -e '.totals.total == 1 and .crates[0].crate == "independent"' "$FIXTURE/independent.json" >/dev/null
# A source module named target is not a Cargo output directory.
mkdir -p "$FIXTURE/independent/src/target" "$FIXTURE/independent/target"
printf 'pub mod target;\n' > "$FIXTURE/independent/src/lib.rs"
printf 'pub fn code() {}\n' > "$FIXTURE/independent/src/target/mod.rs"
printf 'pub fn artifact() {}\n' > "$FIXTURE/independent/target/generated.rs"
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/independent/Cargo.toml" "$FIXTURE" > "$FIXTURE/source-target.json"
jq -e '.totals.library_app == 2 and .totals.total == 2' "$FIXTURE/source-target.json" >/dev/null
rm "$FIXTURE/independent/src/target/mod.rs"
# Exact expected counts: inner attributes must not swallow the next test item.
cat > "$FIXTURE/independent/src/lib.rs" <<'RUST'
#![deny(unsafe_code)]
#[cfg(test)]
fn unit() {}
pub fn live() {}
RUST
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/independent/Cargo.toml" "$FIXTURE" > "$FIXTURE/inner.json"
jq -e '.totals.library_app == 2 and .totals.tests == 2 and .totals.total == 4' "$FIXTURE/inner.json" >/dev/null
# Braced use/const items include their semicolon in the test-only item range.
cat > "$FIXTURE/independent/src/lib.rs" <<'RUST'
#[cfg(test)]
use std::{
    fmt::Debug,
};
#[cfg(test)]
const VALUE: usize = {
    1
};
pub fn live() {}
RUST
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/independent/Cargo.toml" "$FIXTURE" > "$FIXTURE/braces.json"
jq -e '.totals.library_app == 1 and .totals.tests == 8 and .totals.total == 9' "$FIXTURE/braces.json" >/dev/null
# Disabled in both modes is not test-only. Nested predicates must retain meaning.
cat > "$FIXTURE/independent/src/lib.rs" <<'RUST'
#[cfg(any())]
fn dead() {}
#[cfg(all(test, any()))]
fn also_dead() {}
#[cfg(all(test, feature = "fixture"))]
fn helper() {}
#[cfg(not(not(test)))]
fn double_negative() {}
#[cfg(any(test, feature = "public"))]
fn public() {}
RUST
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/independent/Cargo.toml" "$FIXTURE" > "$FIXTURE/cfg.json"
jq -e '.totals.library_app == 6 and .totals.tests == 4 and .totals.total == 10' "$FIXTURE/cfg.json" >/dev/null
# Cargo/module usage wins over a misleading conventional path; raw identifiers
# still resolve, and an inner test gate propagates to external helper modules.
cat > "$FIXTURE/independent/src/lib.rs" <<'RUST'
pub mod tests;
mod r#type;
mod support {
    #![cfg(test)]
    mod helper;
}
RUST
printf 'pub fn shipped() {}\n' > "$FIXTURE/independent/src/tests.rs"
printf 'pub fn identifier() {}\n' > "$FIXTURE/independent/src/type.rs"
mkdir "$FIXTURE/independent/src/support"
printf 'pub fn fixture() {}\n' > "$FIXTURE/independent/src/support/helper.rs"
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/independent/Cargo.toml" "$FIXTURE" > "$FIXTURE/usage.json"
jq -e '
  ([.files[] | select(.path | endswith("/src/tests.rs"))][0].counts.library_app == 1) and
  ([.files[] | select(.path | endswith("/src/type.rs"))][0].counts.library_app == 1) and
  ([.files[] | select(.path | endswith("/support/helper.rs"))][0].counts.tests == 1) and
  (.totals.unclassified == 0) and
  ([.files[].source_sha256 | test("^[0-9a-f]{64}$")] | all)
' "$FIXTURE/usage.json" >/dev/null
rm "$FIXTURE/independent/src/tests.rs" "$FIXTURE/independent/src/type.rs" "$FIXTURE/independent/src/support/helper.rs"
# A Cargo target outside its package is counted once even through ../ aliases.
printf '\n[[bin]]\nname="external"\npath="../external.rs"\n' >> "$FIXTURE/independent/Cargo.toml"
printf '\n[[bin]]\nname="external-alias"\npath=".././external.rs"\n' >> "$FIXTURE/independent/Cargo.toml"
printf 'mod external_support;\nfn main() {}\n' > "$FIXTURE/external.rs"
printf 'pub fn support() {}\n' > "$FIXTURE/external_support.rs"
printf 'pub fn library() {}\n' > "$FIXTURE/independent/src/lib.rs"
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/independent/Cargo.toml" "$FIXTURE" > "$FIXTURE/external.json"
jq -e '.totals.library_app == 4 and .totals.total == 4 and
  ([.files[] | select(.path | endswith("/external.rs"))] | length == 1)' "$FIXTURE/external.json" >/dev/null
rm "$FIXTURE/external.rs" "$FIXTURE/external_support.rs"
perl -0pi -e 's/\n\[\[bin\]\]\nname="external"\n.*\z//s' "$FIXTURE/independent/Cargo.toml"
# A large file with many nested test ranges exercises the scanner hot paths.
perl -e 'for (1..5000) { print "pub fn live_$_() {}\n#[cfg(test)]\nmod test_$_ {\n #[test]\n fn case() {}\n}\n"; }' > "$FIXTURE/independent/src/lib.rs"
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/independent/Cargo.toml" "$FIXTURE" > "$FIXTURE/large.json"
jq -e '.totals.library_app == 5000 and .totals.tests == 25000 and .totals.total == 30000 and .totals.unclassified == 0' "$FIXTURE/large.json" >/dev/null
# Broad module graphs must preserve every file/category when visits are queued
# and token trees are discarded. Keep this separate from the single-file case.
mkdir "$FIXTURE/independent/src/fanout"
printf 'mod fanout;\n' > "$FIXTURE/independent/src/lib.rs"
: > "$FIXTURE/independent/src/fanout/mod.rs"
for ((part=0; part<32; part++)); do
    printf 'pub mod part_%s;\n' "$part" >> "$FIXTURE/independent/src/fanout/mod.rs"
    perl -e 'for (1..100) {print "pub fn live_$_() {}\n#[cfg(test)]\nfn test_$_() {}\n";}' > "$FIXTURE/independent/src/fanout/part_$part.rs"
done
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/independent/Cargo.toml" "$FIXTURE" > "$FIXTURE/fanout.json"
jq -e '.totals.library_app == 3233 and .totals.tests == 6400 and .totals.total == 9633 and .totals.unclassified == 0 and (.files|length)==34' "$FIXTURE/fanout.json" >/dev/null
# cloc failure status is retained and no partial document escapes.
mkdir -p "$FIXTURE/reporter/scripts/dev" "$FIXTURE/bin"
cp "$ROOT/scripts/dev/cloc.sh" "$ROOT/scripts/dev/cloc-classify.pl" "$FIXTURE/reporter/scripts/dev/"
# Concurrent edits between classification and cloc must not change counted bytes.
report > "$FIXTURE/pre-mutation.json"
cp "$FIXTURE/crates/app/src/lib.rs" "$FIXTURE/saved-lib.rs"
export MUTATION_FILE="$FIXTURE/crates/app/src/lib.rs"
export REAL_CLOC
REAL_CLOC="$(command -v cloc)"
cat > "$FIXTURE/bin/cloc" <<'SH'
#!/bin/sh
printf 'pub fn changed_during_scan() {}\n' > "$MUTATION_FILE"
exec "$REAL_CLOC" "$@"
SH
chmod +x "$FIXTURE/bin/cloc"
PATH="$FIXTURE/bin:$PATH" bash "$FIXTURE/reporter/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/Cargo.toml" "$FIXTURE" > "$FIXTURE/mutation.json"
cmp "$FIXTURE/pre-mutation.json" "$FIXTURE/mutation.json"
cp "$FIXTURE/saved-lib.rs" "$FIXTURE/crates/app/src/lib.rs"
printf '#!/bin/sh\nexit 23\n' > "$FIXTURE/bin/cloc"
chmod +x "$FIXTURE/bin/cloc"
status=0
PATH="$FIXTURE/bin:$PATH" bash "$FIXTURE/reporter/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/Cargo.toml" "$FIXTURE" > "$FIXTURE/failed.json" || status=$?
[[ "$status" == 23 && ! -s "$FIXTURE/failed.json" ]]
# Successful cloc exit with missing nonempty file counts must not yield zeros.
printf '#!/bin/sh\nprintf "{}\\n"\n' > "$FIXTURE/bin/cloc"
if PATH="$FIXTURE/bin:$PATH" bash "$FIXTURE/reporter/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/Cargo.toml" "$FIXTURE" > "$FIXTURE/omitted.json" 2> "$FIXTURE/omitted.err"; then exit 1; fi
grep -F 'cloc omitted a nonempty source file' "$FIXTURE/omitted.err" >/dev/null
[[ ! -s "$FIXTURE/omitted.json" ]]
# Cleanup during counting must refuse, not return an incomplete source total.
cat > "$FIXTURE/bin/cloc" <<'SH'
#!/bin/sh
for arg do
    case "$arg" in --list-file=*) list=${arg#--list-file=} ;; esac
done
rm -rf "${list%/*}"
printf '{}\n'
SH
if PATH="$FIXTURE/bin:$PATH" bash "$FIXTURE/reporter/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/Cargo.toml" "$FIXTURE" > "$FIXTURE/removed.json" 2> "$FIXTURE/removed.err"; then exit 1; fi
grep -F 'LOC scratch input disappeared:' "$FIXTURE/removed.err" >/dev/null
[[ ! -s "$FIXTURE/removed.json" ]]
# Depth is a view of existing file counts, never a second counting pass.
depth_root="$FIXTURE/depth"
mkdir -p "$depth_root/src/foo/deep" "$depth_root/tests"
printf '[package]\nname="depth-fixture"\nversion="0.1.0"\nedition="2021"\n[workspace]\n' > "$depth_root/Cargo.toml"
printf 'pub mod foo; pub mod util;\n' > "$depth_root/src/lib.rs"
printf 'pub mod deep;\n' > "$depth_root/src/foo/mod.rs"
printf 'pub mod leaf;\n' > "$depth_root/src/foo/deep/mod.rs"
printf 'pub fn leaf() {}\n' > "$depth_root/src/foo/deep/leaf.rs"
printf 'pub fn util() {}\n' > "$depth_root/src/util.rs"
printf '#[test] fn test() {}\n' > "$depth_root/tests/check.rs"
printf '#[cfg(test)] mod tests;\n' >> "$depth_root/src/lib.rs"
printf '#[test] fn unit() {}\n' > "$depth_root/src/tests.rs"
for depth in 0 1 2 3 999999; do
    bash "$ROOT/scripts/dev/cloc.sh" -d "$depth" --manifest "$depth_root/Cargo.toml" "$depth_root" > "$FIXTURE/depth-$depth"
    grep -Eq '^depth +5 +3 +0 +0 +0 +0 +8$' "$FIXTURE/depth-$depth"
    grep -Eq '^  depth-fixture +5 +3 +0 +0 +0 +0 +8$' "$FIXTURE/depth-$depth"
    if grep -Eq '\(root\)|\(self\)|\.rs |/ ' "$FIXTURE/depth-$depth"; then exit 1; fi
done
if grep -q '^    foo ' "$FIXTURE/depth-0"; then exit 1; fi
grep -Eq '^    foo +3 +0 +0 +0 +0 +0 +3$' "$FIXTURE/depth-1"
grep -Eq '^    util +1 +0 +0 +0 +0 +0 +1$' "$FIXTURE/depth-1"
grep -Eq '^    tests +0 +2 +0 +0 +0 +0 +2$' "$FIXTURE/depth-1"
[[ $(grep -c '^    tests ' "$FIXTURE/depth-1") == 1 ]]
if grep -q '^      deep ' "$FIXTURE/depth-1"; then exit 1; fi
grep -Eq '^      deep +2 +0 +0 +0 +0 +0 +2$' "$FIXTURE/depth-2"
grep -Eq '^      check +0 +1 +0 +0 +0 +0 +1$' "$FIXTURE/depth-2"
if grep -q '^        leaf ' "$FIXTURE/depth-2"; then exit 1; fi
grep -Eq '^        leaf +1 +0 +0 +0 +0 +0 +1$' "$FIXTURE/depth-3"
cmp "$FIXTURE/depth-3" "$FIXTURE/depth-999999"
# foo.rs plus foo/ is equivalent to foo/mod.rs plus foo/.
mv "$depth_root/src/foo/mod.rs" "$depth_root/src/foo.rs"
bash "$ROOT/scripts/dev/cloc.sh" -d 3 --manifest "$depth_root/Cargo.toml" "$depth_root" > "$FIXTURE/depth-file"
cmp "$FIXTURE/depth-3" "$FIXTURE/depth-file"
for invalid in -1 1.5 nope 01 1000000 ''; do
    if bash "$ROOT/scripts/dev/cloc.sh" -d "$invalid" "$depth_root" > "$FIXTURE/invalid-depth" 2>&1; then exit 1; fi
done
if bash "$ROOT/scripts/dev/cloc.sh" -d > "$FIXTURE/invalid-depth" 2>&1; then exit 1; fi
# Named selection resolves Cargo members and reuses the same module tree/counts.
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$FIXTURE/Cargo.toml" app > "$FIXTURE/selected-app.json"
jq -e '(.crates | length) == 1 and .crates[0].crate == "app" and all(.files[]; .crate == "app")' "$FIXTURE/selected-app.json" >/dev/null
bash "$ROOT/scripts/dev/cloc.sh" -d 1 --manifest "$depth_root/Cargo.toml" depth-fixture > "$FIXTURE/selected-crate"
grep -Eq '^depth-fixture +5 +3 +0 +0 +0 +0 +8$' "$FIXTURE/selected-crate"
grep -Eq '^  foo +3 +0 +0 +0 +0 +0 +3$' "$FIXTURE/selected-crate"
bash "$ROOT/scripts/dev/cloc.sh" -d 1 --manifest "$depth_root/Cargo.toml" depth-fixture::foo > "$FIXTURE/selected-module"
grep -Eq '^depth-fixture::foo +3 +0 +0 +0 +0 +0 +3$' "$FIXTURE/selected-module"
grep -Eq '^  deep +2 +0 +0 +0 +0 +0 +2$' "$FIXTURE/selected-module"
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$depth_root/Cargo.toml" depth-fixture::tests > "$FIXTURE/selected-tests.json"
jq -e '.totals.tests == 2 and (.files | length) == 2' "$FIXTURE/selected-tests.json" >/dev/null
for selector in missing-crate depth-fixture::missing depth-fixture::; do
    if bash "$ROOT/scripts/dev/cloc.sh" --manifest "$depth_root/Cargo.toml" "$selector" > "$FIXTURE/bad-selection" 2>&1; then exit 1; fi
done
# Deep inline modules and ordinary blocks must not exhaust Perl's call stack.
perl -e 'print "mod nested {\n" x 150; print "fn deep() {\n", "{\n" x 150;
    print "#[cfg(test)] mod tests { #[test] fn unit() {} }\n";
    print "}\n" x 301' > "$depth_root/src/deep.rs"
printf 'mod deep;\n' >> "$depth_root/src/lib.rs"
bash "$ROOT/scripts/dev/cloc.sh" --json --manifest "$depth_root/Cargo.toml" "$depth_root" > "$FIXTURE/deep.json" 2> "$FIXTURE/deep.err"
[[ ! -s "$FIXTURE/deep.err" ]]
jq -e '[.files[] | select(.path | endswith("/src/deep.rs"))][0].counts | .tests == 1 and .library_app == 602 and .total == 603' "$FIXTURE/deep.json" >/dev/null
echo 'LOC classification, source totals and module depth fixtures passed'
fixture_complete=true
