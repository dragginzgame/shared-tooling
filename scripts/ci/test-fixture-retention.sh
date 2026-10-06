#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/fixture-retention-test.XXXXXX")"
trap 'if [[ $? == 0 ]]; then rm -rf "$fixture"; else echo "Retention fixtures retained: $fixture" >&2; fi' EXIT
mkdir "$fixture/bin" "$fixture/cloc" "$fixture/portable"
export RETENTION_REAL_BASH="$BASH"
cat > "$fixture/bin/cloc" <<'SCRIPT'
#!/usr/bin/env bash
exit 23
SCRIPT
# Write the absolute interpreter directly: BSD sed replacement can join lines.
printf '#!%s\n' "$BASH" > "$fixture/bin/bash"
cat >> "$fixture/bin/bash" <<'SCRIPT'
case "${1:-}" in */verify-file-checksum.sh) exit 24 ;; esac
exec "$RETENTION_REAL_BASH" "$@"
SCRIPT
chmod +x "$fixture/bin/"*
status=0
TMPDIR="$fixture/cloc" PATH="$fixture/bin:$PATH" CARGO_NET_OFFLINE=true RUSTUP_AUTO_INSTALL=0 \
    "$BASH" "$ROOT/scripts/ci/test-cloc.sh" > "$fixture/cloc.log" 2>&1 || status=$?
[[ "$status" == 23 ]] || exit 1
set -- "$fixture/cloc"/shared-tooling-cloc-test.*
[[ $# == 1 && -f "$1/Cargo.toml" && -f "$1/crates/alpha/src/lib.rs" ]] || exit 1

status=0
TMPDIR="$fixture/portable" PATH="$fixture/bin:$PATH" \
    "$BASH" "$ROOT/scripts/ci/test-portable-tools.sh" > "$fixture/portable.log" 2>&1 || status=$?
[[ "$status" == 24 ]] || exit 1
set -- "$fixture/portable"/shared-tooling-test.*
[[ $# == 1 && -f "$1/input.txt" ]] || exit 1
echo 'Failed fixture status and input retention checks passed'
