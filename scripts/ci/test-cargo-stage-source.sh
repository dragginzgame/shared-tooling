#!/usr/bin/env bash
# Shared companions: scripts/ci/prepare-cargo-stage-source.pl scripts/ci/cargo-release-group.sh
set -euo pipefail
qualification=false
if [[ $# != 0 ]]; then
    [[ $# == 1 && $1 == --qualification ]] || exit 2
    qualification=true
fi
if [[ $qualification == false ]]; then bash "$0" --qualification; fi
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
: "${CARGO_RELEASE_METADATA_EDITOR:?select the admitted IC Build editor}"
mkdir -p "$root/target"
fixture=$(mktemp -d "$root/target/cargo-stage-source.XXXXXX")
echo "Cargo candidate qualification retained: $fixture"
mkdir -p "$fixture/source with spaces/crates/api/src" "$fixture/source with spaces/crates/engine/src" "$fixture/source with spaces/ci"
cd "$fixture/source with spaces"
cat > Cargo.toml <<'TOML'
[workspace]
members = ["crates/api", "crates/engine"]
resolver = "3"
[workspace.dependencies]
stage-api = { path = "crates/api", version = "1.2.0" }
stage-engine = { path = "crates/engine", version = "2.3.0" }
TOML
for entry in api:1.2.0:1.2.1 engine:2.3.0:2.3.1; do
    IFS=: read -r group previous next <<< "$entry"
    printf '[package]\nname = "stage-%s"\nversion = "%s"\nedition = "2024"\nrust-version = "1.100.0"\n' "$group" "$previous" > "crates/$group/Cargo.toml"
    printf 'pub const VERSION: &str = env!("CARGO_PKG_VERSION");\n#[test] fn final_version() { assert_eq!(VERSION, "%s"); }\n' "$next" > "crates/$group/src/lib.rs"
    mkdir -p "releases/$group"
    printf '# Notes\n\n## [%s] - Unreleased\n\n### Changed\n\n- Candidate qualification.\n' "$next" > "releases/$group/CHANGELOG.md"
    printf '{}\n' > "releases/$group/release.json"
done
printf '\n[dependencies]\nstage-api.workspace = true\n' >> crates/engine/Cargo.toml
cat > ci/cargo-release-groups.json <<'JSON'
{"schema":1,"groups":[{"name":"api","primary":"stage-api","version":"package","members":["stage-api"],"dependencies":["stage-api"],"changelog":"releases/api/CHANGELOG.md","metadata_files":["releases/api/release.json"]},{"name":"engine","primary":"stage-engine","version":"package","members":["stage-engine"],"dependencies":["stage-engine"],"changelog":"releases/engine/CHANGELOG.md","metadata_files":["releases/engine/release.json"]}]}
JSON
printf '/target/\n/.tools/\n' > .gitignore
stage_args=(--workspace)
if [[ $qualification == true ]]; then
    printf '/qualification/target/\n' >> .gitignore
    perl -pi -e 's/resolver = "3"/exclude = ["qualification"]\nresolver = "3"/' Cargo.toml
    mkdir -p qualification/probe/src "$fixture/supplier/src"
    printf '[package]\nname = "stage-supplier"\nversion = "0.8.0"\nedition = "2024"\n' > "$fixture/supplier/Cargo.toml"
    printf 'pub fn value() -> u8 { 7 }\n' > "$fixture/supplier/src/lib.rs"
    cat > qualification/Cargo.toml <<TOML
[workspace]
members = ["probe"]
resolver = "3"
[workspace.dependencies]
stage-api = { path = "../crates/api", version = "1.2.0" }
stage-engine = { path = "../crates/engine", version = "2.3.0" }
stage-supplier = { path = "$fixture/supplier", version = "0.8.0" }
TOML
    cat > qualification/probe/Cargo.toml <<'TOML'
[package]
name = "stage-probe"
version = "0.7.0"
edition = "2024"
publish = false
[dependencies]
stage-api.workspace = true
stage-engine.workspace = true
stage-supplier.workspace = true
TOML
    printf '#[test] fn candidate() { assert_eq!(stage_api::VERSION, "1.2.1"); assert_eq!(stage_engine::VERSION, "2.3.1"); assert_eq!(stage_supplier::value(), 7); }\n' > qualification/probe/src/lib.rs
    jq '.qualification_workspace="qualification"' ci/cargo-release-groups.json > "$fixture/policy"
    cp "$fixture/policy" ci/cargo-release-groups.json
    stage_args+=(--manifest-path qualification/Cargo.toml)
    (cd qualification && cargo generate-lockfile --offline)
fi
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$PWD" scripts/ci/cargo-release-group.sh
cargo generate-lockfile --offline
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
unset RUSTFLAGS RUSTDOCFLAGS CARGO_ENCODED_RUSTFLAGS RUSTC_WRAPPER RUSTC_WORKSPACE_WRAPPER
# Disposable fixture commits exercise the producer; no real source/tag is changed.
git init -q
git config user.name 'Candidate qualification'
git config user.email 'candidate@example.invalid'
git config core.hooksPath /dev/null
git add .
git -c commit.gpgsign=false commit -qm 'Prepared fixture source'
prepare() {
    local before
    before=$(git rev-parse HEAD)
    perl "$root/scripts/ci/prepare-cargo-stage-source.pl" --root "$PWD" --state target/stage-sources \
        --source "$before" --editor "$CARGO_RELEASE_METADATA_EDITOR" > "$fixture/$1.json" || return
    [[ $(git rev-parse HEAD) == "$before" && -z $(git status --porcelain=v1 --untracked-files=all) ]]
}
prepare first
if [[ $qualification == true ]]; then
    candidate=$(jq -er .directory "$fixture/first.json")
    cmp qualification/probe/Cargo.toml "$candidate/qualification/probe/Cargo.toml"
    yq -p toml -o json '.' "$candidate/qualification/Cargo.lock" | jq -e '
        [.package[] | {name,version}] == [{name:"stage-api",version:"1.2.1"},
        {name:"stage-engine",version:"2.3.1"},{name:"stage-probe",version:"0.7.0"},
        {name:"stage-supplier",version:"0.8.0"}]' > /dev/null
    cp "$candidate/qualification/Cargo.lock" "$fixture/candidate-lock"
    rm "$candidate/qualification/Cargo.lock"
    if perl "$root/scripts/ci/prepare-cargo-stage-source.pl" --verify-projection "$fixture/first.json" > "$fixture/missing-lock.log" 2>&1; then exit 1; fi
    cp "$fixture/candidate-lock" "$candidate/qualification/Cargo.lock"
    printf '\n# drift\n' >> "$candidate/qualification/Cargo.lock"
    if perl "$root/scripts/ci/prepare-cargo-stage-source.pl" --verify-projection "$fixture/first.json" > "$fixture/changed-lock.log" 2>&1; then exit 1; fi
    cp "$fixture/candidate-lock" "$candidate/qualification/Cargo.lock"
fi
cp releases/api/CHANGELOG.md "$fixture/pending-notes"
perl -pi -e 's/ - Unreleased$//' releases/api/CHANGELOG.md
printf '\n## [1.2.0] - 2039-01-01\n\n- Historical notes.\n' >> releases/api/CHANGELOG.md
git add releases/api/CHANGELOG.md
git -c commit.gpgsign=false commit -qm 'Undated numbered candidate with history'
prepare undated
[[ $(jq -r .identity "$fixture/undated.json") == "$(jq -r .identity "$fixture/first.json")" ]]
cp releases/api/CHANGELOG.md "$fixture/undated-notes"
# Invalid first candidates must never qualify the older dated release below.
for heading in '## [Draft]' '## [1.2.1] - pending' '## [1.2.0]' '## [1.1.9]' '## [01.2.1]'; do
    printf '# Notes\n\n%s\n\n## [1.2.0] - 2039-01-01\n' "$heading" > releases/api/CHANGELOG.md
    git add releases/api/CHANGELOG.md
    git -c commit.gpgsign=false commit -qm 'Invalid candidate fixture'
    if prepare rejected > "$fixture/rejected.log" 2>&1; then
        echo "invalid candidate admitted: $heading" >&2; exit 1
    fi
    [[ -z $(git status --porcelain=v1 --untracked-files=all) ]]
done
for heading in '## [1.2.1]' '## [1.2.2] - Unreleased'; do
    cat "$fixture/undated-notes" > releases/api/CHANGELOG.md
    # Put the conflicting draft before the historical boundary.
    { cat "$fixture/pending-notes"; printf '\n%s\n' "$heading"; cat "$fixture/undated-notes"; } > releases/api/CHANGELOG.md
    git add releases/api/CHANGELOG.md
    git -c commit.gpgsign=false commit -qm 'Conflicting candidates fixture'
    if prepare rejected > "$fixture/rejected.log" 2>&1; then
        echo 'conflicting candidates admitted' >&2; exit 1
    fi
done
cp "$fixture/undated-notes" releases/api/CHANGELOG.md
git add releases/api/CHANGELOG.md
git -c commit.gpgsign=false commit -qm 'Restore undated candidate'
candidate=$(jq -er .directory "$fixture/first.json")
perl "$root/scripts/ci/prepare-cargo-stage-source.pl" --verify-projection "$fixture/first.json" > "$fixture/verify-source.log"
mkdir "$candidate/.tools"
if perl "$root/scripts/ci/prepare-cargo-stage-source.pl" --verify-projection "$fixture/first.json" > "$fixture/tools-root-refusal.log" 2>&1; then
    echo 'candidate-local tool root unexpectedly admitted' >&2; exit 1
fi
grep -q 'caller-owned' "$fixture/tools-root-refusal.log"
rmdir "$candidate/.tools"
# Exercise actual Cargo through the shared exact-input runner. Later group
# renders must admit the same original execution, with fresh source/group IDs.
mkdir -p "$fixture/stage-tmp"
files=()
for tool in bash cargo cc c++ ld ar make perl git jq yq tar awk sed grep sort head tail xargs cp mv mkdir rm rmdir mktemp tee shasum; do
    files+=("$(command -v "$tool")")
done
jq -cnS --args '$ARGS.positional | {files:.}' "${files[@]}" "$CARGO_RELEASE_METADATA_EDITOR" > "$fixture/tools.json"
admit() {
    local label=$1 group=$2 projected="$fixture/$1.json" source identity directory
    source=$(jq -er .source "$projected")
    identity=$(jq -er .identity "$projected")
    directory=$(jq -er .directory "$projected")
    if [[ $(uname -s) != Linux ]]; then
        if [[ "$label" == first ]]; then (cd "$directory"; cargo test --offline --locked "${stage_args[@]}") > "$fixture/native.log" 2>&1; fi
        return
    fi
    jq -cnS --arg path "$PATH" --arg home "$HOME" --arg tmp "$fixture/stage-tmp" \
        --arg tools "$fixture/tools.json" --arg identity "$identity" \
        '{PATH:$path,HOME:$home,TMPDIR:$tmp,LC_ALL:"C",CARGO_NET_OFFLINE:"true",RUSTUP_AUTO_INSTALL:"0",CARGO_STAGE_TOOLS:$tools,CARGO_STAGE_IDENTITY:$identity}' > "$fixture/environment.json"
    (cd "$directory"; perl "$root/scripts/ci/run-validation-stage.pl" --state "$fixture/stages" \
        --stage native --contract candidate-native/1 --source "$source" --group "$group" \
        --observe "$root/scripts/ci/observe-cargo-stage.pl" --environment "$fixture/environment.json" \
        --max-bytes 536870912 --admission-output "$fixture/$label-admission.json" \
        -- cargo test --offline --locked "${stage_args[@]}") > "$fixture/$label-native.log" 2>&1
    perl "$root/scripts/ci/seal-validation-stage.pl" "$fixture/$label-admission.json" "$source" "$group" "$identity" > "$fixture/$label-sealed.json"
    local expected=reused
    [[ "$label" != first && "$label" != supplier ]] || expected=executed
    jq -e --arg expected "$expected" '.admission.mode == $expected' "$fixture/$label-sealed.json" > /dev/null
}
admit first api
for entry in api:1.2.0:1.2.1 engine:2.3.0:2.3.1; do
    IFS=: read -r group previous next <<< "$entry"
    RELEASE_PREVIOUS="$previous" RELEASE_VERSION="$next" RELEASE_DATE=2040-01-02 \
        CARGO_RELEASE_METADATA_MAX_BYTES=8388608 \
        bash "$root/scripts/ci/cargo-release-group.sh" prepare "$group" > "$fixture/$group-render.log" 2>&1
    git add Cargo.toml Cargo.lock "crates/$group/Cargo.toml" "releases/$group/CHANGELOG.md"
    if [[ $qualification == true ]]; then git add qualification/Cargo.toml qualification/Cargo.lock; fi
    git -c commit.gpgsign=false commit -qm "Fixture release $group"
    prepare "$group"
    admit "$group" "$group"
    perl "$root/scripts/ci/check-cargo-stage-closure.pl" "$PWD" "$candidate" "stage-$group" > "$fixture/$group-closure.log"
    [[ $(jq -r .identity "$fixture/$group.json") == "$(jq -r .identity "$fixture/first.json")" ]]
    [[ $(jq -r .source "$fixture/$group.json") != "$(jq -r .source "$fixture/first.json")" ]]
done
if [[ $qualification == true && $(uname -s) == Linux ]]; then
    # This dependency belongs only to qualification, outside tracked product
    # source. Its bytes must invalidate a reusable native proof.
    printf '\n// Independently maintained supplier change\n' >> "$fixture/supplier/src/lib.rs"
    cp "$fixture/engine.json" "$fixture/supplier.json"
    admit supplier engine
fi
cp releases/api/CHANGELOG.md "$fixture/finalized-notes"
printf '\n## [1.2.2]\n\n- Misplaced draft.\n' >> releases/api/CHANGELOG.md
git add releases/api/CHANGELOG.md
git -c commit.gpgsign=false commit -qm 'Misplaced draft after finalized release'
if prepare rejected > "$fixture/finalized-refusal.log" 2>&1; then
    echo 'misplaced draft after finalized release admitted' >&2; exit 1
fi
cp "$fixture/finalized-notes" releases/api/CHANGELOG.md
git add releases/api/CHANGELOG.md
git -c commit.gpgsign=false commit -qm 'Restore finalized release'
printf '\n// Changed implementation\n' >> crates/api/src/lib.rs
git add crates/api/src/lib.rs
git -c commit.gpgsign=false commit -qm 'Changed implementation'
prepare changed
[[ $(jq -r .identity "$fixture/changed.json") != "$(jq -r .identity "$fixture/first.json")" ]]
printf '\n// Damaged retained source\n' >> "$candidate/crates/api/src/lib.rs"
if perl "$root/scripts/ci/prepare-cargo-stage-source.pl" --verify-projection "$fixture/first.json" > "$fixture/verify-drift.log" 2>&1; then
    echo 'damaged qualified inventory unexpectedly admitted' >&2; exit 1
fi
if (cd "$candidate"; CARGO_STAGE_TOOLS="$fixture/tools.json" CARGO_STAGE_IDENTITY="$(jq -er .identity "$fixture/first.json")" \
    perl "$root/scripts/ci/observe-cargo-stage.pl") > "$fixture/observe-drift.log" 2>&1; then
    echo 'stale source identity unexpectedly observed' >&2; exit 1
fi
grep -q 'clean qualified source' "$fixture/observe-drift.log"
# The corresponding original source still exists in history. A cache mutation
# must never become new qualified source, and the failed attempt is retained.
if perl "$root/scripts/ci/prepare-cargo-stage-source.pl" --root "$PWD" --state target/stage-sources \
    --source "$(git rev-parse HEAD)" --editor "$CARGO_RELEASE_METADATA_EDITOR" > "$fixture/unexpected.json" 2> "$fixture/refusal.log"; then
    # This invocation addresses the new implementation, not the old candidate.
    changed=$(jq -er .directory "$fixture/changed.json")
    printf '\n// Damaged current retained source\n' >> "$changed/crates/api/src/lib.rs"
    if perl "$root/scripts/ci/prepare-cargo-stage-source.pl" --root "$PWD" --state target/stage-sources \
        --source "$(git rev-parse HEAD)" --editor "$CARGO_RELEASE_METADATA_EDITOR" > "$fixture/unexpected.json" 2> "$fixture/refusal.log"; then
        echo 'damaged retained candidate unexpectedly admitted' >&2; exit 1
    fi
fi
grep -q 'retained candidate source drift' "$fixture/refusal.log"
if [[ $qualification == true ]]; then
    cp ci/cargo-release-groups.json "$fixture/declared-policy"
    jq 'del(.qualification_workspace)' ci/cargo-release-groups.json > "$fixture/undeclared-policy"
    cp "$fixture/undeclared-policy" ci/cargo-release-groups.json
    git add ci/cargo-release-groups.json
    git -c commit.gpgsign=false commit -qm 'Undeclared qualification fixture'
    if prepare undeclared > "$fixture/undeclared.log" 2>&1; then exit 1; fi
    grep -q 'use fresh execution' "$fixture/undeclared.log"
    cp "$fixture/declared-policy" ci/cargo-release-groups.json
    git add ci/cargo-release-groups.json
    git rm qualification/Cargo.lock > /dev/null
    git -c commit.gpgsign=false commit -qm 'Missing qualification lock fixture'
    if prepare missing > "$fixture/missing.log" 2>&1; then exit 1; fi
    [[ -z $(git status --porcelain=v1 --untracked-files=all) ]]
fi
echo 'Final candidate rendering, actual native execution/two admissions, publication closure and source/cache custody passed.'
