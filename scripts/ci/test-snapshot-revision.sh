#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/distribution/refresh-consumer.sh scripts/ci/verify-file-checksum.sh scripts/ci/verify-shared-tooling-snapshot.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
mkdir -p "$ROOT/target"
FIXTURE="$(mktemp -d "$ROOT/target/snapshot-revision.XXXXXX")"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE" "Failed pinned snapshot fixture retained"' EXIT
export GIT_OPTIONAL_LOCKS=0
source_root="$FIXTURE/source"
consumer="$FIXTURE/consumer"
exporter=scripts/distribution/refresh-consumer.sh
helpers=(scripts/ci/shared-companions.sh scripts/ci/verify-file-checksum.sh scripts/ci/verify-shared-tooling-snapshot.sh)
mkdir -p "$source_root/scripts/ci" "$source_root/scripts/distribution" "$consumer"
git init -q "$source_root"
git -C "$source_root" config user.name 'Snapshot fixture'
git -C "$source_root" config user.email 'fixture@example.invalid'
git -C "$source_root" config commit.gpgsign false
git -C "$source_root" config core.hooksPath /dev/null
git -C "$source_root" remote add origin https://example.invalid/shared-tooling
for path in "$exporter" "${helpers[@]}"; do cp -p "$ROOT/$path" "$source_root/$path"; done
printf '#!/bin/sh\n# Shared companions: leaf.txt\nprintf "old committed payload\\n"\n' > "$source_root/sample.sh"
chmod +x "$source_root/sample.sh"
printf 'old leaf\n' > "$source_root/leaf.txt"
printf '0.1.0\n' > "$source_root/VERSION"
git -C "$source_root" add scripts sample.sh leaf.txt VERSION
git -C "$source_root" commit -qm 'Synthetic pinned source'
old="$(git -C "$source_root" rev-parse HEAD)"
printf '#!/bin/sh\n# Shared companions: next.txt\nprintf "new committed payload\\n"\n' > "$source_root/sample.sh"
chmod -x "$source_root/sample.sh"
printf 'next leaf\n' > "$source_root/next.txt"
printf '0.2.0\n' > "$source_root/VERSION"
git -C "$source_root" add sample.sh next.txt VERSION
git -C "$source_root" commit -qm 'Synthetic newer source'
new="$(git -C "$source_root" rev-parse HEAD)"
git -C "$source_root" tag -am 'Synthetic tag object' snapshot-tag
# Deliberately replace a selected working file with a symlink, delete companions,
# stage an unrelated edit, and disagree with the committed display version.
rm "$source_root/sample.sh" "$source_root/leaf.txt" "$source_root/next.txt"
ln -s VERSION "$source_root/sample.sh"
printf '9.9.9\n' > "$source_root/VERSION"
printf 'staged work\n' > "$source_root/local.txt"
git -C "$source_root" add local.txt
# Replacement refs must not reinterpret an exact commit or its display version.
git -C "$source_root" replace "$old" "$new"
git init -q "$consumer"
cp -Rp "$source_root" "$FIXTURE/source-before"
cp -Rp "$consumer" "$FIXTURE/consumer-before"
run_export() {
    bash "$source_root/$exporter" --source "$source_root" --consumer "$consumer" "$@"
}
refuse() {
    local name="$1"; shift
    if run_export "$@" > "$FIXTURE/$name.log" 2>&1; then
        echo "unexpected export success: $name" >&2; exit 1
    fi
}
refuse unpinned --entrypoint sample.sh
grep -F 'source checkout must be clean' "$FIXTURE/unpinned.log" >/dev/null
run_export --revision "$old" --impact --entrypoint sample.sh > "$FIXTURE/impact.log"
grep -F "$(printf 'source\t0.1.0\t%s' "$old")" "$FIXTURE/impact.log" >/dev/null
diff -r "$FIXTURE/consumer-before" "$consumer"
run_export --revision "$old" --entrypoint sample.sh > "$FIXTURE/old.log"
git --no-replace-objects -C "$source_root" show "$old:sample.sh" > "$FIXTURE/expected-sample"
cmp "$FIXTURE/expected-sample" "$consumer/sample.sh"
[[ -x "$consumer/sample.sh" && -f "$consumer/leaf.txt" && ! -e "$consumer/next.txt" ]]
bash "$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh" --consumer "$consumer" --source "$source_root" --revision "$old" > "$FIXTURE/independent.log"
run_export --revision "$new" > "$FIXTURE/new.log"
[[ ! -x "$consumer/sample.sh" && ! -e "$consumer/leaf.txt" && -f "$consumer/next.txt" ]]
run_export --revision "$new" > "$FIXTURE/retry.log"
diff -r "$FIXTURE/source-before" "$source_root"
cp -Rp "$consumer" "$FIXTURE/consumer-adopted"
for revision in HEAD "${old:0:12}" '--help' 0000000000000000000000000000000000000000 \
    "$(git -C "$source_root" rev-parse 'HEAD^{tree}')" \
    "$(git -C "$source_root" rev-parse HEAD:VERSION)" \
    "$(git -C "$source_root" rev-parse snapshot-tag)"; do
    refuse invalid-revision --revision "$revision"
    diff -r "$FIXTURE/consumer-adopted" "$consumer"
done
refuse duplicate-revision --revision "$new" --revision "$old"
# Refuse dirty executable code before it can be sourced, even with a dirty
# export source otherwise supported. Preserve all source/index/consumer inputs.
for path in "$exporter" "${helpers[@]}"; do
    printf '\nprintf "unsafe helper executed" > "%s"\n' "$FIXTURE/executed" >> "$source_root/$path"
    refuse dirty-execution --revision "$new"
    grep -F 'execution source differs' "$FIXTURE/dirty-execution.log" >/dev/null
    [[ ! -e "$FIXTURE/executed" ]]
    cp -p "$FIXTURE/source-before/$path" "$source_root/$path"
    diff -r "$FIXTURE/consumer-adopted" "$consumer"
done
# A clean, newer execution source may export an older commit from another dirty
# local database; it need not switch its branch to the payload's revision.
execution_root="$FIXTURE/execution"
cp -Rp "$source_root" "$execution_root"
bash "$execution_root/$exporter" --source "$source_root" --consumer "$consumer" --revision "$new" --preview > "$FIXTURE/separate.log"

# Inject concurrent changes after consumer capture but during committed payload
# reads. Source working edits cannot affect pinned bytes; origin changes and
# consumer edits still refuse before publication.
mkdir "$FIXTURE/bin"
export SNAPSHOT_REAL_GIT SNAPSHOT_REV_SOURCE SNAPSHOT_REV_CONSUMER SNAPSHOT_REV_MARKER
SNAPSHOT_REAL_GIT="$(command -v git)"
SNAPSHOT_REV_SOURCE="$source_root"
SNAPSHOT_REV_CONSUMER="$consumer"
SNAPSHOT_REV_MARKER="$FIXTURE/race-fired"
cat > "$FIXTURE/bin/git" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == -C && "$2" == "$SNAPSHOT_REV_SOURCE" && "$3" == cat-file && "$4" == blob && "$5" == *:sample.sh && ! -e "$SNAPSHOT_REV_MARKER" ]]; then
    touch "$SNAPSHOT_REV_MARKER"
    case "$SNAPSHOT_REV_RACE" in
        origin) "$SNAPSHOT_REAL_GIT" -C "$SNAPSHOT_REV_SOURCE" remote set-url origin https://example.invalid/changed ;;
        consumer) printf 'concurrent edit\n' >> "$SNAPSHOT_REV_CONSUMER/sample.sh" ;;
        source) printf 'concurrent working edit\n' >> "$SNAPSHOT_REV_SOURCE/VERSION" ;;
    esac
fi
exec "$SNAPSHOT_REAL_GIT" "$@"
WRAPPER
chmod +x "$FIXTURE/bin/git"
for race in origin consumer source; do
    rm -f "$SNAPSHOT_REV_MARKER"
    status=0
    SNAPSHOT_REV_RACE="$race" PATH="$FIXTURE/bin:$PATH" run_export --revision "$old" > "$FIXTURE/race-$race.log" 2>&1 || status=$?
    [[ -e "$SNAPSHOT_REV_MARKER" ]]
    if [[ "$race" == source ]]; then
        [[ "$status" == 0 ]]
        cmp "$FIXTURE/expected-sample" "$consumer/sample.sh"
        grep -F 'concurrent working edit' "$source_root/VERSION" >/dev/null
    else
        [[ "$status" != 0 ]]
        cmp "$FIXTURE/consumer-adopted/.shared-tooling.snapshot" "$consumer/.shared-tooling.snapshot"
        if [[ "$race" == origin ]]; then
            grep -F 'source origin changed' "$FIXTURE/race-origin.log" >/dev/null
            git -C "$source_root" remote set-url origin https://example.invalid/shared-tooling
        else
            grep -F 'consumer destination has local changes' "$FIXTURE/race-consumer.log" >/dev/null
            grep -F 'concurrent edit' "$consumer/sample.sh" >/dev/null
            cp -p "$FIXTURE/consumer-adopted/sample.sh" "$consumer/sample.sh"
        fi
    fi
done
# Only the injected working edit is allowed to differ from the original source.
cp -p "$FIXTURE/source-before/VERSION" "$source_root/VERSION"
diff -r "$FIXTURE/source-before" "$source_root"
echo 'pinned snapshot revision test passed'
fixture_complete=true
