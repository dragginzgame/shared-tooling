#!/usr/bin/env bash
# Shared companions: scripts/dev/install-host-tools.sh scripts/dev/install-ic-tools.sh scripts/dev/install-rust-tools.sh scripts/ci/check-tool-catalogs.pl scripts/ci/prepare-script-fixture.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(CDPATH='' cd -P -- "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/tool-selection.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Tool selection fixture retained"' EXIT
consumer="$fixture/consumer"
mkdir -p "$consumer" "$fixture/bin"
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$consumer" \
    scripts/dev/install-host-tools.sh scripts/dev/install-rust-tools.sh scripts/dev/install-ic-tools.sh
for command in cargo rustc rustup curl; do
    printf '#!/bin/sh\necho forbidden-tool-execution >&2\nexit 91\n' > "$fixture/bin/$command"
    chmod +x "$fixture/bin/$command"
done
export PATH="$fixture/bin:$PATH"
for kind in host rust ic; do
    args=()
    [[ "$kind" != ic ]] || args=(--tool wasm-opt)
    bash "$consumer/scripts/dev/install-$kind-tools.sh" --consumer "$consumer" ${args[@]+"${args[@]}"} --describe > "$fixture/$kind.json"
    jq -e --arg kind "$kind" --arg consumer "$consumer" '.kind == $kind and .consumer == $consumer and (.records | length > 0)' "$fixture/$kind.json" >/dev/null
    [[ ! -e "$consumer/.tools" ]] || exit 1
    if bash "$consumer/scripts/dev/install-$kind-tools.sh" --consumer "$consumer" ${args[@]+"${args[@]}"} --describe --check > "$fixture/conflict.log" 2>&1; then exit 1; fi
done
jq -e '.records | all(.tool == "wasm-opt")' "$fixture/ic.json" >/dev/null
bash "$consumer/scripts/dev/install-rust-tools.sh" --consumer "$consumer" --package ic-build --version 0.63.0 \
    --bin ic-build-release-metadata --profile debug --features cli,cli --describe > "$fixture/recipe.json"
jq -e '.package == "ic-build" and .features == "cli" and .version == "0.63.0" and .profile == "debug"' "$fixture/recipe.json" >/dev/null
[[ ! -e "$consumer/.tools" ]] || exit 1
cp "$fixture/rust.json" "$consumer/selection.json"
cat > "$consumer/bindings.json" <<'JSON'
{"workflows":[{"name":"fixture","kind":"rust","reference":"setup","callers":[
{"role":"setup","observation":"selection.json","exception":"isolated fixture catalog"},
{"role":"check","observation":"selection.json","exception":"isolated fixture catalog"}]}]}
JSON
perl "$root/scripts/ci/check-tool-catalogs.pl" --consumer "$consumer" --bindings bindings.json --json > "$fixture/agreement.json"
jq -e '.callers | all(.status == "AGREES")' "$fixture/agreement.json" >/dev/null
printf '# changed installer\n' >> "$consumer/scripts/dev/install-rust-tools.sh"
if perl "$root/scripts/ci/check-tool-catalogs.pl" --consumer "$consumer" --bindings bindings.json > "$fixture/stale.log"; then exit 1; fi
fixture_complete=true
echo 'Read-only installer selections, explicit recipes and captured catalog agreement passed'
