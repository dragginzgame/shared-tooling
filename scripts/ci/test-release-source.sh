#!/usr/bin/env bash
# Shared companions: scripts/ci/check-release-source.sh
set -euo pipefail
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/release-source-test.XXXXXX")"
# Bash 3.2 can enter EXIT with status zero after nounset; require completion too.
fixture_complete=false
finish() {
    local status=$?
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$fixture"
    else echo "Release source fixtures retained: $fixture" >&2; fi
    exit "$status"
}
trap finish EXIT
SOURCE_TEST_GIT="$(command -v git)"
export SOURCE_TEST_GIT
git clone --quiet --shared --no-checkout "$ROOT" "$fixture/repository"
cd "$fixture/repository"
git read-tree HEAD
git checkout-index --all
check() { bash "$ROOT/scripts/ci/check-release-source.sh" "$@" > "$fixture/output" 2>&1; }
refuse() { if check "$@"; then echo 'unexpected release source admission' >&2; exit 1; fi; }
check
[[ ! -s "$fixture/output" ]]

# A lock-only change names the actual lock and leaves its bytes untouched.
printf '\n' >> ci/frontend/package-lock.json
cp ci/frontend/package-lock.json "$fixture/lock"
cp .git/index "$fixture/index"
refuse
grep -F 'unstaged: ci/frontend/package-lock.json' "$fixture/output" > /dev/null
cmp ci/frontend/package-lock.json "$fixture/lock"
cmp .git/index "$fixture/index"
git checkout-index --force -- ci/frontend/package-lock.json

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
[[ "$(cat "$untracked")" == 'untracked content' ]]
check --allow README.md --allow CONTRIBUTING.md --allow "$untracked"
refuse --allow '*'

# An allowed rename destination does not hide an unapproved source deletion.
git read-tree HEAD
git checkout-index --force -- CONTRIBUTING.md
rm "$untracked"
mv README.md renamed.md
git add -- README.md renamed.md
refuse --allow renamed.md
grep -F 'staged: README.md' "$fixture/output" > /dev/null
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
if [[ "$phase" == "$SOURCE_TEST_FAIL" ]]; then echo "observation-error-$phase" >&2; exit 9; fi
exec "$SOURCE_TEST_GIT" "$@"
STUB
chmod +x "$fixture/bin/git"
cp .git/index "$fixture/index"
for phase in checkout status; do
    SOURCE_TEST_FAIL="$phase" PATH="$fixture/bin:$PATH" refuse
    grep -F "observation-error-$phase" "$fixture/output" > /dev/null
    grep -F 'cannot inspect' "$fixture/output" > /dev/null
    if grep -F 'uncommitted paths' "$fixture/output" > /dev/null; then exit 1; fi
    cmp .git/index "$fixture/index"
done
check
echo 'Release source diagnostics, observation failures and preservation tests passed'
fixture_complete=true
