#!/usr/bin/env bash
# Shared companions: scripts/dev/toko-cloc scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(CDPATH='' cd -P -- "${root%/*}/../.." && pwd)"
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/cloc-launcher.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "LOC launcher fixture retained"' EXIT
mkdir -p "$fixture/bin" "$fixture/templates"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TEMPLATE_DIR="$fixture/templates"
cp "$root/scripts/dev/toko-cloc" "$fixture/bin/toko-cloc"
chmod +x "$fixture/bin/toko-cloc"
export PATH="$fixture/bin:$PATH"
export LAUNCHER_EVIDENCE="$fixture/observed"
for layout in producer vendor; do
    consumer="$fixture/$layout repo"
    mkdir -p "$consumer/subdirectory"
    git init -q "$consumer"
    tooling="$consumer"
    [[ "$layout" != vendor ]] || tooling="$consumer/vendor/toko-tooling"
    mkdir -p "$tooling/scripts/dev"
    cp "$root/scripts/dev/toko-cloc" "$tooling/scripts/dev/toko-cloc"
    cat > "$tooling/scripts/dev/cloc.sh" <<'REPORT'
#!/usr/bin/env bash
printf '%s\0' "$PWD" "$0" "$@" > "$LAUNCHER_EVIDENCE"
[[ "$PATH" == "$EXPECTED_ROOT/.tools/host/bin:$EXPECTED_ROOT/.tools/rust/common/bin:"* ]]
exit "${REPORT_STATUS:-0}"
REPORT
    export EXPECTED_ROOT="$consumer"
    (
        cd "$consumer/subdirectory"
        CDPATH="$fixture" toko-cloc -d 2 --manifest '../a b/Cargo.toml' 'crate::module'
        printf '%s\0' "$PWD" "$tooling/scripts/dev/cloc.sh" -d 2 --manifest '../a b/Cargo.toml' 'crate::module' > "$fixture/expected"
        cmp "$fixture/expected" "$LAUNCHER_EVIDENCE"
        status=0
        REPORT_STATUS=23 toko-cloc --json > "$fixture/failed.log" 2>&1 || status=$?
        [[ "$status" == 23 ]]
        rm "$tooling/scripts/dev/cloc.sh"
        if toko-cloc > "$fixture/missing.log" 2>&1; then exit 1; fi
        grep -F 'no installed LOC reporter' "$fixture/missing.log"
    )
done
if (cd "$fixture"; toko-cloc) > "$fixture/outside.log" 2>&1; then exit 1; fi
grep -F 'run inside a repository' "$fixture/outside.log"
fixture_complete=true
echo 'LOC launcher selection, arguments, cwd, PATH and failure propagation passed'
