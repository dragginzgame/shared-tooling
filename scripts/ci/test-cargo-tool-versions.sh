#!/usr/bin/env bash
# Shared companions: scripts/dev/check-cargo-tool-versions.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"; ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/cargo-version-test.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Cargo version fixture retained"' EXIT
export VERSION_FIXTURE="$fixture"
mkdir -p "$fixture/bin" "$fixture/home" "$fixture/consumer/ci" "$fixture/consumer/.tools/rust/common/bin" "$fixture/bundle/bin" "$fixture/evidence"
export TMPDIR="$fixture/evidence"
cat > "$fixture/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -eu
if [[ "$*" == '--disable --version' ]]; then echo "curl ${VERSION_CURL:-8.4.0} fixture"; exit 0; fi
url="${!#}"; package="${url##*/}"
printf '%s\n' "$*" >> "$VERSION_FIXTURE/calls"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) cp "$VERSION_FIXTURE/$package.json" "$2"; shift 2 ;;
        --stderr) : > "$2"; shift 2 ;;
        *) shift ;;
    esac
done
printf '%s' "${VERSION_HTTP:-200}"
exit "${VERSION_TRANSPORT:-0}"
CURL
chmod +x "$fixture/bin/curl"
export PATH="$fixture/bin:$PATH"
mkdir -p "$fixture/snapshot/scripts/ci" "$fixture/snapshot/scripts/dev" "$fixture/snapshot/ci"
cp "$ROOT/scripts/ci/StableVersion.pm" "$fixture/snapshot/scripts/ci/"
cp "$ROOT/scripts/ci/tool-catalog-records.pl" "$fixture/snapshot/scripts/ci/"
cp "$ROOT/scripts/dev/check-cargo-tool-versions.pl" "$fixture/snapshot/scripts/dev/"
printf 'export SHARED_TOOLING_CARGO_SORT_VERSION=2.1.4\n' > "$fixture/consumer/ci/tool-versions.env"
printf 'SHARED_TOOLING_CARGO_SORT_DERIVES_VERSION=0.14.1\n' >> "$fixture/consumer/ci/tool-versions.env"
cp "$fixture/consumer/ci/tool-versions.env" "$fixture/snapshot/ci/tool-versions.env"
printf 'fixture binary; never execute\n' > "$fixture/bundle/bin/cargo-sort"
ln -s "$fixture/bundle/bin/cargo-sort" "$fixture/consumer/.tools/rust/common/bin/cargo-sort"
jq -n '{installs:{"cargo-sort 2.1.4 (registry+https://github.com/rust-lang/crates.io-index)":{}}}' > "$fixture/bundle/.crates2.json"
tool=cargo-sort-derives version=0.14.1
printf 'fixture binary; never execute\n' > "$fixture/bundle/bin/$tool"
ln -s "$fixture/bundle/bin/$tool" "$fixture/consumer/.tools/rust/common/bin/$tool"
jq --arg name "$tool $version (registry+https://github.com/rust-lang/crates.io-index)" \
    '.installs[$name]={}' "$fixture/bundle/.crates2.json" > "$fixture/receipt.next"
cp "$fixture/receipt.next" "$fixture/bundle/.crates2.json"
jq -n --arg tool "$tool" --arg version "$version" \
    '{crate:{id:$tool},versions:[{crate:$tool,num:$version,yanked:false}]}' > "$fixture/$tool.json"
cp "$fixture/bundle/.crates2.json" "$fixture/home/.crates2.json"
jq '.installs["twiggy 0.8.0 (registry+https://github.com/rust-lang/crates.io-index)"]={}' "$fixture/home/.crates2.json" > "$fixture/global-receipt"
cp "$fixture/global-receipt" "$fixture/home/.crates2.json"
jq -n '{crate:{id:"twiggy"},versions:[{crate:"twiggy",num:"0.8.0",yanked:false}]}' > "$fixture/twiggy.json"
jq -n '{crate:{id:"cargo-sort"},versions:[
 {crate:"cargo-sort",num:"2.1.4",yanked:false,rust_version:"1.82"},
 {crate:"cargo-sort",num:"3.0.0-rc.1",yanked:false},
 {crate:"cargo-sort",num:"4.0.0",yanked:true}]}' > "$fixture/cargo-sort.json"
run() {
    local expected="$1" status=0
    perl "$fixture/snapshot/scripts/dev/check-cargo-tool-versions.pl" --consumer "$fixture/consumer" \
        --versions "$fixture/consumer/ci/tool-versions.env" --cargo-home "$fixture/home" --json > "$fixture/report.json" 2> "$fixture/stderr" || status=$?
    [[ "$status" == "$expected" ]] || { cat "$fixture/report.json" "$fixture/stderr"; exit 1; }
}
run 0
# Default selection comes from the executing snapshot, never the consumer file.
printf 'not a pin catalog\n' > "$fixture/consumer/ci/tool-versions.env"
perl "$fixture/snapshot/scripts/dev/check-cargo-tool-versions.pl" --consumer "$fixture/consumer" \
    --cargo-home "$fixture/home" --json > "$fixture/default.json"
jq -e '(.tools[] | select(.tool=="cargo-sort")).pinned=="2.1.4"' "$fixture/default.json" >/dev/null
cp "$fixture/snapshot/ci/tool-versions.env" "$fixture/consumer/ci/tool-versions.env"
jq -e '(.tools[] | select(.tool=="cargo-sort")) | .status=="current" and .latest=="2.1.4" and .local=="2.1.4" and .global=="2.1.4"' "$fixture/report.json" > /dev/null
jq -e '(.tools[] | select(.tool=="twiggy")) | .tool=="twiggy" and .pinned==null and .local==null and .status=="current"' "$fixture/report.json" > /dev/null
# Compute numeric latest from eligible versions, independently of ordering or max fields.
jq '.versions += [{crate:"cargo-sort",num:"2.1.10",yanked:false},{crate:"cargo-sort",num:"2.1.9",yanked:false}]' "$fixture/cargo-sort.json" > "$fixture/new.json"
cp "$fixture/new.json" "$fixture/cargo-sort.json"
run 1
jq -e '(.tools[] | select(.tool=="cargo-sort")) | .latest=="2.1.10" and (.status|contains("pinned outdated"))' "$fixture/report.json" > /dev/null
evidence="$(jq -r .evidence "$fixture/report.json")"
cmp "$fixture/cargo-sort.json" "$evidence/cargo-sort.json"
[[ -s "$evidence/cargo-sort.request" ]]
# A separately selected local version is visible, as is a missing local binary.
sed 's/2.1.4/2.1.10/g' "$fixture/bundle/.crates2.json" > "$fixture/changed-receipt"
cp "$fixture/changed-receipt" "$fixture/bundle/.crates2.json"
run 1
jq -e '(.tools[] | select(.tool=="cargo-sort")).status | contains("local differs from pin")' "$fixture/report.json" > /dev/null
rm "$fixture/consumer/.tools/rust/common/bin/cargo-sort"
run 1
jq -e '(.tools[] | select(.tool=="cargo-sort")).status | contains("local missing")' "$fixture/report.json" > /dev/null
# Unavailable observations cannot become a false current result.
for http in 404 429 503; do VERSION_HTTP="$http" run 2; done
VERSION_HTTP=200 VERSION_TRANSPORT=28 run 2
jq -e '(.tools[] | select(.tool=="cargo-sort")).status=="ERROR"' "$fixture/report.json" > /dev/null
cp "$fixture/cargo-sort.json" "$fixture/valid.json"
for malformed in identity invalid yanked; do
    case "$malformed" in
        identity) jq '.crate.id="other"' "$fixture/valid.json" > "$fixture/cargo-sort.json" ;;
        invalid) printf 'not JSON\n' > "$fixture/cargo-sort.json" ;;
        yanked) jq '.versions[].yanked="false"' "$fixture/valid.json" > "$fixture/cargo-sort.json" ;;
    esac
    run 2
    jq -e '(.tools[] | select(.tool=="twiggy")).status=="current"' "$fixture/report.json" > /dev/null
done
cp "$fixture/valid.json" "$fixture/cargo-sort.json"
VERSION_CURL=8.3.0 run 2
cat > "$fixture/consumer/ci/tool-versions.env" <<'PINS'
SHARED_TOOLING_CARGO_SORT_VERSION=$(touch "$VERSION_FIXTURE/unexpected") # pin=2.1.4
PINS
run 2
[[ ! -e "$fixture/unexpected" ]]
# Unsupported registry identities and malformed receipts are incomplete checks.
cp "$fixture/snapshot/ci/tool-versions.env" "$fixture/consumer/ci/tool-versions.env"
printf '{"installs":{"twiggy 0.8.0 (git+https://example.invalid/repo)":{}}}\n' > "$fixture/home/.crates2.json"
run 2
printf 'invalid JSON\n' > "$fixture/home/.crates2.json"
run 2
# Registry ordering uses the same exact comparator as release admission, even
# beyond native integer precision. Neither release order nor input order wins.
cp "$fixture/bundle/.crates2.json" "$fixture/home/.crates2.json"
jq '.versions += [
 {crate:"cargo-sort",num:"18446744073709551617.0.0",yanked:false},
 {crate:"cargo-sort",num:"18446744073709551616.0.0",yanked:false}]' \
    "$fixture/valid.json" > "$fixture/cargo-sort.json"
run 1
jq -e '(.tools[] | select(.tool=="cargo-sort")).latest=="18446744073709551617.0.0"' "$fixture/report.json" >/dev/null
echo 'Cargo version freshness, separate selections and incomplete observation tests passed (substitute registry)'
# Optional binary-installed sccache participates in freshness without becoming
# a required common Cargo installation or assuming a Cargo receipt exists.
printf '\nSHARED_TOOLING_SCCACHE_VERSION=0.19.0\nSHARED_TOOLING_SCCACHE_SHA256_LINUX_AMD64=%064d\n' 0 >> "$fixture/snapshot/ci/tool-versions.env"
# The CI catalog parser admits the common group before the optional selection.
for entry in ACTIONLINT:LINUX_AMD64 SHELLCHECK:LINUX_X86_64 GITLEAKS:LINUX_X64; do
    printf 'SHARED_TOOLING_%s_VERSION=1.0.0\nSHARED_TOOLING_%s_SHA256_%s=%064d\n' "${entry%:*}" "${entry%:*}" "${entry#*:}" 0 >> "$fixture/snapshot/ci/tool-versions.env"
done
jq -n '{crate:{id:"sccache"},versions:[{crate:"sccache",num:"0.19.0",yanked:false}]}' > "$fixture/sccache.json"
perl "$fixture/snapshot/scripts/dev/check-cargo-tool-versions.pl" --consumer "$fixture/consumer" --cargo-home "$fixture/home" --tool sccache --json > "$fixture/sccache-report.json"
jq -e '.tools|length==1' "$fixture/sccache-report.json" >/dev/null
jq -e '.tools[0]|.tool=="sccache" and .status=="current" and .local==null' "$fixture/sccache-report.json" >/dev/null
# A targeted check admits only its package's global/local receipt identities.
# Ordinary Git, alternate-registry and prerelease installations remain visible
# to a full inventory but cannot block observing a different selected tool.
cp "$fixture/valid.json" "$fixture/cargo-sort.json"
ln -s "$fixture/bundle/bin/cargo-sort" "$fixture/consumer/.tools/rust/common/bin/cargo-sort"
jq '.installs += {
 "twiggy 0.8.0 (git+https://example.invalid/repo)":{},
 "preview-tool 1.0.0-rc.1 (registry+https://github.com/rust-lang/crates.io-index)":{},
 "private-tool 1.0.0 (registry+https://example.invalid/index)":{}
}' "$fixture/bundle/.crates2.json" > "$fixture/mixed-receipt.json"
cp "$fixture/mixed-receipt.json" "$fixture/home/.crates2.json"
cp "$fixture/mixed-receipt.json" "$fixture/bundle/.crates2.json"
sed 's/SHARED_TOOLING_CARGO_SORT_VERSION=2.1.4/SHARED_TOOLING_CARGO_SORT_VERSION=2.1.10/' \
    "$fixture/snapshot/ci/tool-versions.env" > "$fixture/current-pins"
cp "$fixture/current-pins" "$fixture/snapshot/ci/tool-versions.env"
single() {
    local expected="$1" tool="$2" status=0
    : > "$fixture/calls"
    perl "$fixture/snapshot/scripts/dev/check-cargo-tool-versions.pl" --consumer "$fixture/consumer" \
        --cargo-home "$fixture/home" --tool "$tool" --json > "$fixture/single.json" 2> "$fixture/single.stderr" || status=$?
    [[ "$status" == "$expected" ]] || { cat "$fixture/single.json" "$fixture/single.stderr"; exit 1; }
}
for tool in sccache cargo-sort; do
    single 0 "$tool"
    jq -e --arg tool "$tool" '.tools | length == 1 and .[0].tool == $tool and .[0].status == "current"' "$fixture/single.json" >/dev/null
    [[ "$(wc -l < "$fixture/calls" | tr -d ' ')" == 1 ]] || exit 1
    grep -F "https://crates.io/api/v1/crates/$tool" "$fixture/calls" >/dev/null
done
single 2 twiggy
[[ ! -s "$fixture/calls" ]] || exit 1
single 2 preview-tool
single 2 private-tool
cp "$fixture/snapshot/ci/tool-versions.env" "$fixture/consumer/ci/tool-versions.env"
run 2
grep -E 'unsupported installation identity|non-stable' "$fixture/stderr" >/dev/null
printf 'invalid JSON\n' > "$fixture/home/.crates2.json"
single 2 sccache
printf '{"installs":{"ambiguous":{}}}\n' > "$fixture/home/.crates2.json"
single 2 sccache
printf '{"installs":{"sccache 0.19.0 (registry+https://github.com/rust-lang/crates.io-index)":{},"sccache 0.18.0 (registry+https://github.com/rust-lang/crates.io-index)":{}}}\n' > "$fixture/home/.crates2.json"
single 2 sccache
# Restore valid observations for the existing outdated-version case below.
printf '{"installs":{}}\n' > "$fixture/home/.crates2.json"
jq '.versions += [{crate:"sccache",num:"0.20.0",yanked:false}]' "$fixture/sccache.json" > "$fixture/sccache-new.json"
cp "$fixture/sccache-new.json" "$fixture/sccache.json"
status=0
perl "$fixture/snapshot/scripts/dev/check-cargo-tool-versions.pl" --consumer "$fixture/consumer" --cargo-home "$fixture/home" --tool sccache --json > "$fixture/sccache-outdated.json" || status=$?
[[ "$status" == 1 ]] || exit 1
jq -e '.tools[0].status|contains("pinned outdated")' "$fixture/sccache-outdated.json" >/dev/null
fixture_complete=true
