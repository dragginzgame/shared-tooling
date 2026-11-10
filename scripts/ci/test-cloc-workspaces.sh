#!/usr/bin/env bash
# Shared companions: scripts/dev/cloc.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
export PATH="$ROOT/.tools/host/bin:$PATH"
unset CARGO_TARGET_DIR
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
mkdir -p "$ROOT/target/fixtures"
FIXTURE="$(fixture_create "$ROOT/target/fixtures/cloc-workspaces.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE" "LOC workspace fixtures retained"' EXIT
export TMPDIR="$FIXTURE/scratch"
mkdir -p "$TMPDIR" "$FIXTURE/repos/example/src" "$FIXTURE/repos/example/qualification/domain/probe/src"
repo="$FIXTURE/repos/example"
git init -q "$repo"
cat > "$repo/Cargo.toml" <<'TOML'
[package]
name = "same-name"
version = "0.1.0"
[workspace]
exclude = ["qualification"]
[[test]]
name = "shared"
path = "shared.rs"
TOML
printf 'pub fn example() {}\n' > "$repo/src/lib.rs"
printf '#[test] fn shared() {}\n' > "$repo/shared.rs"
cat > "$repo/qualification/Cargo.toml" <<'TOML'
[workspace]
members = ["domain/probe"]
TOML
cat > "$repo/qualification/domain/probe/Cargo.toml" <<'TOML'
[package]
name = "same-name"
version = "0.8.0"
publish = false
[package.metadata.toko-tooling.loc]
category = "tests"
[[test]]
name = "shared"
path = "../../../shared.rs"
TOML
cp "$repo/src/lib.rs" "$repo/qualification/domain/probe/src/lib.rs"
(cd "$repo" && cargo generate-lockfile --offline)
(cd "$repo/qualification" && cargo generate-lockfile --offline)
cp "$repo/Cargo.lock" "$FIXTURE/product.lock"
cp "$repo/qualification/Cargo.lock" "$FIXTURE/qualification.lock"
reporter="$ROOT/scripts/dev/cloc.sh"
bash "$reporter" --json "$repo" > "$FIXTURE/combined.json"
jq -e '.scope == "repository" and (.manifests | length) == 2 and
    .totals.total == 3 and .totals.library_app == 1 and .totals.tests == 2 and
    (.files | length) == 3 and
    ([.crates[].crate] == ["same-name","qualification/same-name"]) and
    ([.crates[].counts.total] == [2,1]) and
    ([.files[] | select(.path | endswith("/shared.rs"))] | length) == 1 and
    ([.files[] | select(.path | endswith("/shared.rs"))][0].shared == true)' "$FIXTURE/combined.json" > /dev/null
bash "$reporter" -d 1 "$repo" > "$FIXTURE/depth"
grep -q 'qualification/same-name' "$FIXTURE/depth"
bash "$reporter" "$FIXTURE/repos" > "$FIXTURE/parent"
awk '$1 == "example" {if ($NF != 3) exit 1; found=1} END {if(!found) exit 1}' "$FIXTURE/parent"
for manifest in "$repo/Cargo.toml" "$repo/qualification/Cargo.toml"; do
    bash "$reporter" --json --manifest "$manifest" "$repo" > "$FIXTURE/selected.json"
    jq -e '.totals.total == 2 and (.crates | length) == 1 and .scope == null' "$FIXTURE/selected.json" > /dev/null
done
(cd "$repo" && bash "$reporter" --json same-name) > "$FIXTURE/crate.json"
jq -e '.totals.total == 2 and .selection == "same-name"' "$FIXTURE/crate.json" > /dev/null
cmp "$repo/Cargo.lock" "$FIXTURE/product.lock"
cmp "$repo/qualification/Cargo.lock" "$FIXTURE/qualification.lock"
# Two scans observing different bytes must not silently discard either version.
bash "$reporter" --json --manifest "$repo/Cargo.toml" > "$FIXTURE/product.json"
bash "$reporter" --json --manifest "$repo/qualification/Cargo.toml" > "$FIXTURE/qualification.json"
jq '(.files[] | select(.path | endswith("/shared.rs")) | .source_sha256) = "changed"' \
    "$FIXTURE/qualification.json" > "$FIXTURE/changed.json"
if perl "$ROOT/scripts/dev/cloc-classify.pl" --merge-repository "$FIXTURE/product.json" "$FIXTURE/changed.json" \
    > "$FIXTURE/rejected.json" 2> "$FIXTURE/changed.err"; then exit 1; fi
[[ ! -s "$FIXTURE/rejected.json" ]]
grep -q 'shared source changed' "$FIXTURE/changed.err"
# Broken qualification must fail the repository, not produce a healthy root-only total.
printf '\n[broken\n' >> "$repo/qualification/Cargo.toml"
if bash "$reporter" --json "$repo" > "$FIXTURE/failed.json" 2> "$FIXTURE/failed.err"; then exit 1; fi
[[ ! -s "$FIXTURE/failed.json" ]]
if bash "$reporter" "$FIXTURE/repos" > "$FIXTURE/partial" 2> "$FIXTURE/partial.err"; then exit 1; fi
grep -q 'ERROR' "$FIXTURE/partial"
grep -q 'TOTAL (partial)' "$FIXTURE/partial"
# Explicit product checks still work despite the independent workspace failure.
bash "$reporter" --json --manifest "$repo/Cargo.toml" > "$FIXTURE/root-only.json"
jq -e '.totals.total == 2' "$FIXTURE/root-only.json" > /dev/null
fixture_complete=true
printf 'Repository LOC workspace aggregation fixtures passed\n'
