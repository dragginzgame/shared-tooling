#!/usr/bin/env bash
# Shared companions: rust-toolchain.toml .github/workflows/ci.yml .github/workflows/cargo-install-qualification.yml scripts/dev/prepare-rust-toolchain.sh scripts/ci/fixture-lifecycle.sh scripts/ci/extract-workflow-step.sh scripts/ci/prepare-script-fixture.sh
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(CDPATH='' cd -P -- "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/shared-toolchain.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Shared compiler fixture retained"' EXIT
checkout="$fixture/shared checkout"
mkdir -p "$checkout" "$fixture/bin" "$fixture/runner"
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$checkout" \
    rust-toolchain.toml scripts/dev/prepare-rust-toolchain.sh
mkdir -p "$checkout/.tools/host/bin"
# Only effectful leaves are substituted. Execute both actual workflow bodies
# and the real TOML-reading installer; no compiler download or tool build runs.
cat > "$fixture/bin/make" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
    '--no-print-directory install-host-tools'|'--no-print-directory host-tools-check') ;;
    *) exit 91 ;;
esac
printf '%s\n' "$*" >> "$TOOLCHAIN_CALLS"
STUB
cat > "$fixture/bin/rustup" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$TOOLCHAIN_CALLS"
exit "$TOOLCHAIN_STATUS"
STUB
cat > "$checkout/scripts/ci/cargo-tool-cache-key.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == ci/tool-versions.env ]] || exit 91
printf 'cache identity\n' >> "$TOOLCHAIN_CALLS"
STUB
cat > "$checkout/scripts/ci/qualify-cargo-install.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "$RUNNER_TEMP/portable-fixtures/cargo-install" ]] || exit 91
printf 'registry qualification\n' >> "$TOOLCHAIN_CALLS"
STUB
chmod +x "$fixture/bin/"*
export TOOLCHAIN_CALLS="$fixture/calls" TOOLCHAIN_STATUS=0
export GITHUB_WORKSPACE="$checkout" RUNNER_TEMP="$fixture/runner" GITHUB_OUTPUT="$fixture/output"
channel="$(yq -p toml -o json '.toolchain.channel' "$ROOT/rust-toolchain.toml" | jq -r '.')"
[[ "$channel" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
for workflow in ci cargo-install-qualification; do
    step=qualification
    [[ "$workflow" != ci ]] || step=tool-cache-key
    yq -o json '.' "$ROOT/.github/workflows/$workflow.yml" | jq '[.jobs[].steps[]]' > "$fixture/steps.json"
    bash "$ROOT/scripts/ci/extract-workflow-step.sh" "$fixture/steps.json" "$step" > "$fixture/run.sh"
    for TOOLCHAIN_STATUS in 0 49; do
        : > "$TOOLCHAIN_CALLS"
        : > "$GITHUB_OUTPUT"
        : > "$fixture/expected"
        if [[ "$workflow" == ci ]]; then
            printf '%s\n' '--no-print-directory install-host-tools' '--no-print-directory host-tools-check' >> "$fixture/expected"
        fi
        printf 'toolchain install %s --profile minimal --component rustfmt --component clippy\n' "$channel" >> "$fixture/expected"
        if [[ "$TOOLCHAIN_STATUS" == 0 ]]; then
            if [[ "$workflow" == ci ]]; then printf 'cache identity\n'
            else printf 'registry qualification\n'; fi >> "$fixture/expected"
        fi
        status=0
        (cd "$checkout" && PATH="$fixture/bin:$PATH" "$BASH" --noprofile --norc -e -o pipefail "$fixture/run.sh") \
            > "$fixture/$workflow-$TOOLCHAIN_STATUS.log" 2>&1 || status=$?
        [[ "$status" == "$TOOLCHAIN_STATUS" ]] || exit 1
        cmp "$fixture/expected" "$TOOLCHAIN_CALLS"
    done
done
echo 'Shared compiler preparation precedes cache identity and registry builds; setup failure stops both'
fixture_complete=true
