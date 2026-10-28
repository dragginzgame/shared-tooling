#!/usr/bin/env bash
# Shared companions: scripts/ci/verify-shared-tooling-snapshot.sh scripts/ci/verify-file-checksum.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/snapshot-verifier.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Snapshot verifier fixture retained"' EXIT

# A controlled three-file export keeps generic verifier qualification independent
# of consumer payload size, catalogs, Git state and distribution/setup effects.
consumer="$fixture/consumer"
mkdir -p "$consumer/scripts/ci"
cp -p "$ROOT/scripts/ci/verify-file-checksum.sh" "$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh" "$consumer/scripts/ci/"
printf 'inert sample payload\n' > "$consumer/payload.txt"
{
    printf 'format\t1\nsource\thttps://github.com/dragginzgame/shared-tooling\nrevision\t%s\n' \
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    printf '# entrypoint\tpayload.txt\n'
    for path in payload.txt scripts/ci/verify-file-checksum.sh scripts/ci/verify-shared-tooling-snapshot.sh; do
        digest="$("$BASH" "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$consumer/$path")"
        mode=-
        [[ ! -x "$consumer/$path" ]] || mode=x
        printf 'file\t%s\t%s\t%s\n' "$digest" "$mode" "$path"
    done
} > "$consumer/.shared-tooling.snapshot"
verifier="$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh"
"$BASH" "$verifier" --consumer "$consumer" > "$fixture/valid.log"
cp -p "$consumer/.shared-tooling.snapshot" "$fixture/manifest"
# A forbidden physical root must not select its valid trimmed neighbor, even
# when reached through a normal-looking alias or containing a valid snapshot.
for suffix in $'\n' $'\n\n' $'\r' $'\r\n' $'\nchild'; do
    forbidden="$consumer$suffix"
    mkdir "$forbidden"
    cp -Rp "$consumer/." "$forbidden/"
    ln -s "$forbidden" "$fixture/alias"
    for selected in "$forbidden" "$fixture/alias"; do
        status=0
        CDPATH="$fixture" "$BASH" "$verifier" --consumer "$selected" > "$fixture/forbidden.log" 2>&1 || status=$?
        [[ "$status" == 1 ]] || exit 1
        cmp "$fixture/manifest" "$forbidden/.shared-tooling.snapshot"
        cmp "$fixture/manifest" "$consumer/.shared-tooling.snapshot"
    done
    rm "$fixture/alias"
done
# Missing records cannot be hidden by trimming either.
missing="$consumer"$'\n'
rm -rf -- "$missing"
mkdir "$missing"
status=0
"$BASH" "$verifier" --consumer "$missing" > "$fixture/missing.log" 2>&1 || status=$?
[[ "$status" == 1 && ! -e "$missing/.shared-tooling.snapshot" ]] || exit 1
ln -s "$consumer" "$fixture/alias"
(cd "$fixture" && CDPATH="$fixture/consumer" "$BASH" "$verifier" --consumer alias) > "$fixture/alias.log"
rm "$fixture/alias"
# The resolved parent of a custom manifest obeys the same path policy.
mkdir "$consumer/config"$'\n'
cp "$fixture/manifest" "$consumer/config"$'\n'/snapshot
ln -s $'config\n' "$consumer/config-alias"
status=0
"$BASH" "$verifier" --consumer "$consumer" --manifest config-alias/snapshot > "$fixture/parent.log" 2>&1 || status=$?
[[ "$status" == 1 ]] || exit 1
rm "$consumer/config-alias"

# The checksum helper is inspected data, never verification authority.
cp -p "$consumer/payload.txt" "$fixture/payload"
cp -p "$consumer/scripts/ci/verify-file-checksum.sh" "$fixture/checksum"
export SNAPSHOT_HELPER_EXECUTED="$fixture/helper-executed"
for corruption in payload helper both; do
    [[ "$corruption" == helper ]] || printf 'changed\n' >> "$consumer/payload.txt"
    if [[ "$corruption" != payload ]]; then
        # shellcheck disable=SC2016 # Only an incorrectly executed helper expands it.
        printf '%s\n' '#!/usr/bin/env bash' ': > "$SNAPSHOT_HELPER_EXECUTED"' 'exit 0' > "$consumer/scripts/ci/verify-file-checksum.sh"
    fi
    status=0
    "$BASH" "$verifier" --consumer "$consumer" > "$fixture/$corruption.log" 2>&1 || status=$?
    [[ "$status" == 1 && ! -e "$SNAPSHOT_HELPER_EXECUTED" ]] || exit 1
    cp -p "$fixture/payload" "$consumer/payload.txt"
    cp -p "$fixture/checksum" "$consumer/scripts/ci/verify-file-checksum.sh"
    "$BASH" "$verifier" --consumer "$consumer" > "$fixture/restored.log"
done
# Source admission is anchored outside the consumer manifest. A rewritten
# payload and digest pass local integrity, but must fail reviewed-source proof.
source_root="$fixture/trusted-source"
mkdir -p "$source_root"
cp -Rp "$consumer/." "$source_root/"
git -C "$source_root" init -q
git -C "$source_root" add payload.txt scripts/ci
git -C "$source_root" -c user.name=Fixture -c user.email=fixture@example.invalid -c core.hooksPath=/dev/null commit -qm 'reviewed fixture'
revision="$(git -C "$source_root" rev-parse HEAD)"
sed "s/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/$revision/" "$fixture/manifest" > "$consumer/.shared-tooling.snapshot"
"$BASH" "$verifier" --consumer "$consumer" --source "$source_root" --revision "$revision" > "$fixture/source-valid.log"
cp "$consumer/.shared-tooling.snapshot" "$fixture/source-manifest"
old_digest="$("$BASH" "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$consumer/payload.txt")"
printf 'tampered payload\n' > "$consumer/payload.txt"
new_digest="$("$BASH" "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$consumer/payload.txt")"
sed "s/$old_digest/$new_digest/" "$fixture/source-manifest" > "$consumer/.shared-tooling.snapshot"
"$BASH" "$verifier" --consumer "$consumer" > "$fixture/rewritten-integrity.log"
if "$BASH" "$verifier" --consumer "$consumer" --source "$source_root" --revision "$revision" > "$fixture/rewritten-source.log" 2>&1; then exit 1; fi
grep -F 'manifest payload differs from reviewed source' "$fixture/rewritten-source.log"
cp "$fixture/payload" "$consumer/payload.txt"
cp "$fixture/manifest" "$consumer/.shared-tooling.snapshot"
if "$BASH" "$verifier" --consumer "$consumer" --source "$source_root" --revision "$revision" > "$fixture/wrong-revision.log" 2>&1; then exit 1; fi
grep -F 'manifest revision differs' "$fixture/wrong-revision.log"
cp "$fixture/source-manifest" "$consumer/.shared-tooling.snapshot"
# Working source edits do not change immutable source proof.
printf 'unreviewed source edit\n' > "$source_root/payload.txt"
"$BASH" "$verifier" --consumer "$consumer" --source "$source_root" --revision "$revision" > "$fixture/source-dirty.log"
chmod +x "$consumer/payload.txt"
sed $'s/\t-\tpayload.txt/\tx\tpayload.txt/' "$fixture/source-manifest" > "$consumer/.shared-tooling.snapshot"
"$BASH" "$verifier" --consumer "$consumer" > "$fixture/rewritten-mode-integrity.log"
if "$BASH" "$verifier" --consumer "$consumer" --source "$source_root" --revision "$revision" > "$fixture/rewritten-mode-source.log" 2>&1; then exit 1; fi
grep -F 'reviewed source mode differs' "$fixture/rewritten-mode-source.log"
chmod -x "$consumer/payload.txt"
cp "$fixture/source-manifest" "$consumer/.shared-tooling.snapshot"
if "$BASH" "$verifier" --consumer "$consumer" --source "$source_root" > "$fixture/unpaired.log" 2>&1; then exit 1; fi
fixture_complete=true
printf 'Snapshot verifier path admission and inert-helper corruption checks passed\n'
