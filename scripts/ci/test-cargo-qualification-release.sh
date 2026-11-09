#!/usr/bin/env bash
# Shared companions: scripts/ci/cargo-release-group.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES RELEASE_COMMIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
ROOT="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
mkdir -p "$ROOT/target/fixtures"
fixture="$(fixture_create "$ROOT/target/fixtures/cargo-qualification.XXXXXX")"
export TMPDIR="$fixture"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Qualification release fixtures retained"' EXIT
export CARGO_RELEASE_METADATA_EDITOR="${CARGO_RELEASE_METADATA_EDITOR:?select the released Build editor}"
export CARGO_RELEASE_METADATA_MAX_BYTES=8388608
export RELEASE_PREVIOUS=0.1.0 RELEASE_VERSION=0.2.0 RELEASE_DATE=2026-11-09
helper="$ROOT/scripts/ci/cargo-release-group.sh"
mkdir -p "$fixture/source/ci" "$fixture/source/crates/domain/product/src" "$fixture/source/crates/unused/src" \
    "$fixture/source/qualification/domain/probe/src"
cd "$fixture/source"
cat > Cargo.toml <<'TOML'
[workspace]
members = ["crates/domain/product", "crates/unused"]
exclude = ["qualification"]
resolver = "3"
[workspace.dependencies]
product = { path = "crates/domain/product", version = "0.1.0" }
unused = { path = "crates/unused", version = "0.1.0" }
TOML
for path in domain/product unused; do
    printf '[package]\nname = "%s"\nversion = "0.1.0"\nedition = "2024"\n' "${path##*/}" > "crates/$path/Cargo.toml"
    printf 'pub fn fixture() {}\n' > "crates/$path/src/lib.rs"
done
cat > qualification/Cargo.toml <<'TOML'
[workspace]
members = ["domain/probe"]
resolver = "3"
[workspace.dependencies]
renamed = { package = "product", path = "../crates/domain/product", version = "=0.1.0" }
path_only = { package = "product", path = "../crates/domain/product" }
TOML
cat > qualification/domain/probe/Cargo.toml <<'TOML'
[package]
name = "probe"
version = "0.7.0"
edition = "2024"
publish = false
[dependencies]
renamed.workspace = true
TOML
printf 'pub fn probe() { renamed::fixture(); }\n' > qualification/domain/probe/src/lib.rs
cat > ci/cargo-release-groups.json <<'JSON'
{"schema":1,"qualification_workspace":"qualification","groups":[
 {"name":"product","primary":"product","version":"package","members":["product"],"changelog":"CHANGELOG.md","dependencies":["product"]},
 {"name":"unused","primary":"unused","version":"package","members":["unused"],"changelog":"unused.md","dependencies":["unused"]}
]}
JSON
for path in CHANGELOG.md unused.md; do
    printf '# Changelog\n\n## [0.2.0] - Unreleased\n\n- Pending.\n\n## [0.1.0] - 2026-11-08\n\n- Previous.\n' > "$path"
done
cargo generate-lockfile --offline
(cd qualification && cargo generate-lockfile --offline)
cp -R "$fixture/source" "$fixture/original"
refuse() { if "$@"; then echo 'unexpected qualification acceptance' >&2; exit 1; fi; }
restore() { cp -R "$fixture/original/." "$fixture/source/"; }
assert_original() { diff -r "$fixture/original" "$fixture/source"; }
bash "$helper" plan product > "$fixture/plan.json"
cargo metadata --locked --offline --format-version 1 > "$fixture/product.json"
# jq optional indexing must not turn a string requirement into an empty predicate
# that all() accepts. Exercise admission directly before Cargo rejects resolution.
jq -L "$ROOT/scripts/ci" -ne --slurpfile product "$fixture/product.json" --slurpfile plan "$fixture/plan.json" '
    include "cargo-qualification-release";
    {dependencies:{renamed:"0.1.0"}} |
    qualification_member_catalog($product[0]; $plan[0].qualification.catalog) | not' > /dev/null
jq -e '.qualification.members == ["product"] and
    ([.files[] | select(startswith("qualification/"))] == ["qualification/Cargo.toml","qualification/Cargo.lock"]) and
    (.qualification.manifest.dependencies == [{alias:"renamed",previous:"=0.1.0",next:"=0.2.0"}])' "$fixture/plan.json" > /dev/null
bash "$helper" prepare product
bash "$helper" check product
cmp qualification/domain/probe/Cargo.toml "$fixture/original/qualification/domain/probe/Cargo.toml"
cmp crates/unused/Cargo.toml "$fixture/original/crates/unused/Cargo.toml"
yq -p toml -o json '.' qualification/Cargo.lock | jq -e \
    '[.package[] | {name,version}] == [{name:"probe",version:"0.7.0"},{name:"product",version:"0.2.0"}]' > /dev/null
restore
# Qualification need not consume every group; no selected lock entries is a no-op.
bash "$helper" prepare unused
cmp qualification/Cargo.lock "$fixture/original/qualification/Cargo.lock"
cmp qualification/Cargo.toml "$fixture/original/qualification/Cargo.toml"
restore
# Refuse stale locks, public harnesses, aliases escaping their product identity,
# overlapping ownership, and direct member requirements before installation.
for fault in stale public alias overlap direct string reverse symlink; do
    case "$fault" in
        stale) perl -pi -e 's/version = "0.7.0"/version = "0.7.1"/' qualification/Cargo.lock ;;
        public) perl -ni -e 'print unless /publish = false/' qualification/domain/probe/Cargo.toml ;;
        alias) perl -pi -e 's@path = "../crates/domain/product" }@path = "../crates/unused" }@' qualification/Cargo.toml ;;
        overlap) jq '.shared_metadata_files=["qualification/Cargo.lock"]' ci/cargo-release-groups.json > "$fixture/policy"; cp "$fixture/policy" ci/cargo-release-groups.json ;;
        direct) perl -pi -e 's/renamed.workspace = true/renamed = { package = "product", path = "..\/..\/..\/crates\/domain\/product", version = "=0.1.0" }/' qualification/domain/probe/Cargo.toml ;;
        string) printf '\n[target.\x27cfg(any())\x27.dependencies]\nproduct = "0.1.0"\n' >> qualification/domain/probe/Cargo.toml ;;
        reverse) printf '\n[dev-dependencies]\nprobe = { path = "../../../qualification/domain/probe" }\n' >> crates/domain/product/Cargo.toml ;;
        symlink) mv qualification/Cargo.lock "$fixture/symlink-lock"; ln -s "$fixture/symlink-lock" qualification/Cargo.lock ;;
    esac
    cp -R "$fixture/source" "$fixture/$fault"
    refuse bash "$helper" prepare product > "$fixture/$fault.log" 2>&1
    diff -r "$fixture/$fault" "$fixture/source"
    if [[ "$fault" == symlink ]]; then rm qualification/Cargo.lock; fi
    restore
done
# Failure of the second graph after installation restores every selected file.
mkdir "$fixture/bin"
export QUAL_REAL_CARGO
QUAL_REAL_CARGO="$(command -v cargo)"
cat > "$fixture/bin/cargo" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == metadata && "$PWD" == */qualification ]] && rg -q '=0.2.0' Cargo.toml; then
    echo 'controlled qualification candidate refusal' >&2
    exit 37
fi
exec "$QUAL_REAL_CARGO" "$@"
WRAPPER
chmod +x "$fixture/bin/cargo"
PATH="$fixture/bin:$PATH" refuse bash "$helper" prepare product > "$fixture/rollback.log" 2>&1
rg -q 'controlled qualification candidate refusal' "$fixture/rollback.log"
assert_original
# A lock renderer failure also leaves the original complete source intact.
export QUAL_REAL_EDITOR="$CARGO_RELEASE_METADATA_EDITOR"
cat > "$fixture/bin/editor" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$3" == lock && "$4" == */qualification/Cargo.lock ]]; then exit 29; fi
exec "$QUAL_REAL_EDITOR" "$@"
WRAPPER
chmod +x "$fixture/bin/editor"
CARGO_RELEASE_METADATA_EDITOR="$fixture/bin/editor" refuse bash "$helper" prepare product > "$fixture/render-failure.log" 2>&1
assert_original
# Path-only product catalogs are also supported when no version edit is needed.
perl -pi -e 's/, version = "=0.1.0"//' qualification/Cargo.toml
bash "$helper" prepare product
rg -q 'version = "0.2.0"' qualification/Cargo.lock
if rg -q '0.2.0' qualification/Cargo.toml; then exit 1; fi
restore
# The same machinery supports one coordinated product group with inherited
# versions; qualification still has an independent version and lock.
printf '\n[workspace.package]\nversion = "0.1.0"\n' >> Cargo.toml
for path in domain/product unused; do
    perl -pi -e 's/version = "0.1.0"/version.workspace = true/' "crates/$path/Cargo.toml"
done
jq '.groups = [.groups[0]] | .groups[0].version="workspace" |
    .groups[0].members += ["unused"] | .groups[0].dependencies += ["unused"]' \
    ci/cargo-release-groups.json > "$fixture/single-group-policy"
cp "$fixture/single-group-policy" ci/cargo-release-groups.json
bash "$helper" prepare product
yq -p toml -o json '.' Cargo.toml | jq -e '.workspace.package.version == "0.2.0"' > /dev/null
cmp qualification/domain/probe/Cargo.toml "$fixture/original/qualification/domain/probe/Cargo.toml"
restore
# Committed checks must use both exported workspaces, not a broken live tree.
git init -q
git config user.name Fixture
git config user.email fixture@example.invalid
git config core.hooksPath /dev/null
git add -- Cargo.toml Cargo.lock CHANGELOG.md unused.md crates qualification ci
git commit -qm fixture
source_commit="$(git rev-parse HEAD)"
printf '\nnot valid toml\n' >> qualification/Cargo.toml
RELEASE_COMMIT="$source_commit" bash "$helper" check-graph product
refuse bash "$helper" check-graph product > "$fixture/live-refusal.log" 2>&1
fixture_complete=true
printf 'Qualification multi-lock preparation, preservation and rollback passed\n'
