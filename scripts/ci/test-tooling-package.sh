#!/usr/bin/env bash
# Shared companions: scripts/distribution/registry-package.pl scripts/ci/fixture-lifecycle.sh scripts/ci/check-documentation-links.pl scripts/ci/test-vendor-snapshot.sh
set -euo pipefail
# The default remains the complete CI regression. Release/publication select
# only fresh archive installation; no previous result or archive is reused.
installation_only=false
case "$#:${1:-}" in
    0:) ;;
    1:--installation-only) installation_only=true ;;
    *) echo 'usage: test-tooling-package.sh [--installation-only]' >&2; exit 2 ;;
esac
ROOT="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd)"
export PATH="$ROOT/.tools/host/bin:$PATH"
mkdir -p "$ROOT/target/tmp"
fixture="$(mktemp -d "$ROOT/target/tmp/tooling-package.XXXXXX")"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Tooling source-package fixture retained"' EXIT
version="$(perl "$ROOT/scripts/ci/shared-package-version.pl" "$ROOT/Cargo.toml")"
# Cargo's archive verification is owned by publish-check/publish; this check
# qualifies the actual bundled scripts and documentation without compiling twice.
(cd "$ROOT" && cargo package --locked --offline --allow-dirty --no-verify)
archive="$ROOT/target/package/toko-tooling-$version.crate"
checksum="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$archive")"
perl "$ROOT/scripts/distribution/registry-package.pl" extract "$archive" "$checksum" "$version" "$fixture/package"
for path in make/consumer.mk scripts/dev/toko-tooling.sh .github/actions/cache-tool-downloads/action.yml LICENSE.md ci/tool-versions.env; do
    [[ -f "$fixture/package/$path" ]] || { echo "missing published tooling file: $path" >&2; exit 1; }
done
[[ ! -e "$fixture/package/ci/frontend/node_modules" && ! -e "$fixture/package/docs/code-review" ]]
consumer="$fixture/consumer"
mkdir "$consumer"
git -C "$consumer" init -q
printf '# Consumer-owned README\n' > "$consumer/README.md"
printf '# Consumer-owned instructions\n' > "$consumer/AGENTS.md"
entrypoints=(--entrypoint make/consumer.mk --entrypoint scripts/dev/toko-tooling.sh --entrypoint .githooks/pre-commit --entrypoint .github/actions/prepare-common-tools/action.yml)
checker=scripts/ci/check-public-docs.pl
[[ -f "$fixture/package/$checker" ]]
if [[ "$installation_only" == true ]]; then entrypoints+=(--entrypoint "$checker"); fi
for path in TOKO-TOOLING.md LICENSE.md CONTRIBUTING.md; do
    entrypoints+=(--entrypoint "$path")
done
bash "$fixture/package/scripts/distribution/refresh-consumer.sh" --crate "$archive" --checksum "$checksum" \
    --package-version "$version" --consumer "$consumer" "${entrypoints[@]}"
installed="$consumer/vendor/toko-tooling"
[[ -f "$installed/make/consumer.mk" && ! -e "$installed/make/release.mk" && ! -e "$installed/make/cargo-publication.mk" ]]
[[ ! -e "$consumer/scripts" && ! -e "$consumer/make" && ! -e "$consumer/docs" ]]
# GitHub resolves composite action uses from the checkout, not action_path.
while IFS= read -r action; do
    [[ -f "$consumer/${action#./}/action.yml" ]]
done < <(yq -r '.runs.steps[] | select(.uses != null) | .uses' "$installed/.github/actions/prepare-common-tools/action.yml" | sed -n '\|^\./|p')
# Publication exports its own package selection. This independent scratch
# consumer deliberately selects neither release nor publication components.
printf 'override CARGO_PUBLISH_PACKAGES :=\noverride TOKO_TOOLING_RELEASE := 0\ninclude vendor/toko-tooling/make/consumer.mk\n' > "$consumer/Makefile"
mkdir -p "$consumer/src" "$consumer/.cargo" "$fixture/vendor/toko-tooling"
printf '[package]\nname="fixture-consumer"\nversion="0.1.0"\nedition="2024"\n[dev-dependencies]\ntoko-tooling="=%s"\n' "$version" > "$consumer/Cargo.toml"
printf '' > "$consumer/src/lib.rs"
cp -Rp "$fixture/package/." "$fixture/vendor/toko-tooling/"
jq '{files: (.files | map_values(.checksum)), package: .checksum}' \
    "$fixture/vendor/toko-tooling/.toko-tooling.files.json" > "$fixture/vendor/toko-tooling/.cargo-checksum.json"
rm "$fixture/vendor/toko-tooling/.toko-tooling.files.json"
printf '[source.crates-io]\nreplace-with="fixture"\n[source.fixture]\ndirectory="%s"\n' "$fixture/vendor" > "$consumer/.cargo/config.toml"
(cd "$consumer" && cargo generate-lockfile --offline)
if [[ "$installation_only" == false ]]; then
    bash "$ROOT/scripts/ci/test-vendor-snapshot.sh"
    make --no-print-directory -C "$consumer" toko-tooling-check
    # A native checker is taken over only from a clean, reviewed consumer state.
    perl "$fixture/package/scripts/ci/test-public-docs.pl"
    mkdir -p "$installed/scripts/ci"
    printf '# Consumer-owned comparator\n' > "$installed/$checker"
    git -C "$consumer" add -- .
    git -C "$consumer" -c user.name=Fixture -c user.email=fixture@example.invalid \
        -c core.hooksPath=/dev/null -c commit.gpgSign=false commit -qm 'Native checker before adoption'
    cp "$consumer/.toko-tooling.snapshot" "$fixture/before.snapshot"
    entrypoints+=(--entrypoint "$checker")
    refresh=(bash "$fixture/package/scripts/distribution/refresh-consumer.sh" --crate "$archive" --checksum "$checksum"
        --package-version "$version" --consumer "$consumer" "${entrypoints[@]}")
    cp "$installed/$checker" "$fixture/local-checker"
    for state in clean unstaged staged; do
        if [[ "$state" == unstaged ]]; then printf '# Local checker edit\n' >> "$installed/$checker"; cp "$installed/$checker" "$fixture/local-checker"; fi
        if [[ "$state" == staged ]]; then git -C "$consumer" add -- "vendor/toko-tooling/$checker"; fi
        if "${refresh[@]}" > "$fixture/$state.log" 2>&1; then
            echo "checker takeover accepted $state changes" >&2; exit 1
        fi
        grep -E 'consumer destination (is not an unchanged owned snapshot file|has local changes)' "$fixture/$state.log" >/dev/null
        cmp "$fixture/local-checker" "$installed/$checker"
        cmp "$fixture/before.snapshot" "$consumer/.toko-tooling.snapshot"
    done
    git -C "$consumer" rm -q --force -- "vendor/toko-tooling/$checker"
    git -C "$consumer" -c user.name=Fixture -c user.email=fixture@example.invalid \
        -c core.hooksPath=/dev/null -c commit.gpgSign=false commit -qm 'Explicitly retire native collision'
    "${refresh[@]}" --preview
    cmp "$fixture/before.snapshot" "$consumer/.toko-tooling.snapshot"
    [[ ! -e "$installed/$checker" ]]
    "${refresh[@]}"
    while IFS= read -r entry; do
        grep -Fx -- "$entry" "$consumer/.toko-tooling.snapshot" >/dev/null
    done < <(grep '^# entrypoint' "$fixture/before.snapshot")
    printf 'Packaged installer takeover, refusal and preview regressions passed.\n'
fi
cmp "$fixture/package/$checker" "$installed/$checker"
printf '' > "$fixture/diagnostics.jsonl"
printf '[]\n' > "$fixture/baseline.json"
perl "$installed/$checker" "$fixture/diagnostics.jsonl" "$fixture/baseline.json"
make --no-print-directory -C "$consumer" toko-tooling-check
bash "$installed/scripts/dev/install-git-hooks.sh" --consumer "$consumer"
[[ "$(git -C "$consumer" config core.hooksPath)" == vendor/toko-tooling/.githooks ]]
documents=()
while IFS= read -r path; do documents+=("${path#"$consumer/"}"); done < <(find "$consumer" -type f -name '*.md' -not -path '*/.git/*' | sort)
perl "$fixture/package/scripts/ci/check-documentation-links.pl" --root "$consumer" "${documents[@]}"
printf 'Published tooling source bundle installs its complete governance/Make closure and verifies offline.\n'
fixture_complete=true
