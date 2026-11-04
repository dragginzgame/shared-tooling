#!/usr/bin/env bash
# Shared companions: scripts/ci/prepare-cargo-stage-source.pl scripts/ci/cargo-release-group.sh
set -euo pipefail
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
    printf '[package]\nname = "stage-%s"\nversion = "%s"\nedition = "2024"\nrust-version = "1.99.1"\n' "$group" "$previous" > "crates/$group/Cargo.toml"
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
        --source "$before" --editor "$CARGO_RELEASE_METADATA_EDITOR" > "$fixture/$1.json"
    [[ $(git rev-parse HEAD) == "$before" && -z $(git status --porcelain=v1 --untracked-files=all) ]]
}
prepare first
candidate=$(jq -er .directory "$fixture/first.json")
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
        if [[ "$label" == first ]]; then cargo test --offline --locked --manifest-path "$directory/Cargo.toml" --workspace > "$fixture/native.log" 2>&1; fi
        return
    fi
    jq -cnS --arg path "$PATH" --arg home "$HOME" --arg tmp "$fixture/stage-tmp" \
        --arg tools "$fixture/tools.json" --arg identity "$identity" \
        '{PATH:$path,HOME:$home,TMPDIR:$tmp,LC_ALL:"C",CARGO_NET_OFFLINE:"true",RUSTUP_AUTO_INSTALL:"0",CARGO_STAGE_TOOLS:$tools,CARGO_STAGE_IDENTITY:$identity}' > "$fixture/environment.json"
    (cd "$directory"; perl "$root/scripts/ci/run-validation-stage.pl" --state "$fixture/stages" \
        --stage native --contract candidate-native/1 --source "$source" --group "$group" \
        --observe "$root/scripts/ci/observe-cargo-stage.pl" --environment "$fixture/environment.json" \
        --max-bytes 536870912 --admission-output "$fixture/$label-admission.json" \
        -- cargo test --offline --locked --workspace) > "$fixture/$label-native.log" 2>&1
    perl "$root/scripts/ci/seal-validation-stage.pl" "$fixture/$label-admission.json" "$source" "$group" "$identity" > "$fixture/$label-sealed.json"
    local expected=reused
    [[ "$label" != first ]] || expected=executed
    jq -e --arg expected "$expected" '.admission.mode == $expected' "$fixture/$label-sealed.json" > /dev/null
}
admit first api
for entry in api:1.2.0:1.2.1 engine:2.3.0:2.3.1; do
    IFS=: read -r group previous next <<< "$entry"
    RELEASE_PREVIOUS="$previous" RELEASE_VERSION="$next" RELEASE_DATE=2040-01-02 \
        CARGO_RELEASE_METADATA_MAX_BYTES=8388608 \
        bash "$root/scripts/ci/cargo-release-group.sh" prepare "$group" > "$fixture/$group-render.log" 2>&1
    git add Cargo.toml Cargo.lock "crates/$group/Cargo.toml" "releases/$group/CHANGELOG.md"
    git -c commit.gpgsign=false commit -qm "Fixture release $group"
    prepare "$group"
    admit "$group" "$group"
    perl "$root/scripts/ci/check-cargo-stage-closure.pl" "$PWD" "$candidate" "stage-$group" > "$fixture/$group-closure.log"
    [[ $(jq -r .identity "$fixture/$group.json") == "$(jq -r .identity "$fixture/first.json")" ]]
    [[ $(jq -r .source "$fixture/$group.json") != "$(jq -r .source "$fixture/first.json")" ]]
done
printf '\n// Changed implementation\n' >> crates/api/src/lib.rs
git add crates/api/src/lib.rs
git -c commit.gpgsign=false commit -qm 'Changed implementation'
prepare changed
[[ $(jq -r .identity "$fixture/changed.json") != "$(jq -r .identity "$fixture/first.json")" ]]
printf '\n// Damaged retained source\n' >> "$candidate/crates/api/src/lib.rs"
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
echo 'Final candidate rendering, actual native execution/two admissions, publication closure and source/cache custody passed.'
