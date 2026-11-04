#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh
set -euo pipefail

ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# Synthetic workspaces own their output paths, not the enclosing consumer.
unset CARGO_TARGET_DIR
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-tooling-cloc-siblings-test.XXXXXX")"
FIXTURE="$(CDPATH="" cd -P -- "$FIXTURE" && printf '%s/.' "$PWD")"
FIXTURE="${FIXTURE%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE" "Failed sibling LOC fixture retained"' EXIT

parent="$FIXTURE/parent [projects]"
alpha="$parent/alpha repo [copy]"
zeta="$parent/zeta"
mkdir -p "$alpha/crates/library/src" "$alpha/apps/demo/service/src" \
    "$alpha/apps/demo/service/tests" "$alpha/.cargo" "$parent/.notes" \
    "$parent/not-a-repository" "$FIXTURE/gitdirs" "$FIXTURE/elsewhere"
git init -q "$alpha"
git init -q "$parent/.notes"
git init -q --separate-git-dir "$FIXTURE/gitdirs/zeta" "$zeta"
ln -s "$alpha" "$parent/alias"

cat >"$alpha/Cargo.toml" <<'TOML'
[workspace]
members = ["crates/library", "apps/demo/service"]
resolver = "2"
TOML
for spec in 'crates/library library' 'apps/demo/service service'; do
    read -r path name <<<"$spec"
    cat >"$alpha/$path/Cargo.toml" <<TOML
[package]
name = "$name"
version = "0.1.0"
edition = "2021"
TOML
done
cat >"$alpha/crates/library/src/lib.rs" <<'RUST'
pub fn library() -> u8 { 1 }
#[test]
fn inline_test() {}
RUST
printf 'pub fn application() {}\n' >"$alpha/apps/demo/service/src/lib.rs"
printf '#[test]\nfn smoke() {}\n' >"$alpha/apps/demo/service/tests/smoke.rs"
cat >"$alpha/.cargo/config.toml" <<'TOML'
[build]
target-dir = "crates/library/build [generated]"
TOML
mkdir -p "$alpha/crates/library/build [generated]/tests"
printf '#[test]\nfn generated() {}\n' >"$alpha/crates/library/build [generated]/tests/generated.rs"
(cd "$alpha" && cargo generate-lockfile --offline)
cp "$alpha/Cargo.lock" "$FIXTURE/alpha.lock"
cat >"$alpha/Makefile" <<'MAKE'
$(error repository Make targets must not run during reporting)
MAKE

cat >"$zeta/Cargo.toml" <<'TOML'
[package]
name = "zeta"
version = "0.1.0"
edition = "2021"

[workspace]
TOML
mkdir -p "$zeta/src" "$zeta/scripts/dev" "$zeta/.cargo"
printf '[build]\ntarget-dir = "target"\n' > "$zeta/.cargo/config.toml"
printf '#[test]\nfn another_test() {}\n' >"$zeta/src/lib.rs"
cp "$ROOT/scripts/dev/cloc.sh" "$zeta/scripts/dev/"

# Reject line breaks before they can select the ordinary parent as a decoy.
for suffix in $'\n' $'\r'; do
    invalid_parent="$parent$suffix"
    mkdir -p "$invalid_parent"
    printf '[workspace]\n' > "$invalid_parent/Cargo.toml"
    ln -s "$invalid_parent" "$FIXTURE/invalid-alias"
    for selected in "$invalid_parent" "$FIXTURE/invalid-alias"; do
        if bash "$ROOT/scripts/dev/cloc.sh" "$selected" > "$FIXTURE/path.out" 2> "$FIXTURE/path.err"; then
            echo 'line-break directory was accepted' >&2; exit 1
        fi
        [[ ! -s "$FIXTURE/path.out" ]] || exit 1
        grep -F 'line breaks' "$FIXTURE/path.err" >/dev/null
        if bash "$ROOT/scripts/dev/cloc.sh" --manifest "$selected/Cargo.toml" \
            > "$FIXTURE/path.out" 2> "$FIXTURE/path.err"; then exit 1; fi
        [[ ! -s "$FIXTURE/path.out" ]] || exit 1
        grep -F 'line breaks' "$FIXTURE/path.err" >/dev/null
    done
    rm "$FIXTURE/invalid-alias"
done

output="$(bash "$ROOT/scripts/dev/cloc.sh" "$parent")"
[[ "$(bash "$ROOT/scripts/dev/cloc.sh" "$parent")" == "$output" ]] || exit 1
expanded="$(bash "$ROOT/scripts/dev/cloc.sh" --subcrates "$parent")"
[[ "$(printf '%s\n' "$expanded" | awk '$1 == "library" { print $2 }')" == 3 ]] || exit 1
[[ "$(printf '%s\n' "$expanded" | tail -1)" == "$(printf '%s\n' "$output" | tail -1)" ]] || exit 1
make_output="$(make --no-print-directory -s -f "$ROOT/make/tools.mk" cloc \
    SHARED_TOOLING_ROOT="$ROOT" CLOC_ROOT="$parent" CLOC_SUBCRATES=1)"
[[ "$make_output" == "$expanded" ]] || exit 1
# A long crate in the later repository must widen every row, including earlier
# workspace summaries, N/A rows, headers and totals, without changing counts.
long_name=icydb-testing-audit-default-empty-fixtures
sed "s/name = \"zeta\"/name = \"$long_name\"/" "$zeta/Cargo.toml" > "$FIXTURE/long.toml"
cp "$zeta/Cargo.toml" "$FIXTURE/zeta.toml"
cp "$FIXTURE/long.toml" "$zeta/Cargo.toml"
wide="$(bash "$ROOT/scripts/dev/cloc.sh" --subcrates "$parent")"
printf '%s\n' "$wide" | awk -v width="$((${#long_name} + 2))" '
    NR == 1 { expected = length($0) }
    length($0) != expected { exit 1 }
    substr($0, width + 1, 1) != " " { exit 1 }
    END { if (expected != width + 58) exit 1 }
' || exit 1
[[ "$(printf '%s\n' "$wide" | awk 'END { print $1,$2,$3,$4,$5,$6 }')" == 'TOTAL 6 2 25.0% 3 2' ]] || exit 1
cp "$FIXTURE/zeta.toml" "$zeta/Cargo.toml"
# Absolute operands prevent CDPATH output from becoming part of the parent.
relative_output="$(cd "$FIXTURE" && CDPATH="$FIXTURE" bash "$ROOT/scripts/dev/cloc.sh" 'parent [projects]')"
[[ "$relative_output" == "$output" ]] || exit 1
ln -s "$parent" "$FIXTURE/valid-alias"
alias_output="$(bash "$ROOT/scripts/dev/cloc.sh" "$FIXTURE/valid-alias")"
[[ "$alias_output" == "$output" ]] || exit 1
[[ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" == 7 ]] || exit 1
[[ "$(printf '%s\n' "$output" | awk 'NR == 3 { print $1, $2, $3, $4, $5, $6 }')" == '.notes N/A N/A N/A N/A N/A' ]] || exit 1
[[ "$(printf '%s\n' "$output" | awk 'NR == 4 { print $(NF-4), $(NF-3), $(NF-2), $(NF-1), $NF }')" == '4 2 33.3% 2 1' ]] || exit 1
[[ "$(printf '%s\n' "$output" | awk 'NR == 5 { print $1, $2, $3, $4, $5, $6 }')" == 'zeta 2 0 0.0% 1 1' ]] || exit 1
# Percentages are recomputed from combined LOC, not averaged from repository rows.
[[ "$(printf '%s\n' "$output" | awk 'END { print $1, $2, $3, $4, $5, $6 }')" == 'TOTAL 6 2 25.0% 3 2' ]] || exit 1
[[ -f "$zeta/.git" && ! -e "$zeta/Cargo.lock" ]] || exit 1
cmp "$alpha/Cargo.lock" "$FIXTURE/alpha.lock"

# The default target is the caller's current directory.
default_output="$(cd "$parent" && bash "$zeta/scripts/dev/cloc.sh")"
[[ "$default_output" == "$output" ]] || exit 1

# A missing shared prerequisite fails once, before printing a misleading table.
# Use the copied scripts so this checkout's installed tools cannot mask absence.
mkdir "$FIXTURE/no-cloc"
for tool in bash dirname git cargo jq; do
    ln -s "$(command -v "$tool")" "$FIXTURE/no-cloc/$tool"
done
if PATH="$FIXTURE/no-cloc" "$BASH" "$zeta/scripts/dev/cloc.sh" "$parent" \
    >"$FIXTURE/missing.out" 2>"$FIXTURE/missing.err"; then
    echo 'missing cloc was accepted' >&2
    exit 1
fi
[[ ! -s "$FIXTURE/missing.out" && "$(grep -c 'missing LOC tools: cloc' "$FIXTURE/missing.err")" == 1 ]] || exit 1
grep -F 'make install-host-tools' "$FIXTURE/missing.err" >/dev/null
# Explicit installation beside the report supplies cloc without a PATH export.
mkdir -p "$zeta/.tools/host/bin"
ln -s "$(command -v cloc)" "$zeta/.tools/host/bin/cloc"
PATH="$FIXTURE/no-cloc" "$BASH" "$zeta/scripts/dev/cloc.sh" --check-tools

# A broken workspace reports failure without hiding later successful rows.
git init -q "$parent/middle-broken"
printf '[workspace\n' >"$parent/middle-broken/Cargo.toml"
if bash "$ROOT/scripts/dev/cloc.sh" "$parent" >"$FIXTURE/failed.out" 2>"$FIXTURE/failed.err"; then
    echo 'broken Cargo workspace was reported as successful' >&2
    exit 1
fi
[[ "$(awk '$1 == "middle-broken" { print $2, $3, $4, $5, $6 }' "$FIXTURE/failed.out")" == 'ERROR ERROR ERROR ERROR ERROR' ]] || exit 1
[[ "$(awk '$1 == "zeta" { print $2, $3, $4, $5, $6 }' "$FIXTURE/failed.out")" == '2 0 0.0% 1 1' ]] || exit 1
[[ "$(awk 'END { print $1, $2, $3, $4, $5, $6, $7 }' "$FIXTURE/failed.out")" == 'TOTAL (partial) 6 2 25.0% 3 2' ]] || exit 1
grep -F "$parent/middle-broken" "$FIXTURE/failed.err" >/dev/null
cmp "$alpha/Cargo.lock" "$FIXTURE/alpha.lock"

# No measured workspace remains distinct from a measured empty Rust package.
mkdir "$FIXTURE/no-rust"
git init -q "$FIXTURE/no-rust/notes"
output="$(bash "$ROOT/scripts/dev/cloc.sh" "$FIXTURE/no-rust")"
[[ "$(printf '%s\n' "$output" | awk 'END { print $0 }')" =~ TOTAL[[:space:]]+N/A[[:space:]]+N/A[[:space:]]+N/A[[:space:]]+N/A[[:space:]]+N/A$ ]] || exit 1
mkdir -p "$FIXTURE/empty-rust/empty/src"
git init -q "$FIXTURE/empty-rust/empty"
cp "$zeta/Cargo.toml" "$FIXTURE/empty-rust/empty/Cargo.toml"
cp -R "$zeta/.cargo" "$FIXTURE/empty-rust/empty/"
: > "$FIXTURE/empty-rust/empty/src/lib.rs"
output="$(bash "$ROOT/scripts/dev/cloc.sh" "$FIXTURE/empty-rust")"
[[ "$(printf '%s\n' "$output" | awk 'END { print $1, $2, $3, $4, $5, $6 }')" == 'TOTAL 0 0 0.0% 0 0' ]] || exit 1

bash "$ROOT/scripts/dev/cloc.sh" --help >/dev/null
for path in "$FIXTURE/absent" "$FIXTURE/elsewhere"; do
    if bash "$ROOT/scripts/dev/cloc.sh" "$path" >"$FIXTURE/invalid.out" 2>"$FIXTURE/invalid.err"; then
        echo 'invalid or empty parent was accepted' >&2
        exit 1
    fi
done

echo 'sibling cloc tests passed'
fixture_complete=true
