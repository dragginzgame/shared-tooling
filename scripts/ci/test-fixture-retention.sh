#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
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
# Stop an overlong suite before the job deadline so its failure collector can run.
jq -e '
  .jobs["portable-regression"] as $job |
  [$job.steps[] | select(.run? | strings | contains("bash scripts/ci/test-portable-tools.sh"))] as $gate |
  ($gate | length) == 1 and
  ($gate[0]["timeout-minutes"] | type == "number" and . > 0) and
  $job["timeout-minutes"] > $gate[0]["timeout-minutes"] and
  $gate[0]["continue-on-error"] != true
' "$fixture/workflow.json" > /dev/null
# shellcheck disable=SC2016 # GitHub expressions are literal workflow inputs.
jq -e '
  .jobs["portable-regression"].steps | to_entries |
  map(select(.value.run? | strings | contains("make --no-print-directory install-ic-tools"))) as $native |
  map(select(.value.uses == "./.github/actions/retain-failure-evidence" and .value.if == "failure()")) as $uploads |
  ($native | length) == 1 and ($uploads | length) == 1 and
  $uploads[0].key > $native[0].key and $uploads[0].key == length - 1 and
  $uploads[0].value.with["temp-root"] == "${{ runner.temp }}" and
  $uploads[0].value.with["repository-root"] == "${{ github.workspace }}"
' "$fixture/workflow.json" > /dev/null
jq -e '.runs.steps | map(select(.uses? | strings | startswith("actions/upload-artifact@"))) |
  length == 1 and .[0].with["if-no-files-found"] == "error"' "$fixture/collector.json" > /dev/null
jq -r '.jobs["portable-regression"].steps[] | select(.run? | strings |
  contains("make --no-print-directory install-ic-tools")) | .run' "$fixture/workflow.json" > "$fixture/native-step.sh"
jq -er '.runs.steps[] | select(.id == "archive") | .run' "$fixture/collector.json" > "$fixture/collect.sh"
for phase in install check; do
    native="$fixture/native-$phase"
    mkdir -p "$native/scripts/dev" "$native/temp" "$native/make"
    cp "$ROOT/make/tools.mk" "$native/make/"
    printf 'include make/tools.mk\n' > "$native/Makefile"
    cat > "$native/scripts/dev/install-ic-tools.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
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
    EVIDENCE_TEMP_ROOT="$native/temp" EVIDENCE_REPOSITORY_ROOT="$native" \
        EVIDENCE_ACTION_ROOT="$ROOT/.github/actions/retain-failure-evidence" \
        RUNNER_TEMP="$native/temp" GITHUB_OUTPUT="$native/archive-output" \
        "$BASH" --noprofile --norc -e -o pipefail "$fixture/collect.sh"
    archive="$(sed -n 's/^path=//p' "$native/archive-output")"
    mkdir "$native/unpacked"
    tar -xzf "$archive" -C "$native/unpacked"
    cmp "$native/.tools/ic-set.fixture/payload" "$native/unpacked/.tools/ic-set.fixture/payload"
    cmp "$native/temp/ic-tools-$phase.log" "$native/unpacked/ic-tools-$phase.log"
    grep -Fx "native fixture: $phase" "$native/unpacked/ic-tools-$phase.log" > /dev/null
done
echo 'Failed fixture status and input retention checks passed'
