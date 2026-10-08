#!/usr/bin/env bash
set -euo pipefail

# Online CI-only negative qualification. Use the real installer, checksum guard
# and upstream Quill payload in a NEW disposable root. Never touch active tools.
# Success is an intentional exit 1, but only after writing expected.sha256.
# The workflow must observe failure, upload through the ordinary collector,
# download that artifact, then verify every expected byte against this manifest.
[[ $# == 1 && ! -e "$1" && ! -L "$1" ]] || {
    echo 'usage: qualify-native-failure-retention.sh <new-evidence-directory>' >&2; exit 2;
}
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
mkdir -p "$1/consumer" "$1/temp/portable-fixtures"
fixture="$(cd "$1" && pwd -P)"
echo "Native failure evidence: $fixture"
original="$ROOT/ci/ic-tools.tsv"
pins="$fixture/temp/portable-fixtures/rejected-pins.tsv"
bad_digest=0000000000000000000000000000000000000000000000000000000000000000
awk -F '\t' -v OFS='\t' -v digest="$bad_digest" '$1 == "quill" { $4 = digest } { print }' "$original" > "$pins"
status=0
make --no-print-directory -C "$fixture/consumer" -f "$ROOT/make/tools.mk" \
    SHARED_TOOLING_ROOT="$ROOT" IC_TOOL_PINS="$pins" install-ic-tools \
    2>&1 | tee "$fixture/temp/ic-tools-install.log" || status=$?
[[ "$status" == 2 ]] || { echo 'Expected the install recipe to fail' >&2; exit 1; }
[[ ! -e "$fixture/consumer/.tools/ic" && ! -L "$fixture/consumer/.tools/ic" ]]
set -- "$fixture/consumer/.tools/"ic-set.*
[[ $# == 1 && -d "$1" && ! -f "$1/files.sha256" ]]
candidate="$1"
cmp "$pins" "$candidate/pins.tsv"
host="$(cat "$candidate/host")"
set -- "$candidate/downloads/quill/"*
[[ $# == 1 && -s "$1" ]]
archive="$1"
digest="$(awk -F '\t' -v host="$host" '$1 == "quill" && $3 == host { print $4 }' "$original")"
# Prove this was an actual upstream payload rejected by the altered pin, not a
# network outage or a substitute download with the same failure status.
bash "$ROOT/scripts/ci/verify-file-checksum.sh" sha256 "$digest" "$archive"

# Exercise offline --check with actual native bytes and a damaged receipt. The
# checksum guard must reject it before executable version probing. Preserve both
# the install candidate and the deliberately invalid installed bundle.
bundle="$fixture/consumer/.tools/ic-set.check"
mkdir -p "$bundle/bin"
cp "$archive" "$bundle/bin/quill"
chmod +x "$bundle/bin/quill"
cp "$original" "$bundle/pins.tsv"
cp "$candidate/host" "$bundle/host"
printf '%s  bin/quill\n' "$bad_digest" > "$bundle/files.sha256"
ln -s ic-set.check "$fixture/consumer/.tools/ic"
status=0
make --no-print-directory -C "$fixture/consumer" -f "$ROOT/make/tools.mk" \
    SHARED_TOOLING_ROOT="$ROOT" IC_TOOL_PINS="$original" ic-tools-check \
    2>&1 | tee "$fixture/temp/ic-tools-check.log" || status=$?
[[ "$status" == 2 && "$(readlink "$fixture/consumer/.tools/ic")" == ic-set.check ]]
bash "$ROOT/scripts/ci/verify-file-checksum.sh" sha256 "$digest" "$bundle/bin/quill"
cmp "$original" "$bundle/pins.tsv"

# The real Rust installer and Make entrypoints, with Cargo replaced at its
# install boundary. No registry build/download is needed to qualify retention.
mkdir "$fixture/bin"
cat > "$fixture/bin/cargo" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ $# == 9 && "$1" == install && "$6" == --root && "$8" == --target-dir && "$9" == "$7/build" ]]
mkdir -p "$9"
printf 'retained Rust build output\n' > "$9/failed-build.txt"
echo 'injected Cargo installation failure' >&2
exit 23
SCRIPT
chmod +x "$fixture/bin/cargo"
for phase in install check; do
    target=install-rust-tools
    [[ "$phase" != check ]] || target=rust-tools-check
    status=0
    PATH="$fixture/bin:$PATH" make --no-print-directory -C "$fixture/consumer" -f "$ROOT/make/tools.mk" \
        SHARED_TOOLING_ROOT="$ROOT" RUST_TOOL_VERSIONS="$ROOT/ci/tool-versions.env" "$target" \
        2>&1 | tee "$fixture/temp/rust-tools-$phase.log" || status=$?
    [[ "$status" == 2 && -s "$fixture/consumer/.tools/rust/build/failed-build.txt" ]]
done
grep -F 'injected Cargo installation failure' "$fixture/temp/rust-tools-install.log" >/dev/null
grep -F 'missing or mismatched cargo-sort' "$fixture/temp/rust-tools-check.log" >/dev/null

{
    printf 'source_commit=%s\nhost=%s\nrun_id=%s\nrun_attempt=%s\ninstall_status=2\ncheck_status=2\n' \
        "$(git -C "$ROOT" rev-parse HEAD)" "$host" "${GITHUB_RUN_ID:-local}" "${GITHUB_RUN_ATTEMPT:-local}"
    printf 'rust_install_status=2\nrust_check_status=2\nrust_cargo=substituted\n'
    # Bind local dirty-source runs as well as hosted committed-source runs.
    for path in scripts/ci/qualify-native-failure-retention.sh scripts/dev/install-ic-tools.sh scripts/dev/install-rust-tools.sh \
        scripts/ci/ic-tool-pins.awk scripts/ci/verify-file-checksum.sh \
        scripts/ci/verify-evidence-checksums.sh scripts/ci/archive-evidence.sh make/tools.mk ci/ic-tools.tsv \
        ci/tool-versions.env .github/actions/retain-failure-evidence/action.yml; do
        printf '%s  %s\n' "$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$ROOT/$path")" "$path"
    done
} > "$fixture/temp/portable-fixtures/source.txt"
# The collector archives paths relative to each selected evidence root. Keep
# the oracle outside the upload selection and verify original bytes after download.
cd "$fixture"
find consumer/.tools/ic-set.* consumer/.tools/rust/build temp -type f -print | LC_ALL=C sort > files.txt
while IFS= read -r file; do
    printf '%s  %s\n' "$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$file")" "${file#*/}"
done < files.txt > expected.sha256.tmp
# The line-oriented checksum manifest deliberately excludes this filename.
# The workflow separately checks its bytes/mode and the unfollowed link.
printf 'retained unusual filename\n' > temp/portable-fixtures/$'line\nbreak:payload'
chmod 640 temp/portable-fixtures/$'line\nbreak:payload'
printf 'outside collection\n' > temp/outside-evidence
ln -s ../outside-evidence temp/portable-fixtures/link
echo 'Expected install/check failures qualified; deliberately failing this CI step for collection.' >&2
mv expected.sha256.tmp expected.sha256
# A failed/refused invocation cannot qualify a stale manifest from another try.
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo 'qualified=true' >> "$GITHUB_OUTPUT"
fi
exit 1
