#!/usr/bin/env bash
set -euo pipefail
# Upstream integration only: consumers vendor test-cloc-tooling.sh instead.
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/cloc-tooling-distribution.XXXXXX")"
# Bash 3.2 can enter EXIT with status zero after nounset; require completion too.
fixture_complete=false
finish() {
    local status=$?
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$fixture"
    else printf "Failed tooling distribution fixture retained: %s\n" "$fixture" >&2; fi
    exit "$status"
}
trap finish EXIT

# Export actual committed scripts, verify, then inventory the same bytes.
# Existing objects suffice; no fixture commits or network access are needed.
source_repo="$fixture/source"
export_parent="$fixture/exported"
consumer="$export_parent/consumer"
git clone -q --shared "$ROOT" "$source_repo"
source_version="$(git -C "$source_repo" show HEAD:VERSION)"
mkdir "$export_parent"
git clone -q --shared --no-checkout "$ROOT" "$consumer"
export_files=(scripts/ci/verify-file-checksum.sh scripts/ci/verify-shared-tooling-snapshot.sh scripts/ci/check-make-execution.sh)
git -C "$consumer" checkout HEAD -- "${export_files[@]}"
for source in https://github.com/dragginzgame/shared-tooling.git git@github.com:dragginzgame/shared-tooling.git ssh://git@github.com/dragginzgame/shared-tooling; do
    git -C "$source_repo" remote set-url origin "$source"
    rm -f "$consumer/config/.shared-tooling.snapshot"
    bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_repo" \
        --consumer "$consumer" --manifest config/.shared-tooling.snapshot \
        --file "${export_files[0]}" --file "${export_files[1]}" --file "${export_files[2]}" > "$fixture/export.log"
    bash "$consumer/scripts/ci/verify-shared-tooling-snapshot.sh" --manifest config/.shared-tooling.snapshot > "$fixture/verify.log"
    perl "$ROOT/scripts/dev/cloc-tooling.pl" --json "$export_parent" > "$fixture/export.json"
    jq -e --arg version "$source_version" '.partial == false and .totals.shared_loc > 0 and .totals.local_loc == 0 and
      .repositories[0].snapshot_manifests[0].version == $version and
      .repositories[0].snapshot_manifests[0].integrity == "ok"' "$fixture/export.json" >/dev/null
done
mv "$consumer/config/.shared-tooling.snapshot" "$consumer/.shared-tooling.snapshot"
perl "$ROOT/scripts/dev/cloc-tooling.pl" --json "$export_parent" > "$fixture/export-root.json"
[[ "$(jq -c .totals "$fixture/export.json")" == "$(jq -c .totals "$fixture/export-root.json")" ]] || exit 1
# Export/verify a real dotted manifest with records overlapping the default.
# Its name must not require a special root option in the inventory.
git -C "$consumer" checkout HEAD -- scripts/ci/archive-evidence.sh
bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_repo" \
    --consumer "$consumer" --manifest .shared-tooling.archives.snapshot \
    --file "${export_files[0]}" --file "${export_files[1]}" --file scripts/ci/archive-evidence.sh > "$fixture/dotted-export.log"
bash "$consumer/scripts/ci/verify-shared-tooling-snapshot.sh" --manifest .shared-tooling.archives.snapshot > "$fixture/dotted-verify.log"
perl "$ROOT/scripts/dev/cloc-tooling.pl" --json "$export_parent" > "$fixture/export-dotted.json"
jq -e '.partial == false and .totals.shared_loc > 0 and .totals.local_loc == 0 and
  (.repositories[0].snapshot_manifests | length) == 2' "$fixture/export-dotted.json" >/dev/null
# Return to the original bundle for the nested-root comparison below.
rm "$consumer/.shared-tooling.archives.snapshot" "$consumer/scripts/ci/archive-evidence.sh"
mkdir -p "$consumer/vendor/shared"
cp -Rp "$consumer/scripts" "$consumer/vendor/shared/"
cp "$consumer/.shared-tooling.snapshot" "$consumer/vendor/shared/"
bash "$consumer/vendor/shared/scripts/ci/verify-shared-tooling-snapshot.sh" > "$fixture/nested-verify.log"
perl "$ROOT/scripts/dev/cloc-tooling.pl" --json "$export_parent" > "$fixture/export-nested.json"
expected_shared="$(jq '.totals.shared_loc * 2' "$fixture/export-root.json")"
jq -e --argjson expected "$expected_shared" '.partial == false and .totals.shared_loc == $expected and .totals.local_loc == 0' "$fixture/export-nested.json" >/dev/null

# Qualify the consumer fixture before commit, with only its declared companions
# present in the worktree. In particular there is no distribution helper.
adoption="$fixture/adoption"
git clone -q --shared --no-checkout "$ROOT" "$adoption"
mkdir -p "$adoption/scripts/ci" "$adoption/scripts/dev"
cp "$ROOT/scripts/ci/test-cloc-tooling.sh" "$ROOT/scripts/ci/verify-file-checksum.sh" "$adoption/scripts/ci/"
cp "$ROOT/scripts/dev/cloc-tooling.pl" "$adoption/scripts/dev/"
bash "$adoption/scripts/ci/test-cloc-tooling.sh" > "$fixture/adoption.log" 2>&1
echo 'Tooling LOC exporter integration and uncommitted consumer fixture passed'
fixture_complete=true
