#!/usr/bin/env bash
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

run_fixture() {
    local start="$SECONDS" status=0
    "$@" || status=$?
    printf '%s\t%s\t%s\n' "${2##*/}" "$((SECONDS - start))" "$status" >> "$FIXTURE/timings.tsv"
    return "$status"
}

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

run_fixture bash "$ROOT/scripts/ci/test-portable-prerequisites.sh"
run_fixture bash "$ROOT/scripts/ci/test-script-paths.sh"
run_fixture bash "$ROOT/scripts/ci/test-cargo-install-qualification.sh"
run_fixture bash "$ROOT/scripts/ci/test-evidence-archive.sh"
run_fixture bash "$ROOT/scripts/ci/test-evidence-download.sh"
run_fixture bash "$ROOT/scripts/ci/test-gh-ci.sh"
run_fixture bash "$ROOT/scripts/ci/test-github-siblings.sh"
run_fixture bash "$ROOT/scripts/ci/test-maintenance-task.sh"
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
    run_fixture bash "$ROOT/scripts/ci/test-validation-target-runner.sh"
for destination in logs/sentinel failures/sentinel summary.md; do
    cmp "$FIXTURE/runner-parent/expected" "$FIXTURE/runner-parent/$destination"
done
for directory in logs failures; do
    [[ "$(ls -A "$FIXTURE/runner-parent/$directory")" == sentinel ]] || exit 1
done
echo 'Runner fixture preserves inherited parent logs and summary'
run_fixture bash "$ROOT/scripts/ci/test-runner-disk-space.sh"
run_fixture bash "$ROOT/scripts/ci/test-installers.sh"
run_fixture bash "$ROOT/scripts/ci/test-tool-downloads.sh"
run_fixture bash "$ROOT/scripts/ci/test-ic-tools.sh"
run_fixture bash "$ROOT/scripts/ci/test-host-tools.sh"
# Consumer-root invocation must not leak its compiler selection into substitutes.
mkdir "$FIXTURE/rust-consumer"
printf '[toolchain]\nchannel = "fixture-unprepared"\n' > "$FIXTURE/rust-consumer/rust-toolchain.toml"
(cd "$FIXTURE/rust-consumer" && run_fixture bash "$ROOT/scripts/ci/test-rust-tools.sh")
run_fixture bash "$ROOT/scripts/ci/test-tool-commands.sh"
run_fixture bash "$ROOT/scripts/ci/test-make-format.sh"
run_fixture bash "$ROOT/scripts/ci/test-make-consumer.sh"
run_fixture bash "$ROOT/scripts/ci/test-tool-path-contexts.sh"
run_fixture bash "$ROOT/scripts/ci/test-evidence-checksums.sh"
run_fixture bash "$ROOT/scripts/ci/test-file-digests.sh"
run_fixture bash "$ROOT/scripts/ci/test-rustsec-db.sh"
run_fixture perl "$ROOT/scripts/ci/test-local-lock-versions.pl"
run_fixture perl "$ROOT/scripts/ci/test-workspace-version-rendering.pl"
run_fixture perl "$ROOT/scripts/ci/test-readme-version-rendering.pl"
run_fixture perl "$ROOT/scripts/ci/test-stable-version-ordering.pl"
run_fixture perl "$ROOT/scripts/ci/test-tag-maintenance.pl"
run_fixture bash "$ROOT/scripts/ci/test-verification-helpers.sh"
run_fixture bash "$ROOT/scripts/ci/test-publication.sh"
run_fixture bash "$ROOT/scripts/ci/test-cargo-publication-attempt.sh"
run_fixture perl "$ROOT/scripts/ci/test-tool-catalogs.pl"
run_fixture perl "$ROOT/scripts/ci/test-documentation-links.pl"
run_fixture bash "$ROOT/scripts/ci/test-crates-io-version.sh"
run_fixture bash "$ROOT/scripts/ci/test-cargo-tool-versions.sh"
run_fixture bash "$ROOT/scripts/ci/test-release-commands.sh"
run_fixture bash "$ROOT/scripts/ci/test-dependency-pins.sh"
run_fixture bash "$ROOT/scripts/ci/test-npm-pins.sh"
run_fixture bash "$ROOT/scripts/ci/test-cargo-metadata.sh"
run_fixture bash "$ROOT/scripts/ci/test-format-tools.sh"
run_fixture bash "$ROOT/scripts/ci/test-git-hooks.sh"
run_fixture bash "$ROOT/scripts/ci/test-cloc.sh"
run_fixture bash "$ROOT/scripts/ci/test-cloc-siblings.sh"
run_fixture bash "$ROOT/scripts/ci/test-cloc-tooling.sh"
run_fixture bash "$ROOT/scripts/ci/test-cloc-tooling-distribution.sh"
run_fixture bash "$ROOT/scripts/ci/test-cloc-fixture-contexts.sh"
run_fixture bash "$ROOT/scripts/ci/test-fixture-retention.sh"
run_fixture bash "$ROOT/scripts/ci/test-snapshot-distribution.sh"
run_fixture bash "$ROOT/scripts/ci/test-snapshot-retirement.sh"
run_fixture bash "$ROOT/scripts/ci/test-release-runner.sh"
run_fixture bash "$ROOT/scripts/ci/test-release-tracking.sh"
run_fixture bash "$ROOT/scripts/ci/test-release-pr.sh"
run_fixture bash "$ROOT/scripts/ci/test-release-metadata.sh"
run_fixture bash "$ROOT/scripts/ci/test-cargo-release-metadata.sh"
run_fixture bash "$ROOT/scripts/ci/test-hosted-failure.sh"
run_fixture bash "$ROOT/scripts/ci/test-release-source.sh"

mkdir -p "$FIXTURE/repository" "$FIXTURE/result"
cat >"$FIXTURE/fake-sccache" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$SCCACHE_SERVER_UDS" >"$SCCACHE_TEST_RESULT/socket"
printf '%s\n' "$TMPDIR" >"$SCCACHE_TEST_RESULT/tmpdir"
printf '%s\n' "$*" >"$SCCACHE_TEST_RESULT/arguments"
SCRIPT
chmod +x "$FIXTURE/fake-sccache"

SCCACHE_BIN="$FIXTURE/fake-sccache" \
    SCCACHE_REPOSITORY_ROOT="$FIXTURE/repository" \
    SCCACHE_TEST_RESULT="$FIXTURE/result" \
    bash "$ROOT/scripts/ci/run-sccache.sh" rustc --version

expected_runtime="$FIXTURE/repository/.tmp/sccache-runtime"
[[ "$(<"$FIXTURE/result/socket")" == "$expected_runtime/server.sock" ]] || exit 1
[[ "$(<"$FIXTURE/result/tmpdir")" == "$expected_runtime/tmp" ]] || exit 1
[[ "$(<"$FIXTURE/result/arguments")" == "rustc --version" ]] || exit 1

# Refused symlink selections must not create anything through the link.
for selection in parent root child override trailing dot; do
    probe="$FIXTURE/sccache-$selection"
    mkdir -p "$probe/repository" "$probe/outside" "$probe/result"
    runtime="$probe/repository/.tmp/sccache-runtime"
    case "$selection" in
        parent) ln -s "$probe/outside" "$probe/repository/.tmp" ;;
        root) mkdir "$probe/repository/.tmp"; ln -s "$probe/outside" "$runtime" ;;
        child) mkdir -p "$runtime"; ln -s "$probe/outside" "$runtime/tmp" ;;
        override) runtime="$probe/explicit"; ln -s "$probe/outside" "$runtime" ;;
        trailing) runtime="$probe/explicit"; ln -s "$probe/outside" "$runtime"; runtime="$runtime///" ;;
        dot) runtime="$probe/explicit"; ln -s "$probe/outside" "$runtime"; runtime="$runtime/." ;;
    esac
    if SCCACHE_BIN="$FIXTURE/fake-sccache" SCCACHE_REPOSITORY_ROOT="$probe/repository" \
        SCCACHE_RUNTIME_DIR="$runtime" SCCACHE_TEST_RESULT="$probe/result" \
        bash "$ROOT/scripts/ci/run-sccache.sh" rustc --version > "$probe/refusal.log" 2>&1; then
        echo "accepted symlinked sccache path: $selection" >&2; exit 1
    fi
    [[ -z "$(ls -A "$probe/outside")" && ! -e "$probe/result/arguments" ]] || exit 1
done
SCCACHE_BIN="$FIXTURE/fake-sccache" SCCACHE_REPOSITORY_ROOT="$FIXTURE/repository" \
    SCCACHE_RUNTIME_DIR="$FIXTURE/explicit-runtime" SCCACHE_TEST_RESULT="$FIXTURE/result" \
    bash "$ROOT/scripts/ci/run-sccache.sh" --show-stats
[[ "$(<"$FIXTURE/result/tmpdir")" == "$FIXTURE/explicit-runtime/tmp" ]] || exit 1

for installer in actionlint gitleaks shellcheck sccache yq; do
    bash "$ROOT/scripts/ci/install-ci-tool.sh" "$installer" --help >/dev/null 2>&1
    if bash "$ROOT/scripts/ci/install-ci-tool.sh" "$installer" \
        --version 1.0.0 --sha256 invalid >/dev/null 2>&1; then
        echo "portable tools test failed: $installer accepted an invalid checksum" >&2
        exit 1
    fi
done

bash "$ROOT/scripts/dev/gh-ci.sh" --help >/dev/null 2>&1

# Node belongs to opt-in browser consumers, not portable shell prerequisites.
if command -v node >/dev/null 2>&1; then
    run_fixture node "$ROOT/scripts/ci/test-node-tools.mjs"
else
    printf 'Node prerequisite tests skipped: Node is not selected on this host.\n'
fi

echo "portable tools tests passed"
fixture_complete=true
