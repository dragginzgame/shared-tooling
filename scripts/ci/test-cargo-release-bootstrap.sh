#!/usr/bin/env bash
# Shared companions: scripts/ci/cargo-release-group.sh scripts/ci/observe-cargo-release-bootstrap.sh scripts/ci/fixture-lifecycle.sh scripts/ci/prepare-script-fixture.sh
set -euo pipefail
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/cargo-bootstrap-observation.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Bootstrap observation fixture retained"' EXIT
unset RELEASE_COMMIT RELEASE_VERSION RELEASE_PREVIOUS
export RUSTUP_AUTO_INSTALL=0 CARGO_NET_OFFLINE=true
mkdir "$fixture/exported"
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$fixture/exported" scripts/ci/observe-cargo-release-bootstrap.sh
observer="$fixture/exported/scripts/ci/observe-cargo-release-bootstrap.sh"
mkdir -p "$fixture/source with spaces/ci" "$fixture/bin"
cd "$fixture/source with spaces"
cat > Cargo.toml <<'TOML'
[workspace]
members = ["alpha", "alpha-helper", "beta", "gamma"]
resolver = "2"
[workspace.dependencies]
alpha = { path = "alpha", version = "^0.1.0" }
alpha-helper = { path = "alpha-helper", version = "=0.1.0" }
alias = { package = "beta", path = "beta", version = "~0.1.0" }
gamma = { path = "gamma", version = "0.1.0" }
TOML
for package in alpha alpha-helper beta gamma; do
    mkdir -p "$package/src"
    printf '[package]\nname = "%s"\nversion = "0.1.0"\nedition = "2021"\n' "$package" > "$package/Cargo.toml"
    : > "$package/src/lib.rs"
done
cat > ci/cargo-release-groups.json <<'JSON'
{"schema":1,"groups":[
 {"name":"alpha","primary":"alpha","version":"package","members":["alpha","alpha-helper"],"changelog":"alpha.md","dependencies":["alpha","alpha-helper"]},
 {"name":"beta","primary":"beta","version":"package","members":["beta"],"changelog":"beta.md","dependencies":["alias"]},
 {"name":"gamma","primary":"gamma","version":"package","members":["gamma"],"changelog":"gamma.md","dependencies":["gamma"]}
]}
JSON
cargo generate-lockfile --offline
for group in alpha beta gamma; do printf '# Group notes\n' > "$group.md"; done
cp -R . "$fixture/original"
observe() { bash "$observer" observe; }
bash "$observer" policy > "$fixture/policy.json"
jq -e '.schema == 1 and (.groups | length) == 3' "$fixture/policy.json" > /dev/null
for group in alpha beta gamma; do
    bash "$root/scripts/ci/cargo-release-group.sh" plan "$group" > "$fixture/$group.admitted.json"
done
for filter in '.schema = 2' '.groups[1].members = ["alpha"]' '.groups[0].metadata_files = ["../escape"]' '.groups[0].extra = true'; do
    jq "$filter" "$fixture/original/ci/cargo-release-groups.json" > ci/cargo-release-groups.json
    if bash "$observer" policy > "$fixture/refused.json" 2> "$fixture/refused.log"; then exit 1; fi
    [[ ! -s "$fixture/refused.json" ]]
done
cp "$fixture/original/ci/cargo-release-groups.json" ci/cargo-release-groups.json
refuse() {
    if observe > "$fixture/refused.json" 2> "$fixture/refused.log"; then
        echo 'unexpected bootstrap observation' >&2; exit 1
    fi
    [[ ! -s "$fixture/refused.json" ]]
}
reset_inputs() {
    cp "$fixture/original/Cargo.toml" Cargo.toml
    cp "$fixture/original/Cargo.lock" Cargo.lock
    cp "$fixture/original/ci/cargo-release-groups.json" ci/cargo-release-groups.json
    for package in alpha alpha-helper beta gamma; do cp "$fixture/original/$package/Cargo.toml" "$package/Cargo.toml"; done
}
change_lock() {
    awk -v name="$1" '
      /^name = / { selected = ($0 == "name = \"" name "\"" || (name == "alpha" && $0 == "name = \"alpha-helper\"")) }
      selected && /^version = / { sub("0.1.0", "0.2.0") }
      { print }' Cargo.lock > "$fixture/next.lock"
    cp "$fixture/next.lock" Cargo.lock
}
# Coherent, lock-first and manifest-first orders for every independent group,
# including groups unselected by the observer. No compiled editor is required.
for package in alpha beta gamma; do
    for state in coherent lock-first manifest-first catalog-first lock-catalog-first member-first; do
        reset_inputs
        case "$state" in lock-first|lock-catalog-first) change_lock "$package" ;; esac
        case "$state" in
            manifest-first|member-first)
                sed 's/0.1.0/0.2.0/g' "$fixture/original/$package/Cargo.toml" > "$package/Cargo.toml" ;;
        esac
        case "$state" in
            manifest-first|catalog-first|lock-catalog-first)
                awk -v package="$package" '{if ($0 ~ "path = \"" package "\"") sub("0.1.0", "0.2.0"); print}' \
                    "$fixture/original/Cargo.toml" > Cargo.toml ;;
        esac
        cp -R . "$fixture/before-$package-$state"
        observe > "$fixture/$package-$state.json"
        jq -e --arg state "$state" '
          .schema == 1 and ([.groups[].members[]] | length) == 4 and (.inputs | length) == 7 and
          all(.inputs[]; test("^[0-9a-f]{64}$")) and
          (.coherent == ($state == "coherent")) and
          (.catalog_edit.dependencies[] | select(.alias == "alias") | .next | startswith("~"))' \
          "$fixture/$package-$state.json" > /dev/null
        diff -r "$fixture/before-$package-$state" .
    done
done
reset_inputs
# Member identity is independent of whether anyone uses its root dependency alias.
for roster in partial empty; do
    for state in coherent lock-first manifest-first; do
        reset_inputs
        if [[ "$roster" == partial ]]; then
            sed '/^gamma = /d' "$fixture/original/Cargo.toml" > Cargo.toml
            jq '.groups[2].dependencies=[]' "$fixture/original/ci/cargo-release-groups.json" > ci/cargo-release-groups.json
        else
            sed '/^alpha = /d; /^alpha-helper = /d; /^alias = /d; /^gamma = /d' "$fixture/original/Cargo.toml" > Cargo.toml
            jq '.groups[].dependencies=[]' "$fixture/original/ci/cargo-release-groups.json" > ci/cargo-release-groups.json
        fi
        case "$state" in
            lock-first) change_lock gamma ;;
            manifest-first) sed 's/0.1.0/0.2.0/g' "$fixture/original/gamma/Cargo.toml" > gamma/Cargo.toml ;;
        esac
        cp -R . "$fixture/before-$roster-$state"
        observe > "$fixture/$roster-$state.json"
        jq -e --arg state "$state" --arg roster "$roster" '
          ([.groups[].members[]] | length) == 4 and (.inputs | length) == 7 and
          (.coherent == ($state == "coherent")) and
          (.catalog_edit.dependencies | length) == (if $roster == "partial" then 3 else 0 end)' \
          "$fixture/$roster-$state.json" > /dev/null
        diff -r "$fixture/before-$roster-$state" .
    done
done
reset_inputs
# The normal release boundary still refuses incoherent graphs.
change_lock beta
if bash "$root/scripts/ci/cargo-release-group.sh" plan alpha > "$fixture/plan.log" 2>&1; then exit 1; fi
reset_inputs
for fault in missing duplicate foreign malformed unsupported lock-format missing-alias incomplete-alias wrong-path invalid-group; do
    reset_inputs
    case "$fault" in
        missing) awk 'BEGIN {RS="\\[\\[package\\]\\]"} !/name = "beta"/ {if (NR > 1) printf "[[package]]"; printf "%s", $0}' Cargo.lock > "$fixture/bad.lock"; cp "$fixture/bad.lock" Cargo.lock ;;
        duplicate) printf '\n[[package]]\nname = "beta"\nversion = "0.1.0"\n' >> Cargo.lock ;;
        foreign) printf '\n[[package]]\nname = "foreign"\nversion = "0.1.0"\n' >> Cargo.lock ;;
        malformed) printf '\nversion = [\n' >> Cargo.lock ;;
        unsupported) sed 's/0.1.0/0.1.0-beta/g' "$fixture/original/beta/Cargo.toml" > beta/Cargo.toml ;;
        lock-format) sed 's/^version = 4$/version = 99/' "$fixture/original/Cargo.lock" > Cargo.lock ;;
        missing-alias) sed '/^alias = /d' "$fixture/original/Cargo.toml" > Cargo.toml ;;
        incomplete-alias) sed 's/~0.1.0/~0.1/' "$fixture/original/Cargo.toml" > Cargo.toml ;;
        wrong-path) sed 's/path = "beta"/path = "gamma"/' "$fixture/original/Cargo.toml" > Cargo.toml ;;
        invalid-group) jq '.groups[1].members=["alpha"]' "$fixture/original/ci/cargo-release-groups.json" > ci/cargo-release-groups.json ;;
    esac
    refuse
done
reset_inputs
for suffix in $'\n' $'\r' $'\t'; do
    invalid="$fixture/invalid$suffix"
    mkdir "$invalid"
    cp -R "$fixture/original/." "$invalid/"
    (cd "$invalid"; refuse)
    grep -F 'invalid bootstrap directory' "$fixture/refused.log" > /dev/null
done
observe > "$fixture/comments-before.json"
printf '\n# Byte identity matters even with unchanged declared versions.\n' >> beta/Cargo.toml
observe > "$fixture/comments-after.json"
jq -n -e --slurpfile before "$fixture/comments-before.json" --slurpfile after "$fixture/comments-after.json" '
    $before[0].groups == $after[0].groups and $before[0].inputs != $after[0].inputs' > /dev/null
reset_inputs
real_yq="$(command -v yq)"
export BOOTSTRAP_REAL_YQ="$real_yq" BOOTSTRAP_SOURCE="$PWD"
cat > "$fixture/bin/yq" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
"$BOOTSTRAP_REAL_YQ" "$@"
case "${BOOTSTRAP_MODE:-}" in
    fail) exit 27 ;;
    mutate) printf '\n# mutation during parser dispatch\n' >> "$BOOTSTRAP_SOURCE/Cargo.toml" ;;
esac
SH
chmod +x "$fixture/bin/yq"
export YQ="$fixture/bin/yq"
BOOTSTRAP_MODE=fail refuse
BOOTSTRAP_MODE=mutate refuse
reset_inputs
unset YQ
export BOOTSTRAP_REAL_CARGO
BOOTSTRAP_REAL_CARGO="$(command -v cargo)"
cat > "$fixture/bin/cargo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == metadata && "$*" == *--no-deps* && "$*" == *--locked* && "$*" == *--offline* ]]
"$BOOTSTRAP_REAL_CARGO" "$@"
exit 29
SH
chmod +x "$fixture/bin/cargo"
PATH="$fixture/bin:$PATH" refuse
grep -F 'Bootstrap observation evidence retained:' "$fixture/refused.log" > /dev/null
observe > "$fixture/final.json"
diff -r "$fixture/original" .
fixture_complete=true
echo 'Read-only bootstrap observation, interrupted groups, malformed identities and parser drift passed'
