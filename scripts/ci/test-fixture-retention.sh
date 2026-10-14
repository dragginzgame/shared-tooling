#!/usr/bin/env bash
# Shared companions: scripts/ci/prepare-cargo-failure-fixture.sh scripts/ci/fixture-lifecycle.sh scripts/ci/fixture-retention-probes.sh
set -euo pipefail
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/fixture-retention-test.XXXXXX")"
fixture="$(CDPATH="" cd -P -- "$fixture" && printf '%s/.' "$PWD")"
fixture="${fixture%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
# shellcheck source=scripts/ci/fixture-retention-probes.sh
source "$ROOT/scripts/ci/fixture-retention-probes.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Retention fixtures retained"' EXIT
# Inject exits into disposable copies of actual fixtures immediately after their
# EXIT trap. No installer, release, or nested test body is dispatched. Exercise
# cleanup/status handling using this invocation's Bash (including 3.2).
mkdir -p "$fixture/exit-source/scripts/ci"
cp "$ROOT/scripts/ci/fixture-lifecycle.sh" "$fixture/exit-source/scripts/ci/"
cp "$ROOT/scripts/ci/fixture-retention-probes.sh" "$fixture/exit-source/scripts/ci/"
mkdir -p "$fixture/exit-input/src" "$fixture/exit-input/.githooks" "$fixture/exit-input/scripts/dev" "$fixture/exit-input/scripts/ci"
for input in src/lib.rs Cargo.toml Makefile README.md .githooks/pre-commit scripts/dev/install-git-hooks.sh scripts/ci/check-make-execution.sh; do
    printf 'retained input\n' > "$fixture/exit-input/$input"
done
export RETENTION_EXIT_PATH="$fixture/exit-path"
for name in format-tools tool-commands rust-tools release-runner host-tools ic-tools fixture-retention check-formatting-hooks; do
    source="$ROOT/scripts/ci/test-$name.sh"
    probe_args=()
    if [[ "$name" == check-formatting-hooks ]]; then
        source="$ROOT/scripts/ci/$name.sh"
        probe_args=("$fixture/exit-input" src/lib.rs Cargo.toml --no-dependency-tables)
    fi
    fixture_probe_exits "$source" "$fixture" "$ROOT" "$name" ${probe_args[@]+"${probe_args[@]}"} || exit 1
    if [[ "$name" == ic-tools ]]; then
        fixture_probe_exit "$source" "$fixture" "$ROOT" "$name" cleanup-failure || exit 1
        grep -F 'IC fixture cleanup started:' "$fixture/$name-cleanup-failure.log" > /dev/null
        grep -E 'IC fixture cleanup finished: [0-9]+s, status 37' "$fixture/$name-cleanup-failure.log" > /dev/null
    fi
done

# Consumer fixtures use different local root names and can fail while reporting.
# Exercise the shared injector itself, preserving the original exit and evidence.
for root_name in TEST_ROOT scratch; do
    cat > "$fixture/consumer-root.sh" <<PROBE
#!/usr/bin/env bash
set -euo pipefail
$root_name="\$(mktemp -d "\${TMPDIR:-/tmp}/consumer-probe.XXXXXX")"
fixture_complete=false
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
trap 'fixture_finish "\$?" "\$$root_name" "Consumer probe retained"' EXIT
PROBE
    TEST_ROOT="$fixture/unrelated-root" fixture_probe_exits "$fixture/consumer-root.sh" "$fixture" "$ROOT" "$root_name" || exit 1
    TEST_ROOT="$fixture/unrelated-root" fixture_probe_exit "$fixture/consumer-root.sh" "$fixture" "$ROOT" "$root_name" diagnostic || exit 1
    [[ ! -e "$fixture/unrelated-root" ]] || exit 1
done

# Conditional callers must not mask a mismatch or continue to later cases.
cat > "$fixture/wrong-owner.sh" <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
fixture="$(mktemp -d "${TMPDIR:-/tmp}/contradicted-owner.XXXXXX")"
printf 'called\n' >> "$RETENTION_ASSERTION_EVENTS"
trap 'exit 23' EXIT
PROBE
status=0
RETENTION_ASSERTION_EVENTS="$fixture/probe-events" fixture_probe_exits \
    "$fixture/wrong-owner.sh" "$fixture" "$ROOT" contradicted > "$fixture/contradicted.log" 2>&1 || status=$?
[[ "$status" == 1 && "$(cat "$fixture/probe-events")" == called ]] || exit 1
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/no-trap.sh"
status=0
fixture_probe_exit "$fixture/no-trap.sh" "$fixture" "$ROOT" no-trap completed \
    > "$fixture/no-trap.log" 2>&1 || status=$?
[[ "$status" != 0 ]] || exit 1

# Qualify cleanup independently of errexit: a caller can invoke its EXIT helper
# from a conditional, and diagnostics can fail after the original operation.
cat > "$fixture/cleanup-probe.sh" <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
source "$1"
directory="$2"
mode="$3"
fixture_complete=true
trap 'fixture_finish "$?" "$directory" "Cleanup probe retained" || exit 99' EXIT
case "$mode" in
    cleanup-failure) rm() { return 37; } ;;
    false-cleanup) rm() { return 0; } ;;
    reporting-failure) printf() { return 41; }; exit 23 ;;
    both-failures) rm() { return 37; }; printf() { return 41; } ;;
    relative) ;;
esac
PROBE
for mode in cleanup-failure false-cleanup reporting-failure both-failures relative; do
    directory="$fixture/cleanup-$mode"
    mkdir "$directory"
    printf 'payload\n' > "$directory/payload"
    selected="$directory"
    case "$mode" in
        cleanup-failure|both-failures) expected=37 ;;
        reporting-failure) expected=23 ;;
        false-cleanup) expected=1 ;;
        relative) expected=1; selected="cleanup-$mode" ;;
    esac
    status=0
    (cd "$fixture" && "$BASH" "$fixture/cleanup-probe.sh" \
        "$ROOT/scripts/ci/fixture-lifecycle.sh" "$selected" "$mode") \
        > "$fixture/cleanup-$mode.log" 2>&1 || status=$?
    [[ "$status" == "$expected" && "$(cat "$directory/payload")" == payload ]] || exit 1
done
# Exercise actual caller setup through its trap, then change cwd and retarget a
# TMPDIR alias. Cleanup must still address only the directory that was created.
mkdir "$fixture/physical parent" "$fixture/decoy" "$fixture/changed-cwd"
printf 'unrelated evidence\n' > "$fixture/decoy/payload"
export RETENTION_ALIAS="$fixture/tmp-alias" RETENTION_DECOY="$fixture/decoy"
export RETENTION_CHANGED_CWD="$fixture/changed-cwd"
for name in format-tools release-runner fixture-retention; do
    awk '
        { print }
        /^trap .* EXIT$/ { found=1; exit }
        END { if (!found) exit 1 }
    ' "$ROOT/scripts/ci/test-$name.sh" > "$fixture/exit-source/scripts/ci/anchor-probe.sh"
    cat >> "$fixture/exit-source/scripts/ci/anchor-probe.sh" <<'PROBE'
directory="${fixture:-${FIXTURE_ROOT:-}}"
printf '%s\n' "$directory" > "$RETENTION_EXIT_PATH"
printf 'retained evidence\n' > "$directory/payload"
cd "$RETENTION_CHANGED_CWD"
rm "$RETENTION_ALIAS"
ln -s "$RETENTION_DECOY" "$RETENTION_ALIAS"
if [[ "$1" == failed ]]; then exit 23; fi
fixture_complete=true
PROBE
    for outcome in completed failed; do
        rm -f "$RETENTION_ALIAS"
        ln -s "$fixture/physical parent" "$RETENTION_ALIAS"
        status=0
        (cd "$fixture" && CDPATH="$fixture" TMPDIR=tmp-alias "$BASH" \
            "$fixture/exit-source/scripts/ci/anchor-probe.sh" "$outcome") \
            > "$fixture/anchor-$name-$outcome.log" 2>&1 || status=$?
        retained="$(cat "$RETENTION_EXIT_PATH")"
        [[ "$retained" == "$fixture/physical parent/"* ]] || exit 1
        if [[ "$outcome" == completed ]]; then
            [[ "$status" == 0 && ! -e "$retained" ]] || exit 1
        else
            [[ "$status" == 23 && "$(cat "$retained/payload")" == 'retained evidence' ]] || exit 1
        fi
        [[ "$(cat "$fixture/decoy/payload")" == 'unrelated evidence' ]] || exit 1
    done
done
# Exercise the Rust fixture's real Git guard and EXIT owner without dispatching
# its installer body. Expected-failure handling must not hide forbidden effects.
for operation in commit commit-tree tag push; do
    awk '
        { print }
        /^export PATH="\$fixture\/commands:\$PATH"$/ { found=1; exit }
        END { if (!found) exit 1 }
    ' "$ROOT/scripts/ci/test-rust-tools.sh" > "$fixture/exit-source/scripts/ci/git-guard.sh"
    cat >> "$fixture/exit-source/scripts/ci/git-guard.sh" <<'PROBE'
printf '%s\n' "$fixture" > "$RETENTION_EXIT_PATH"
if git -C "$fixture" -c user.name=Fixture "$RETENTION_GIT_OPERATION"; then exit 99; fi
fixture_complete=true
PROBE
    status=0
    RETENTION_GIT_OPERATION="$operation" TMPDIR="$fixture" "$BASH" "$fixture/exit-source/scripts/ci/git-guard.sh" \
        > "$fixture/git-guard-$operation.log" 2>&1 || status=$?
    [[ "$status" == 1 ]] || exit 1
    retained="$(cat "$RETENTION_EXIT_PATH")"
    [[ "$(cat "$retained/forbidden-git")" == "forbidden fixture Git command: $operation" ]] || exit 1
done
# Contradict successful command results in actual fixtures. Bash 3.2 does not
# apply errexit to a standalone [[ ... ]]; a completion flag alone cannot catch
# a failed assertion followed by successful commands and normal cleanup.
assertion_root="$fixture/assertion-source"
mkdir -p "$assertion_root/scripts/ci" "$fixture/assertion-digests" "$fixture/assertion-disk"
cp "$ROOT/scripts/ci/test-file-digests.sh" "$ROOT/scripts/ci/test-runner-disk-space.sh" "$ROOT/scripts/ci/fixture-lifecycle.sh" "$assertion_root/scripts/ci/"
export ASSERTION_CALLS="$fixture/digest-calls"
cat > "$assertion_root/scripts/ci/verify-file-checksum.sh" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$ASSERTION_CALLS"
if [[ "$1" == --print ]]; then
    printf '%064d\n' 0
else
    # The mismatched printed digest must prevent reaching verification.
    exit 23
fi
SCRIPT
status=0
TMPDIR="$fixture/assertion-digests" "$BASH" "$assertion_root/scripts/ci/test-file-digests.sh" \
    > "$fixture/assertion-digests.log" 2>&1 || status=$?
[[ "$status" == 1 && "$(cat "$ASSERTION_CALLS")" == --print ]] || exit 1
set -- "$fixture/assertion-digests"/file-digests.*
[[ $# == 1 && "$(cat "$1/file with spaces")" == abc ]] || exit 1

export ASSERTION_DISK_CHECKER="$ROOT/scripts/ci/check-runner-disk-space.sh"
cat > "$assertion_root/scripts/ci/check-runner-disk-space.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
status=0
"$BASH" "$ASSERTION_DISK_CHECKER" "$@" || status=$?
if [[ "$status" == 0 && "${DISK_FIXTURE:-}" != '' && "$*" == *'before build'* ]]; then
    # Capacity and command status are valid, but the observed path is wrong.
    printf 'wrong workspace\n' > "$DISK_FIXTURE/df-path"
fi
exit "$status"
SCRIPT
status=0
TMPDIR="$fixture/assertion-disk" "$BASH" "$assertion_root/scripts/ci/test-runner-disk-space.sh" \
    > "$fixture/assertion-disk.log" 2>&1 || status=$?
[[ "$status" == 1 ]] || exit 1
set -- "$fixture/assertion-disk"/runner-disk-test.*
[[ $# == 1 && "$(cat "$1/df-path")" == 'wrong workspace' &&
    "$(cat "$1/workspace [one]/artifact")" == 'retained build/evidence input' ]] || exit 1
grep -F 'before build: 4 MiB available; 4 MiB required' "$1/output.log" > /dev/null

mkdir "$fixture/bin" "$fixture/cloc" "$fixture/portable"
export RETENTION_REAL_BASH="$BASH"
cat > "$fixture/bin/cloc" <<'SCRIPT'
#!/usr/bin/env bash
exit 23
SCRIPT
# Write the absolute interpreter directly: BSD sed replacement can join lines.
printf '#!%s\n' "$BASH" > "$fixture/bin/bash"
cat >> "$fixture/bin/bash" <<'SCRIPT'
case "${1:-}" in
    */verify-file-checksum.sh) [[ "${RETENTION_TIMED_FAILURE:-}" == yes ]] || exit 24 ;;
    */test-portable-prerequisites.sh) [[ "${RETENTION_TIMED_FAILURE:-}" != yes ]] || exit 23 ;;
esac
exec "$RETENTION_REAL_BASH" "$@"
SCRIPT
chmod +x "$fixture/bin/"*
# Isolate the report from this checkout's prepared host set so the failing
# cloc substitute exercises retention even when local tools take precedence.
mkdir -p "$fixture/source/scripts/ci" "$fixture/source/scripts/dev"
cp "$ROOT/scripts/ci/test-cloc.sh" "$ROOT/scripts/ci/fixture-lifecycle.sh" "$fixture/source/scripts/ci/"
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

# Timing a child fixture must preserve its original failure and stop the suite.
mkdir "$fixture/portable-timed"
status=0
RETENTION_TIMED_FAILURE=yes TMPDIR="$fixture/portable-timed" PATH="$fixture/bin:$PATH" \
    "$BASH" "$ROOT/scripts/ci/test-portable-tools.sh" > "$fixture/portable-timed.log" 2>&1 || status=$?
[[ "$status" == 23 ]] || exit 1
set -- "$fixture/portable-timed"/shared-tooling-test.*
[[ $# == 1 && -f "$1/input.txt" && -s "$1/timings.tsv" ]] || exit 1
[[ "$(wc -l < "$1/timings.tsv")" -eq 1 ]] || exit 1
IFS=$'\t' read -r timed_name timed_seconds timed_status < "$1/timings.tsv"
[[ "$timed_name" == test-portable-prerequisites.sh && "$timed_seconds" =~ ^[0-9]+$ && "$timed_status" == 23 ]] || exit 1
grep -F "$(cat "$1/timings.tsv")" "$fixture/portable-timed.log" > /dev/null

# Exercise the actual workflow's native qualification commands with a failed
# installer substitute, then check the final collector selects its evidence.
# This checks local ordering/paths; GitHub's upload service is qualified by CI.
yq -o json '.' "$ROOT/.github/workflows/ci.yml" > "$fixture/workflow.json"
yq -o json '.' "$ROOT/.github/actions/retain-failure-evidence/action.yml" > "$fixture/collector.json"
# Cache transport is optional; native setup/admission and the complete gate are
# mandatory unless the classifier admitted a reviewed documentation-only change.
# A main-only save follows native reuse, and carries the exact restore selection.
# shellcheck disable=SC2016 # GitHub expressions are literal workflow inputs.
jq -e --arg save_condition "\${{ needs.change-scope.outputs.scope != 'docs' && (github.event_name == 'push' && github.ref == 'refs/heads/main' && steps.tool-cache.outputs.cache-hit != 'true') }}" \
  --arg native_condition "needs.change-scope.outputs.scope != 'docs'" '
  .jobs["portable-regression"].steps | to_entries |
  map(select(.value.uses? | strings | startswith("actions/cache/restore@"))) as $restore |
  map(select(.value.uses? | strings | startswith("actions/cache/save@"))) as $save |
  map(select(.value.run? | strings | contains("make --no-print-directory install-tools"))) as $setup |
  map(select(.value.run? | strings | contains("CARGO_NET_OFFLINE=true bash scripts/dev/install-rust-tools.sh"))) as $reuse |
  map(select(.value.run? | strings | contains("bash scripts/ci/test-portable-tools.sh"))) as $gate |
  ($restore | length) == 1 and ($save | length) == 1 and
  ($setup | length) == 1 and ($reuse | length) == 1 and ($gate | length) == 1 and
  $restore[0].key < $setup[0].key and $setup[0].key < $reuse[0].key and
  $reuse[0].key < $save[0].key and $save[0].key < $gate[0].key and
  $save[0].value.if == $save_condition and
  $restore[0].value.with.key == $save[0].value.with.key and
  $restore[0].value.with.path == $save[0].value.with.path and
  $restore[0].value.with.path == "${{ steps.tool-cache-key.outputs.root }}/cargo-cache\n${{ steps.tool-cache-key.outputs.root }}/rust-*\n" and
  $restore[0].value.with["restore-keys"] == null and
  $restore[0].value["timeout-minutes"] <= 3 and $save[0].value["timeout-minutes"] <= 3 and
  all($setup[], $reuse[], $gate[]; .value.if == $native_condition and .value["continue-on-error"] != true)
' "$fixture/workflow.json" > /dev/null
# A failed regression gate must still fail the job and reach failure collection.
jq -e '
  .jobs["portable-regression"] as $job |
  [$job.steps[] | select(.run? | strings | contains("bash scripts/ci/test-portable-tools.sh"))] as $gate |
  ($gate | length) == 1 and
  $gate[0]["continue-on-error"] != true
' "$fixture/workflow.json" > /dev/null
# shellcheck disable=SC2016 # GitHub expressions are literal workflow inputs.
jq -e --arg failure_condition "\${{ needs.change-scope.outputs.scope != 'docs' && (failure()) }}" '
  .jobs["portable-regression"].steps | to_entries |
  map(select(.value.run? | strings | contains("make --no-print-directory install-tools"))) as $native |
  map(select(.value.uses == "./.github/actions/retain-failure-evidence" and .value.if == $failure_condition)) as $uploads |
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
    cp "$ROOT/make/tools.mk" "$ROOT/make/execution.mk" "$native/make/"
    mkdir -p "$native/scripts/ci"
    cp "$ROOT/scripts/ci/check-make-execution.sh" "$native/scripts/ci/"
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
cp "$ROOT/make/tools.mk" "$ROOT/make/execution.mk" "$native/make/"
mkdir -p "$native/scripts/ci"
cp "$ROOT/scripts/ci/check-make-execution.sh" "$native/scripts/ci/"
cat > "$native/Makefile" <<'MAKE'
include make/tools.mk
# Host/IC effects are substituted; the Rust installer and collector are real.
install-host-tools install-ic-tools:
	@:
MAKE
bash "$ROOT/scripts/ci/prepare-cargo-failure-fixture.sh" "$native/cargo-fixture"
export SHARED_TOOLING_STORE="$native/store"
for phase in install check; do
    target=install-tools
    [[ "$phase" != check ]] || target=rust-tools-check
    status=0
    PATH="$native/cargo-fixture/bin:$PATH" make --no-print-directory -C "$native" SHARED_TOOLING_ROOT="$ROOT" \
        IC_TOOL_PINS="$ROOT/ci/ic-tools.tsv" RUST_TOOL_VERSIONS="$ROOT/ci/tool-versions.env" "$target" \
        2>&1 | tee "$native/temp/rust-tools-$phase.log" > "$native/$phase.log" || status=$?
    set -- "$SHARED_TOOLING_STORE"/rust-*/set.*
    [[ "$status" == 2 && $# == 1 && -f "$1/build/failed-build.txt" ]] || exit 1
    attempt="$1"
    archived_attempt="${attempt#"$SHARED_TOOLING_STORE/"}"
    mkdir -p "$native/.tools/rust/fixture-1.0.0-bin-fixture-release/installed/build"
    printf 'retained admitted-slot evidence\n' > "$native/.tools/rust/fixture-1.0.0-bin-fixture-release/installed/build/evidence"
    for compact in false true; do
        EVIDENCE_TEMP_ROOT="$native/temp" EVIDENCE_REPOSITORY_ROOT="$native" EVIDENCE_COMPACT="$compact" \
            EVIDENCE_ACTION_ROOT="$ROOT/.github/actions/retain-failure-evidence" \
            RUNNER_TEMP="$native/temp" GITHUB_OUTPUT="$native/archive-$phase-$compact" \
            "$BASH" --noprofile --norc -e -o pipefail "$fixture/collect.sh"
        archive="$(sed -n 's/^path=//p' "$native/archive-$phase-$compact")"
        unpacked="$native/unpacked-$phase-$compact"
        mkdir "$unpacked"
        tar -xzf "$archive" -C "$unpacked"
        cmp "$attempt/build/failed-build.txt" "$unpacked/$archived_attempt/build/failed-build.txt"
        cmp "$native/.tools/rust/fixture-1.0.0-bin-fixture-release/installed/build/evidence" "$unpacked/.tools/rust/fixture-1.0.0-bin-fixture-release/installed/build/evidence"
        cmp "$native/temp/rust-tools-$phase.log" "$unpacked/rust-tools-$phase.log"
    done
done
grep -F 'injected Cargo installation failure' "$native/temp/rust-tools-install.log" >/dev/null
grep -F 'missing or invalid shared Cargo tool' "$native/temp/rust-tools-check.log" >/dev/null
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
        [[ -L "$linked/unpacked/$route" && "$(readlink "$linked/unpacked/$route")" == "$linked/outside" ]] || exit 1
    else
        [[ ! -e "$linked/unpacked/.tools" ]] || exit 1
    fi
    [[ ! -e "$linked/unpacked/outside" ]] || exit 1
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
    if [[ "$damaged" == none ]]; then [[ "$status" == 0 ]] || exit 1; else [[ "$status" != 0 ]] || exit 1; fi
    rm -rf "$compact/temp/compact-tools-downloaded/payload"
    if [[ "$damaged" != none ]]; then cp "$compact/temp/portable-fixtures/native-retention/temp/$damaged.log" "$compact/data/$damaged.log"; fi
done
echo 'Failed fixture status and input retention checks passed'
fixture_complete=true
