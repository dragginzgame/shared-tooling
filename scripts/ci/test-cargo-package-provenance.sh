#!/usr/bin/env bash
# Shared companions: scripts/ci/check-cargo-package-provenance.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/package-provenance.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Package provenance fixture retained"' EXIT
mkdir "$fixture/remote" "$fixture/archives with spaces" "$fixture/evidence" "$fixture/bin"
export PROVENANCE_FIXTURE="$fixture" REAL_PROVENANCE_GIT REAL_PROVENANCE_TAR REAL_PROVENANCE_JQ
REAL_PROVENANCE_GIT="$(command -v git)"
REAL_PROVENANCE_TAR="$(command -v tar)"
REAL_PROVENANCE_JQ="$(command -v jq)"
# Real disposable Git history and archives; no external fetch or Cargo operation.
git -C "$fixture/remote" init -q
printf 'source\n' > "$fixture/remote/source"
git -C "$fixture/remote" add source
git -C "$fixture/remote" -c user.name=Fixture -c user.email=fixture@example.invalid \
    -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qm source
source_id="$(git -C "$fixture/remote" rev-parse HEAD)"
archive() {
    local name="$1" version="$2" path="$3"
    mkdir -p "$fixture/staging/$name-$version"
    jq -n --arg source "$source_id" --arg path "$path" \
        '{git: {sha1: $source}, path_in_vcs: $path}' > "$fixture/staging/$name-$version/.cargo_vcs_info.json"
    tar -czf "$fixture/archives with spaces/$name-$version.crate" -C "$fixture/staging" "$name-$version"
}
archive library 1.2.3 ''
archive cli 2.0.0 'apps/a b'
cp "$fixture/staging/cli-2.0.0/.cargo_vcs_info.json" "$fixture/original.json"
cat > "$fixture/bin/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$PROVENANCE_FIXTURE/git-calls"
if [[ "${3:-}" == rev-parse && -n "${PROVENANCE_RETRIEVED:-}" ]]; then
    printf '%s\n' "$PROVENANCE_RETRIEVED"; exit 0
fi
"$REAL_PROVENANCE_GIT" "$@"
if [[ "${PROVENANCE_GIT_FAILURE:-}" == "$1" || "${PROVENANCE_GIT_FAILURE:-}" == "${3:-}" ]]; then exit 17; fi
STUB
cat > "$fixture/bin/tar" <<'STUB'
#!/usr/bin/env bash
"$REAL_PROVENANCE_TAR" "$@" || exit $?
exit "${PROVENANCE_TAR_STATUS:-0}"
STUB
cat > "$fixture/bin/jq" <<'STUB'
#!/usr/bin/env bash
"$REAL_PROVENANCE_JQ" "$@" || exit $?
exit "${PROVENANCE_JQ_STATUS:-0}"
STUB
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH"
runner="$ROOT/scripts/ci/check-cargo-package-provenance.sh"
run() {
    bash "$runner" "$fixture/evidence/$1" "$fixture/archives with spaces" "$fixture/remote" "$source_id" \
        --package library@1.2.3 . --package cli@2.0.0 'apps/a b'
}
refuse() {
    if "$@" > "$fixture/refusal.log" 2>&1; then
        echo 'Invalid provenance unexpectedly succeeded' >&2; exit 1
    fi
}
run success
[[ "$(cat "$fixture/evidence/success/source-verified")" == "$source_id" ]] || exit 1
[[ "$(git -C "$fixture/evidence/success/source.git" rev-parse 'FETCH_HEAD^{commit}')" == "$source_id" ]] || exit 1
cp "$fixture/evidence/success/source-verified" "$fixture/saved"
: > "$fixture/git-calls"
refuse run success
cmp "$fixture/saved" "$fixture/evidence/success/source-verified"
[[ ! -s "$fixture/git-calls" ]] || exit 1
for path in '' /absolute ../outside a/../b a//b a/./b a/ $'bad\npath' $'bad\rpath'; do
    refuse bash "$runner" "$fixture/evidence/invalid" "$fixture/archives with spaces" "$fixture/remote" "$source_id" \
        --package cli@2.0.0 "$path"
done
refuse bash "$runner" "$fixture/evidence/invalid" "$fixture/archives with spaces" "$fixture/remote" "$source_id" \
    --package cli@2.0.0 apps/a --package cli@2.0.0 apps/a
refuse bash "$runner" "$fixture/evidence/invalid" "$fixture/archives with spaces" "$fixture/remote" bad \
    --package cli@2.0.0 apps/a
refuse bash "$runner" "$fixture/evidence/invalid" "$fixture/archives with spaces" "$fixture/remote" "$source_id" \
    --package cli@2.0 apps/a
[[ ! -e "$fixture/evidence/invalid" && ! -s "$fixture/git-calls" ]] || exit 1
ln -s success "$fixture/evidence/alias"
refuse run alias
mv "$fixture/archives with spaces/cli-2.0.0.crate" "$fixture/saved.crate"
ln -s "$fixture/saved.crate" "$fixture/archives with spaces/cli-2.0.0.crate"
refuse run symlink
rm "$fixture/archives with spaces/cli-2.0.0.crate"
refuse run missing
mv "$fixture/saved.crate" "$fixture/archives with spaces/cli-2.0.0.crate"
[[ ! -s "$fixture/git-calls" ]] || exit 1
for scenario in dirty source path multiple empty missing; do
    case "$scenario" in
        dirty) jq '.git.dirty = true' "$fixture/original.json" ;;
        source) jq '.git.sha1 = "1111111111111111111111111111111111111111"' "$fixture/original.json" ;;
        path) jq '.path_in_vcs = "other"' "$fixture/original.json" ;;
        multiple) cat "$fixture/original.json" "$fixture/original.json" ;;
        empty|missing) : ;;
    esac > "$fixture/staging/cli-2.0.0/.cargo_vcs_info.json"
    if [[ "$scenario" == missing ]]; then rm "$fixture/staging/cli-2.0.0/.cargo_vcs_info.json"; fi
    tar -czf "$fixture/archives with spaces/cli-2.0.0.crate" -C "$fixture/staging" cli-2.0.0
    : > "$fixture/git-calls"
    refuse run "$scenario"
    [[ ! -s "$fixture/git-calls" && ! -e "$fixture/evidence/$scenario/source-verified" ]] || exit 1
done
archive cli 2.0.0 'apps/a b'
for command in init fetch rev-parse; do
    PROVENANCE_GIT_FAILURE="$command" refuse run "failed-$command"
    [[ ! -e "$fixture/evidence/failed-$command/source-verified" ]] || exit 1
done
PROVENANCE_TAR_STATUS=17 refuse run failed-tar
PROVENANCE_JQ_STATUS=17 refuse run failed-jq
PROVENANCE_RETRIEVED=1111111111111111111111111111111111111111 refuse run mismatched-fetch
# A valid object in a different store is not remote retrieval authority.
GIT_OBJECT_DIRECTORY="$fixture/remote/.git/objects" run isolated-store
[[ -f "$fixture/evidence/isolated-store/source-verified" ]] || exit 1
mv "$fixture/remote" "$fixture/retained-remote"
GIT_OBJECT_DIRECTORY="$fixture/retained-remote/.git/objects" refuse run unavailable
[[ ! -e "$fixture/evidence/unavailable/source-verified" ]] || exit 1
echo 'Package provenance checks passed (real local Git and archives; no upload).'
fixture_complete=true
