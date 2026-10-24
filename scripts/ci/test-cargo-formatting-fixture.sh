#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/ci/prepare-cargo-formatting-fixture.pl
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(CDPATH='' cd -P -- "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/cargo-formatting-fixture.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Cargo formatting fixture retained"' EXIT
helper="$ROOT/scripts/ci/prepare-cargo-formatting-fixture.pl"
cat > "$fixture/original" <<'TOML'
[workspace.dependencies]
# Keep this comment in its original position.
alpha = "0.1" # Inline comment belongs to the declaration.
beta = { path = "crates/beta", features = ["serde"], version = "0.2" }

[dependencies]
alpha = "0.3"
beta = "0.4"
TOML
cat > "$fixture/expected" <<'TOML'
[workspace.dependencies]
# Keep this comment in its original position.
beta = { path = "crates/beta", features = ["serde"], version = "0.2" }
alpha = "0.1" # Inline comment belongs to the declaration.

[dependencies]
alpha = "0.3"
beta = "0.4"
TOML
for kind in lf crlf no-final-lf; do
    case "$kind" in
        lf) cp "$fixture/original" "$fixture/input"; cp "$fixture/expected" "$fixture/wanted" ;;
        crlf)
            perl -pe 's/\n/\r\n/g' "$fixture/original" > "$fixture/input"
            perl -pe 's/\n/\r\n/g' "$fixture/expected" > "$fixture/wanted" ;;
        no-final-lf)
            printf '[workspace.dependencies]\nalpha = "0.1"\nbeta = "0.2"' > "$fixture/input"
            printf '[workspace.dependencies]\nbeta = "0.2"\nalpha = "0.1"' > "$fixture/wanted" ;;
    esac
    cp "$fixture/input" "$fixture/before"
    perl "$helper" "$fixture/input" workspace.dependencies alpha beta > "$fixture/output"
    cmp "$fixture/output" "$fixture/wanted"
    cmp "$fixture/input" "$fixture/before"
done
refuse() {
    local status=0
    perl "$helper" "$@" > "$fixture/refused" 2> "$fixture/error" || status=$?
    [[ "$status" != 0 && ! -s "$fixture/refused" && -s "$fixture/error" ]] || exit 1
}
refuse "$fixture/original" workspace.dependencies alpha alpha
refuse "$fixture/original" workspace.dependencies beta alpha
refuse "$fixture/original" workspace.dependencies absent beta
refuse "$fixture/original" 'workspace[dependencies]' alpha beta
refuse "$fixture/original" workspace.dependencies alpha
ln -s "$fixture/original" "$fixture/link"
refuse "$fixture/link" workspace.dependencies alpha beta
for invalid in nonadjacent duplicate-key duplicate-table multiline-value multiline-string nul; do
    case "$invalid" in
        nonadjacent) printf '[workspace.dependencies]\nalpha = "0.1"\n# separator\nbeta = "0.2"\n' ;;
        duplicate-key) printf '[workspace.dependencies]\nalpha = "0.1"\nbeta = "0.2"\nalpha = "0.3"\n' ;;
        duplicate-table) cat "$fixture/original"; printf '\n[workspace.dependencies]\n' ;;
        multiline-value) printf '[workspace.dependencies]\nalpha = [\nbeta = "0.2"\n]\n' ;;
        multiline-string) printf '[workspace.dependencies]\nalpha = """text"""\nbeta = "0.2"\n' ;;
        nul) printf '[workspace.dependencies]\nalpha = "0.1"\nbeta = "0.2"\000\n' ;;
    esac > "$fixture/invalid"
    cp "$fixture/invalid" "$fixture/before"
    refuse "$fixture/invalid" workspace.dependencies alpha beta
    cmp "$fixture/invalid" "$fixture/before"
done
fixture_complete=true
echo 'Cargo formatting fixture swaps only the selected pair; refusals publish no bytes'
