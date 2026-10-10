#!/usr/bin/env bash
# Shared companions: scripts/ci/install-actionlint.sh scripts/ci/install-gitleaks.sh scripts/ci/install-shellcheck.sh scripts/ci/install-yq.sh scripts/ci/install-sccache.sh
set -euo pipefail

ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-tooling-installers-test.XXXXXX")"
fixture_complete=false
finish() {
    local status=$?
    # Bash 3.2 may report zero after nounset before assertions finish.
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$FIXTURE"
    else echo "Installer fixtures retained: $FIXTURE" >&2; fi
    exit "$status"
}
trap finish EXIT

archives="$FIXTURE/archives"
payloads="$FIXTURE/payloads"
mkdir -p "$archives" "$payloads/actionlint" "$payloads/gitleaks" \
    "$payloads/shellcheck/shellcheck-v0.11.0" "$FIXTURE/bin"

cat >"$payloads/actionlint/actionlint" <<'SCRIPT'
#!/usr/bin/env bash
printf '1.7.12\n'
SCRIPT
chmod +x "$payloads/actionlint/actionlint"
tar -czf "$archives/actionlint_1.7.12_linux_amd64.tar.gz" \
    -C "$payloads/actionlint" actionlint
cp "$archives/actionlint_1.7.12_linux_amd64.tar.gz" \
    "$archives/actionlint_1.7.1_linux_amd64.tar.gz"

cat >"$payloads/gitleaks/gitleaks" <<'SCRIPT'
#!/usr/bin/env bash
printf '8.30.1\n'
SCRIPT
chmod +x "$payloads/gitleaks/gitleaks"
tar -czf "$archives/gitleaks_8.30.1_linux_x64.tar.gz" \
    -C "$payloads/gitleaks" gitleaks

cat >"$payloads/shellcheck/shellcheck-v0.11.0/shellcheck" <<'SCRIPT'
#!/usr/bin/env bash
cat <<'OUTPUT'
ShellCheck - shell script analysis tool
version: 0.11.0
license: GNU General Public License, version 3
OUTPUT
SCRIPT
chmod +x "$payloads/shellcheck/shellcheck-v0.11.0/shellcheck"
tar -cJf "$archives/shellcheck-v0.11.0.linux.x86_64.tar.xz" \
    -C "$payloads/shellcheck" shellcheck-v0.11.0

sccache_package=sccache-v0.17.0-x86_64-unknown-linux-musl
mkdir -p "$payloads/sccache/$sccache_package"
cat > "$payloads/sccache/$sccache_package/sccache" <<'SCRIPT'
#!/usr/bin/env bash
echo executed >> "$INSTALLER_SCCACHE_EXECUTIONS"
printf 'sccache %s\n' "${INSTALLER_SCCACHE_VERSION:-0.17.0}"
exit "${INSTALLER_SCCACHE_STATUS:-0}"
SCRIPT
chmod +x "$payloads/sccache/$sccache_package/sccache"
tar -czf "$archives/$sccache_package.tar.gz" -C "$payloads/sccache" "$sccache_package"
export INSTALLER_SCCACHE_EXECUTIONS="$FIXTURE/sccache-executions"

for platform in linux_amd64 linux_arm64 darwin_amd64 darwin_arm64; do
    cat > "$archives/yq_$platform" <<'SCRIPT'
#!/usr/bin/env bash
echo 'yq (https://github.com/mikefarah/yq/) version v4.47.2'
exit "${INSTALLER_YQ_STATUS:-0}"
SCRIPT
done

cat >"$FIXTURE/bin/uname" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
-s) printf '%s\n' "${INSTALLER_TEST_OS:-Linux}" ;;
-m) printf '%s\n' "${INSTALLER_TEST_ARCH:-x86_64}" ;;
*) exit 2 ;;
esac
SCRIPT
chmod +x "$FIXTURE/bin/uname"

cat >"$FIXTURE/bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

output=""
url=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    -o)
        output="$2"
        shift 2
        ;;
    --proto | --proto-redir | --retry | --retry-delay | --connect-timeout | --max-time)
        shift 2
        ;;
    -* )
        shift
        ;;
    *)
        url="$1"
        shift
        ;;
    esac
done

[[ -n "$output" && -n "$url" ]] || exit 1
cp "$INSTALLER_TEST_ARCHIVES/${url##*/}" "$output"
# Model another process creating the destination after initial admission.
if [[ -n "${INSTALLER_TEST_DIRECTORY_DESTINATION:-}" ]]; then
    mkdir "$INSTALLER_TEST_DIRECTORY_DESTINATION"
    printf 'consumer-owned contents\n' > "$INSTALLER_TEST_DIRECTORY_DESTINATION/actionlint"
fi
if [[ -n "${INSTALLER_TEST_LINK_DESTINATION:-}" ]]; then
    mkdir "$INSTALLER_TEST_LINK_DESTINATION-target"
    printf 'consumer-owned contents\n' > "$INSTALLER_TEST_LINK_DESTINATION-target/actionlint"
    ln -s "$INSTALLER_TEST_LINK_DESTINATION-target" "$INSTALLER_TEST_LINK_DESTINATION"
fi
SCRIPT
chmod +x "$FIXTURE/bin/curl"

checksum_sha256() {
    local file="$1"
    local output

    if command -v sha256sum >/dev/null 2>&1; then
        output="$(sha256sum "$file")"
    else
        output="$(shasum -a 256 "$file")"
    fi
    printf '%s\n' "${output%% *}"
}

actionlint_checksum="$(checksum_sha256 "$archives/actionlint_1.7.12_linux_amd64.tar.gz")"
gitleaks_checksum="$(checksum_sha256 "$archives/gitleaks_8.30.1_linux_x64.tar.gz")"
shellcheck_checksum="$(checksum_sha256 "$archives/shellcheck-v0.11.0.linux.x86_64.tar.xz")"
sccache_checksum="$(checksum_sha256 "$archives/$sccache_package.tar.gz")"

PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-sccache.sh" --version 0.17.0 \
    --sha256 "$sccache_checksum" --install-dir "$FIXTURE/installed" >/dev/null
[[ "$("$FIXTURE/installed/sccache" --version)" == 'sccache 0.17.0' ]] || exit 1


PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-actionlint.sh" \
    --version 1.7.12 \
    --sha256 "$actionlint_checksum" \
    --install-dir "$FIXTURE/installed" >/dev/null
[[ "$("$FIXTURE/installed/actionlint" -version)" == "1.7.12" ]] || exit 1

# A directory introduced during download is not a publication container.
if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    INSTALLER_TEST_DIRECTORY_DESTINATION="$FIXTURE/changed-destination/actionlint" \
    bash "$ROOT/scripts/ci/install-actionlint.sh" --version 1.7.12 \
    --sha256 "$actionlint_checksum" --install-dir "$FIXTURE/changed-destination" \
    > "$FIXTURE/changed-destination.log" 2>&1; then
    echo 'installer accepted a destination changed into a directory' >&2; exit 1
fi
[[ "$(cat "$FIXTURE/changed-destination/actionlint/actionlint")" == 'consumer-owned contents' ]] || exit 1
for attempt in "$FIXTURE/changed-destination/.actionlint-install."*; do
    cmp "$archives/actionlint_1.7.12_linux_amd64.tar.gz" "$attempt/actionlint_1.7.12_linux_amd64.tar.gz"
    cmp "$payloads/actionlint/actionlint" "$attempt/actionlint"
done

# A late symlink is replaced as an entry; its target remains untouched.
PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    INSTALLER_TEST_LINK_DESTINATION="$FIXTURE/changed-link/actionlint" \
    bash "$ROOT/scripts/ci/install-actionlint.sh" --version 1.7.12 \
    --sha256 "$actionlint_checksum" --install-dir "$FIXTURE/changed-link" \
    > "$FIXTURE/changed-link.log" 2>&1
[[ ! -L "$FIXTURE/changed-link/actionlint" ]] || exit 1
cmp "$payloads/actionlint/actionlint" "$FIXTURE/changed-link/actionlint"
[[ "$(cat "$FIXTURE/changed-link/actionlint-target/actionlint")" == 'consumer-owned contents' ]] || exit 1

# Missing publication prerequisites fail before creating or downloading tools.
mkdir "$FIXTURE/no-perl"
ln -s "$(command -v bash)" "$FIXTURE/no-perl/bash"
ln -s "$FIXTURE/bin/uname" "$FIXTURE/no-perl/uname"
if PATH="$FIXTURE/no-perl" bash "$ROOT/scripts/ci/install-actionlint.sh" \
    --version 1.7.12 --sha256 "$actionlint_checksum" --install-dir "$FIXTURE/unprepared" \
    > "$FIXTURE/no-perl.log" 2>&1; then exit 1; fi
[[ ! -e "$FIXTURE/unprepared" ]] || exit 1
grep -F 'Perl is required' "$FIXTURE/no-perl.log" > /dev/null

PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-gitleaks.sh" \
    --version 8.30.1 \
    --sha256 "$gitleaks_checksum" \
    --install-dir "$FIXTURE/installed" >/dev/null
[[ "$("$FIXTURE/installed/gitleaks" version)" == "8.30.1" ]] || exit 1

PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-shellcheck.sh" \
    --version 0.11.0 \
    --sha256 "$shellcheck_checksum" \
    --install-dir "$FIXTURE/installed" >/dev/null
"$FIXTURE/installed/shellcheck" --version | grep -F 'version: 0.11.0' >/dev/null

yq_checksum="$(checksum_sha256 "$archives/yq_linux_amd64")"
for platform in Linux:x86_64 Linux:aarch64 Darwin:x86_64 Darwin:arm64; do
    PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        INSTALLER_TEST_OS="${platform%:*}" INSTALLER_TEST_ARCH="${platform#*:}" \
        bash "$ROOT/scripts/ci/install-yq.sh" --version 4.47.2 --sha256 "$yq_checksum" \
        --install-dir "$FIXTURE/installed" >/dev/null
    [[ "$("$FIXTURE/installed/yq" --version)" == 'yq (https://github.com/mikefarah/yq/) version v4.47.2' ]] || exit 1
done
for failure in version checksum; do
    version=4.47.2
    digest="$yq_checksum"
    if [[ "$failure" == version ]]; then version=4.47.1; else digest=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff; fi
    if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        bash "$ROOT/scripts/ci/install-yq.sh" --version "$version" --sha256 "$digest" \
        --install-dir "$FIXTURE/installed" >/dev/null 2>&1; then
        echo "installer test failed: yq accepted a $failure mismatch" >&2
        exit 1
    fi
    # Failed installation must preserve the previously verified executable.
    [[ "$("$FIXTURE/installed/yq" --version)" == 'yq (https://github.com/mikefarah/yq/) version v4.47.2' ]] || exit 1
done

cp "$FIXTURE/installed/yq" "$FIXTURE/original-yq"
if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" INSTALLER_YQ_STATUS=17 \
    bash "$ROOT/scripts/ci/install-yq.sh" --version 4.47.2 --sha256 "$yq_checksum" \
    --install-dir "$FIXTURE/installed" > "$FIXTURE/yq-status.log" 2>&1; then exit 1; fi
cmp "$FIXTURE/original-yq" "$FIXTURE/installed/yq"
retained=0
for attempt in "$FIXTURE/installed/.yq-install."*; do
    [[ -f "$attempt/yq_linux_amd64" ]] || exit 1
    cmp "$archives/yq_linux_amd64" "$attempt/yq_linux_amd64"
    retained=$((retained + 1))
done
[[ "$retained" == 3 ]] || exit 1
mkdir -p "$FIXTURE/yq-directory/yq"
printf 'keep directory contents\n' > "$FIXTURE/yq-directory/yq/existing"
if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-yq.sh" --version 4.47.2 --sha256 "$yq_checksum" \
    --install-dir "$FIXTURE/yq-directory" > "$FIXTURE/yq-directory.log" 2>&1; then exit 1; fi
[[ ! -e "$FIXTURE/yq-directory/yq/yq" && "$(cat "$FIXTURE/yq-directory/yq/existing")" == 'keep directory contents' ]] || exit 1
for version in 3.4.5 4.47.2-rc.1; do
    if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        bash "$ROOT/scripts/ci/install-yq.sh" --version "$version" --sha256 "$yq_checksum" \
        --install-dir "$FIXTURE/yq-unsupported" > "$FIXTURE/yq-version.log" 2>&1; then exit 1; fi
    [[ ! -e "$FIXTURE/yq-unsupported" ]] || exit 1
done

if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-actionlint.sh" \
    --version 1.7.1 \
    --sha256 "$actionlint_checksum" \
    --install-dir "$FIXTURE/mismatch" >/dev/null 2>&1; then
    echo "installer test failed: actionlint accepted a prefix version match" >&2
    exit 1
fi

if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-actionlint.sh" \
    --version 1.7.12 \
    --sha256 ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
    --install-dir "$FIXTURE/bad-checksum" >/dev/null 2>&1; then
    echo "installer test failed: actionlint accepted a mismatched checksum" >&2
    exit 1
fi

# All shared public entry points exercise the same preservation boundary.
for tool in actionlint gitleaks shellcheck sccache; do
    case "$tool" in
        actionlint) version=1.7.12; digest="$actionlint_checksum"; archive=actionlint_1.7.12_linux_amd64.tar.gz ;;
        gitleaks) version=8.30.1; digest="$gitleaks_checksum"; archive=gitleaks_8.30.1_linux_x64.tar.gz ;;
        shellcheck) version=0.11.0; digest="$shellcheck_checksum"; archive=shellcheck-v0.11.0.linux.x86_64.tar.xz ;;
        sccache) version=0.17.0; digest="$sccache_checksum"; archive="$sccache_package.tar.gz" ;;
    esac
    cp "$FIXTURE/installed/$tool" "$FIXTURE/original"
    : > "$INSTALLER_SCCACHE_EXECUTIONS"
    if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        bash "$ROOT/scripts/ci/install-$tool.sh" --version "$version" \
        --sha256 ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
        --install-dir "$FIXTURE/installed" > "$FIXTURE/rejected" 2>&1; then exit 1; fi
    cmp "$FIXTURE/original" "$FIXTURE/installed/$tool"
    [[ ! -s "$INSTALLER_SCCACHE_EXECUTIONS" ]] || exit 1
    retained=0
    for attempt in "$FIXTURE/installed/.$tool-install."*; do
        [[ -f "$attempt/$archive" ]] || continue
        cmp "$archives/$archive" "$attempt/$archive"
        retained=$((retained + 1))
    done
    [[ "$retained" == 1 ]] || exit 1
    # The wrong expected version has authenticated bytes, but may not replace
    # the already-installed executable. Preserve the rejected candidate too.
    wrong_archive="${archive/"$version"/9.9.9}"
    cp "$archives/$archive" "$archives/$wrong_archive"
    if [[ "$tool" == shellcheck ]]; then
        mkdir -p "$payloads/shellcheck/shellcheck-v9.9.9"
        cp "$FIXTURE/original" "$payloads/shellcheck/shellcheck-v9.9.9/shellcheck"
        tar -cJf "$archives/$wrong_archive" -C "$payloads/shellcheck" shellcheck-v9.9.9
        digest="$(checksum_sha256 "$archives/$wrong_archive")"
    elif [[ "$tool" == sccache ]]; then
        wrong_package=sccache-v9.9.9-x86_64-unknown-linux-musl
        mkdir -p "$payloads/sccache/$wrong_package"
        cp "$FIXTURE/original" "$payloads/sccache/$wrong_package/sccache"
        tar -czf "$archives/$wrong_archive" -C "$payloads/sccache" "$wrong_package"
        digest="$(checksum_sha256 "$archives/$wrong_archive")"
    fi
    if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        bash "$ROOT/scripts/ci/install-$tool.sh" --version 9.9.9 --sha256 "$digest" \
        --install-dir "$FIXTURE/installed" > "$FIXTURE/rejected" 2>&1; then exit 1; fi
    cmp "$FIXTURE/original" "$FIXTURE/installed/$tool"
done

# Successful version text does not override a failed probe, and prefix matches
# must not admit a different sccache version. Neither failure replaces the tool.
cp "$FIXTURE/installed/sccache" "$FIXTURE/original-sccache"
for failure in status version; do
    probe_status=0; reported_version=0.17.0
    if [[ "$failure" == status ]]; then probe_status=7; else reported_version=0.17.00; fi
    if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        INSTALLER_SCCACHE_STATUS="$probe_status" INSTALLER_SCCACHE_VERSION="$reported_version" \
        bash "$ROOT/scripts/ci/install-sccache.sh" --version 0.17.0 --sha256 "$sccache_checksum" \
        --install-dir "$FIXTURE/installed" > "$FIXTURE/rejected" 2>&1; then exit 1; fi
    cmp "$FIXTURE/original-sccache" "$FIXTURE/installed/sccache"
done
# Only the reviewed Linux x86-64 asset is selected; reject other hosts before
# creating an installation destination or attempting a download.
for host in Linux:aarch64 Darwin:x86_64 Darwin:arm64; do
    if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        INSTALLER_TEST_OS="${host%:*}" INSTALLER_TEST_ARCH="${host#*:}" \
        bash "$ROOT/scripts/ci/install-sccache.sh" --version 0.17.0 --sha256 "$sccache_checksum" \
        --install-dir "$FIXTURE/unsupported-$host" > "$FIXTURE/rejected" 2>&1; then exit 1; fi
    [[ ! -e "$FIXTURE/unsupported-$host" ]] || exit 1
done

# Exercise each native asset spelling using substitutes, not native binaries.
for host in Linux:aarch64 Darwin:x86_64 Darwin:arm64; do
    case "$host" in
        Linux:aarch64) action_platform=linux_arm64; leaks_platform=linux_arm64; shell_platform=linux.aarch64 ;;
        Darwin:x86_64) action_platform=darwin_amd64; leaks_platform=darwin_x64; shell_platform=darwin.x86_64 ;;
        Darwin:arm64) action_platform=darwin_arm64; leaks_platform=darwin_arm64; shell_platform=darwin.aarch64 ;;
    esac
    cp "$archives/actionlint_1.7.12_linux_amd64.tar.gz" "$archives/actionlint_1.7.12_$action_platform.tar.gz"
    cp "$archives/gitleaks_8.30.1_linux_x64.tar.gz" "$archives/gitleaks_8.30.1_$leaks_platform.tar.gz"
    cp "$archives/shellcheck-v0.11.0.linux.x86_64.tar.xz" "$archives/shellcheck-v0.11.0.$shell_platform.tar.xz"
    for tool in actionlint gitleaks shellcheck; do
        case "$tool" in
            actionlint) version=1.7.12; digest="$actionlint_checksum" ;;
            gitleaks) version=8.30.1; digest="$gitleaks_checksum" ;;
            shellcheck) version=0.11.0; digest="$shellcheck_checksum" ;;
        esac
        PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
            INSTALLER_TEST_OS="${host%:*}" INSTALLER_TEST_ARCH="${host#*:}" \
            bash "$ROOT/scripts/ci/install-$tool.sh" --version "$version" --sha256 "$digest" \
            --install-dir "$FIXTURE/installed" >/dev/null
    done
done
echo "installer tests passed"
fixture_complete=true
