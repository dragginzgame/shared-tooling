#!/usr/bin/env bash
# Observe only. Callers own host matrices, PATH changes and later setup.
set -euo pipefail
if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo 'usage: check-native-host.sh Linux|Darwin ARCHITECTURE [MACOS_MAJOR]' >&2
    exit 2
fi
expected_os="$1" expected_architecture="$2"
[[ "$expected_architecture" =~ ^[A-Za-z0-9_]+$ ]] || exit 2
case "$expected_os:$#" in
    Linux:2) ;;
    Darwin:3) [[ "$3" =~ ^[1-9][0-9]*$ ]] || exit 2 ;;
    *) echo 'select Linux with two arguments or Darwin with an explicit macOS major' >&2; exit 2 ;;
esac
# Standalone assignments preserve an observer's nonzero exit, even when it
# printed the expected value. Comparison cannot turn failed observation clean.
observed_os="$(uname -s)"
observed_architecture="$(uname -m)"
if [[ "$observed_os" != "$expected_os" || "$observed_architecture" != "$expected_architecture" ]]; then
    printf 'native host mismatch: expected %s/%s, observed %s/%s\n' \
        "$expected_os" "$expected_architecture" "$observed_os" "$observed_architecture" >&2
    exit 1
fi
if [[ "$expected_os" == Darwin ]]; then
    observed_version="$(sw_vers -productVersion)"
    if [[ ! "$observed_version" =~ ^[0-9]+(\.[0-9]+){1,2}$ || "${observed_version%%.*}" != "$3" ]]; then
        printf 'native macOS version mismatch: expected major %s, observed %s\n' "$3" "$observed_version" >&2
        exit 1
    fi
fi
