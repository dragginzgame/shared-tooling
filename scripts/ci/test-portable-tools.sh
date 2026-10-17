#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-timing.sh scripts/ci/test-license.pl
set -euo pipefail

ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
bash "$ROOT/scripts/ci/check-portable-prerequisites.sh"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-tooling-test.XXXXXX")"
# Bash 3.2 can enter EXIT with status zero after nounset; require completion too.
fixture_complete=false
finish() {
    local status=$?
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ -f "$FIXTURE/timings.tsv" ]]; then
        printf '\nPortable fixture timings (name, seconds, exit status):\n'
        cat "$FIXTURE/timings.tsv"
    fi
    if [[ "$status" == 0 ]]; then rm -rf "$FIXTURE"
    else printf "Failed portable-tools fixture retained: %s\n" "$FIXTURE" >&2; fi
    exit "$status"
}
trap finish EXIT

# shellcheck source=scripts/ci/fixture-timing.sh
source "$ROOT/scripts/ci/fixture-timing.sh"

for script in \
    "$ROOT"/scripts/ci/*.sh \
    "$ROOT"/scripts/dev/*.sh \
    "$ROOT"/scripts/distribution/*.sh \
    "$ROOT"/scripts/release/*.sh; do
    bash -n "$script"
done
bash -n "$ROOT/.githooks/pre-commit"

printf 'portable checksum fixture\n' >"$FIXTURE/input.txt"
bash "$ROOT/scripts/ci/verify-file-checksum.sh" \
    sha256 \
    a583af206ec9aaef88f36b9beffb4f51802b2cfff67c6e0dd41577a7d492fab4 \
    "$FIXTURE/input.txt"

if bash "$ROOT/scripts/ci/verify-file-checksum.sh" \
    sha256 \
    ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
    "$FIXTURE/input.txt" >/dev/null 2>&1; then
    echo "portable tools test failed: checksum mismatch was accepted" >&2
    exit 1
fi

run_fixture test-portable-prerequisites.sh bash "$ROOT/scripts/ci/test-portable-prerequisites.sh"
run_fixture test-fixture-timing.sh bash "$ROOT/scripts/ci/test-fixture-timing.sh"
run_fixture test-fixture-allocation.sh bash "$ROOT/scripts/ci/test-fixture-allocation.sh"
run_fixture test-cargo-formatting-fixture.sh bash "$ROOT/scripts/ci/test-cargo-formatting-fixture.sh"
run_fixture test-cargo-release-preflight.sh bash "$ROOT/scripts/ci/test-cargo-release-preflight.sh"
run_fixture test-release-changelog.sh bash "$ROOT/scripts/ci/test-release-changelog.sh"
run_fixture test-saved-cargo-manifest.pl perl "$ROOT/scripts/ci/test-saved-cargo-manifest.pl"
run_fixture test-workflow-step.sh bash "$ROOT/scripts/ci/test-workflow-step.sh"
run_fixture test-fixture-workflow-steps.sh bash "$ROOT/scripts/ci/test-fixture-workflow-steps.sh"
run_fixture test-fixture-completion.sh bash "$ROOT/scripts/ci/test-fixture-completion.sh"
run_fixture test-fixture-log-replay.sh bash "$ROOT/scripts/ci/test-fixture-log-replay.sh"
run_fixture test-script-paths.sh bash "$ROOT/scripts/ci/test-script-paths.sh"
run_fixture test-type-docs.pl perl "$ROOT/scripts/ci/test-type-docs.pl"
run_fixture test-ci-change-selection.pl perl "$ROOT/scripts/ci/test-ci-change-selection.pl"
run_fixture test-rust-toolchains.sh bash "$ROOT/scripts/ci/test-rust-toolchains.sh"
run_fixture test-runtime-panic-qualification.sh bash "$ROOT/scripts/ci/test-runtime-panic-qualification.sh"
run_fixture test-cargo-install-qualification.sh bash "$ROOT/scripts/ci/test-cargo-install-qualification.sh"
run_fixture test-evidence-archive.sh bash "$ROOT/scripts/ci/test-evidence-archive.sh"
run_fixture test-native-diagnostics.sh bash "$ROOT/scripts/ci/test-native-diagnostics.sh"
run_fixture test-evidence-download.sh bash "$ROOT/scripts/ci/test-evidence-download.sh"
run_fixture test-gh-ci.sh bash "$ROOT/scripts/ci/test-gh-ci.sh"
run_fixture test-github-siblings.sh bash "$ROOT/scripts/ci/test-github-siblings.sh"
run_fixture test-maintenance-task.sh bash "$ROOT/scripts/ci/test-maintenance-task.sh"
# A parent gate may retain its own logs and GitHub summary. The runner fixture
# must select its own destinations without changing those parent-owned outputs.
mkdir -p "$FIXTURE/runner-parent/logs" "$FIXTURE/runner-parent/failures"
printf 'parent-owned evidence\n' > "$FIXTURE/runner-parent/expected"
for destination in logs/sentinel failures/sentinel summary.md; do
    cp "$FIXTURE/runner-parent/expected" "$FIXTURE/runner-parent/$destination"
done
VALIDATION_LOG_DIR="$FIXTURE/runner-parent/logs" \
    VALIDATION_FAILURE_LOG_DIR="$FIXTURE/runner-parent/failures" \
    GITHUB_STEP_SUMMARY="$FIXTURE/runner-parent/summary.md" \
    run_fixture test-validation-target-runner.sh bash "$ROOT/scripts/ci/test-validation-target-runner.sh"
for destination in logs/sentinel failures/sentinel summary.md; do
    cmp "$FIXTURE/runner-parent/expected" "$FIXTURE/runner-parent/$destination"
done
for directory in logs failures; do
    [[ "$(ls -A "$FIXTURE/runner-parent/$directory")" == sentinel ]] || exit 1
done
echo 'Runner fixture preserves inherited parent logs and summary'
run_fixture test-runner-disk-space.sh bash "$ROOT/scripts/ci/test-runner-disk-space.sh"
run_fixture test-installers.sh bash "$ROOT/scripts/ci/test-installers.sh"
run_fixture test-tool-downloads.sh bash "$ROOT/scripts/ci/test-tool-downloads.sh"
run_fixture test-ic-tools.sh bash "$ROOT/scripts/ci/test-ic-tools.sh"
run_fixture test-host-tools.sh bash "$ROOT/scripts/ci/test-host-tools.sh"
# Consumer-root invocation must not leak its compiler selection into substitutes.
mkdir "$FIXTURE/rust-consumer"
printf '[toolchain]\nchannel = "fixture-unprepared"\n' > "$FIXTURE/rust-consumer/rust-toolchain.toml"
(cd "$FIXTURE/rust-consumer" && run_fixture test-rust-tools.sh bash "$ROOT/scripts/ci/test-rust-tools.sh")
run_fixture test-tool-commands.sh bash "$ROOT/scripts/ci/test-tool-commands.sh"
run_fixture test-make-format.sh bash "$ROOT/scripts/ci/test-make-format.sh"
run_fixture test-script-fixture.sh bash "$ROOT/scripts/ci/test-script-fixture.sh"
run_fixture test-make-consumer.sh bash "$ROOT/scripts/ci/test-make-consumer.sh"
run_fixture test-prepare-common-tools.sh bash "$ROOT/scripts/ci/test-prepare-common-tools.sh"
run_fixture test-tool-path-contexts.sh bash "$ROOT/scripts/ci/test-tool-path-contexts.sh"
run_fixture test-evidence-checksums.sh bash "$ROOT/scripts/ci/test-evidence-checksums.sh"
run_fixture test-file-digests.sh bash "$ROOT/scripts/ci/test-file-digests.sh"
run_fixture test-rustsec-db.sh bash "$ROOT/scripts/ci/test-rustsec-db.sh"
run_fixture test-local-lock-versions.pl perl "$ROOT/scripts/ci/test-local-lock-versions.pl"
run_fixture test-workspace-version-rendering.pl perl "$ROOT/scripts/ci/test-workspace-version-rendering.pl"
run_fixture test-stable-version-ordering.pl perl "$ROOT/scripts/ci/test-stable-version-ordering.pl"
run_fixture test-tag-maintenance.pl perl "$ROOT/scripts/ci/test-tag-maintenance.pl"
run_fixture test-verification-helpers.sh bash "$ROOT/scripts/ci/test-verification-helpers.sh"
run_fixture test-cargo-publication-attempt.sh bash "$ROOT/scripts/ci/test-cargo-publication-attempt.sh"
run_fixture test-tool-catalogs.pl perl "$ROOT/scripts/ci/test-tool-catalogs.pl"
run_fixture test-documentation-links.pl perl "$ROOT/scripts/ci/test-documentation-links.pl"
run_fixture test-license.pl perl "$ROOT/scripts/ci/test-license.pl"
run_fixture test-crates-io-version.sh bash "$ROOT/scripts/ci/test-crates-io-version.sh"
run_fixture test-cargo-tool-versions.sh bash "$ROOT/scripts/ci/test-cargo-tool-versions.sh"
run_fixture test-release-commands.sh bash "$ROOT/scripts/ci/test-release-commands.sh"
run_fixture test-release-delivery.sh bash "$ROOT/scripts/ci/test-release-delivery.sh"
run_fixture test-checker-retention.sh bash "$ROOT/scripts/ci/test-checker-retention.sh"
run_fixture test-cargo-dependency-boundaries.sh bash "$ROOT/scripts/ci/test-cargo-dependency-boundaries.sh"
run_fixture test-dependency-pins.sh bash "$ROOT/scripts/ci/test-dependency-pins.sh"
run_fixture test-npm-pins.sh bash "$ROOT/scripts/ci/test-npm-pins.sh"
run_fixture test-cargo-metadata.sh bash "$ROOT/scripts/ci/test-cargo-metadata.sh"
run_fixture test-format-tools.sh bash "$ROOT/scripts/ci/test-format-tools.sh"
run_fixture test-git-hooks.sh bash "$ROOT/scripts/ci/test-git-hooks.sh"
run_fixture test-rust-formatting-sources.sh bash "$ROOT/scripts/ci/test-rust-formatting-sources.sh"
run_fixture test-cloc.sh bash "$ROOT/scripts/ci/test-cloc.sh"
run_fixture test-cloc-siblings.sh bash "$ROOT/scripts/ci/test-cloc-siblings.sh"
run_fixture test-cloc-tooling.sh bash "$ROOT/scripts/ci/test-cloc-tooling.sh"
run_fixture test-cloc-tooling-distribution.sh bash "$ROOT/scripts/ci/test-cloc-tooling-distribution.sh"
run_fixture test-cloc-fixture-contexts.sh bash "$ROOT/scripts/ci/test-cloc-fixture-contexts.sh"
run_fixture test-tool-version-report.sh bash "$ROOT/scripts/ci/test-tool-version-report.sh"
run_fixture test-pipe-jobserver.sh bash "$ROOT/scripts/ci/test-pipe-jobserver.sh"
run_fixture test-native-host.sh bash "$ROOT/scripts/ci/test-native-host.sh"
run_fixture test-formatting-evidence.sh bash "$ROOT/scripts/ci/test-formatting-evidence.sh"
run_fixture test-consumer-flow-probes.sh bash "$ROOT/scripts/ci/test-consumer-flow-probes.sh"
run_fixture test-fixture-retention.sh bash "$ROOT/scripts/ci/test-fixture-retention.sh"
run_fixture test-collect-tool-evidence.sh bash "$ROOT/scripts/ci/test-collect-tool-evidence.sh"
run_fixture test-snapshot-distribution.sh bash "$ROOT/scripts/ci/test-snapshot-distribution.sh"
run_fixture test-snapshot-performance.sh bash "$ROOT/scripts/ci/test-snapshot-performance.sh"
run_fixture test-snapshot-takeover.sh bash "$ROOT/scripts/ci/test-snapshot-takeover.sh"
run_fixture test-snapshot-retirement.sh bash "$ROOT/scripts/ci/test-snapshot-retirement.sh"
run_fixture test-release-runner.sh bash "$ROOT/scripts/ci/test-release-runner.sh"
run_fixture test-release-inputs.sh bash "$ROOT/scripts/ci/test-release-inputs.sh"
run_fixture test-release-tracking.sh bash "$ROOT/scripts/ci/test-release-tracking.sh"
run_fixture test-release-pr.sh bash "$ROOT/scripts/ci/test-release-pr.sh"
run_fixture test-release-metadata.sh bash "$ROOT/scripts/ci/test-release-metadata.sh"
run_fixture test-cargo-release-metadata.sh bash "$ROOT/scripts/ci/test-cargo-release-metadata.sh"
run_fixture test-hosted-failure.sh bash "$ROOT/scripts/ci/test-hosted-failure.sh"
run_fixture test-release-source.sh bash "$ROOT/scripts/ci/test-release-source.sh"
run_fixture test-release-changes.sh bash "$ROOT/scripts/ci/test-release-changes.sh"

run_fixture test-sccache-launcher.sh bash "$ROOT/scripts/ci/test-sccache-launcher.sh"

bash "$ROOT/scripts/dev/gh-ci.sh" --help >/dev/null 2>&1

# Node belongs to opt-in browser consumers, not portable shell prerequisites.
if command -v node >/dev/null 2>&1; then
    run_fixture test-node-tools.mjs node "$ROOT/scripts/ci/test-node-tools.mjs"
else
    printf 'Node prerequisite tests skipped: Node is not selected on this host.\n'
fi

echo "portable tools tests passed"
fixture_complete=true
