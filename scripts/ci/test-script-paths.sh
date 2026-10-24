#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/ci/test-file-digests.sh scripts/ci/prepare-script-fixture.sh scripts/ci/test-cargo-graph.sh scripts/ci/test-release-changelog.sh scripts/ci/prepare-cargo-failure-fixture.sh scripts/ci/test-cargo-release-preflight.sh scripts/ci/test-cargo-formatting-fixture.sh scripts/ci/test-snapshot-retirement.sh scripts/ci/test-fixture-completion.sh scripts/ci/test-fixture-timing.sh scripts/ci/test-fixture-allocation.sh scripts/ci/test-prepare-common-tools.sh scripts/ci/test-hosted-failure.sh scripts/ci/test-shared-toolchain.sh scripts/ci/test-runtime-panic-qualification.sh scripts/ci/test-consumer-flow-probes.sh scripts/ci/test-rust-formatting-sources.sh scripts/ci/test-fixture-log-replay.sh scripts/ci/test-workflow-step.sh scripts/ci/test-release-receipts.sh scripts/ci/test-pipe-jobserver.sh scripts/ci/test-cargo-dependency-boundaries.sh scripts/ci/test-rust-toolchains.sh scripts/ci/test-release-metadata-transaction.sh scripts/ci/test-snapshot-takeover.sh scripts/ci/test-release-delivery.sh scripts/ci/test-cargo-publication-attempt.sh
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/script-paths-test.XXXXXX")"
fixture="$(CDPATH="" cd -P -- "$fixture" && printf '%s/.' "$PWD")"
fixture="${fixture%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Script path fixture retained"' EXIT
checkout="$fixture/checkout"$'\n'
mkdir -p "$checkout/scripts/ci" "$checkout/scripts/dev" "$fixture/decoy/scripts/ci"
for script in check-dependency-pins verify-shared-tooling-snapshot install-ci-tool; do
    cp "$ROOT/scripts/ci/$script.sh" "$checkout/scripts/ci/"
done
for script in install-host-tools install-ic-tools; do cp "$ROOT/scripts/dev/$script.sh" "$checkout/scripts/dev/"; done
# Initial help admission must not resolve a relative script against CDPATH or
# trim a newline from its physical checkout. No setup or Git effects are invoked.
for path in "$checkout"/scripts/ci/*.sh "$checkout"/scripts/dev/*.sh; do
    relative="${path#"$checkout/"}"
    arguments=(--help)
    [[ "${path##*/}" != install-ci-tool.sh ]] || arguments=(shellcheck --help)
    (cd "$checkout"; CDPATH="$fixture/decoy:$checkout" "$BASH" "$relative" "${arguments[@]}") > "$fixture/help.log" 2>&1
    (cd "$fixture"; CDPATH="$checkout" "$BASH" "$path" "${arguments[@]}") >> "$fixture/help.log" 2>&1
done
cp "$ROOT/scripts/ci/test-evidence-archive.sh" "$ROOT/scripts/ci/archive-evidence.sh" "$ROOT/scripts/ci/fixture-lifecycle.sh" "$checkout/scripts/ci/"
(cd "$checkout"; CDPATH="$fixture/decoy:$checkout" bash scripts/ci/test-evidence-archive.sh) > "$fixture/archive.log" 2>&1
# Installer admission rejects both the supplied path and its physical target,
# before sourcing consumer configuration, probing tools or preparing a store.
mkdir "$fixture/valid" "$fixture/physical"$'\r'
ln -s "$fixture/valid" "$fixture/alias"$'\n'
ln -s "$fixture/valid" "$fixture/alias"$'\r'
ln -s "$checkout" "$fixture/redirect"
mkdir -p "$fixture/ancestor"$'\n'/child
printf 'printf reached > %q\nexit 97\n' "$fixture/config-read" > "$fixture/versions.env"
for consumer in "$checkout" "$fixture/physical"$'\r' "$fixture/alias"$'\n' \
    "$fixture/alias"$'\r' "$fixture/redirect" "$fixture/ancestor"$'\n'/child; do
    for kind in host ic rust; do
        for mode in install check preflight; do
            [[ "$kind:$mode" != host:preflight ]] || continue
            args=(--consumer "$consumer")
            if [[ "$kind" == ic ]]; then args+=(--pins "$ROOT/ci/ic-tools.tsv" --tool wasm-opt)
            else args+=(--versions "$fixture/versions.env"); fi
            [[ "$mode" == install ]] || args+=("--$mode")
            if "$BASH" "$ROOT/scripts/dev/install-$kind-tools.sh" "${args[@]}" > "$fixture/path-refusal.log" 2>&1; then
                echo 'installer accepted a CR/LF consumer path' >&2; exit 1
            fi
            [[ ! -e "$fixture/config-read" && ! -e "$consumer/.tools" ]] || {
                echo 'invalid consumer path reached configuration or setup' >&2; exit 1;
            }
        done
    done
done
# The digest fixture changes cwd after allocation. Its tool selections and
# cleanup must remain anchored for both relative and aliased scratch roots.
mkdir -p "$fixture/digest-caller/scratch" "$fixture/decoy/scratch"
ln -s "$fixture/digest-caller/scratch" "$fixture/digest-caller/alias"
for selected_tmp in scratch alias/; do
    (cd "$fixture/digest-caller" && CDPATH="$fixture/decoy" TMPDIR="$selected_tmp" \
        "$BASH" "$ROOT/scripts/ci/test-file-digests.sh") > "$fixture/digest-path.log" 2>&1
    grep -F 'Portable digest vectors, filenames, backend failures and verifier round trips passed' \
        "$fixture/digest-path.log" >/dev/null
    [[ -z "$(ls -A "$fixture/digest-caller/scratch")" && -z "$(ls -A "$fixture/decoy/scratch")" ]] || exit 1
done
# Exercise the affected fixture entrypoints without replaying their test bodies.
# A private companion reports that bootstrap selected the actual fixture root.
entry_checkout="$fixture/fixture checkout"
mkdir "$entry_checkout"
entry_scripts=(
    test-cargo-graph test-release-changelog test-cargo-release-preflight
    test-cargo-formatting-fixture test-snapshot-retirement test-fixture-completion
    test-fixture-timing test-fixture-allocation test-prepare-common-tools
    test-hosted-failure test-shared-toolchain test-runtime-panic-qualification
    test-consumer-flow-probes test-rust-formatting-sources test-fixture-log-replay
    test-workflow-step test-release-receipts test-pipe-jobserver
    test-cargo-dependency-boundaries test-rust-toolchains
    test-release-metadata-transaction test-snapshot-takeover test-release-delivery
)
entry_roots=()
for script in "${entry_scripts[@]}"; do entry_roots+=("scripts/ci/$script.sh"); done
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$entry_checkout" "${entry_roots[@]}"
cat > "$entry_checkout/scripts/ci/fixture-lifecycle.sh" <<'BOOTSTRAP'
[[ "${ROOT:-}" == "$BOOTSTRAP_EXPECTED_ROOT" || "${root:-}" == "$BOOTSTRAP_EXPECTED_ROOT" ]] || exit 42
printf 'bootstrap admitted\n'
exit 41
BOOTSTRAP
mkdir "$fixture/entry-scratch" "$fixture/entry-bin"
# Some entrypoints discover Cargo before sourcing their lifecycle helper. A
# substitute admits discovery without requiring or invoking an actual compiler.
printf '#!/usr/bin/env bash\nexit 97\n' > "$fixture/entry-bin/cargo"
chmod +x "$fixture/entry-bin/cargo"
for shape in spaces newline; do
    if [[ "$shape" == newline ]]; then
        mv "$entry_checkout" "$entry_checkout"$'\n'
        entry_checkout+=$'\n'
    fi
    for script in "${entry_scripts[@]}"; do
        for entry in relative absolute; do
            status=0
            (
                export CDPATH="$fixture/decoy:$entry_checkout"
                export BOOTSTRAP_EXPECTED_ROOT="$entry_checkout" TMPDIR="$fixture/entry-scratch"
                if [[ "$entry" == relative ]]; then
                    cd "$entry_checkout"
                    PATH="$fixture/entry-bin:$PATH" "$BASH" "scripts/ci/$script.sh"
                else
                    cd "$fixture"
                    PATH="$fixture/entry-bin:$PATH" "$BASH" "$entry_checkout/scripts/ci/$script.sh"
                fi
            ) > "$fixture/entry.log" 2> "$fixture/entry.err" || status=$?
            if [[ "$status" != 41 || -s "$fixture/entry.err" ]]; then
                printf 'Fixture bootstrap failed: %s (%s, %s), status %s\n' "$script" "$shape" "$entry" "$status" >&2
                cat "$fixture/entry.err" >&2
                exit 1
            fi
            grep -Fx 'bootstrap admitted' "$fixture/entry.log" > /dev/null
        done
    done
done
# Exercise actual allocation/cleanup after bootstrap as well. Relative and
# aliased TMPDIR values must not select a CDPATH decoy or leave successful runs.
lifecycle_caller="$fixture/lifecycle caller"
mkdir -p "$lifecycle_caller/physical" "$fixture/lifecycle-decoy/physical"
ln -s "$lifecycle_caller/physical" "$lifecycle_caller/alias"
for selected_tmp in physical alias/; do
    for script in test-fixture-allocation test-pipe-jobserver test-cargo-dependency-boundaries test-release-receipts test-cargo-publication-attempt; do
        if ! (cd "$lifecycle_caller" && CDPATH="$fixture/lifecycle-decoy:$lifecycle_caller" TMPDIR="$selected_tmp" \
            "$BASH" "$ROOT/scripts/ci/$script.sh") > "$fixture/lifecycle-path.log" 2>&1; then
            printf 'Fixture scratch path failed: %s (%s)\n' "$script" "$selected_tmp" >&2
            cat "$fixture/lifecycle-path.log" >&2
            exit 1
        fi
        [[ -z "$(ls -A "$lifecycle_caller/physical")" && -z "$(ls -A "$fixture/lifecycle-decoy/physical")" ]] || exit 1
    done
done
# Preparation anchors the selected destination before any later cwd changes.
# The emitted executables are substitutes; no real compiler/build is dispatched.
caller="$fixture/preparation caller"
mkdir -p "$caller/physical" "$fixture/preparation-decoy/relative"
ln -s "$caller/physical" "$caller/alias"
preparer="$ROOT/scripts/ci/prepare-cargo-failure-fixture.sh"
for destination in relative 'with spaces' -leading alias/nested; do
    (cd "$caller" && CDPATH="$fixture/preparation-decoy" "$BASH" "$preparer" "$destination")
    prepared="$caller/$destination"
    [[ "$destination" != alias/nested ]] || prepared="$caller/physical/nested"
    [[ -x "$prepared/bin/rustc" && -x "$prepared/bin/cargo" ]]
    [[ "$(cd / && "$prepared/bin/rustc" --print sysroot)" == "$prepared" ]]
    status=0
    (cd / && HOME="$prepared/home" "$prepared/bin/cargo" install --target-dir "$prepared/build") \
        > "$fixture/prepared-install.log" 2>&1 || status=$?
    [[ "$status" == 23 && -f "$prepared/build/failed-build.txt" ]]
    status=0
    "$BASH" "$preparer" "$prepared" > "$fixture/prepared-retry.log" 2>&1 || status=$?
    [[ "$status" == 2 && -f "$prepared/build/failed-build.txt" ]]
done
[[ -z "$(ls -A "$fixture/preparation-decoy/relative")" ]]
# Refuse invalid supplied paths before mkdir, including the empty path that
# would otherwise turn the requested bin child into /bin. Guard that effect
# independently so a regressed helper cannot write outside this fixture.
mkdir "$fixture/preparation-guard"
# shellcheck disable=SC2016 # The guarded child reads its own effect destination.
printf 'printf "mkdir dispatched\\n" >> "$PREPARATION_EFFECTS"\nexit 93\n' \
    > "$fixture/preparation-guard/mkdir"
chmod +x "$fixture/preparation-guard/mkdir"
for invalid in '' "$caller/line"$'\n'"break" "$caller/line"$'\r'"break"; do
    status=0
    PATH="$fixture/preparation-guard:$PATH" PREPARATION_EFFECTS="$fixture/preparation-effects" \
        "$BASH" "$preparer" "$invalid" > "$fixture/preparation-invalid.log" 2>&1 || status=$?
    [[ "$status" == 2 && ! -e "$fixture/preparation-effects" ]]
done
mkdir "$caller/physical"$'\n'"parent"
ln -s "$caller/physical"$'\n'"parent" "$caller/bad-alias"
status=0
"$BASH" "$preparer" "$caller/bad-alias/retained" > "$fixture/preparation-physical.log" 2>&1 || status=$?
[[ "$status" == 2 && -d "$caller/bad-alias/retained/bin" &&
   ! -e "$caller/bad-alias/retained/bin/rustc" && ! -e "$caller/bad-alias/retained/bin/cargo" ]]
echo 'Relative/absolute entry points, inherited CDPATH and newline checkout bootstrap passed'
fixture_complete=true
