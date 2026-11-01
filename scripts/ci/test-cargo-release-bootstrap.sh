#!/usr/bin/env bash
# Actual Cargo discovery over coherent and interrupted group metadata; no Git effects.
set -euo pipefail
root="$(pwd -P)"
source scripts/ci/fixture-lifecycle.sh
fixture="$(fixture_create "${TMPDIR:-/tmp}/shared-bootstrap.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Bootstrap observation fixture retained"' EXIT
workspace="$fixture/workspace with spaces"
mkdir -p "$workspace/ci"
cat > "$workspace/ci/cargo-release-groups.json" <<'JSON'
{"schema":1,"groups":[
 {"name":"core","primary":"core","version":"package","members":["core","storage"],"changelog":"releases/core/CHANGELOG.md","dependencies":["core","storage"]},
 {"name":"metrics","primary":"metrics","version":"package","members":["metrics"],"changelog":"releases/metrics/CHANGELOG.md","dependencies":["metrics"]},
 {"name":"logging","primary":"logging","version":"package","members":["logging"],"changelog":"releases/logging/CHANGELOG.md","dependencies":["logging"]}]}
JSON
cat > "$workspace/Cargo.toml" <<'TOML'
[workspace]
resolver = "3"
members = ["crates/*"]
[workspace.dependencies]
core = { path = "crates/core", version = "1.2.3" }
storage = { path = "crates/storage", version = "1.2.3" }
metrics = { path = "crates/metrics", version = "1.2.3" }
logging = { path = "crates/logging", version = "1.2.3" }
TOML
printf 'version = 4\n' > "$workspace/Cargo.lock"
for package in core storage metrics logging; do
    mkdir -p "$workspace/crates/$package/src"
    printf '[package]\nname = "%s"\nversion = "1.2.3"\nedition = "2021"\n' "$package" > "$workspace/crates/$package/Cargo.toml"
    : > "$workspace/crates/$package/src/lib.rs"
    printf '[[package]]\nname = "%s"\nversion = "1.2.3"\n' "$package" >> "$workspace/Cargo.lock"
done
observe() (cd "$workspace" && bash "$root/scripts/ci/observe-cargo-release-bootstrap.sh" "$@")
cp "$workspace/Cargo.lock" "$fixture/original-lock"
cp "$workspace/ci/cargo-release-groups.json" "$fixture/original-policy"
observe policy > "$fixture/policy.json"
cmp "$fixture/policy.json" <(jq '.' "$fixture/original-policy")
(cd "$workspace" && cargo metadata --locked --offline --format-version 1) > "$fixture/metadata.json"
yq -p toml -o json '.' "$workspace/Cargo.toml" > "$fixture/catalog.json"
yq -p toml -o json '.' "$workspace/Cargo.lock" > "$fixture/lock.json"
printf '{}\n' > "$fixture/manifests.json"
for package in core storage metrics logging; do
    yq -p toml -o json '.' "$workspace/crates/$package/Cargo.toml" > "$fixture/member.json"
    jq --arg name "$package" --slurpfile member "$fixture/member.json" '. + {($name):$member[0]}' "$fixture/manifests.json" > "$fixture/next.json"
    mv "$fixture/next.json" "$fixture/manifests.json"
done
for group in core metrics logging; do
    jq -e -L "$root/scripts/ci" --slurpfile policy "$fixture/policy.json" --slurpfile catalog "$fixture/catalog.json" \
        --slurpfile lock "$fixture/lock.json" --slurpfile manifests "$fixture/manifests.json" --arg group "$group" \
        'include "cargo-release-groups"; admit_groups($policy[0];$catalog[0];$manifests[0];$lock[0];$group)' \
        "$fixture/metadata.json" > "$fixture/$group.admitted.json"
done
observe observe > "$fixture/coherent.json"
jq -e '.coherent and (.groups | length == 3)' "$fixture/coherent.json" > /dev/null
for package in core metrics logging; do
    for mode in manifest-first lock-first; do
        cp "$fixture/original-lock" "$workspace/Cargo.lock"
        if [[ "$mode" == manifest-first ]]; then
            sed 's/1.2.3/1.2.4/' "$workspace/crates/$package/Cargo.toml" > "$fixture/changed"
            cp "$workspace/crates/$package/Cargo.toml" "$fixture/manifest"
            cp "$fixture/changed" "$workspace/crates/$package/Cargo.toml"
        else
            # Core owns two members; a lock transaction changes both together.
            awk -v group="$package" '
                /^name = / { selected = ($0 == "name = \"" group "\"" || (group == "core" && $0 == "name = \"storage\"")) }
                selected && /^version = / {$0 = "version = \"1.2.4\""}
                {print}
            ' "$fixture/original-lock" > "$workspace/Cargo.lock"
        fi
        shasum -a 256 "$workspace/Cargo.toml" "$workspace/Cargo.lock" "$workspace"/crates/*/Cargo.toml > "$fixture/before.sha256"
        observe observe > "$fixture/$package-$mode.json"
        jq -e '(.coherent | not) and (.groups | length == 3)' "$fixture/$package-$mode.json" > /dev/null
        shasum -a 256 -c "$fixture/before.sha256" > /dev/null
        if [[ "$mode" == manifest-first ]]; then cp "$fixture/manifest" "$workspace/crates/$package/Cargo.toml"; fi
    done
done
cp "$fixture/original-lock" "$workspace/Cargo.lock"
for change in '.schema = 2' '.groups[1].members = ["core"]' '.groups[0].metadata_files = ["../escape"]' '.groups[0].extra = true'; do
    jq "$change" "$fixture/original-policy" > "$workspace/ci/cargo-release-groups.json"
    if observe policy > "$fixture/refused.json" 2> "$fixture/refused.stderr"; then exit 1; fi
done
cp "$fixture/original-policy" "$workspace/ci/cargo-release-groups.json"
for change in missing duplicate malformed foreign; do
    cp "$fixture/original-lock" "$workspace/Cargo.lock"
    case "$change" in
        missing) sed '/name = "logging"/,$d' "$fixture/original-lock" > "$workspace/Cargo.lock" ;;
        duplicate) printf '[[package]]\nname = "core"\nversion = "1.2.3"\n' >> "$workspace/Cargo.lock" ;;
        malformed) printf 'not toml [' > "$workspace/Cargo.lock" ;;
        foreign) printf '[[package]]\nname = "foreign"\nversion = "1.2.3"\n' >> "$workspace/Cargo.lock" ;;
    esac
    if observe observe > "$fixture/refused.json" 2> "$fixture/refused.stderr"; then exit 1; fi
done
fixture_complete=true
printf '%s\n' 'Shared policy and six interrupted bootstrap observations passed; real source remained unchanged.'
