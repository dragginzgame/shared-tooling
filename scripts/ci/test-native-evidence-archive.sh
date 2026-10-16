#!/usr/bin/env bash
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/native-archive.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Native archive fixture retained"' EXIT
real_tar="$(command -v tar)"
real_shasum="$(command -v shasum)"
export NATIVE_ARCHIVE_REAL_TAR="$real_tar" NATIVE_ARCHIVE_REAL_SHASUM="$real_shasum"
for scenario in success occupied checksum-occupied output-link inventory-link inside alias-inside hash-failure tar-failure final-hash-failure; do (
    mkdir "$fixture/$scenario"
    cd "$fixture/$scenario"
    mkdir -p 'evidence tree/scratch/release/.git/release-state' bin
    printf 'readable diagnostics\n' > diagnostics.tar.gz
    shasum -a 256 diagnostics.tar.gz > diagnostics.tar.gz.sha256
    cp diagnostics.tar.gz.sha256 expected-diagnostics.sha256
    printf 'source identity\n' > 'evidence tree/source.txt'
    printf 'index\n' > 'evidence tree/scratch/release/.git/index'
    printf 'intent\n' > 'evidence tree/scratch/release/.git/release-state/attempt.plan'
    printf 'executable\n' > 'evidence tree/scratch/executable:probe'
    chmod 755 'evidence tree/scratch/executable:probe'
    printf 'newline filename\n' > "evidence tree/scratch/"$'line\nfile'
    output=native.tar.gz
    expected=2
    case "$scenario" in
        success) expected=0 ;;
        occupied) printf 'earlier archive\n' > "$output" ;;
        checksum-occupied) printf 'earlier checksum\n' > "$output.sha256" ;;
        output-link) ln -s missing "$output" ;;
        inventory-link) ln -s scratch/release/.git/index 'evidence tree/artifact-sha256.txt' ;;
        inside) output='evidence tree/forbidden.tar.gz' ;;
        alias-inside) ln -s "$PWD/evidence tree/scratch" alias; output=alias/forbidden.tar.gz ;;
        hash-failure|final-hash-failure)
            expected=31
            printf '#!%s\n' "$BASH" > bin/shasum
            cat >> bin/shasum <<'HASH'
case "$NATIVE_ARCHIVE_SCENARIO:${3:-}" in
    hash-failure:*|final-hash-failure:native.tar.gz) printf 'partial hash\n'; exit 31 ;;
esac
exec "$NATIVE_ARCHIVE_REAL_SHASUM" "$@"
HASH
            chmod +x bin/shasum ;;
        tar-failure)
            expected=23
            printf '#!%s\nprintf "partial archive"\necho archive-write-failed >&2\nexit 23\n' "$BASH" > bin/tar
            chmod +x bin/tar ;;
    esac
    status=0
    PATH="$PWD/bin:$PATH" NATIVE_ARCHIVE_SCENARIO="$scenario" \
        bash "$root/scripts/ci/collect-native-evidence.sh" 'evidence tree' "$output" > result.log 2>&1 || status=$?
    [[ "$status" == "$expected" ]] || exit 1
    [[ "$(cat diagnostics.tar.gz)" == 'readable diagnostics' ]] || exit 1
    cmp expected-diagnostics.sha256 diagnostics.tar.gz.sha256
    shasum -a 256 -c diagnostics.tar.gz.sha256 > diagnostic-check.log
    [[ "$(cat 'evidence tree/scratch/release/.git/release-state/attempt.plan')" == intent ]] || exit 1
    [[ "$(cat 'evidence tree/scratch/release/.git/index')" == index ]] || exit 1
    case "$scenario" in
        success)
            shasum -a 256 -c "$output.sha256" > checksum.log
            mkdir replay
            tar -xzf "$output" -C replay
            for file in source.txt scratch/release/.git/index scratch/release/.git/release-state/attempt.plan \
                scratch/executable:probe $'scratch/line\nfile'; do
                cmp "evidence tree/$file" "replay/$file"
            done
            [[ -x replay/scratch/executable:probe ]] || exit 1
            mkdir -p readback/'evidence tree'
            cp -R replay/. readback/'evidence tree/'
            (cd readback; shasum -a 256 -c 'evidence tree/artifact-sha256.txt') > inventory.log ;;
        occupied) [[ "$(cat "$output")" == 'earlier archive' ]] ;;
        checksum-occupied) [[ ! -e "$output" && "$(cat "$output.sha256")" == 'earlier checksum' ]] ;;
        output-link) [[ -L "$output" && ! -e missing ]] ;;
        inside|alias-inside|hash-failure|inventory-link) [[ ! -e "$output" ]] ;;
        tar-failure)
            [[ "$(cat "$output")" == 'partial archive' && ! -e "$output.sha256" ]]
            grep -Fx archive-write-failed result.log > /dev/null ;;
        final-hash-failure) tar -tzf "$output" > retained.list; [[ "$(cat "$output.sha256")" == 'partial hash' ]] ;;
    esac
); done
echo 'Native archive hashes, hidden recovery state, exact failures and retained inputs passed'
fixture_complete=true
