#!/usr/bin/env bash
set -euo pipefail

ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/verification-helpers.XXXXXX")"
trap 'if [[ $? == 0 ]]; then rm -rf "$fixture"; else echo "Verification fixtures retained: $fixture" >&2; fi' EXIT
mkdir "$fixture/bin" "$fixture/workspace" "$fixture/logs"
export VERIFY_HELPER_FIXTURE="$fixture"
cat > "$fixture/bin/cargo" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$PWD" "$@" > "$VERIFY_HELPER_FIXTURE/arguments"
[[ "$CARGO_TERM_COLOR" == never ]]
case "${VERIFY_TEST_MODE:-pass}" in
    pass) echo 'test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out' ;;
    empty) echo 'test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 3 filtered out' ;;
    fail) echo 'test result: FAILED. 0 passed; 1 failed'; exit 7 ;;
esac
SCRIPT
cat > "$fixture/bin/git" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
commit=1111111111111111111111111111111111111111
case "$*" in
    "rev-parse --verify $commit^{commit}")
        if [[ "${VERIFY_TAG_MODE:-valid}" == invalid-commit ]]; then echo invalid;
        else echo "$commit"; fi
        [[ "${VERIFY_TAG_MODE:-valid}" != commit-read-fail ]] || exit 9 ;;
    'cat-file -t refs/tags/v0.1.2')
        case "${VERIFY_TAG_MODE:-valid}" in
            missing) exit 128 ;;
            lightweight) echo commit ;;
            *) echo tag; [[ "${VERIFY_TAG_MODE:-valid}" != type-read-fail ]] || exit 9 ;;
        esac ;;
    'rev-parse --verify refs/tags/v0.1.2^{commit}')
        if [[ "${VERIFY_TAG_MODE:-valid}" == wrong ]]; then echo 2222222222222222222222222222222222222222;
        else echo "$commit"; fi
        [[ "${VERIFY_TAG_MODE:-valid}" != tag-read-fail ]] || exit 9 ;;
    *) echo "unexpected Git operation: $*" >&2; exit 99 ;;
esac
SCRIPT
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH" TMPDIR="$fixture/logs"
cd "$fixture/workspace"
bash "$ROOT/scripts/ci/run-nonempty-cargo-test.sh" --locked --offline -p fixture --lib > /dev/null
[[ "$(head -n 1 "$fixture/arguments")" == "$PWD" ]]
rg -x -- '--locked' "$fixture/arguments" >/dev/null
rg -x -- '--offline' "$fixture/arguments" >/dev/null
for mode in empty fail; do
    status=0
    VERIFY_TEST_MODE="$mode" bash "$ROOT/scripts/ci/run-nonempty-cargo-test.sh" --lib > "$fixture/output" 2>&1 || status=$?
    expected=3; [[ "$mode" != fail ]] || expected=7
    [[ "$status" == "$expected" ]]
    rg -F 'Test output retained:' "$fixture/output" >/dev/null
done
logs=("$fixture/logs"/nonempty-cargo-test.*)
[[ "${#logs[@]}" == 2 ]]

# Logging failure must not be hidden by a successful Cargo process.
cat > "$fixture/bin/tee" <<'SCRIPT'
#!/usr/bin/env bash
cat > /dev/null
exit 8
SCRIPT
chmod +x "$fixture/bin/tee"
status=0
bash "$ROOT/scripts/ci/run-nonempty-cargo-test.sh" --lib > /dev/null 2>&1 || status=$?
[[ "$status" == 8 ]]

commit=1111111111111111111111111111111111111111
bash "$ROOT/scripts/ci/check-release-tag.sh" "$commit" 0.1.2
for mode in missing lightweight wrong invalid-commit commit-read-fail type-read-fail tag-read-fail; do
    if VERIFY_TAG_MODE="$mode" bash "$ROOT/scripts/ci/check-release-tag.sh" "$commit" 0.1.2 > /dev/null 2>&1; then
        echo "tag verification accepted $mode" >&2; exit 1
    fi
done
for version in 01.1.2 v0.1.2 0.1.2-rc.1; do
    if bash "$ROOT/scripts/ci/check-release-tag.sh" "$commit" "$version" > /dev/null 2>&1; then exit 1; fi
done
if bash "$ROOT/scripts/ci/check-release-tag.sh" HEAD 0.1.2 > /dev/null 2>&1; then exit 1; fi
echo 'Verification helper failure, identity and evidence tests passed'
