#!/usr/bin/env bash
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/native-diagnostics.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Native diagnostics fixture retained"' EXIT
real_tar="$(command -v tar)"
export NATIVE_DIAGNOSTICS_REAL_TAR="$real_tar"

# Exercise the real collector, selector and archiver without installers or a
# consumer workflow. Consumers retain ordering, outcomes, uploads and Git custody.
for scenario in host-store ic-store rust-store rust-store-invalid rust-archive-write rust-archive-conflict; do (
    mkdir -p "$fixture/$scenario"
    cd "$fixture/$scenario"
    mkdir -p checkout/.tools/rust evidence format-logs bin
    printf 'explicit source record\n' > evidence/source.txt
    printf 'original tool failure\n' > evidence/tools.log
    printf 'unselected private payload\n' > evidence/private.txt
    printf 'local failed compilation\n' > checkout/.tools/rust/local-failure
    export SHARED_TOOLING_STORE="$PWD/shared-store"
    kind=rust
    case "$scenario" in host-store) kind=host ;; ic-store) kind=ic ;; esac
    physical_store="$SHARED_TOOLING_STORE"
    if [[ "$scenario" == rust-store-invalid ]]; then
        physical_store="$SHARED_TOOLING_STORE.physical"
        mkdir "$physical_store"
        ln -s "$physical_store" "$SHARED_TOOLING_STORE"
    fi
    slot="$kind-$(printf '%064d' 0)"
    mkdir -p "$physical_store/$slot/set.fixture" "$physical_store/$slot/set.unrelated"
    chmod 700 "$physical_store" "$physical_store/$slot" "$physical_store/$slot/set.fixture"
    printf 'retained failed candidate\n' > "$physical_store/$slot/set.fixture/payload"
    printf 'unrelated bundle\n' > "$physical_store/$slot/set.unrelated/private"
    reference=".tools/$kind-set.fixture"
    [[ "$kind" != rust ]] || reference=.tools/rust/rust-set.fixture
    ln -s "$physical_store/$slot/set.fixture" "checkout/$reference"
    expected=0
    case "$scenario" in
        rust-store-invalid) expected=1 ;;
        rust-archive-write)
            expected=2
            printf '#!%s\n' "$BASH" > bin/tar
            cat >> bin/tar <<'TAR'
case "$*" in *./.tools/*) printf 'partial candidate archive'; exit 23 ;; esac
exec "$NATIVE_DIAGNOSTICS_REAL_TAR" "$@"
TAR
            chmod +x bin/tar ;;
        rust-archive-conflict)
            expected=2
            printf 'occupied candidate archive' > evidence/tool-candidates.tar.gz ;;
    esac
    status=0
    PATH="$PWD/bin:$PATH" bash "$root/scripts/ci/collect-native-diagnostics.sh" \
        "$PWD/checkout" "$PWD/evidence" diagnostics.tar.gz "$PWD/format-logs" \
        failure unused-host-pins unused-ic-pins source.txt tools.log > result.log 2>&1 || status=$?
    [[ "$status" == "$expected" ]] || exit 1
    # Readable, explicitly selected diagnostics precede even fatal tool failures.
    shasum -a 256 -c diagnostics.tar.gz.sha256 > checksum.log
    mkdir diagnostics
    tar -xzf diagnostics.tar.gz -C diagnostics
    cmp evidence/source.txt diagnostics/source.txt
    cmp evidence/tools.log diagnostics/tools.log
    [[ "$(find diagnostics -type f | wc -l)" -eq 2 && ! -e diagnostics/private.txt ]] || exit 1
    [[ "$(cat checkout/.tools/rust/local-failure)" == 'local failed compilation' ]] || exit 1
    [[ "$(cat "$physical_store/$slot/set.fixture/payload")" == 'retained failed candidate' ]] || exit 1
    if [[ "$expected" == 2 ]]; then
        expected_output='partial candidate archive'
        [[ "$scenario" != rust-archive-conflict ]] || expected_output='occupied candidate archive'
        [[ "$(cat evidence/tool-candidates.tar.gz)" == "$expected_output" ]] || exit 1
        details=(evidence/tool-evidence.*/archive-status)
        [[ ${#details[@]} == 1 && "$(cat "${details[0]}")" == 1 ]] || exit 1
        exit 0
    fi
    mkdir candidates
    tar -xzf evidence/tool-candidates.tar.gz -C candidates
    cmp checkout/.tools/rust/local-failure candidates/.tools/rust/local-failure
    [[ -L "candidates/$reference" && "$(readlink "candidates/$reference")" == "$(readlink "checkout/$reference")" ]] || exit 1
    [[ ! -e "candidates/$slot/set.unrelated" ]] || exit 1
    if [[ "$expected" == 1 ]]; then
        grep -F 'Tool evidence collection incomplete' result.log > /dev/null
        [[ ! -e "candidates/$slot" ]] || exit 1
        details=(candidates/tool-evidence.*/selection-status)
        [[ ${#details[@]} == 1 && "$(cat "${details[0]}")" != 0 ]] || exit 1
    else
        cmp "$physical_store/$slot/set.fixture/payload" "candidates/$slot/set.fixture/payload"
    fi
); done
echo 'Native diagnostics preserve selected logs, referenced bundles and exact collection failures'
fixture_complete=true
