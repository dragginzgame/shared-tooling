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
mkdir -p "$output/docs/fleet"
for file in "$output/docs/fleet/overview.md" "$output/docs/fleet/stack.md"; do
    printf 'Retain handwritten prose.\n<!-- stack-graph:start -->\n<!-- stack-graph:end -->\n' > "$file"
done
for name in app engine platform unused ic-tooling; do
    directory="$parent/$name"
    package="$name"
    [[ "$name" != ic-tooling ]] || package=ic-build
    mkdir -p "$directory/crates/$package/src"
    printf '[workspace]\nmembers=["crates/%s"]\nresolver="2"\n' "$package" > "$directory/Cargo.toml"
    printf '[package]\nname="%s"\nversion="0.1.0"\nedition="2021"\n' "$package" > "$directory/crates/$package/Cargo.toml"
    : > "$directory/crates/$package/src/lib.rs"
done
# An unselected test package can reuse an application's name in another repo.
# It must neither replace the application's node nor make an unused name ambiguous.
mkdir -p "$parent/unused/testing/memory-client/src"
: > "$parent/unused/testing/memory-client/src/lib.rs"
printf '[package]\nname="memory-client"\nversion="0.1.0"\nedition="2021"\n' > "$parent/unused/testing/memory-client/Cargo.toml"
printf '[workspace]\nmembers=["crates/unused", "testing/memory-client"]\nresolver="2"\n' > "$parent/unused/Cargo.toml"
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
ic-build = { path = "../../../ic-tooling/crates/ic-build" }
[dev-dependencies]
unused = { path = "../../../unused/crates/unused" }
legacy-bridge = { git = "https://github.com/dragginzgame/engine", rev = "0000000000000000000000000000000000000000" }
TOML
cat >> "$parent/ic-tooling/crates/ic-build/Cargo.toml" <<'TOML'
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
[dependencies]
engine-core = { path = "../engine-core" }
[target.'cfg(target_arch = "wasm32")'.dependencies]
platform = { path = "../../../platform/crates/platform", optional = true }
TOML
# Two crates in one workspace are independent dependencies. A consumer of only
# memory must not inherit storage or the unrelated native CLI's dependencies.
for package in memory storage engine-core; do
    mkdir -p "$parent/engine/crates/$package/src"
    : > "$parent/engine/crates/$package/src/lib.rs"
    printf '[package]\nname="%s"\nversion="0.1.0"\nedition="2021"\n' "$package" > "$parent/engine/crates/$package/Cargo.toml"
done
printf '\n[dependencies]\nmemory = { path = "../memory" }\n' >> "$parent/engine/crates/storage/Cargo.toml"
printf '\n[dependencies]\nstorage = { path = "../storage" }\n' >> "$parent/engine/crates/engine-core/Cargo.toml"
sed 's/"crates\/engine-cli"/"crates\/engine-cli", "crates\/memory", "crates\/storage", "crates\/engine-core"/' "$parent/engine/Cargo.toml" > "$FIXTURE/engine-members"
cp "$FIXTURE/engine-members" "$parent/engine/Cargo.toml"
mkdir -p "$parent/app/crates/memory-client/src"
: > "$parent/app/crates/memory-client/src/lib.rs"
cat > "$parent/app/crates/memory-client/Cargo.toml" <<'TOML'
[package]
name = "memory-client"
version = "0.1.0"
edition = "2021"
[dependencies]
memory = { path = "../../../engine/crates/memory" }
TOML
sed 's/"crates\/fixture"/"crates\/fixture", "crates\/memory-client"/' "$parent/app/Cargo.toml" > "$FIXTURE/app-members"
cp "$FIXTURE/app-members" "$parent/app/Cargo.toml"
for name in app platform; do mkdir -p "$parent/$name/browser"; done
printf '{"name":"app-browser","dependencies":{"@fleet/platform":"1"}}\n' > "$parent/app/browser/package.json"
printf '{"name":"@fleet/platform"}\n' > "$parent/platform/browser/package.json"
cat > "$FIXTURE/catalog.json" <<'JSON'
{"roots":["app"],"overview":["engine","storage","memory","platform"],"repositories":[
  {"name":"app","branch":"development","paths":["crates"],"exclude":["crates/fixture"],"npm":["browser/package.json"]},
  {"name":"engine","paths":["crates"],"native":["crates/engine-cli"]},
  {"name":"platform","paths":["crates"],"npm":["browser/package.json"]},
  {"name":"unused","paths":["crates"]},
  {"name":"ic-tooling","paths":["crates"]}
]}
JSON
mkdir -p "$parent/engine/ci" "$parent/engine/releases"
printf '# Engine\n' > "$parent/engine/releases/engine.md"
printf '# Storage\n' > "$parent/engine/releases/storage.md"
cat > "$parent/engine/ci/cargo-release-groups.json" <<'JSON'
{"schema":1,"groups":[
  {"name":"engine","primary":"engine","members":["engine","engine-core","engine-cli"],"changelog":"releases/engine.md"},
  {"name":"storage","primary":"storage","members":["storage","memory"],"changelog":"releases/storage.md"}
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
grep -Fq 'p_app_7ccargo_3aapp --> p_engine_7ccargo_3aengine' "$output/docs/fleet/stack.md"
grep -Fq 'p_engine_7ccargo_3aengine -. "normal, conditional" .-> p_platform_7ccargo_3aplatform' "$output/docs/fleet/stack.md"
grep -Fq 'p_app_7ccargo_3aapp -. "normal, native" .-> p_ic_2dtooling_7ccargo_3aic_2dbuild' "$output/docs/fleet/stack.md"
grep -Fq 'p_ic_2dtooling_7ccargo_3aic_2dbuild -. "normal, native" .-> p_platform_7ccargo_3aplatform' "$output/docs/fleet/stack.md"
grep -Fq 'p_engine_7ccargo_3aengine --> p_engine_7ccargo_3aengine_2dcore' "$output/docs/fleet/stack.md"
grep -Fq 'p_engine_7ccargo_3aengine_2dcore --> p_engine_7ccargo_3astorage' "$output/docs/fleet/stack.md"
grep -Fq 'p_engine_7ccargo_3astorage --> p_engine_7ccargo_3amemory' "$output/docs/fleet/stack.md"
grep -Fq 'p_app_7ccargo_3amemory_2dclient --> p_engine_7ccargo_3amemory' "$output/docs/fleet/stack.md"
grep -Fq 'p_app_7cnpm_3aapp_2dbrowser --> p_platform_7cnpm_3a_40fleet_2fplatform' "$output/docs/fleet/stack.md"
if grep -Eq 'p_app_7ccargo_3aapp --> p_platform_7ccargo_3aplatform|p_app_7ccargo_3aapp --> p_unused_7ccargo_3aunused|p_app_7ccargo_3amemory_2dclient --> p_engine_7ccargo_3astorage' "$output/docs/fleet/stack.md"; then
    echo 'graph invented a workspace dependency or retained a redundant arrow' >&2; exit 1
fi
# The overview groups application packages, contracts through hidden internals,
# and omits native/browser plumbing without merging distinct storage crates.
grep -Fq 'p_app_3aapp(["app"])' "$output/docs/fleet/overview.md"
grep -Fq 'p_app_3aapp --> p_engine_7ccargo_3aengine' "$output/docs/fleet/overview.md"
grep -Fq 'p_engine_7ccargo_3aengine --> p_engine_7ccargo_3astorage' "$output/docs/fleet/overview.md"
grep -Fq 'p_engine_7ccargo_3astorage --> p_engine_7ccargo_3amemory' "$output/docs/fleet/overview.md"
if grep -Eq 'engine-core|engine-cli|ic-build|app-browser|memory-client|p_app_3aapp --> p_platform_7ccargo_3aplatform' "$output/docs/fleet/overview.md"; then
    echo 'overview expanded internals or retained a redundant arrow' >&2; exit 1
fi
grep -Fq 'storage → memory' "$output/docs/fleet/stack.md"
grep -Fq 'engine-cli → app' "$output/docs/fleet/stack.md"
grep -Fq 'app → legacy-bridge (pinned Git)' "$output/docs/fleet/stack.md"
# shellcheck disable=SC2016 # Match literal Markdown code spans.
grep -Fq '→ `engine` (cargo normal)' "$output/docs/fleet/stack.md"
grep -Fq 'target-specific' "$output/docs/fleet/stack.md"
grep -Fq 'target=cfg(target_arch = "wasm32")' "$output/docs/fleet/stack.md"
grep -Fq 'declared source=path:engine/crates/engine' "$output/docs/fleet/stack.md"
grep -Fq 'Generated and independent qualification workspaces are unobserved' "$output/docs/fleet/stack.md"
grep -Fq 'p_app_7ccargo_3aapp -. "dev" .-> p_unused_7ccargo_3aunused' "$output/docs/fleet/stack.md"
# shellcheck disable=SC2016
grep -Fq '→ `legacy-bridge` (cargo dev)' "$output/docs/fleet/stack.md"
# shellcheck disable=SC2016
grep -Fq '→ `unused` (cargo dev)' "$output/docs/fleet/stack.md"
# shellcheck disable=SC2016
grep -Fq '→ `@fleet/platform` (npm normal' "$output/docs/fleet/stack.md"
grep -Fq 'Retain handwritten prose.' "$output/docs/fleet/stack.md"
grep -Fq '/app/blob/development/crates/app/Cargo.toml' "$output/docs/fleet/stack.md"
if grep -Fq '/crates/fixture/' "$output/docs/fleet/stack.md"; then
    echo 'excluded fixture included in report' >&2; exit 1
fi
cp "$output/docs/fleet/overview.md" "$FIXTURE/saved-readme"
cp "$output/docs/fleet/stack.md" "$FIXTURE/saved-details"
graph --write
cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"
cmp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"

# A private qualification consumer may use normal dependencies while its
# supplier's return edge is optional: neither belongs in the compact overview.
cp "$parent/unused/crates/unused/Cargo.toml" "$FIXTURE/saved-unused"
cp "$parent/engine/crates/memory/Cargo.toml" "$FIXTURE/role-memory"
cat >> "$parent/unused/crates/unused/Cargo.toml" <<'TOML'
[package.metadata.toko-tooling.loc]
category = "tests"
[dependencies]
memory = { path = "../../../engine/crates/memory", version = ">=0.1, <0.3" }
platform = { version = "0.2", optional = true, default-features = false, features = ["fixture"] }
TOML
cat >> "$parent/engine/crates/memory/Cargo.toml" <<'TOML'
[dependencies]
unused = { path = "../../../unused/crates/unused", version = "0.1", optional = true }
TOML
mkdir -p "$parent/unused/generated/driver"
printf 'Not a Cargo manifest: this generator output must not be executed.\n' > "$parent/unused/generated/driver/Cargo.toml"
graph --write
grep -Fq 'unused (qualification: tests)' "$output/docs/fleet/stack.md"
grep -Fq 'p_unused_7ccargo_3aunused -. "normal, qualification" .-> p_engine_7ccargo_3amemory' "$output/docs/fleet/stack.md"
grep -Fq 'p_engine_7ccargo_3amemory -. "normal, conditional, qualification" .-> p_unused_7ccargo_3aunused' "$output/docs/fleet/stack.md"
grep -Fq 'requirement=&#62;=0.1, &#60;0.3' "$output/docs/fleet/stack.md"
grep -Fq 'requirement=^0.2; declared source=registry+' "$output/docs/fleet/stack.md"
grep -Fq 'requested features=fixture; default features=no' "$output/docs/fleet/stack.md"
grep -Fq 'crates/platform/Cargo.toml) (0.1.0;' "$output/docs/fleet/stack.md"
cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"
cp "$FIXTURE/saved-unused" "$parent/unused/crates/unused/Cargo.toml"
cp "$FIXTURE/role-memory" "$parent/engine/crates/memory/Cargo.toml"
graph --write
cmp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"

# Policies group nodes without merging their dependency edges; the full view
# also retains selected packages outside the application closure.
grep -Fq 'subgraph p_group_3aengine_7cstorage["storage · 0.1.0"]' "$output/docs/fleet/overview.md"
grep -Fq 'subgraph p_group_3aengine_7cengine["engine · 0.1.0"]' "$output/docs/fleet/stack.md"
grep -Fq 'p_unused_7ccargo_3aunused["unused"]' "$output/docs/fleet/stack.md"
grep -Fq '/engine/blob/main/releases/storage.md' "$output/docs/fleet/stack.md"
cp "$parent/engine/ci/cargo-release-groups.json" "$FIXTURE/saved-groups"
for fault in duplicate unknown unassigned primary ledger; do
    perl -MJSON::PP -e '
        local $/; my $fault=shift; my $p=decode_json(<>);
        push @{$p->{groups}[1]{members}}, "engine" if $fault eq "duplicate";
        push @{$p->{groups}[1]{members}}, "missing" if $fault eq "unknown";
        pop @{$p->{groups}[1]{members}} if $fault eq "unassigned";
        $p->{groups}[1]{primary}="engine" if $fault eq "primary";
        $p->{groups}[1]{changelog}="releases/missing.md" if $fault eq "ledger";
        print encode_json($p);
    ' "$fault" "$FIXTURE/saved-groups" > "$parent/engine/ci/cargo-release-groups.json"
    if graph --write; then echo "invalid group accepted: $fault" >&2; exit 1; fi
    grep -Eq 'release-group member|primary is not a member|Invalid group changelog' "$FIXTURE/command.log"
    cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"
    cmp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"
done
cp "$FIXTURE/saved-groups" "$parent/engine/ci/cargo-release-groups.json"
# Single-group owners can keep their ledger at the workspace root.
cp "$parent/engine/releases/engine.md" "$parent/engine/CHANGELOG.md"
sed 's@releases/engine.md@CHANGELOG.md@' "$FIXTURE/saved-groups" > "$parent/engine/ci/cargo-release-groups.json"
graph --write
grep -Fq '/engine/blob/main/CHANGELOG.md' "$output/docs/fleet/stack.md"
cp "$FIXTURE/saved-groups" "$parent/engine/ci/cargo-release-groups.json"
graph --write
cmp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"
cp "$parent/engine/crates/memory/Cargo.toml" "$FIXTURE/saved-memory"
sed 's/0.1.0/0.2.0/' "$FIXTURE/saved-memory" > "$parent/engine/crates/memory/Cargo.toml"
if graph --write; then echo 'mismatched group version accepted' >&2; exit 1; fi
grep -Fq 'Release-group version mismatch' "$FIXTURE/command.log"
cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"
cmp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"
cp "$FIXTURE/saved-memory" "$parent/engine/crates/memory/Cargo.toml"
# A legitimate independent version change must refresh both group projections.
cp "$parent/engine/crates/storage/Cargo.toml" "$FIXTURE/saved-storage"
sed 's/0.1.0/0.2.0/' "$FIXTURE/saved-memory" > "$parent/engine/crates/memory/Cargo.toml"
sed 's/0.1.0/0.2.0/' "$FIXTURE/saved-storage" > "$parent/engine/crates/storage/Cargo.toml"
if graph --check; then echo 'stale group version accepted' >&2; exit 1; fi
grep -Fq 'Stack graph is stale' "$FIXTURE/command.log"
graph --write
grep -Fq 'storage · 0.2.0' "$output/docs/fleet/overview.md"
grep -Fq 'engine · 0.1.0' "$output/docs/fleet/stack.md"
cp "$FIXTURE/saved-memory" "$parent/engine/crates/memory/Cargo.toml"
cp "$FIXTURE/saved-storage" "$parent/engine/crates/storage/Cargo.toml"
graph --write
cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"
cmp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"

# A typo or a native tool in the overview selection must not replace either
# output. Custom catalogs may still omit the optional overview selection.
cp "$FIXTURE/catalog.json" "$FIXTURE/saved-catalog"
for package in missing ic-build; do
    perl -MJSON::PP -e 'local $/; my $p=shift; my $c=decode_json(<>); $c->{overview}=[$p]; print encode_json($c)' \
        "$package" "$FIXTURE/saved-catalog" > "$FIXTURE/catalog.json"
    if graph --write; then echo 'invalid overview selection accepted' >&2; exit 1; fi
    grep -Eq 'Unknown or ambiguous overview crate|Overview crate is not a selected library' "$FIXTURE/command.log"
    cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"
    cmp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"
done
perl -MJSON::PP -e 'local $/; my $c=decode_json(<>); delete $c->{overview}; print encode_json($c)' \
    "$FIXTURE/saved-catalog" > "$FIXTURE/catalog.json"
graph --write
grep -Fq '["engine-core"]' "$output/docs/fleet/overview.md"
cp "$FIXTURE/saved-catalog" "$FIXTURE/catalog.json"
graph --write
cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"
cmp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"

# Changed declarations make --check fail without changing either output.
printf '\n[build-dependencies]\nengine = { path = "../../../engine/crates/engine" }\n' >> "$parent/platform/crates/platform/Cargo.toml"
if graph --check; then echo 'stale graph accepted' >&2; exit 1; fi
grep -Fq 'Stack graph is stale' "$FIXTURE/command.log"
cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"
cmp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"
graph --write
grep -Fq 'platform → engine' "$output/docs/fleet/stack.md"

# A missing final checkout cannot leave a partial publication of earlier inputs.
cp "$output/docs/fleet/overview.md" "$FIXTURE/saved-readme"
cp "$output/docs/fleet/stack.md" "$FIXTURE/saved-details"
mv "$parent/unused" "$parent/unused.saved"
if graph --write; then echo 'missing checkout accepted' >&2; exit 1; fi
grep -Fq 'Missing checkout: unused' "$FIXTURE/command.log"
cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"
cmp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"
mv "$parent/unused.saved" "$parent/unused"

# Do not destroy reachability by reducing a graph containing a normal cycle.
# Make the formerly conditional edges unconditional for this separate case.
sed '/\[target\./d;s/, optional = true//' "$parent/engine/crates/engine/Cargo.toml" > "$FIXTURE/unconditional-engine"
cp "$FIXTURE/unconditional-engine" "$parent/engine/crates/engine/Cargo.toml"
sed 's/, optional = true//' "$parent/app/crates/app/Cargo.toml" > "$FIXTURE/unconditional-app"
cp "$FIXTURE/unconditional-app" "$parent/app/crates/app/Cargo.toml"
sed 's/\[build-dependencies\]/[dependencies]/' "$parent/platform/crates/platform/Cargo.toml" > "$FIXTURE/cyclic-manifest"
cp "$FIXTURE/cyclic-manifest" "$parent/platform/crates/platform/Cargo.toml"
graph --write
grep -Fq 'p_engine_7ccargo_3aengine --> p_platform_7ccargo_3aplatform' "$output/docs/fleet/overview.md"
grep -Fq 'p_platform_7ccargo_3aplatform --> p_engine_7ccargo_3aengine' "$output/docs/fleet/overview.md"
grep -Fq 'p_app_3aapp --> p_platform_7ccargo_3aplatform' "$output/docs/fleet/overview.md"

# A broken second output must not publish an already prepared overview change.
cp "$output/docs/fleet/overview.md" "$FIXTURE/saved-readme"
printf 'Missing generated markers.\n' > "$output/docs/fleet/stack.md"
if graph --write; then echo 'missing output markers accepted' >&2; exit 1; fi
grep -Fq 'Expected one generated block' "$FIXTURE/command.log"
cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"

cp "$FIXTURE/saved-details" "$output/docs/fleet/stack.md"
mkdir -p "$parent/unused/browser"
cp "$parent/platform/browser/package.json" "$parent/unused/browser/package.json"
perl -MJSON::PP -e 'local $/; my $c=decode_json(<>); for (@{$c->{repositories}}) { $_->{npm}=["browser/package.json"] if $_->{name} eq "unused" } print encode_json($c)' \
    "$FIXTURE/catalog.json" > "$FIXTURE/ambiguous.json"
cp "$FIXTURE/ambiguous.json" "$FIXTURE/catalog.json"
if graph --write; then echo 'ambiguous dependency owner accepted' >&2; exit 1; fi
grep -Fq 'Ambiguous owner for npm dependency' "$FIXTURE/command.log"
cmp "$FIXTURE/saved-readme" "$output/docs/fleet/overview.md"

fixture_complete=true
printf 'Stack graph metadata, evidence, reduction, stale-check and failure cases passed\n'
