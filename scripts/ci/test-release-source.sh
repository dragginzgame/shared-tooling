#!/usr/bin/env bash
# Shared companions: scripts/ci/check-release-source.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/release-source-test.XXXXXX")"
fixture="$(CDPATH="" cd -P -- "$fixture" && printf '%s/.' "$PWD")"
fixture="${fixture%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Release source fixtures retained"' EXIT
SOURCE_TEST_GIT="$(command -v git)"
export SOURCE_TEST_GIT
# A minimal owned Git fixture makes this test exportable to any consumer.
# It never depends on the producer repository's layout or committed objects.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
mkdir "$fixture/repository"
git init --quiet "$fixture/repository"
cd "$fixture/repository"
for path in README.md AGENTS.md CONTRIBUTING.md Cargo.lock; do
    printf 'original %s\n' "$path" > "$path"
done
git add -- README.md AGENTS.md CONTRIBUTING.md Cargo.lock
git -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m fixture
check() { bash "$ROOT/scripts/ci/check-release-source.sh" "$@" > "$fixture/output" 2>&1; }
refuse() {
    refusal_status=0
    check "$@" || refusal_status=$?
    [[ "$refusal_status" != 0 ]] || { echo 'unexpected release source admission' >&2; exit 1; }
}
check
[[ ! -s "$fixture/output" ]] || exit 1

# A lock-only change names the actual lock and leaves its bytes untouched.
printf '\n' >> Cargo.lock
cp Cargo.lock "$fixture/lock"
cp .git/index "$fixture/index"
refuse
grep -F 'unstaged: Cargo.lock' "$fixture/output" > /dev/null
cmp Cargo.lock "$fixture/lock"
cmp .git/index "$fixture/index"
# Literal admission must preserve the same working bytes and index too.
check --allow Cargo.lock
[[ ! -s "$fixture/output" ]] || exit 1
cmp Cargo.lock "$fixture/lock"
cmp .git/index "$fixture/index"
git checkout-index --force -- Cargo.lock

# Preserve a hidden staged edit, an ordinary working edit and an unusual name.
replacement="$(git rev-parse HEAD:AGENTS.md)"
git update-index --cacheinfo "100644,$replacement,README.md"
git diff --quiet HEAD -- README.md
printf '\nworking edit\n' >> CONTRIBUTING.md
untracked=$'untracked\nname.txt'
printf 'untracked content\n' > "$untracked"
cp .git/index "$fixture/index"
cp CONTRIBUTING.md "$fixture/working"
refuse
for expected in 'staged: README.md' 'unstaged: README.md' 'unstaged: CONTRIBUTING.md'; do
    grep -F "$expected" "$fixture/output" > /dev/null
done
printf '  untracked: %q\n' "$untracked" > "$fixture/expected"
grep -Fx -f "$fixture/expected" "$fixture/output" > /dev/null
cmp .git/index "$fixture/index"
cmp CONTRIBUTING.md "$fixture/working"
[[ "$(cat "$untracked")" == 'untracked content' ]] || exit 1
check --allow README.md --allow CONTRIBUTING.md --allow "$untracked"
refuse --allow '*'

# An allowed rename destination does not hide an unapproved source deletion.
git read-tree HEAD
git checkout-index --force -- CONTRIBUTING.md
rm "$untracked"
mv README.md renamed.md
git add -- README.md renamed.md
cp .git/index "$fixture/index"
cp renamed.md "$fixture/renamed"
refuse --allow renamed.md
grep -F 'staged: README.md' "$fixture/output" > /dev/null
cmp .git/index "$fixture/index"
cmp renamed.md "$fixture/renamed"
git read-tree HEAD
git checkout-index --force -- README.md
rm renamed.md

# Observation errors retain their original diagnostic and cannot mean clean.
mkdir "$fixture/bin"
cat > "$fixture/bin/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
phase=other
case "$1" in
    rev-parse) phase=checkout ;;
    status) phase=status ;;
esac
printf '%s\n' "$phase" >> "$SOURCE_TEST_EVENTS"
if [[ "$phase" == "$SOURCE_TEST_FAIL" ]]; then
    case "$SOURCE_TEST_OUTPUT" in
        empty) ;;
        root) printf '\n' ;;
        allowed) printf ' M Cargo.lock\0' ;;
        forbidden) printf '?? forbidden.txt\0' ;;
    esac
    echo "observation-error-$phase" >&2
    exit 9
fi
exec "$SOURCE_TEST_GIT" "$@"
STUB
chmod +x "$fixture/bin/git"
cp .git/index "$fixture/index"
cp Cargo.lock "$fixture/lock"
export SOURCE_TEST_EVENTS="$fixture/git-events"
mkdir "$fixture/scratch"
for phase in checkout status; do
    outputs=(empty)
    if [[ "$phase" == checkout ]]; then outputs+=(root); else outputs+=(allowed forbidden); fi
    for output in "${outputs[@]}"; do
        SOURCE_TEST_FAIL="$phase" SOURCE_TEST_OUTPUT="$output" TMPDIR="$fixture/scratch" \
            PATH="$fixture/bin:$PATH" refuse --allow Cargo.lock
        [[ "$refusal_status" == 1 ]] || exit 1
        grep -F "observation-error-$phase" "$fixture/output" > /dev/null
        grep -F 'cannot inspect' "$fixture/output" > /dev/null
        if grep -F 'uncommitted paths' "$fixture/output" > /dev/null; then exit 1; fi
        cmp .git/index "$fixture/index"
        cmp Cargo.lock "$fixture/lock"
        [[ -z "$(ls -A "$fixture/scratch")" ]] || exit 1
    done
done

# Invalid selections refuse before Git observation or scratch allocation.
for invalid in missing empty absolute parent dot repeated-separator unknown; do
    case "$invalid" in
        missing) arguments=(--allow) ;;
        empty) arguments=(--allow '') ;;
        absolute) arguments=(--allow /Cargo.lock) ;;
        parent) arguments=(--allow ../Cargo.lock) ;;
        dot) arguments=(--allow ./Cargo.lock) ;;
        repeated-separator) arguments=(--allow directory//Cargo.lock) ;;
        unknown) arguments=(--unknown) ;;
    esac
    : > "$SOURCE_TEST_EVENTS"
    SOURCE_TEST_FAIL=unused SOURCE_TEST_OUTPUT=empty TMPDIR="$fixture/scratch" \
        PATH="$fixture/bin:$PATH" refuse "${arguments[@]}"
    [[ "$refusal_status" == 2 && ! -s "$SOURCE_TEST_EVENTS" ]] || exit 1
    [[ -z "$(ls -A "$fixture/scratch")" ]] || exit 1
    cmp .git/index "$fixture/index"
    cmp Cargo.lock "$fixture/lock"
done
check
echo 'Release source diagnostics, observation failures and preservation tests passed'
fixture_complete=true
