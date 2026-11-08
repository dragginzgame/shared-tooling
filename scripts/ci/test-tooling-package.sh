#!/usr/bin/env bash
# Shared companions: scripts/distribution/registry-package.pl scripts/ci/fixture-lifecycle.sh scripts/distribution/governance-files.txt scripts/ci/check-documentation-links.pl
set -euo pipefail
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
for path in make/consumer.mk scripts/dev/shared-tooling.sh .github/actions/cache-tool-downloads/action.yml licenses/MIT.txt ci/tool-versions.env; do
    [[ -f "$fixture/package/$path" ]] || { echo "missing published tooling file: $path" >&2; exit 1; }
done
[[ ! -e "$fixture/package/ci/frontend/node_modules" && ! -e "$fixture/package/docs/code-review" ]]
consumer="$fixture/consumer"
mkdir "$consumer"
git -C "$consumer" init -q
printf '# Consumer-owned README\n' > "$consumer/README.md"
printf '# Consumer-owned instructions\n' > "$consumer/AGENTS.md"
entrypoints=(--entrypoint make/consumer.mk --entrypoint scripts/dev/shared-tooling.sh)
while IFS= read -r path; do
    [[ -n "$path" && "$path" != \#* ]] || continue
    entrypoints+=(--entrypoint "$path")
done < "$fixture/package/scripts/distribution/governance-files.txt"
bash "$fixture/package/scripts/distribution/refresh-consumer.sh" --crate "$archive" --checksum "$checksum" \
    --package-version "$version" --consumer "$consumer" "${entrypoints[@]}"
printf 'version = 4\n[[package]]\nname = "toko-tooling"\nversion = "%s"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\nchecksum = "%s"\n' \
    "$version" "$checksum" > "$consumer/Cargo.lock"
make --no-print-directory -C "$consumer" -f make/consumer.mk shared-tooling-check
documents=()
while IFS= read -r path; do documents+=("${path#"$consumer/"}"); done < <(find "$consumer" -type f -name '*.md' -not -path '*/.git/*' | sort)
perl "$fixture/package/scripts/ci/check-documentation-links.pl" --root "$consumer" "${documents[@]}"
printf 'Published tooling source bundle installs its complete governance/Make closure and verifies offline.\n'
fixture_complete=true
