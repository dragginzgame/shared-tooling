#!/usr/bin/env bash
# Shared companions: scripts/ci/install-ci-tool.sh scripts/ci/fixture-lifecycle.sh scripts/ci/prepare-script-fixture.sh scripts/ci/verify-file-checksum.sh
set -euo pipefail

ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
FIXTURE="$(fixture_create "${TMPDIR:-/tmp}/shared-tooling-installers-test.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE" "Installer fixtures retained"' EXIT

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

cat >"$FIXTURE/bin/uname" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
-s) printf '%s\n' "${INSTALLER_TEST_OS:-Linux}" ;;
-m) printf '%s\n' "${INSTALLER_TEST_ARCH:-x86_64}" ;;
*) exit 2 ;;
esac
[[ "$1" != "${INSTALLER_TEST_UNAME_FAILURE:-}" ]] || exit 79
SCRIPT
chmod +x "$FIXTURE/bin/uname"

# Alias normalization is shared; asset scope remains with each installer.
for os in Linux Darwin; do
    for architecture in x86_64 amd64 arm64 aarch64; do
        expected_architecture=x86_64
        case "$architecture" in arm64|aarch64) expected_architecture=arm64 ;; esac
        observed="$(PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_OS="$os" INSTALLER_TEST_ARCH="$architecture" \
            bash "$ROOT/scripts/dev/host-platform.sh")"
        [[ "$observed" == "$os:$expected_architecture" ]] || exit 1
    done
done
for observer in -s -m; do
    status=0
    PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_UNAME_FAILURE="$observer" \
        bash "$ROOT/scripts/ci/install-ci-tool.sh" actionlint --version 1.7.12 \
        --sha256 "$(printf '%064d' 0)" --install-dir "$FIXTURE/failed-observer" \
        > "$FIXTURE/observer.log" 2>&1 || status=$?
    [[ "$status" == 79 && ! -e "$FIXTURE/failed-observer" ]] || exit 1
done

cat >"$FIXTURE/bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

[[ -z "${INSTALLER_TEST_PROBES:-}" ]] || printf 'download\n' >> "$INSTALLER_TEST_PROBES"
output=""
url=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    -o)
        output="$2"
        shift 2
        ;;
    --proto | --proto-redir | --retry | --retry-delay | --retry-max-time | --connect-timeout | --max-time)
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

actionlint_checksum="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$archives/actionlint_1.7.12_linux_amd64.tar.gz")"
gitleaks_checksum="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$archives/gitleaks_8.30.1_linux_x64.tar.gz")"
shellcheck_checksum="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$archives/shellcheck-v0.11.0.linux.x86_64.tar.xz")"
sccache_checksum="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$archives/$sccache_package.tar.gz")"

# Default and explicitly selected catalogs use the same authenticated installer.
cat > "$FIXTURE/ci.env" <<CATALOG
SHARED_TOOLING_ACTIONLINT_VERSION=1.7.12
SHARED_TOOLING_ACTIONLINT_SHA256_LINUX_AMD64=$actionlint_checksum
SHARED_TOOLING_SHELLCHECK_VERSION=0.11.0
SHARED_TOOLING_SHELLCHECK_SHA256_LINUX_X86_64=$shellcheck_checksum
SHARED_TOOLING_GITLEAKS_VERSION=8.30.1
SHARED_TOOLING_GITLEAKS_SHA256_LINUX_X64=$gitleaks_checksum
SHARED_TOOLING_SCCACHE_VERSION=0.17.0
SHARED_TOOLING_SCCACHE_SHA256_LINUX_AMD64=$sccache_checksum
CATALOG
for tool in actionlint shellcheck gitleaks sccache; do
    PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        bash "$ROOT/scripts/ci/install-ci-tool.sh" "$tool" --catalog "$FIXTURE/ci.env" \
        --install-dir "$FIXTURE/catalog-installed" > "$FIXTURE/catalog-$tool.log"
    [[ -x "$FIXTURE/catalog-installed/$tool" ]] || exit 1
done
mkdir "$FIXTURE/snapshot"
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$FIXTURE/snapshot" scripts/ci/install-ci-tool.sh
cp "$FIXTURE/ci.env" "$FIXTURE/snapshot/ci/tool-versions.env"
PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$FIXTURE/snapshot/scripts/ci/install-ci-tool.sh" actionlint \
    --install-dir "$FIXTURE/default-installed" > "$FIXTURE/default-catalog.log"
[[ -x "$FIXTURE/default-installed/actionlint" ]] || exit 1
for invalid in missing malformed duplicate executable conflict; do
    cp "$FIXTURE/ci.env" "$FIXTURE/invalid.env"
    arguments=(actionlint --catalog "$FIXTURE/invalid.env" --install-dir "$FIXTURE/refused-$invalid")
    case "$invalid" in
        missing) arguments=(actionlint --catalog "$FIXTURE/missing.env" --install-dir "$FIXTURE/refused-$invalid") ;;
        malformed) printf '\nSHARED_TOOLING_GITLEAKS_VERSION=invalid\n' > "$FIXTURE/invalid.env" ;;
        duplicate) cat "$FIXTURE/ci.env" >> "$FIXTURE/invalid.env" ;;
        executable) printf '\ntouch SHOULD_NOT_EXIST\n' >> "$FIXTURE/invalid.env" ;;
        conflict) arguments+=(--version 1.7.12 --sha256 "$actionlint_checksum") ;;
    esac
    status=0
    PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        bash "$ROOT/scripts/ci/install-ci-tool.sh" "${arguments[@]}" > "$FIXTURE/catalog-$invalid.log" 2>&1 || status=$?
    [[ "$status" != 0 && ! -e "$FIXTURE/refused-$invalid" ]] || exit 1
done

for host in Linux:arm64 Darwin:x86_64 Darwin:arm64; do
    status=0
    : > "$FIXTURE/catalog-host-probes"
    INSTALLER_TEST_OS="${host%:*}" INSTALLER_TEST_ARCH="${host#*:}" \
        INSTALLER_TEST_PROBES="$FIXTURE/catalog-host-probes" PATH="$FIXTURE/bin:$PATH" \
        INSTALLER_TEST_ARCHIVES="$archives" \
        bash "$ROOT/scripts/ci/install-ci-tool.sh" actionlint --catalog "$FIXTURE/ci.env" \
        --install-dir "$FIXTURE/unqualified-host" > "$FIXTURE/catalog-host.log" 2>&1 || status=$?
    [[ "$status" != 0 && ! -e "$FIXTURE/unqualified-host" && ! -s "$FIXTURE/catalog-host-probes" ]] || exit 1
done

# A destination must be part of the invocation before any setup effect.
mkdir "$FIXTURE/admission-bin"
cat > "$FIXTURE/admission-bin/uname" <<'SCRIPT'
#!/usr/bin/env bash
printf 'host probe\n' >> "$INSTALLER_TEST_PROBES"
exit 93
SCRIPT
chmod +x "$FIXTURE/admission-bin/uname"
for destination in omitted environment empty; do
    arguments=(actionlint --version 1.7.12 --sha256 "$actionlint_checksum")
    [[ "$destination" != empty ]] || arguments+=(--install-dir '')
    destination_env=''
    [[ "$destination" != environment ]] || destination_env="$FIXTURE/unselected-$destination"
    : > "$FIXTURE/destination-probes"
    status=0
    TOOL_INSTALL_DIR="$destination_env" INSTALLER_TEST_PROBES="$FIXTURE/destination-probes" \
        PATH="$FIXTURE/admission-bin:$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        bash "$ROOT/scripts/ci/install-ci-tool.sh" "${arguments[@]}" > "$FIXTURE/destination-$destination.log" 2>&1 || status=$?
    [[ "$status" == 2 && ! -e "$FIXTURE/unselected-$destination" && ! -s "$FIXTURE/destination-probes" ]] || exit 1
done

TOOL_INSTALL_DIR="$FIXTURE/unselected-environment" PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-ci-tool.sh" sccache --version 0.17.0 \
    --sha256 "$sccache_checksum" --install-dir "$FIXTURE/installed" >/dev/null
[[ "$("$FIXTURE/installed/sccache" --version)" == 'sccache 0.17.0' ]] || exit 1
[[ ! -e "$FIXTURE/unselected-environment" ]] || exit 1


PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-ci-tool.sh" actionlint \
    --version 1.7.12 \
    --sha256 "$actionlint_checksum" \
    --install-dir "$FIXTURE/installed" >/dev/null
[[ "$("$FIXTURE/installed/actionlint" -version)" == "1.7.12" ]] || exit 1

# A directory introduced during download is not a publication container.
if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    INSTALLER_TEST_DIRECTORY_DESTINATION="$FIXTURE/changed-destination/actionlint" \
    bash "$ROOT/scripts/ci/install-ci-tool.sh" actionlint --version 1.7.12 \
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
    bash "$ROOT/scripts/ci/install-ci-tool.sh" actionlint --version 1.7.12 \
    --sha256 "$actionlint_checksum" --install-dir "$FIXTURE/changed-link" \
    > "$FIXTURE/changed-link.log" 2>&1
[[ ! -L "$FIXTURE/changed-link/actionlint" ]] || exit 1
cmp "$payloads/actionlint/actionlint" "$FIXTURE/changed-link/actionlint"
[[ "$(cat "$FIXTURE/changed-link/actionlint-target/actionlint")" == 'consumer-owned contents' ]] || exit 1

# Missing publication prerequisites fail before creating or downloading tools.
mkdir "$FIXTURE/no-perl"
ln -s "$(command -v bash)" "$FIXTURE/no-perl/bash"
ln -s "$FIXTURE/bin/uname" "$FIXTURE/no-perl/uname"
if PATH="$FIXTURE/no-perl" bash "$ROOT/scripts/ci/install-ci-tool.sh" actionlint \
    --version 1.7.12 --sha256 "$actionlint_checksum" --install-dir "$FIXTURE/unprepared" \
    > "$FIXTURE/no-perl.log" 2>&1; then exit 1; fi
[[ ! -e "$FIXTURE/unprepared" ]] || exit 1
grep -F 'Perl is required' "$FIXTURE/no-perl.log" > /dev/null

PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-ci-tool.sh" gitleaks \
    --version 8.30.1 \
    --sha256 "$gitleaks_checksum" \
    --install-dir "$FIXTURE/installed" >/dev/null
[[ "$("$FIXTURE/installed/gitleaks" version)" == "8.30.1" ]] || exit 1

PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-ci-tool.sh" shellcheck \
    --version 0.11.0 \
    --sha256 "$shellcheck_checksum" \
    --install-dir "$FIXTURE/installed" >/dev/null
"$FIXTURE/installed/shellcheck" --version | grep -F 'version: 0.11.0' >/dev/null

# An existing directory is consumer-owned and cannot become an install container.
mkdir -p "$FIXTURE/directory/actionlint"
printf 'keep directory contents\n' > "$FIXTURE/directory/actionlint/existing"
if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-ci-tool.sh" actionlint --version 1.7.12 --sha256 "$actionlint_checksum" \
    --install-dir "$FIXTURE/directory" > "$FIXTURE/directory.log" 2>&1; then exit 1; fi
[[ ! -e "$FIXTURE/directory/actionlint/actionlint" && "$(cat "$FIXTURE/directory/actionlint/existing")" == 'keep directory contents' ]] || exit 1

if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-ci-tool.sh" actionlint \
    --version 1.7.1 \
    --sha256 "$actionlint_checksum" \
    --install-dir "$FIXTURE/mismatch" >/dev/null 2>&1; then
    echo "installer test failed: actionlint accepted a prefix version match" >&2
    exit 1
fi

if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-ci-tool.sh" actionlint \
    --version 1.7.12 \
    --sha256 ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
    --install-dir "$FIXTURE/bad-checksum" >/dev/null 2>&1; then
    echo "installer test failed: actionlint accepted a mismatched checksum" >&2
    exit 1
fi

# All shared public entry points exercise the same preservation boundary.
for tool in actionlint gitleaks shellcheck sccache; do
    bash "$ROOT/scripts/ci/install-ci-tool.sh" "$tool" --help > "$FIXTURE/$tool-help.log" 2>&1
    case "$tool" in
        actionlint) version=1.7.12; digest="$actionlint_checksum"; archive=actionlint_1.7.12_linux_amd64.tar.gz ;;
        gitleaks) version=8.30.1; digest="$gitleaks_checksum"; archive=gitleaks_8.30.1_linux_x64.tar.gz ;;
        shellcheck) version=0.11.0; digest="$shellcheck_checksum"; archive=shellcheck-v0.11.0.linux.x86_64.tar.xz ;;
        sccache) version=0.17.0; digest="$sccache_checksum"; archive="$sccache_package.tar.gz" ;;
    esac
    cp "$FIXTURE/installed/$tool" "$FIXTURE/original"
    : > "$INSTALLER_SCCACHE_EXECUTIONS"
    if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        bash "$ROOT/scripts/ci/install-ci-tool.sh" "$tool" --version "$version" \
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
        digest="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$archives/$wrong_archive")"
    elif [[ "$tool" == sccache ]]; then
        wrong_package=sccache-v9.9.9-x86_64-unknown-linux-musl
        mkdir -p "$payloads/sccache/$wrong_package"
        cp "$FIXTURE/original" "$payloads/sccache/$wrong_package/sccache"
        tar -czf "$archives/$wrong_archive" -C "$payloads/sccache" "$wrong_package"
        digest="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$archives/$wrong_archive")"
    fi
    if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        bash "$ROOT/scripts/ci/install-ci-tool.sh" "$tool" --version 9.9.9 --sha256 "$digest" \
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
        bash "$ROOT/scripts/ci/install-ci-tool.sh" sccache --version 0.17.0 --sha256 "$sccache_checksum" \
        --install-dir "$FIXTURE/installed" > "$FIXTURE/rejected" 2>&1; then exit 1; fi
    cmp "$FIXTURE/original-sccache" "$FIXTURE/installed/sccache"
done
for attempt in "$FIXTURE/installed/.sccache-install."*; do
    [[ -f "$attempt/$sccache_package.tar.gz" ]] || continue
    cmp "$archives/$sccache_package.tar.gz" "$attempt/$sccache_package.tar.gz"
done
# Only the reviewed Linux x86-64 asset is selected; reject other hosts before
# creating an installation destination or attempting a download.
for host in Linux:aarch64 Darwin:x86_64 Darwin:arm64; do
    if PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
        INSTALLER_TEST_OS="${host%:*}" INSTALLER_TEST_ARCH="${host#*:}" \
        bash "$ROOT/scripts/ci/install-ci-tool.sh" sccache --version 0.17.0 --sha256 "$sccache_checksum" \
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
            bash "$ROOT/scripts/ci/install-ci-tool.sh" "$tool" --version "$version" --sha256 "$digest" \
            --install-dir "$FIXTURE/installed" >/dev/null
    done
done
echo "installer tests passed"
fixture_complete=true
