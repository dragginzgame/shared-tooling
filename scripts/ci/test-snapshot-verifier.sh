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
if "$BASH" "$verifier" --consumer "$consumer" --require-annotations > "$fixture/annotations.log" 2>&1; then exit 1; fi
{ printf '# version\t0.31.0\n'; cat "$fixture/manifest"; } > "$consumer/.shared-tooling.snapshot"
"$BASH" "$verifier" --consumer "$consumer" --require-annotations > "$fixture/annotated.log"
sed '/^# entrypoint/d' "$consumer/.shared-tooling.snapshot" > "$fixture/no-entrypoints"
if "$BASH" "$verifier" --read-manifest "$fixture/no-entrypoints" --require-annotations > "$fixture/annotations.log" 2>&1; then exit 1; fi
cp -p "$fixture/manifest" "$consumer/.shared-tooling.snapshot"
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
# Command substitution drops NUL, so a record with a NUL beside a correct digest
# must be rejected before capture. The fake backend reports the real digest and
# adds a NUL on one selected call only.
nul_backend="$fixture/nul-backend"
mkdir "$nul_backend"
if command -v sha256sum >/dev/null 2>&1; then
    real_digest=("$(command -v sha256sum)")
else
    real_digest=("$(command -v shasum)" -a 256)
fi
{
    printf '#!%s\n' "$BASH"
    # shellcheck disable=SC2016 # The generated backend expands it.
    printf 'record="$('
    printf '%q ' "${real_digest[@]}"
    printf ')"\n'
    cat <<'SCRIPT'
digest="${record%% *}"
count=$(($(cat "$NUL_COUNTER") + 1))
printf '%s\n' "$count" > "$NUL_COUNTER"
if [[ "$count" != "$NUL_ON_CALL" ]]; then printf '%s  -\n' "$digest"; exit 0; fi
case "$NUL_POSITION" in
    backend-failure) printf '%s  -\n' "$digest"; exit 3 ;;
    digest) printf '%s\0%s  -\n' "${digest:0:12}" "${digest:12}" ;;
    marker) printf '%s\0  -\n' "$digest" ;;
    trailing) printf '%s  -\n\0' "$digest" ;;
esac
SCRIPT
} > "$nul_backend/sha256sum"
cp -p "$nul_backend/sha256sum" "$nul_backend/shasum"
chmod +x "$nul_backend/sha256sum" "$nul_backend/shasum"
export NUL_COUNTER="$fixture/nul-counter"
run_nul_backend() {
    printf '0\n' > "$NUL_COUNTER"
    PATH="$nul_backend:$PATH" NUL_ON_CALL="$1" NUL_POSITION="$2" "$BASH" "$verifier" "${@:3}"
}
run_nul_backend 0 none --consumer "$consumer" > "$fixture/nul-control.log"
status=0
run_nul_backend 1 backend-failure --consumer "$consumer" > "$fixture/backend-failure.log" 2>&1 || status=$?
[[ "$status" == 1 ]] || exit 1
grep -F 'checksum backend failed: payload.txt' "$fixture/backend-failure.log"
if grep -F 'NUL byte' "$fixture/backend-failure.log"; then exit 1; fi
for position in digest marker trailing; do
    status=0
    run_nul_backend 1 "$position" --consumer "$consumer" > "$fixture/nul-$position.log" 2>&1 || status=$?
    [[ "$status" == 1 ]] || exit 1
    grep -F 'checksum output contains a NUL byte: payload.txt' "$fixture/nul-$position.log"
    if grep -F 'backend failed' "$fixture/nul-$position.log"; then exit 1; fi
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
# The reviewed blob is hashed through the same NUL guard. Call 2 is the first
# reviewed-source digest, after the consumer copy of payload.txt.
for position in digest marker trailing; do
    status=0
    run_nul_backend 2 "$position" --consumer "$consumer" --source "$source_root" --revision "$revision" \
        > "$fixture/source-nul-$position.log" 2>&1 || status=$?
    [[ "$status" == 1 ]] || exit 1
    grep -F 'source checksum output contains a NUL byte: payload.txt' "$fixture/source-nul-$position.log"
done
# A declared file absent from the reviewed commit is reported as missing, not as
# a mode difference: ls-tree succeeds with no output for an absent path.
printf 'unreviewed extra\n' > "$consumer/extra.txt"
{
    cat "$fixture/source-manifest"
    printf 'file\t%s\t-\textra.txt\n' "$("$BASH" "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$consumer/extra.txt")"
} > "$consumer/.shared-tooling.snapshot"
"$BASH" "$verifier" --consumer "$consumer" > "$fixture/extra-integrity.log"
if "$BASH" "$verifier" --consumer "$consumer" --source "$source_root" --revision "$revision" > "$fixture/extra-source.log" 2>&1; then exit 1; fi
grep -F 'reviewed source is missing: extra.txt' "$fixture/extra-source.log"
rm "$consumer/extra.txt"
cp "$fixture/source-manifest" "$consumer/.shared-tooling.snapshot"
if "$BASH" "$verifier" --consumer "$consumer" --source "$source_root" > "$fixture/unpaired.log" 2>&1; then exit 1; fi
fixture_complete=true
printf 'Snapshot verifier path admission and inert-helper corruption checks passed\n'
