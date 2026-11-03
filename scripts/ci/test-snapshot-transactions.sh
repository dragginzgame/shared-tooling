#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/distribution/refresh-consumer.sh scripts/ci/verify-file-checksum.sh scripts/ci/verify-shared-tooling-snapshot.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
mkdir -p "$ROOT/target"
FIXTURE="$(mktemp -d "$ROOT/target/snapshot-transactions.XXXXXX")"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE" "Failed snapshot transaction fixture retained"' EXIT
REAL_GIT="$(command -v git)"
export REAL_GIT
checksum_path=scripts/ci/verify-file-checksum.sh
verifier_path=scripts/ci/verify-shared-tooling-snapshot.sh
# Advance a real, unchanged uncommitted export without touching its index.
# Only these isolated source fixtures create synthetic commits.
advance_source="$FIXTURE/advance-source"
advance_seed="$FIXTURE/advance-seed"
mkdir -p "$advance_source/scripts/ci" "$advance_seed" "$FIXTURE/advance-bin"
git init -q "$advance_source"
git -C "$advance_source" config user.name 'Snapshot fixture'
git -C "$advance_source" config user.email 'fixture@example.invalid'
git -C "$advance_source" config commit.gpgsign false
git -C "$advance_source" config core.hooksPath /dev/null
git -C "$advance_source" remote add origin https://example.invalid/shared-tooling
for path in "$checksum_path" "$verifier_path"; do cp -p "$ROOT/$path" "$advance_source/$path"; done
printf '#!/usr/bin/env bash\nprintf "old snapshot\\n"\n' > "$advance_source/scripts/ci/sample.sh"
printf '0.2.8\n' > "$advance_source/VERSION"
chmod +x "$advance_source/scripts/ci/sample.sh"
git -C "$advance_source" add scripts VERSION
git -C "$advance_source" commit -qm 'Synthetic previous snapshot'
git init -q "$advance_seed"
bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$advance_source" --consumer "$advance_seed" \
    --entrypoint "$checksum_path" --entrypoint "$verifier_path" --entrypoint scripts/ci/sample.sh > "$FIXTURE/advance-initial.log"
printf 'unrelated staged input\n' > "$advance_seed/unrelated"
git -C "$advance_seed" add unrelated
printf '#!/usr/bin/env bash\nprintf "new snapshot\\n"\n' > "$advance_source/scripts/ci/sample.sh"
printf '0.2.9\n' > "$advance_source/VERSION"
chmod -x "$advance_source/scripts/ci/sample.sh"
git -C "$advance_source" add scripts/ci/sample.sh VERSION
git -C "$advance_source" commit -qm 'Synthetic next snapshot'
cp -Rp "$advance_seed" "$FIXTURE/advance-preview-before"
bash "$ROOT/scripts/distribution/refresh-consumer.sh" --preview \
    --source "$advance_source" --consumer "$advance_seed" > "$FIXTURE/advance-preview.log"
grep -F "$(printf 'UPDATE\tselected\tscripts/ci/sample.sh')" "$FIXTURE/advance-preview.log" >/dev/null
[[ "$(grep -c '^KEEP' "$FIXTURE/advance-preview.log")" == 2 ]] || exit 1
diff -r "$FIXTURE/advance-preview-before" "$advance_seed"
export SNAPSHOT_ADVANCE_SOURCE="$advance_source"
cat > "$FIXTURE/advance-bin/git" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == -C && "$2" == "$SNAPSHOT_ADVANCE_SOURCE" && "$3" == cat-file && "$4" == blob && "$5" == *:scripts/ci/* &&
    ! -e "$SNAPSHOT_ADVANCE_CONSUMER/mutated" ]]; then
    consumer="$SNAPSHOT_ADVANCE_CONSUMER"
    case "$SNAPSHOT_ADVANCE_CASE" in
        manifest-race) printf '# concurrent manifest edit\n' >> "$consumer/.shared-tooling.snapshot" ;;
        index-race) "$REAL_GIT" -C "$consumer" update-index --add --cacheinfo "100755,$SNAPSHOT_CONFLICT_BLOB,scripts/ci/sample.sh" ;;
        manifest-index-race) "$REAL_GIT" -C "$consumer" update-index --add --cacheinfo "100644,$SNAPSHOT_CONFLICT_BLOB,.shared-tooling.snapshot" ;;
        path-race)
            cp -p "$consumer/scripts/ci/sample.sh" "$consumer/replacement"
            mv "$consumer/replacement" "$consumer/scripts/ci/sample.sh" ;;
        parent-race) mv "$consumer/scripts" "$consumer/kept-scripts"; ln -s kept-scripts "$consumer/scripts" ;;
        *) exec "$REAL_GIT" "$@" ;;
    esac
    touch "$consumer/mutated"
    "$REAL_GIT" -C "$consumer" write-tree > "$consumer/expected-index"
    cp -p "$consumer/.shared-tooling.snapshot" "$consumer/expected-manifest"
fi
exec "$REAL_GIT" "$@"
SCRIPT
chmod +x "$FIXTURE/advance-bin/git"
for state in unchanged partial edited mode staged symlink forged unavailable manifest-race index-race manifest-index-race path-race parent-race; do
    consumer="$FIXTURE/advance-$state"
    cp -Rp "$advance_seed" "$consumer"
    conflict_blob="$(printf 'staged conflict\n' | git -C "$consumer" hash-object -w --stdin)"
    case "$state" in
        partial) cp -p "$advance_source/scripts/ci/sample.sh" "$consumer/scripts/ci/sample.sh" ;;
        edited) printf '# local edit\n' >> "$consumer/scripts/ci/sample.sh" ;;
        mode) chmod -x "$consumer/scripts/ci/sample.sh" ;;
        staged) git -C "$consumer" update-index --add --cacheinfo "100755,$conflict_blob,scripts/ci/sample.sh" ;;
        symlink) mv "$consumer/scripts/ci/sample.sh" "$consumer/kept-sample"; ln -s ../../kept-sample "$consumer/scripts/ci/sample.sh" ;;
        forged)
            printf '# local edit\n' >> "$consumer/scripts/ci/sample.sh"
            digest="$(bash "$ROOT/$checksum_path" --print sha256 "$consumer/scripts/ci/sample.sh")"
            awk -F '\t' -v OFS='\t' -v digest="$digest" '$1 == "file" && $4 == "scripts/ci/sample.sh" {$2=digest} {print}' \
                "$consumer/.shared-tooling.snapshot" > "$consumer/forged"
            mv "$consumer/forged" "$consumer/.shared-tooling.snapshot" ;;
        unavailable)
            awk -F '\t' -v OFS='\t' '$1 == "revision" {$2="1111111111111111111111111111111111111111"} {print}' \
                "$consumer/.shared-tooling.snapshot" > "$consumer/unavailable"
            mv "$consumer/unavailable" "$consumer/.shared-tooling.snapshot" ;;
    esac
    cp -p "$consumer/scripts/ci/sample.sh" "$consumer/expected-sample"
    cp -p "$consumer/.shared-tooling.snapshot" "$consumer/expected-manifest"
    git -C "$consumer" write-tree > "$consumer/expected-index"
    status=0
    SNAPSHOT_ADVANCE_CASE="$state" SNAPSHOT_ADVANCE_CONSUMER="$consumer" SNAPSHOT_CONFLICT_BLOB="$conflict_blob" \
        PATH="$FIXTURE/advance-bin:$PATH" bash "$ROOT/scripts/distribution/refresh-consumer.sh" \
        --source "$advance_source" --consumer "$consumer" > "$FIXTURE/advance-$state.log" 2>&1 || status=$?
    if [[ "$state" == unchanged || "$state" == partial ]]; then
        [[ "$status" == 0 ]] || exit 1
        [[ "$(awk -F '\t' '$1 == "# version" {print $2}' "$consumer/.shared-tooling.snapshot")" == 0.2.9 ]] || exit 1
        cmp "$advance_source/scripts/ci/sample.sh" "$consumer/scripts/ci/sample.sh"
        [[ ! -x "$consumer/scripts/ci/sample.sh" ]] || exit 1
        bash "$ROOT/$verifier_path" --consumer "$consumer" >/dev/null
    else
        [[ "$status" != 0 ]] || exit 1
        cmp "$consumer/expected-sample" "$consumer/scripts/ci/sample.sh"
        if [[ -x "$consumer/expected-sample" ]]; then [[ -x "$consumer/scripts/ci/sample.sh" ]] || exit 1;
        else [[ ! -x "$consumer/scripts/ci/sample.sh" ]] || exit 1; fi
        cmp "$consumer/expected-manifest" "$consumer/.shared-tooling.snapshot"
    fi
    [[ "$(git -C "$consumer" write-tree)" == "$(cat "$consumer/expected-index")" ]] || exit 1
    [[ "$(cat "$consumer/unrelated")" == 'unrelated staged input' ]] || exit 1
    if git -C "$consumer" rev-parse --verify HEAD >/dev/null 2>&1; then exit 1; fi
    cmp "$advance_seed/$checksum_path" "$consumer/$checksum_path"
    cmp "$advance_seed/$verifier_path" "$consumer/$verifier_path"
done

# Fail in the middle of a payload copy, and mutate destination/index while a
# replacement is prepared. Neither failure may overwrite the admitted old file.
mkdir "$FIXTURE/copy-bin"
export SNAPSHOT_REAL_CP
SNAPSHOT_REAL_CP="$(command -v cp)"
cat > "$FIXTURE/copy-bin/cp" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" == 3 && "$1" == -p && "$2" == */files/scripts/ci/sample.sh ]]; then
    if [[ "$SNAPSHOT_COPY_CASE" == interrupted ]]; then
        printf 'partial replacement\n' > "$3"
        exit 23
    fi
    "$SNAPSHOT_REAL_CP" "$@"
    if [[ "$SNAPSHOT_COPY_CASE" == payload-race ]]; then
        printf '# concurrent edit\n' >> "$SNAPSHOT_COPY_CONSUMER/scripts/ci/sample.sh"
        "$SNAPSHOT_REAL_CP" -p "$SNAPSHOT_COPY_CONSUMER/scripts/ci/sample.sh" "$SNAPSHOT_COPY_CONSUMER/expected-sample"
    else
        "$REAL_GIT" -C "$SNAPSHOT_COPY_CONSUMER" add scripts/ci/sample.sh
        "$REAL_GIT" -C "$SNAPSHOT_COPY_CONSUMER" write-tree > "$SNAPSHOT_COPY_CONSUMER/expected-index"
    fi
    exit 0
fi
exec "$SNAPSHOT_REAL_CP" "$@"
SCRIPT
chmod +x "$FIXTURE/copy-bin/cp"
for state in interrupted payload-race index-race; do
    consumer="$FIXTURE/copy-$state"
    cp -Rp "$advance_seed" "$consumer"
    cp -p "$consumer/scripts/ci/sample.sh" "$consumer/expected-sample"
    git -C "$consumer" write-tree > "$consumer/expected-index"
    status=0
    SNAPSHOT_COPY_CASE="$state" SNAPSHOT_COPY_CONSUMER="$consumer" PATH="$FIXTURE/copy-bin:$PATH" \
        bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$advance_source" --consumer "$consumer" \
        > "$FIXTURE/copy-$state.log" 2>&1 || status=$?
    [[ "$status" != 0 ]]
    [[ "$state" != interrupted || "$status" == 23 ]]
    cmp "$consumer/expected-sample" "$consumer/scripts/ci/sample.sh"
    [[ -x "$consumer/scripts/ci/sample.sh" ]]
    cmp "$advance_seed/.shared-tooling.snapshot" "$consumer/.shared-tooling.snapshot"
    [[ "$(git -C "$consumer" write-tree)" == "$(cat "$consumer/expected-index")" ]]
    [[ -z "$(find "$consumer" -name '.shared-tooling-payload.*')" ]]
    if [[ "$state" == interrupted ]]; then
        bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$advance_source" --consumer "$consumer" \
            > "$FIXTURE/copy-retry.log"
        cmp "$advance_source/scripts/ci/sample.sh" "$consumer/scripts/ci/sample.sh"
        [[ ! -x "$consumer/scripts/ci/sample.sh" ]]
        bash "$ROOT/$verifier_path" --consumer "$consumer" >/dev/null
        [[ "$(git -C "$consumer" write-tree)" == "$(cat "$consumer/expected-index")" ]]
    fi
done

echo "snapshot transactions test passed"
fixture_complete=true
