#!/usr/bin/env bash
# Shared companions: scripts/distribution/refresh-consumer.sh scripts/ci/verify-file-checksum.sh scripts/ci/verify-shared-tooling-snapshot.sh
set -euo pipefail
ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/snapshot-retirement.XXXXXX")"
FIXTURE="$(cd "$FIXTURE" && pwd -P)"
complete=false
finish() {
    local status=$?
    [[ "$complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$FIXTURE"
    else printf 'Failed retirement fixture retained: %s\n' "$FIXTURE" >&2; fi
    exit "$status"
}
trap finish EXIT
source_root="$FIXTURE/source"
seed="$FIXTURE/seed"
mkdir -p "$source_root/scripts/ci" "$seed" "$FIXTURE/bin"
git init -q "$source_root"
git -C "$source_root" config user.name 'Snapshot fixture'
git -C "$source_root" config user.email fixture@example.invalid
git -C "$source_root" config commit.gpgsign false
git -C "$source_root" config core.hooksPath /dev/null
git -C "$source_root" remote add origin https://example.invalid/shared-tooling
for path in verify-file-checksum.sh verify-shared-tooling-snapshot.sh; do
    cp -p "$ROOT/scripts/ci/$path" "$source_root/scripts/ci/"
done
printf '0.7.0\n' > "$source_root/VERSION"
printf '#!/bin/sh\n# Shared companions: obsolete.sh\n' > "$source_root/root.sh"
printf '#!/bin/sh\necho obsolete\n' > "$source_root/obsolete.sh"
chmod +x "$source_root/obsolete.sh"
git -C "$source_root" add .
git -C "$source_root" commit -qm initial
old_revision="$(git -C "$source_root" rev-parse HEAD)"
git init -q "$seed"
bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_root" \
    --consumer "$seed" --entrypoint root.sh > "$FIXTURE/initial.log"
[[ -f "$seed/obsolete.sh" ]] || exit 1
printf 'unrelated\n' > "$seed/unrelated"
git -C "$seed" add unrelated
printf '#!/bin/sh\n# Shared companions: current.sh\n' > "$source_root/root.sh"
printf '#!/bin/sh\necho current\n' > "$source_root/current.sh"
git -C "$source_root" rm -q obsolete.sh
git -C "$source_root" add .
git -C "$source_root" commit -qm replacement

# An unannotated payload record remains integrity evidence, not inferred roots.
consumer="$FIXTURE/adopt"
cp -Rp "$seed" "$consumer"
sed '/^# entrypoint/d' "$consumer/.shared-tooling.snapshot" > "$consumer/old-manifest"
mv "$consumer/old-manifest" "$consumer/.shared-tooling.snapshot"
if bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_root" \
    --consumer "$consumer" > "$FIXTURE/unselected.log" 2>&1; then exit 1; fi
bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_root" \
    --consumer "$consumer" --entrypoint root.sh --retire-file obsolete.sh > "$FIXTURE/adopt.log"
[[ ! -e "$consumer/obsolete.sh" && -f "$consumer/current.sh" ]] || exit 1

for state in unchanged absent edited committed mode staged symlink forged unavailable unowned required; do
    consumer="$FIXTURE/$state"
    cp -Rp "$seed" "$consumer"
    retire=obsolete.sh
    case "$state" in
        absent) rm "$consumer/obsolete.sh"; cp -p "$source_root/root.sh" "$consumer/root.sh" ;;
        edited) printf '# local\n' >> "$consumer/obsolete.sh" ;;
        committed)
            printf '# consumer-owned committed edit\n' >> "$consumer/obsolete.sh"
            git -C "$consumer" -c core.hooksPath=/dev/null add .
            git -C "$consumer" -c core.hooksPath=/dev/null -c commit.gpgsign=false \
                -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm 'Consumer edit' ;;
        mode) chmod -x "$consumer/obsolete.sh" ;;
        staged) git -C "$consumer" add obsolete.sh ;;
        symlink) mv "$consumer/obsolete.sh" "$consumer/kept"; ln -s kept "$consumer/obsolete.sh" ;;
        forged)
            printf '# local\n' >> "$consumer/obsolete.sh"
            digest="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$consumer/obsolete.sh")"
            awk -F '\t' -v OFS='\t' -v digest="$digest" '$1=="file" && $4=="obsolete.sh" {$2=digest} {print}' \
                "$consumer/.shared-tooling.snapshot" > "$consumer/forged"
            mv "$consumer/forged" "$consumer/.shared-tooling.snapshot" ;;
        unavailable)
            sed "s/$old_revision/1111111111111111111111111111111111111111/" "$consumer/.shared-tooling.snapshot" > "$consumer/missing"
            mv "$consumer/missing" "$consumer/.shared-tooling.snapshot" ;;
        unowned) retire=unrelated ;;
        required) retire=root.sh ;;
    esac
    cp -Rp "$consumer" "$FIXTURE/before-$state"
    if [[ "$state" == unchanged ]]; then
        status=0
        bash "$ROOT/scripts/distribution/refresh-consumer.sh" --preview --source "$source_root" \
            --consumer "$consumer" > "$FIXTURE/preview.log" 2>&1 || status=$?
        [[ "$status" == 2 ]] || exit 1
        grep -F "$(printf 'REMOVE\trequired\tobsolete.sh')" "$FIXTURE/preview.log" >/dev/null
        diff -r "$FIXTURE/before-$state" "$consumer"
        if bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_root" \
            --consumer "$consumer" > "$FIXTURE/unauthorized.log" 2>&1; then exit 1; fi
        diff -r "$FIXTURE/before-$state" "$consumer"
        bash "$ROOT/scripts/distribution/refresh-consumer.sh" --preview --source "$source_root" \
            --consumer "$consumer" --retire-file obsolete.sh > "$FIXTURE/approved.log"
        grep -F "$(printf 'REMOVE\tapproved\tobsolete.sh')" "$FIXTURE/approved.log" >/dev/null
        diff -r "$FIXTURE/before-$state" "$consumer"
    fi
    git -C "$consumer" write-tree > "$FIXTURE/index-before"
    status=0
    bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_root" \
        --consumer "$consumer" --retire-file "$retire" > "$FIXTURE/$state.log" 2>&1 || status=$?
    if [[ "$state" == unchanged || "$state" == absent ]]; then
        [[ "$status" == 0 && ! -e "$consumer/obsolete.sh" && -f "$consumer/current.sh" ]] || exit 1
        bash "$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh" --consumer "$consumer" >/dev/null
        bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_root" \
            --consumer "$consumer" > "$FIXTURE/$state-repeat.log"
    else
        [[ "$status" != 0 ]] || exit 1
        # Git's read-only status may refresh its index stat cache; compare its
        # semantic contents separately, alongside every non-Git input.
        diff -r --exclude=.git "$FIXTURE/before-$state" "$consumer"
    fi
    git -C "$consumer" write-tree > "$FIXTURE/index-after"
    cmp "$FIXTURE/index-before" "$FIXTURE/index-after"
done

# Retirement identity/index/manifest races must stop before publishing payloads.
export SNAPSHOT_REAL_GIT SNAPSHOT_RETIRE_REVISION="$old_revision"
SNAPSHOT_REAL_GIT="$(command -v git)"
cat > "$FIXTURE/bin/git" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" == 5 && "$3" == cat-file && "$4" == blob &&
    "$5" == "$SNAPSHOT_RETIRE_REVISION:obsolete.sh" && ! -e "$SNAPSHOT_RACE_MARKER" ]]; then
    case "$SNAPSHOT_RACE" in
        identity)
            cp -p "$SNAPSHOT_RACE_CONSUMER/obsolete.sh" "$SNAPSHOT_RACE_CONSUMER/replacement"
            mv "$SNAPSHOT_RACE_CONSUMER/replacement" "$SNAPSHOT_RACE_CONSUMER/obsolete.sh" ;;
        index) "$SNAPSHOT_REAL_GIT" -C "$SNAPSHOT_RACE_CONSUMER" add obsolete.sh ;;
        manifest) printf '# concurrent edit\n' >> "$SNAPSHOT_RACE_CONSUMER/.shared-tooling.snapshot" ;;
        symlink)
            mv "$SNAPSHOT_RACE_CONSUMER/obsolete.sh" "$SNAPSHOT_RACE_CONSUMER/preserved"
            ln -s preserved "$SNAPSHOT_RACE_CONSUMER/obsolete.sh" ;;
    esac
    touch "$SNAPSHOT_RACE_MARKER"
    cp -Rp "$SNAPSHOT_RACE_CONSUMER" "$SNAPSHOT_RACE_EXPECTED"
fi
exec "$SNAPSHOT_REAL_GIT" "$@"
SCRIPT
chmod +x "$FIXTURE/bin/git"
for race in identity index manifest symlink; do
    consumer="$FIXTURE/race-$race"
    cp -Rp "$seed" "$consumer"
    if SNAPSHOT_RACE="$race" SNAPSHOT_RACE_CONSUMER="$consumer" \
        SNAPSHOT_RACE_MARKER="$FIXTURE/seen-$race" SNAPSHOT_RACE_EXPECTED="$FIXTURE/expected-$race" \
        PATH="$FIXTURE/bin:$PATH" bash "$ROOT/scripts/distribution/refresh-consumer.sh" \
        --source "$source_root" --consumer "$consumer" --retire-file obsolete.sh \
        > "$FIXTURE/race-$race.log" 2>&1; then exit 1; fi
    [[ -f "$FIXTURE/seen-$race" ]] || exit 1
    diff -r --exclude=.git --exclude='.shared-tooling-refresh.*' "$FIXTURE/expected-$race" "$consumer"
    git -C "$consumer" write-tree > "$FIXTURE/race-index.tree"
    git -C "$FIXTURE/expected-$race" write-tree > "$FIXTURE/expected-index.tree"
    cmp "$FIXTURE/race-index.tree" "$FIXTURE/expected-index.tree"
done
rm "$FIXTURE/bin/git"

# Lose the process after the exact deletion, before manifest publication.
consumer="$FIXTURE/interrupted"
cp -Rp "$seed" "$consumer"
export SNAPSHOT_RETIRE_DESTINATION="$consumer/obsolete.sh"
export SNAPSHOT_REAL_RM
SNAPSHOT_REAL_RM="$(command -v rm)"
cat > "$FIXTURE/bin/rm" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" == 2 && "$1" == -- && "$2" == "$SNAPSHOT_RETIRE_DESTINATION" ]]; then
    "$SNAPSHOT_REAL_RM" "$@"
    exit 19
fi
exec "$SNAPSHOT_REAL_RM" "$@"
SCRIPT
chmod +x "$FIXTURE/bin/rm"
status=0
PATH="$FIXTURE/bin:$PATH" bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_root" \
    --consumer "$consumer" --retire-file obsolete.sh > "$FIXTURE/interrupted.log" 2>&1 || status=$?
[[ "$status" == 19 && ! -e "$consumer/obsolete.sh" ]] || exit 1
cmp "$seed/.shared-tooling.snapshot" "$consumer/.shared-tooling.snapshot"
bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_root" \
    --consumer "$consumer" --retire-file obsolete.sh > "$FIXTURE/reconciled.log"
bash "$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh" --consumer "$consumer" >/dev/null
# Replace the complete root selection, retiring a root and its former companion.
consumer="$FIXTURE/reselected"
cp -Rp "$seed" "$consumer"
bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_root" \
    --consumer "$consumer" --entrypoint current.sh --retire-file root.sh --retire-file obsolete.sh \
    > "$FIXTURE/reselected.log"
[[ ! -e "$consumer/root.sh" && ! -e "$consumer/obsolete.sh" && -f "$consumer/current.sh" ]] || exit 1
grep -F "$(printf '# entrypoint\tcurrent.sh')" "$consumer/.shared-tooling.snapshot" >/dev/null
for annotation in $'# entrypoint\t' $'# entrypoint\tcurrent.sh' $'# entrypoint\tunowned.sh' $'# entrypoint\t../escape' $'# entrypoint\tcurrent.sh\t' $'# entrypoint\t\tcurrent.sh'; do
    cp "$consumer/.shared-tooling.snapshot" "$FIXTURE/valid-manifest"
    printf '%s\n' "$annotation" >> "$consumer/.shared-tooling.snapshot"
    if bash "$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh" --consumer "$consumer" \
        > "$FIXTURE/bad-annotation.log" 2>&1; then exit 1; fi
    if bash "$ROOT/scripts/distribution/refresh-consumer.sh" --preview --source "$source_root" \
        --consumer "$consumer" > "$FIXTURE/bad-root-preview.log" 2>&1; then exit 1; fi
    cp "$FIXTURE/valid-manifest" "$consumer/.shared-tooling.snapshot"
done
# Missing committed companions fail before exporting anything, even in preview.
printf '#!/bin/sh\n# Shared companions: absent.sh\n' > "$source_root/root.sh"
git -C "$source_root" add root.sh
git -C "$source_root" commit -qm 'Synthetic unavailable companion'
cp -Rp "$consumer" "$FIXTURE/unavailable-before"
if bash "$ROOT/scripts/distribution/refresh-consumer.sh" --preview --source "$source_root" \
    --consumer "$consumer" --entrypoint root.sh > "$FIXTURE/missing-companion.log" 2>&1; then exit 1; fi
diff -r "$FIXTURE/unavailable-before" "$consumer"
complete=true
echo 'Snapshot retirement checks passed'
