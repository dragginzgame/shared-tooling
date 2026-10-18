#!/usr/bin/env bash
# Shared companions: scripts/ci/read-cargo-source-context.sh scripts/ci/render-cargo-workspace-version.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail

root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(CDPATH='' cd -P -- "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/cargo-source-context-test.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Cargo source context fixtures retained"' EXIT
helper="$root/scripts/ci/read-cargo-source-context.sh"
mkdir -p "$fixture/source/crates/first member" "$fixture/source/apps/second" "$fixture/bin"
git -C "$fixture/source" init -q
git -C "$fixture/source" config user.name Fixture
git -C "$fixture/source" config user.email fixture@example.invalid
git -C "$fixture/source" config core.hooksPath /dev/null
cat > "$fixture/source/Cargo.toml" <<'TOML'
[workspace]
members = ["crates/first member", "apps/second"]
[workspace.package]
version = "0.1.0"
[workspace.dependencies]
renamed = { package = "first", path = "crates/first member", version = "0.1" }
TOML
printf '[package]\nname = "first"\n' > "$fixture/source/crates/first member/Cargo.toml"
printf '[package]\nname = "second"\n' > "$fixture/source/apps/second/Cargo.toml"
git -C "$fixture/source" add Cargo.toml 'crates/first member/Cargo.toml' apps/second/Cargo.toml
git -C "$fixture/source" -c commit.gpgsign=false commit -qm Fixture
source_commit="$(git -C "$fixture/source" rev-parse HEAD)"
"${YQ:-yq}" -p toml -o json '.' "$fixture/source/Cargo.toml" > "$fixture/manifest.json"
cp "$fixture/source/Cargo.toml" "$fixture/saved.toml"
printf 'invalid live TOML\n' > "$fixture/source/crates/first member/Cargo.toml"
rm "$fixture/source/apps/second/Cargo.toml"
capture() {
    bash "$helper" "$fixture/source" "$source_commit" "$fixture/manifest.json" "$@"
}
capture 'crates/first member' apps/second > "$fixture/context.json"
jq -e '.source_root == "/release-source" and
    [.members[].name] == ["first", "second"] and
    .members[0].manifest_path == "/release-source/crates/first member/Cargo.toml"' \
    "$fixture/context.json" > /dev/null
perl "$root/scripts/ci/render-cargo-workspace-version.pl" "$fixture/saved.toml" \
    0.1.0 0.2.0 "$fixture/context.json" > "$fixture/rendered.toml"
"${YQ:-yq}" -p toml -o json '.' "$fixture/rendered.toml" |
    jq -e '.workspace.package.version == "0.2.0" and .workspace.dependencies.renamed.version == "0.2"' > /dev/null
# Every refusal emits no context, including failures after valid partial stdout.
refuse() {
    if capture "$@" > "$fixture/refused.json" 2> "$fixture/refused.log"; then
        echo 'invalid source context accepted' >&2; exit 1
    fi
    [[ ! -s "$fixture/refused.json" ]]
}
for path in /absolute ../escape crates/../first 'crates/*' 'crates//first' 'crates/./first' '' $'bad\npath'; do
    refuse "$path"
done
refuse missing/member
refuse 'crates/first member' 'crates/first member'
selected_commit="$source_commit"
source_commit="$(git -C "$fixture/source" rev-parse 'HEAD^{tree}')"
refuse 'crates/first member'
source_commit=main
refuse 'crates/first member'
source_commit="$selected_commit"
real_git="$(command -v git)"
real_yq="$(command -v "${YQ:-yq}")"
export CONTEXT_REAL_GIT="$real_git" CONTEXT_REAL_YQ="$real_yq"
cat > "$fixture/bin/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
"$CONTEXT_REAL_GIT" "$@"
if [[ "$3" == show ]]; then exit 23; fi
STUB
cat > "$fixture/bin/yq" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
"$CONTEXT_REAL_YQ" "$@"
exit 24
STUB
chmod +x "$fixture/bin/git" "$fixture/bin/yq"
PATH="$fixture/bin:$PATH" refuse 'crates/first member'
mv "$fixture/bin/git" "$fixture/bin/disabled-git"
YQ="$fixture/bin/yq" refuse 'crates/first member'
# A successful parser must still produce exactly one package observation for
# each selected source member, never expand the caller's roster through a stream.
cat > "$fixture/bin/yq" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$CONTEXT_OBSERVATION"
STUB
for observation in \
    '{"package":{"name":"first"}} {"package":{"name":"extra"}}' \
    'null {"package":{"name":"first"}}' \
    '{"package":{"name":"first"}} []' \
    '' '{"package":{"name":"first"}} malformed'; do
    CONTEXT_OBSERVATION="$observation" YQ="$fixture/bin/yq" refuse 'crates/first member'
done
fixture_complete=true
