#!/usr/bin/env bash
set -euo pipefail
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/fixture-retention-test.XXXXXX")"
trap 'if [[ $? == 0 ]]; then rm -rf "$fixture"; else echo "Retention fixtures retained: $fixture" >&2; fi' EXIT
mkdir "$fixture/bin" "$fixture/cloc" "$fixture/portable"
export RETENTION_REAL_BASH="$BASH"
cat > "$fixture/bin/cloc" <<'SCRIPT'
#!/usr/bin/env bash
exit 23
SCRIPT
# Write the absolute interpreter directly: BSD sed replacement can join lines.
printf '#!%s\n' "$BASH" > "$fixture/bin/bash"
cat >> "$fixture/bin/bash" <<'SCRIPT'
case "${1:-}" in */verify-file-checksum.sh) exit 24 ;; esac
exec "$RETENTION_REAL_BASH" "$@"
SCRIPT
chmod +x "$fixture/bin/"*
# Isolate the report from this checkout's prepared host set so the failing
# cloc substitute exercises retention even when local tools take precedence.
mkdir -p "$fixture/source/scripts/ci" "$fixture/source/scripts/dev"
cp "$ROOT/scripts/ci/test-cloc.sh" "$fixture/source/scripts/ci/"
cp "$ROOT/scripts/dev/cloc.sh" "$fixture/source/scripts/dev/"
status=0
TMPDIR="$fixture/cloc" PATH="$fixture/bin:$PATH" CARGO_NET_OFFLINE=true RUSTUP_AUTO_INSTALL=0 \
    "$BASH" "$fixture/source/scripts/ci/test-cloc.sh" > "$fixture/cloc.log" 2>&1 || status=$?
[[ "$status" == 23 ]] || exit 1
set -- "$fixture/cloc"/shared-tooling-cloc-test.*
[[ $# == 1 && -f "$1/Cargo.toml" && -f "$1/crates/alpha/src/lib.rs" ]] || exit 1

status=0
TMPDIR="$fixture/portable" PATH="$fixture/bin:$PATH" \
    "$BASH" "$ROOT/scripts/ci/test-portable-tools.sh" > "$fixture/portable.log" 2>&1 || status=$?
[[ "$status" == 24 ]] || exit 1
set -- "$fixture/portable"/shared-tooling-test.*
[[ $# == 1 && -f "$1/input.txt" ]] || exit 1

# Exercise the actual workflow's native qualification commands with a failed
# installer substitute, then check the final collector selects its evidence.
# This checks local ordering/paths; GitHub's upload service is qualified by CI.
yq -o json '.' "$ROOT/.github/workflows/ci.yml" > "$fixture/workflow.json"
yq -o json '.' "$ROOT/.github/actions/retain-failure-evidence/action.yml" > "$fixture/collector.json"
# A failed regression gate must still fail the job and reach failure collection.
jq -e '
  .jobs["portable-regression"] as $job |
  [$job.steps[] | select(.run? | strings | contains("bash scripts/ci/test-portable-tools.sh"))] as $gate |
  ($gate | length) == 1 and
  $gate[0]["continue-on-error"] != true
' "$fixture/workflow.json" > /dev/null
# shellcheck disable=SC2016 # GitHub expressions are literal workflow inputs.
jq -e '
  .jobs["portable-regression"].steps | to_entries |
  map(select(.value.run? | strings | contains("make --no-print-directory install-tools"))) as $native |
  map(select(.value.uses == "./.github/actions/retain-failure-evidence" and .value.if == "failure()")) as $uploads |
  ($native | length) == 1 and ($uploads | length) == 1 and
  $uploads[0].key > $native[0].key and $uploads[0].key == length - 1 and
  $uploads[0].value.with["temp-root"] == "${{ runner.temp }}" and
  $uploads[0].value.with["repository-root"] == "${{ github.workspace }}"
' "$fixture/workflow.json" > /dev/null
jq -e '.runs.steps | map(select(.uses? | strings | startswith("actions/upload-artifact@"))) |
  length == 1 and .[0].with["if-no-files-found"] == "error"' "$fixture/collector.json" > /dev/null
jq -r '.jobs["portable-regression"].steps[] | select(.run? | strings |
  contains("make --no-print-directory install-tools")) | .run' "$fixture/workflow.json" > "$fixture/native-step.sh"
jq -er '.runs.steps[] | select(.id == "archive") | .run' "$fixture/collector.json" > "$fixture/collect.sh"
for phase in install check; do
    native="$fixture/native-$phase"
    mkdir -p "$native/scripts/dev" "$native/temp" "$native/make"
    cp "$ROOT/make/tools.mk" "$native/make/"
    printf 'include make/tools.mk\n' > "$native/Makefile"
    for tool in host rust; do
        printf '#!/usr/bin/env bash\nexit 0\n' > "$native/scripts/dev/install-$tool-tools.sh"
    done
    cat > "$native/scripts/dev/install-ic-tools.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "${!#}" != --preflight ]] || exit 0
mkdir -p .tools/ic-set.fixture
printf 'retained installed input\n' > .tools/ic-set.fixture/payload
selected=install
for arg in "$@"; do
    [[ "$arg" != --check ]] || selected=check
done
echo "native fixture: $selected"
[[ "$selected" != "$RETENTION_FAIL_IC_PHASE" ]] || exit 23
SCRIPT
    status=0
    (cd "$native"; RUNNER_TEMP="$native/temp" RETENTION_FAIL_IC_PHASE="$phase" \
        "$BASH" --noprofile --norc -e -o pipefail "$fixture/native-step.sh") \
        > "$native/command.log" 2>&1 || status=$?
    # GNU Make reports a failed recipe as status 2; the installer evidence stays.
    [[ "$status" == 2 && -f "$native/.tools/ic-set.fixture/payload" ]] || exit 1
    printf 'retained formatter diff\n' > "$native/temp/formatting.fixture"
    EVIDENCE_TEMP_ROOT="$native/temp" EVIDENCE_REPOSITORY_ROOT="$native" \
        EVIDENCE_ACTION_ROOT="$ROOT/.github/actions/retain-failure-evidence" \
        RUNNER_TEMP="$native/temp" GITHUB_OUTPUT="$native/archive-output" \
        "$BASH" --noprofile --norc -e -o pipefail "$fixture/collect.sh"
    archive="$(sed -n 's/^path=//p' "$native/archive-output")"
    mkdir "$native/unpacked"
    tar -xzf "$archive" -C "$native/unpacked"
    cmp "$native/.tools/ic-set.fixture/payload" "$native/unpacked/.tools/ic-set.fixture/payload"
    cmp "$native/temp/tools-$phase.log" "$native/unpacked/tools-$phase.log"
    cmp "$native/temp/formatting.fixture" "$native/unpacked/formatting.fixture"
    grep -Fx "native fixture: $phase" "$native/unpacked/tools-$phase.log" > /dev/null
done
# Exercise the real Rust installer through the complete common setup route.
# Cargo alone is substituted, failing after it has produced build evidence.
native="$fixture/native-rust"
mkdir -p "$native/temp" "$native/bin" "$native/make"
cp "$ROOT/make/tools.mk" "$native/make/"
cat > "$native/Makefile" <<'MAKE'
include make/tools.mk
# Host/IC effects are substituted; the Rust installer and collector are real.
install-host-tools install-ic-tools:
	@:
MAKE
cat > "$native/bin/cargo" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" != --version ]] || { echo "cargo fixture"; exit 0; }
[[ $# == 9 && "$1" == install && "$6" == --root && "$8" == --target-dir && "$9" == "$7/build" ]]
mkdir -p "$9"
printf 'retained Rust build output\n' > "$9/failed-build.txt"
echo 'injected Cargo installation failure' >&2
exit 23
SCRIPT
chmod +x "$native/bin/cargo"
for phase in install check; do
    target=install-tools
    [[ "$phase" != check ]] || target=rust-tools-check
    status=0
    PATH="$native/bin:$PATH" make --no-print-directory -C "$native" SHARED_TOOLING_ROOT="$ROOT" \
        IC_TOOL_PINS="$ROOT/ci/ic-tools.tsv" RUST_TOOL_VERSIONS="$ROOT/ci/tool-versions.env" "$target" \
        2>&1 | tee "$native/temp/rust-tools-$phase.log" > "$native/$phase.log" || status=$?
    [[ "$status" == 2 && -f "$native/.tools/rust/build/failed-build.txt" ]]
    for compact in false true; do
        EVIDENCE_TEMP_ROOT="$native/temp" EVIDENCE_REPOSITORY_ROOT="$native" EVIDENCE_COMPACT="$compact" \
            EVIDENCE_ACTION_ROOT="$ROOT/.github/actions/retain-failure-evidence" \
            RUNNER_TEMP="$native/temp" GITHUB_OUTPUT="$native/archive-$phase-$compact" \
            "$BASH" --noprofile --norc -e -o pipefail "$fixture/collect.sh"
        archive="$(sed -n 's/^path=//p' "$native/archive-$phase-$compact")"
        unpacked="$native/unpacked-$phase-$compact"
        mkdir "$unpacked"
        tar -xzf "$archive" -C "$unpacked"
        cmp "$native/.tools/rust/build/failed-build.txt" "$unpacked/.tools/rust/build/failed-build.txt"
        cmp "$native/temp/rust-tools-$phase.log" "$unpacked/rust-tools-$phase.log"
    done
done
grep -F 'injected Cargo installation failure' "$native/temp/rust-tools-install.log" >/dev/null
grep -F 'missing or mismatched cargo-sort' "$native/temp/rust-tools-check.log" >/dev/null
# Final links are preserved without their targets. Redirected parents must
# neither leak external files nor prevent collection of the original setup log.
for route in .tools .tools/rust .tools/rust/build; do
    linked="$fixture/linked-${route//\//-}"
    mkdir -p "$linked/temp" "$linked/$(dirname "$route")" "$linked/outside/build"
    printf 'not selected\n' > "$linked/outside/build/private-input"
    ln -s "$linked/outside" "$linked/$route"
    printf 'Rust setup refused a link\n' > "$linked/temp/rust-tools-check.log"
    EVIDENCE_TEMP_ROOT="$linked/temp" EVIDENCE_REPOSITORY_ROOT="$linked" \
        EVIDENCE_ACTION_ROOT="$ROOT/.github/actions/retain-failure-evidence" \
        RUNNER_TEMP="$linked/temp" GITHUB_OUTPUT="$linked/archive-output" \
        "$BASH" --noprofile --norc -e -o pipefail "$fixture/collect.sh"
    mkdir "$linked/unpacked"
    tar -xzf "$(sed -n 's/^path=//p' "$linked/archive-output")" -C "$linked/unpacked"
    cmp "$linked/temp/rust-tools-check.log" "$linked/unpacked/rust-tools-check.log"
    if [[ "$route" == .tools/rust/build ]]; then
        [[ -L "$linked/unpacked/$route" && "$(readlink "$linked/unpacked/$route")" == "$linked/outside" ]]
    else
        [[ ! -e "$linked/unpacked/.tools" ]]
    fi
    [[ ! -e "$linked/unpacked/outside" ]]
done
# Execute the actual compact download verifier against a payload with the four
# current producer logs. Installer/selector checks above own tool qualification;
# this boundary owns byte comparisons after transport, including corrupt logs.
jq -er '.jobs["portable-regression"].steps[] |
  select(.name == "Verify compact native tool evidence and retained candidate") | .run' \
    "$fixture/workflow.json" > "$fixture/verify-compact.sh"
compact="$fixture/compact"
mkdir -p "$compact/ci" "$compact/.tools/ic" "$compact/.tools/ic-set.candidate/bin" \
    "$compact/temp/portable-fixtures/native-retention/temp" \
    "$compact/temp/compact-tools-downloaded" "$compact/data/tool-evidence.fixture/host" \
    "$compact/data/tool-evidence.fixture/ic" "$compact/data/.tools/ic-set.candidate/bin"
cp "$ROOT/ci/tool-versions.env" "$ROOT/ci/ic-tools.tsv" "$compact/ci/"
cp "$compact/ci/tool-versions.env" "$compact/data/tool-evidence.fixture/host/caller-pins"
cp "$compact/ci/ic-tools.tsv" "$compact/data/tool-evidence.fixture/ic/caller-pins"
for kind in host ic; do
    printf '%s\n' "$compact/.tools/$kind-set.verified" > "$compact/data/tool-evidence.fixture/$kind/selection.txt"
    printf 'verified fixture\n' > "$compact/data/tool-evidence.fixture/$kind/check.log"
done
for receipt in pins.tsv host files.sha256; do
    printf 'receipt %s\n' "$receipt" > "$compact/.tools/ic/$receipt"
    cp "$compact/.tools/ic/$receipt" "$compact/data/tool-evidence.fixture/ic/$receipt"
done
printf '#!/bin/sh\nexit 1\n' > "$compact/.tools/ic-set.candidate/bin/quill"
chmod +x "$compact/.tools/ic-set.candidate/bin/quill"
cp -p "$compact/.tools/ic-set.candidate/bin/quill" "$compact/data/.tools/ic-set.candidate/bin/quill"
for log in ic-tools-install ic-tools-check rust-tools-install rust-tools-check; do
    printf 'original %s failure\n' "$log" > "$compact/temp/portable-fixtures/native-retention/temp/$log.log"
    cp "$compact/temp/portable-fixtures/native-retention/temp/$log.log" "$compact/data/$log.log"
done
for damaged in none ic-tools-install ic-tools-check rust-tools-install rust-tools-check; do
    if [[ "$damaged" != none ]]; then printf 'corrupt log\n' > "$compact/data/$damaged.log"; fi
    tar -czf "$compact/temp/compact-tools-downloaded/evidence.tar.gz" -C "$compact/data" .
    status=0
    (cd "$compact"; RUNNER_TEMP="$compact/temp" EVIDENCE_CANDIDATE=ic-set.candidate \
        "$BASH" --noprofile --norc -e -o pipefail "$fixture/verify-compact.sh") \
        > "$compact/verify-$damaged.log" 2>&1 || status=$?
    if [[ "$damaged" == none ]]; then [[ "$status" == 0 ]]; else [[ "$status" != 0 ]]; fi
    rm -rf "$compact/temp/compact-tools-downloaded/payload"
    if [[ "$damaged" != none ]]; then cp "$compact/temp/portable-fixtures/native-retention/temp/$damaged.log" "$compact/data/$damaged.log"; fi
done
echo 'Failed fixture status and input retention checks passed'
