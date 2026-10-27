#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/dev/stack-graph.pl
set -euo pipefail
ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
FIXTURE="$(fixture_create "${TMPDIR:-/tmp}/stack-graph.XXXXXX")"
fixture_complete=false
finish() {
    local status=$?
    if [[ "$status" != 0 || "$fixture_complete" != true ]]; then
        fixture_replay_logs "$FIXTURE/command.log"
    fi
    fixture_finish "$status" "$FIXTURE" "Stack graph fixture retained"
}
trap finish EXIT

parent="$FIXTURE/sibling checkouts"
output="$FIXTURE/report"
mkdir -p "$output/docs"
for file in "$output/README.md" "$output/docs/stack.md"; do
    printf 'Retain handwritten prose.\n<!-- stack-graph:start -->\n<!-- stack-graph:end -->\n' > "$file"
done
for name in app engine platform unused ic-tooling; do
    directory="$parent/$name"
    mkdir -p "$directory/crates/$name/src"
    printf '[workspace]\nmembers=["crates/%s"]\nresolver="2"\n' "$name" > "$directory/Cargo.toml"
    printf '[package]\nname="%s"\nversion="0.1.0"\nedition="2021"\n' "$name" > "$directory/crates/$name/Cargo.toml"
    : > "$directory/crates/$name/src/lib.rs"
done
cat >> "$parent/app/Cargo.toml" <<'TOML'
[workspace.dependencies]
renamed_engine = { package = "engine", path = "../engine/crates/engine" }
# Unused catalog declarations must not become dependency edges.
unused = { path = "../unused/crates/unused" }
TOML
cat >> "$parent/app/crates/app/Cargo.toml" <<'TOML'
[dependencies]
renamed_engine.workspace = true
platform = { path = "../../../platform/crates/platform", optional = true }
ic-tooling = { path = "../../../ic-tooling/crates/ic-tooling" }
[dev-dependencies]
unused = { path = "../../../unused/crates/unused" }
legacy-bridge = { git = "https://github.com/dragginzgame/engine", rev = "0000000000000000000000000000000000000000" }
TOML
cat >> "$parent/ic-tooling/crates/ic-tooling/Cargo.toml" <<'TOML'
[dependencies]
platform = { path = "../../../platform/crates/platform" }
TOML
# An excluded fixture's ordinary dependencies must not enter the product view.
mkdir -p "$parent/app/crates/fixture/src"
: > "$parent/app/crates/fixture/src/lib.rs"
cat > "$parent/app/crates/fixture/Cargo.toml" <<'TOML'
[package]
name = "fixture"
version = "0.1.0"
edition = "2021"
[dependencies]
unused = { path = "../../../unused/crates/unused" }
TOML
sed 's/members=\["crates\/app"\]/members=["crates\/app", "crates\/fixture"]/' "$parent/app/Cargo.toml" > "$FIXTURE/app-members"
cp "$FIXTURE/app-members" "$parent/app/Cargo.toml"
mkdir -p "$parent/engine/crates/engine-cli/src"
: > "$parent/engine/crates/engine-cli/src/lib.rs"
cat > "$parent/engine/crates/engine-cli/Cargo.toml" <<'TOML'
[package]
name = "engine-cli"
version = "0.1.0"
edition = "2021"
[dependencies]
app = { path = "../../../app/crates/app" }
TOML
sed 's/members=\["crates\/engine"\]/members=["crates\/engine", "crates\/engine-cli"]/' "$parent/engine/Cargo.toml" > "$FIXTURE/engine-members"
cp "$FIXTURE/engine-members" "$parent/engine/Cargo.toml"
cat >> "$parent/engine/crates/engine/Cargo.toml" <<'TOML'
[target.'cfg(target_arch = "wasm32")'.dependencies]
platform = { path = "../../../platform/crates/platform", optional = true }
TOML
for name in app platform; do mkdir -p "$parent/$name/browser"; done
printf '{"name":"app-browser","dependencies":{"@fleet/platform":"1"}}\n' > "$parent/app/browser/package.json"
printf '{"name":"@fleet/platform"}\n' > "$parent/platform/browser/package.json"
cat > "$FIXTURE/catalog.json" <<'JSON'
{"roots":["app"],"repositories":[
  {"name":"app","branch":"development","paths":["crates"],"exclude":["crates/fixture"],"npm":["browser/package.json"]},
  {"name":"engine","paths":["crates"],"native":["crates/engine-cli"]},
  {"name":"platform","paths":["crates"],"npm":["browser/package.json"]},
  {"name":"unused","paths":["crates"]},
  {"name":"ic-tooling","paths":["crates"]}
]}
JSON
graph() {
    perl "$ROOT/scripts/dev/stack-graph.pl" --parent "$parent" \
        --catalog "$FIXTURE/catalog.json" --output-root "$output" "$@" > "$FIXTURE/command.log" 2>&1
}
# Inherited aliases, optional/target-specific dependencies, npm owners, and a
# dev-only dependency are classified using real Cargo metadata, without builds.
graph --write
graph --check
grep -Fq 'r_app --> r_engine' "$output/README.md"
grep -Fq 'r_engine --> r_platform' "$output/README.md"
grep -Fq 'r_app -.-> r_ic_tooling' "$output/README.md"
grep -Fq 'r_ic_tooling -.-> r_platform' "$output/README.md"
grep -Fq 'r_engine -.-> r_app' "$output/README.md"
if grep -Eq 'r_app --> r_platform|r_unused' "$output/README.md"; then
    echo 'graph retained a redundant arrow or promoted a dev-only owner' >&2; exit 1
fi
# shellcheck disable=SC2016 # Match literal Markdown code spans.
grep -Fq '→ `engine` (cargo normal)' "$output/docs/stack.md"
grep -Fq 'target-specific' "$output/docs/stack.md"
# shellcheck disable=SC2016
grep -Fq '→ `legacy-bridge` (cargo dev)' "$output/docs/stack.md"
# shellcheck disable=SC2016
grep -Fq '→ `unused` (cargo dev)' "$output/docs/stack.md"
# shellcheck disable=SC2016
grep -Fq '→ `@fleet/platform` (npm normal' "$output/docs/stack.md"
grep -Fq 'Retain handwritten prose.' "$output/docs/stack.md"
grep -Fq '/app/blob/development/crates/app/Cargo.toml' "$output/docs/stack.md"
if grep -Fq '/crates/fixture/' "$output/docs/stack.md"; then
    echo 'excluded fixture included in report' >&2; exit 1
fi
cp "$output/README.md" "$FIXTURE/saved-readme"
cp "$output/docs/stack.md" "$FIXTURE/saved-details"
graph --write
cmp "$FIXTURE/saved-readme" "$output/README.md"
cmp "$FIXTURE/saved-details" "$output/docs/stack.md"

# Changed declarations make --check fail without changing either output.
printf '\n[build-dependencies]\nengine = { path = "../../../engine/crates/engine" }\n' >> "$parent/platform/crates/platform/Cargo.toml"
if graph --check; then echo 'stale graph accepted' >&2; exit 1; fi
grep -Fq 'Stack graph is stale' "$FIXTURE/command.log"
cmp "$FIXTURE/saved-readme" "$output/README.md"
cmp "$FIXTURE/saved-details" "$output/docs/stack.md"
graph --write
grep -Fq 'platform → engine' "$output/docs/stack.md"

# A missing final checkout cannot leave a partial publication of earlier inputs.
cp "$output/README.md" "$FIXTURE/saved-readme"
cp "$output/docs/stack.md" "$FIXTURE/saved-details"
mv "$parent/unused" "$parent/unused.saved"
if graph --write; then echo 'missing checkout accepted' >&2; exit 1; fi
grep -Fq 'Missing checkout: unused' "$FIXTURE/command.log"
cmp "$FIXTURE/saved-readme" "$output/README.md"
cmp "$FIXTURE/saved-details" "$output/docs/stack.md"
mv "$parent/unused.saved" "$parent/unused"

# Do not destroy reachability by reducing a graph containing a normal cycle.
sed 's/\[build-dependencies\]/[dependencies]/' "$parent/platform/crates/platform/Cargo.toml" > "$FIXTURE/cyclic-manifest"
cp "$FIXTURE/cyclic-manifest" "$parent/platform/crates/platform/Cargo.toml"
graph --write
grep -Fq 'r_engine --> r_platform' "$output/README.md"
grep -Fq 'r_platform --> r_engine' "$output/README.md"
grep -Fq 'r_app --> r_platform' "$output/README.md"

# A broken second output must not publish an already prepared README change.
cp "$output/README.md" "$FIXTURE/saved-readme"
printf 'Missing generated markers.\n' > "$output/docs/stack.md"
if graph --write; then echo 'missing output markers accepted' >&2; exit 1; fi
grep -Fq 'Expected one generated block' "$FIXTURE/command.log"
cmp "$FIXTURE/saved-readme" "$output/README.md"

cp "$FIXTURE/saved-details" "$output/docs/stack.md"
mkdir -p "$parent/unused/browser"
cp "$parent/platform/browser/package.json" "$parent/unused/browser/package.json"
perl -MJSON::PP -e 'local $/; my $c=decode_json(<>); for (@{$c->{repositories}}) { $_->{npm}=["browser/package.json"] if $_->{name} eq "unused" } print encode_json($c)' \
    "$FIXTURE/catalog.json" > "$FIXTURE/ambiguous.json"
cp "$FIXTURE/ambiguous.json" "$FIXTURE/catalog.json"
if graph --write; then echo 'ambiguous dependency owner accepted' >&2; exit 1; fi
grep -Fq 'Ambiguous owner for npm dependency' "$FIXTURE/command.log"
cmp "$FIXTURE/saved-readme" "$output/README.md"

fixture_complete=true
printf 'Stack graph metadata, evidence, reduction, stale-check and failure cases passed\n'
