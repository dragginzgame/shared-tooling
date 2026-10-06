#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-tooling-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

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

bash "$ROOT/scripts/ci/test-validation-target-runner.sh"
bash "$ROOT/scripts/ci/test-installers.sh"
bash "$ROOT/scripts/ci/test-ic-tools.sh"
bash "$ROOT/scripts/ci/test-host-tools.sh"
bash "$ROOT/scripts/ci/test-evidence-checksums.sh"
bash "$ROOT/scripts/ci/test-file-digests.sh"
bash "$ROOT/scripts/ci/test-rustsec-db.sh"
perl "$ROOT/scripts/ci/test-local-lock-versions.pl"
perl "$ROOT/scripts/ci/test-tag-maintenance.pl"
bash "$ROOT/scripts/ci/test-verification-helpers.sh"
perl "$ROOT/scripts/ci/test-documentation-links.pl"
bash "$ROOT/scripts/ci/test-crates-io-version.sh"
bash "$ROOT/scripts/ci/test-release-commands.sh"
bash "$ROOT/scripts/ci/test-dependency-pins.sh"
bash "$ROOT/scripts/ci/test-cargo-metadata.sh"
bash "$ROOT/scripts/ci/test-git-hooks.sh"
bash "$ROOT/scripts/ci/test-cloc.sh"
bash "$ROOT/scripts/ci/test-snapshot-distribution.sh"
bash "$ROOT/scripts/ci/test-release-runner.sh"
bash "$ROOT/scripts/ci/test-release-metadata.sh"

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
[[ "$(<"$FIXTURE/result/socket")" == "$expected_runtime/server.sock" ]]
[[ "$(<"$FIXTURE/result/tmpdir")" == "$expected_runtime/tmp" ]]
[[ "$(<"$FIXTURE/result/arguments")" == "rustc --version" ]]

for installer in install-actionlint.sh install-gitleaks.sh install-shellcheck.sh install-yq.sh; do
    bash "$ROOT/scripts/ci/$installer" --help >/dev/null 2>&1
    if bash "$ROOT/scripts/ci/$installer" \
        --version 1.0.0 --sha256 invalid >/dev/null 2>&1; then
        echo "portable tools test failed: $installer accepted an invalid checksum" >&2
        exit 1
    fi
done

bash "$ROOT/scripts/dev/gh-ci.sh" --help >/dev/null 2>&1

echo "portable tools tests passed"
