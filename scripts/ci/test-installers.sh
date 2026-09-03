#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-tooling-installers-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

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

cat >"$FIXTURE/bin/uname" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
-s) printf 'Linux\n' ;;
-m) printf 'x86_64\n' ;;
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

[[ -n "$output" && -n "$url" ]]
cp "$INSTALLER_TEST_ARCHIVES/${url##*/}" "$output"
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

PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-actionlint.sh" \
    --version 1.7.12 \
    --sha256 "$actionlint_checksum" \
    --install-dir "$FIXTURE/installed" >/dev/null
[[ "$("$FIXTURE/installed/actionlint" -version)" == "1.7.12" ]]

PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-gitleaks.sh" \
    --version 8.30.1 \
    --sha256 "$gitleaks_checksum" \
    --install-dir "$FIXTURE/installed" >/dev/null
[[ "$("$FIXTURE/installed/gitleaks" version)" == "8.30.1" ]]

PATH="$FIXTURE/bin:$PATH" INSTALLER_TEST_ARCHIVES="$archives" \
    bash "$ROOT/scripts/ci/install-shellcheck.sh" \
    --version 0.11.0 \
    --sha256 "$shellcheck_checksum" \
    --install-dir "$FIXTURE/installed" >/dev/null
"$FIXTURE/installed/shellcheck" --version | grep -F 'version: 0.11.0' >/dev/null

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

echo "installer tests passed"

