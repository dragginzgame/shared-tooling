#!/usr/bin/env bash
# Shared companions: scripts/ci/cargo-release-metadata.sh scripts/ci/check-dependency-pins.sh scripts/ci/run-release.sh scripts/ci/release-receipts.sh scripts/ci/fixture-lifecycle.sh scripts/ci/cargo-publication-selection.pl
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
ROOT="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/cargo-release-groups-test.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Release-group fixtures retained"' EXIT
export CARGO_RELEASE_METADATA_EDITOR="${CARGO_RELEASE_METADATA_EDITOR:?select group-capable compiled IC Build editor}"
export CARGO_RELEASE_METADATA_MAX_BYTES=8388608
export RELEASE_GROUP=endpoint RELEASE_PREVIOUS=0.1.0 RELEASE_VERSION=0.2.0 RELEASE_DATE=2026-10-31
unset RELEASE_COMMIT
helper="$ROOT/scripts/ci/cargo-release-metadata.sh"
group_helper="$ROOT/scripts/ci/cargo-release-group.sh"
mkdir -p "$fixture/source/ci" "$fixture/source/docs"
cd "$fixture/source"
git init -q
git config user.name Fixture
git config user.email fixture@example.invalid
git config core.hooksPath /dev/null
git remote add origin https://example.invalid/release-groups.git
cat > Cargo.toml <<'TOML'
[workspace]
members = ["codec", "derive", "endpoint"]
resolver = "3"
[workspace.package]
version = "0.11.0"
edition = "2024"
[workspace.dependencies]
codec = { path = "codec", version = "0.11.0" }
derive = { path = "derive", version = "0.11.0" }
entry = { package = "endpoint", path = "endpoint", version = "^0.1.0" }
serde = { version = "1.0", default-features = false }
TOML
for package in codec derive endpoint; do
    mkdir -p "$package/src"
    printf '[package]\nname = "%s"\n' "$package" > "$package/Cargo.toml"
    if [[ "$package" == endpoint ]]; then printf 'version = "0.1.0"\n'; else printf 'version.workspace = true\n'; fi >> "$package/Cargo.toml"
    printf 'edition.workspace = true\n' >> "$package/Cargo.toml"
    printf 'pub fn fixture() {}\n' > "$package/src/lib.rs"
done
printf '\n[dev-dependencies]\nentry.workspace = true\n' >> codec/Cargo.toml
printf '\n[dependencies]\ncodec.workspace = true\nserde.workspace = true\n' >> endpoint/Cargo.toml
cat > ci/cargo-release-groups.json <<'JSON'
{"schema":1,"groups":[
 {"name":"codec","primary":"codec","version":"workspace","members":["codec","derive"],"changelog":"CHANGELOG.md","dependencies":["codec","derive"]},
 {"name":"endpoint","primary":"endpoint","version":"package","members":["endpoint"],"changelog":"docs/endpoint.md","dependencies":["entry"],"metadata_files":["ci/endpoint-pin.json"]}
]}
JSON
printf '{"version":"0.1.0"}\n' > ci/endpoint-pin.json
printf '# Changelog\n\n## [0.12.0]\n\n- Codec draft.\n\n## [0.11.0] - 2026-10-30\n\n- Previous.\n' > CHANGELOG.md
printf '# Endpoint\n\n## [0.2.0]\n\n- Endpoint draft.\n\n## [0.1.0] - 2026-10-30\n\n- Previous.\n' > docs/endpoint.md
cargo generate-lockfile --offline > "$fixture/lock.log" 2>&1
git add -- Cargo.toml Cargo.lock CHANGELOG.md codec derive endpoint docs ci
git commit -qm fixture
cp ci/cargo-release-groups.json "$fixture/policy.json"
cp Cargo.lock "$fixture/lock"
cp Cargo.toml "$fixture/manifest"
cp docs/endpoint.md "$fixture/changelog"
cp codec/Cargo.toml "$fixture/codec"
cp ci/endpoint-pin.json "$fixture/endpoint-pin"
refuse() { if "$@"; then echo 'unexpected release-group admission' >&2; exit 1; fi; }
bash "$helper" check-graph endpoint
[[ "$(bash "$group_helper" version endpoint)" == 0.1.0 ]]
bash "$ROOT/scripts/ci/check-dependency-pins.sh" --consumer "$PWD" --cargo-inheritance
RELEASE_GROUP='' refuse bash "$helper" check-graph codec
refuse bash "$helper" check-graph codec
for fault in missing overlap version unknown-alias missing-alias ledger traversal metadata-shape metadata-missing metadata-traversal metadata-duplicate metadata-overlap metadata-manifest metadata-ledger metadata-policy metadata-git; do
    case "$fault" in
        missing) filter='.groups[0].members=["codec"]' ;;
        overlap) filter='.groups[1].members += ["codec"]' ;;
        version) filter='.groups[1].version="workspace"' ;;
        unknown-alias) filter='.groups[1].dependencies=["serde"]' ;;
        missing-alias) filter='.groups[1].dependencies=[]' ;;
        ledger) filter='.groups[1].changelog="CHANGELOG.md"' ;;
        traversal) filter='.groups[1].changelog="../outside"' ;;
        metadata-shape) filter='.groups[1].metadata_files=null' ;;
        metadata-missing) filter='.groups[1].metadata_files=["ci/missing.json"]' ;;
        metadata-traversal) filter='.groups[1].metadata_files=["../outside"]' ;;
        metadata-duplicate) filter='.groups[1].metadata_files += .groups[1].metadata_files' ;;
        metadata-overlap) filter='.groups[0].metadata_files=.groups[1].metadata_files' ;;
        metadata-manifest) filter='.groups[1].metadata_files=["codec/Cargo.toml"]' ;;
        metadata-ledger) filter='.groups[1].metadata_files=["CHANGELOG.md"]' ;;
        metadata-policy) filter='.groups[1].metadata_files=["ci/cargo-release-groups.json"]' ;;
        metadata-git) filter='.groups[1].metadata_files=[".git/config"]' ;;
    esac
    jq "$filter" "$fixture/policy.json" > ci/cargo-release-groups.json
    refuse bash "$helper" prepare endpoint > "$fixture/$fault.log" 2>&1
    cmp Cargo.toml "$fixture/manifest"
    cmp Cargo.lock "$fixture/lock"
    cmp docs/endpoint.md "$fixture/changelog"
    cmp ci/endpoint-pin.json "$fixture/endpoint-pin"
done
cp "$fixture/policy.json" ci/cargo-release-groups.json
# A stale unsourced lock record refuses even if its rendered version is plausible.
sed 's/version = "0.1.0"/version = "0.1.1"/' "$fixture/lock" > Cargo.lock
refuse bash "$helper" prepare endpoint > "$fixture/stale.log" 2>&1
cp "$fixture/lock" Cargo.lock
# Renderer failure must never install partial candidates.
real_editor="$CARGO_RELEASE_METADATA_EDITOR"
printf '#!/usr/bin/env bash\nexit 23\n' > "$fixture/broken-editor"
chmod +x "$fixture/broken-editor"
CARGO_RELEASE_METADATA_EDITOR="$fixture/broken-editor" refuse bash "$helper" prepare endpoint > "$fixture/renderer.log" 2>&1
cmp Cargo.toml "$fixture/manifest"
cmp Cargo.lock "$fixture/lock"
cmp docs/endpoint.md "$fixture/changelog"
export CARGO_RELEASE_METADATA_EDITOR="$real_editor"
# The full workspace is revalidated after candidate installation. A failing graph
# restores every selected manifest, lock and group ledger, retaining evidence.
real_cargo="$(command -v cargo)"
export GROUP_REAL_CARGO="$real_cargo"
mkdir "$fixture/bin"
cat > "$fixture/bin/cargo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == metadata ]] && grep -q 'version = "0.2.0"' endpoint/Cargo.toml; then
    "$GROUP_REAL_CARGO" "$@"
    printf 'controlled metadata corruption\n' > ci/endpoint-pin.json
    echo 'controlled prepared group graph refusal' >&2
    exit 37
fi
exec "$GROUP_REAL_CARGO" "$@"
SH
chmod +x "$fixture/bin/cargo"
PATH="$fixture/bin:$PATH" refuse bash "$helper" prepare endpoint > "$fixture/rollback.log" 2>&1
cmp Cargo.toml "$fixture/manifest"
cmp Cargo.lock "$fixture/lock"
cmp docs/endpoint.md "$fixture/changelog"
cmp ci/endpoint-pin.json "$fixture/endpoint-pin"
grep -q 'controlled prepared group graph refusal' "$fixture/rollback.log"
bash "$helper" prepare endpoint > "$fixture/prepared.log" 2>&1
bash "$helper" check endpoint
cmp ci/endpoint-pin.json "$fixture/endpoint-pin"
cmp codec/Cargo.toml "$fixture/codec"
cmp CHANGELOG.md <(git show HEAD:CHANGELOG.md)
[[ "$(bash "$ROOT/scripts/ci/read-cargo-workspace-version.sh" Cargo.toml)" == 0.11.0 ]]
yq -p toml -o json '.' Cargo.lock > "$fixture/after.json"
yq -p toml -o json '.' "$fixture/lock" > "$fixture/before.json"
jq -ne --slurpfile before "$fixture/before.json" --slurpfile after "$fixture/after.json" '
    ($before[0].package | map(select(.name != "endpoint"))) == ($after[0].package | map(select(.name != "endpoint"))) and
    ($after[0].package | map(select(.name == "endpoint"))[0].version) == "0.2.0"' > /dev/null
grep -q 'version = "\^0.2.0"' Cargo.toml
cargo metadata --locked --offline --format-version 1 > "$fixture/publication-metadata.json"
perl "$ROOT/scripts/ci/cargo-publication-selection.pl" "$fixture/publication-metadata.json" \
    'codec derive endpoint' 'codec endpoint' crates-io > "$fixture/publication-selection"
printf 'codec@0.11.0\0endpoint@0.2.0\0' > "$fixture/publication-expected"
cmp "$fixture/publication-selection" "$fixture/publication-expected"
bash "$ROOT/scripts/ci/check-dependency-pins.sh" --consumer "$PWD" --cargo-inheritance
# Committed checks use the selected source, including its selected group ledger.
git add -- Cargo.toml Cargo.lock docs/endpoint.md endpoint/Cargo.toml
git commit -qm 'prepared endpoint fixture'
export RELEASE_COMMIT
RELEASE_COMMIT="$(git rev-parse HEAD)"
printf 'unrelated live draft\n' > docs/endpoint.md
bash "$helper" check endpoint
unset RELEASE_COMMIT
git restore -- docs/endpoint.md
# Validation receipts bind group and policy, including identical numeric versions.
# shellcheck source=scripts/ci/release-receipts.sh
source "$ROOT/scripts/ci/release-receipts.sh"
export RELEASE_SOURCE RELEASE_REMOTE=origin RELEASE_BRANCH=main
RELEASE_SOURCE="$(git rev-parse HEAD)"
release_receipt_write "$fixture/validated" release_receipt_identity
release_receipt_check "$fixture/validated" release_receipt_identity
RELEASE_GROUP=codec refuse release_receipt_check "$fixture/validated" release_receipt_identity
printf '\n' >> ci/cargo-release-groups.json
refuse release_receipt_check "$fixture/validated" release_receipt_identity
git restore -- ci/cargo-release-groups.json
# Exercise the ordinary runner, source admission and receipts against a real
# disposable bare destination. The fixture's complete gate is locked metadata;
# no production release, credential, remote service or package publication runs.
mkdir "$fixture/runner"
git archive HEAD~1 | tar -xf - -C "$fixture/runner"
git init -q --bare "$fixture/destination.git"
cd "$fixture/runner"
git init -q -b main
git config user.name Fixture
git config user.email fixture@example.invalid
git config core.hooksPath /dev/null
git remote add origin "$fixture/destination.git"
export GROUP_SHARED_ROOT="$ROOT" GROUP_ADAPTER="$fixture/adapter"
cat > "$GROUP_ADAPTER" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
root="$GROUP_SHARED_ROOT/scripts/ci"
operation="$1"
group="$RELEASE_GROUP"
if [[ "$operation" == version ]]; then
    exec bash "$root/cargo-release-group.sh" "$operation" "$group"
fi
if [[ "$operation" == files ]]; then
    bash "$root/cargo-release-group.sh" files "$group"
    if [[ "${GROUP_EXTRA_FILES:-0}" == 1 ]]; then printf 'codec/src/lib.rs\0'; fi
    exit
fi
state="$(git rev-parse --git-path release-state)/$group-$RELEASE_VERSION.receipts"
source "$root/release-receipts.sh"
case "$operation" in
    preflight)
        bash "$root/check-release-source.sh"
        bash "$root/cargo-release-group.sh" check-graph "$group"
        ;;
    verify)
        cargo metadata --locked --offline --format-version 1 > /dev/null
        mkdir -p "$state"
        release_receipt_write "$state/validated" release_receipt_identity
        ;;
    prepare)
        release_receipt_check "$state/validated" release_receipt_identity
        bash "$root/cargo-release-group.sh" prepare "$group"
        if [[ "$group" == endpoint ]]; then
            printf '{"version":"%s"}\n' "$RELEASE_VERSION" > ci/endpoint-pin.json
        fi
        files=()
        while IFS= read -r -d '' file; do files+=("$file"); done < <(bash "$root/cargo-release-group.sh" files "$group")
        release_receipt_write "$state/prepared" release_receipt_payload '' "${files[@]}"
        ;;
    prepared|commit|committed|tagged|push)
        release_receipt_check "$state/validated" release_receipt_identity
        bash "$root/cargo-release-group.sh" check "$group"
        if [[ "$group" == endpoint ]]; then
            [[ "$(jq -r .version ci/endpoint-pin.json)" == "$RELEASE_VERSION" ]]
        fi
        files=()
        while IFS= read -r -d '' file; do files+=("$file"); done < <(bash "$root/cargo-release-group.sh" files "$group")
        release_receipt_check "$state/prepared" release_receipt_payload "${RELEASE_COMMIT:-}" "${files[@]}"
        if [[ "$operation" == push && "${GROUP_FAIL_PUSH:-0}" == 1 ]]; then exit 31; fi
        ;;
    *) exit 2 ;;
esac
SH
cat > Makefile <<'MAKE'
release-version:
	@bash "$(GROUP_ADAPTER)" version
release-files:
	@bash "$(GROUP_ADAPTER)" files
release-preflight:
	@bash "$(GROUP_ADAPTER)" preflight
release-verify:
	@bash "$(GROUP_ADAPTER)" verify
release-prepare-version:
	@bash "$(GROUP_ADAPTER)" prepare
release-prepared-check:
	@bash "$(GROUP_ADAPTER)" prepared
release-commit-check:
	@bash "$(GROUP_ADAPTER)" commit
release-committed-check:
	@bash "$(GROUP_ADAPTER)" committed
release-tagged-check:
	@bash "$(GROUP_ADAPTER)" tagged
release-push-check:
	@bash "$(GROUP_ADAPTER)" push
MAKE
git add -- Cargo.toml Cargo.lock CHANGELOG.md codec derive endpoint docs ci Makefile
git commit -qm 'runner fixture'
git push -q origin main
unset RELEASE_SOURCE RELEASE_PREVIOUS RELEASE_VERSION RELEASE_DATE RELEASE_REMOTE RELEASE_BRANCH
GROUP_EXTRA_FILES=1 refuse bash "$ROOT/scripts/ci/run-release.sh" minor origin main > "$fixture/extra-files.log" 2>&1
grep -q 'adapter release files differ from the selected group' "$fixture/extra-files.log"
git diff --cached --quiet HEAD --
git restore -- Cargo.toml Cargo.lock docs/endpoint.md endpoint/Cargo.toml ci/endpoint-pin.json
GROUP_FAIL_PUSH=1 refuse bash "$ROOT/scripts/ci/run-release.sh" minor origin main > "$fixture/runner-failure.log" 2>&1
[[ "$(git log -1 --format=%s)" == 'Release endpoint 0.2.0' ]]
[[ "$(git rev-parse 'endpoint-v0.2.0^{commit}')" == "$(git rev-parse HEAD)" ]]
[[ "$(git show HEAD:ci/endpoint-pin.json | jq -r .version)" == 0.2.0 ]]
[[ -f .git/release-state/endpoint-0.2.0.plan ]]
# An attempt copied into another group's namespace must refuse before effects.
cp .git/release-state/endpoint-0.2.0.plan .git/release-state/codec-0.2.0.plan
RELEASE_GROUP=codec refuse bash "$ROOT/scripts/ci/run-release.sh" resume 0.2.0 origin main > "$fixture/wrong-resume.log" 2>&1
grep -q 'release group changed' "$fixture/wrong-resume.log"
bash "$ROOT/scripts/ci/run-release.sh" resume 0.2.0 origin main > "$fixture/resume.log" 2>&1
[[ "$(git --git-dir="$fixture/destination.git" rev-parse main)" == "$(git rev-parse HEAD)" ]]
[[ "$(git status --porcelain)" == '' ]]
[[ "$(bash "$ROOT/scripts/ci/read-cargo-workspace-version.sh" Cargo.toml)" == 0.11.0 ]]
RELEASE_GROUP=codec bash "$ROOT/scripts/ci/run-release.sh" minor origin main > "$fixture/codec-runner.log" 2>&1
[[ "$(git log -1 --format=%s)" == 'Release codec 0.12.0' ]]
grep -q 'version = "0.2.0"' endpoint/Cargo.toml
[[ "$(jq -r .version ci/endpoint-pin.json)" == 0.2.0 ]]
[[ "$(git status --porcelain)" == '' ]]
mkdir -p "$fixture/root-package/other/src" "$fixture/root-package/src" "$fixture/root-package/ci"
cd "$fixture/root-package"
cat > Cargo.toml <<'TOML'
[package]
name = "root"
version = "0.1.0"
edition = "2024"
[workspace]
members = ["other"]
resolver = "3"
[workspace.package]
version = "0.11.0"
TOML
printf '[package]\nname="other"\nversion.workspace=true\nedition="2024"\n' > other/Cargo.toml
printf 'pub fn fixture() {}\n' > src/lib.rs
cp src/lib.rs other/src/lib.rs
cat > ci/cargo-release-groups.json <<'JSON'
{"schema":1,"groups":[
 {"name":"root","primary":"root","version":"package","members":["root"],"changelog":"CHANGELOG.md","dependencies":[]},
 {"name":"other","primary":"other","version":"workspace","members":["other"],"changelog":"other.md","dependencies":[]}
]}
JSON
cp "$fixture/changelog" CHANGELOG.md
printf '# Other group\n' > other.md
cargo generate-lockfile --offline > /dev/null
RELEASE_GROUP=root RELEASE_PREVIOUS=0.1.0 RELEASE_VERSION=0.2.0 RELEASE_DATE=2026-10-31 \
    bash "$helper" prepare root > "$fixture/root-package.log" 2>&1
yq -p toml -o json '.' Cargo.toml | jq -e '.package.version == "0.2.0" and .workspace.package.version == "0.11.0"' > /dev/null
fixture_complete=true
printf 'Cargo release-group fixtures passed\n'
