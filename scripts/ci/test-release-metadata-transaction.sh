#!/usr/bin/env bash
# Shared companions: scripts/ci/release-metadata-transaction.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(CDPATH='' cd -P -- "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/release-metadata.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Release metadata fixtures retained"' EXIT
mkdir "$fixture/bin"
export RECEIPT_REAL_CP
RECEIPT_REAL_CP="$(command -v cp)"
cat > "$fixture/bin/cp" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$MODE" == restore && "$*" == *'/original/Cargo.toml ./Cargo.toml' ]]; then
    exit 37
fi
"$RECEIPT_REAL_CP" "$@"
case "$*" in
    *'/candidate/nested/selected file'*)
        case "$MODE" in
            copy) exit 29 ;;
            signal) kill -TERM "$PPID" ;;
        esac ;;
esac
STUB
chmod +x "$fixture/bin/cp"
cat > "$fixture/driver" <<'DRIVER'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$HELPER"
render() {
    printf 'new manifest\n' > "$2/Cargo.toml" || return
    printf 'new notes\n' > "$2/nested/selected file" || return
    case "$MODE" in
        render) return 23 ;;
        omitted) rm "$2/nested/selected file" || return ;;
        candidate-link)
            rm "$2/nested/selected file" || return
            ln -s "$PWD/Cargo.toml" "$2/nested/selected file" || return ;;
    esac
}
check() {
    printf 'checked\n' > checked || return
    case "$MODE" in
        check|restore) return 31 ;;
        mutate) printf 'changed after validation\n' > Cargo.toml || return ;;
    esac
}
release_metadata_prepare "$PWD/evidence.XXXXXX" render check Cargo.toml 'nested/selected file'
DRIVER
for mode in success render omitted candidate-link copy signal check restore mutate source-link parent-link; do
    selected="$fixture/$mode"
    mkdir -p "$selected/nested"
    printf 'old manifest\n' > "$selected/Cargo.toml"
    printf 'old notes\n' > "$selected/nested/selected file"
    chmod 640 "$selected/Cargo.toml" "$selected/nested/selected file"
    cp -p "$selected/Cargo.toml" "$selected/original-manifest"
    cp -p "$selected/nested/selected file" "$selected/original-notes"
    case "$mode" in
        source-link)
            rm "$selected/Cargo.toml"
            ln -s original-manifest "$selected/Cargo.toml" ;;
        parent-link)
            mv "$selected/nested" "$selected/retained"
            ln -s retained "$selected/nested" ;;
    esac
    status=0
    (cd "$selected" && MODE="$mode" HELPER="$root/scripts/ci/release-metadata-transaction.sh" \
        PATH="$fixture/bin:$PATH" bash "$fixture/driver") > "$selected/result.log" 2>&1 || status=$?
    if [[ "$mode" == success ]]; then
        [[ "$status" == 0 && -f "$selected/checked" ]] || exit 1
        [[ "$(cat "$selected/Cargo.toml")" == 'new manifest' ]] || exit 1
        [[ "$(cat "$selected/nested/selected file")" == 'new notes' ]] || exit 1
        [[ "$(find "$selected" -name 'evidence.*' -print)" == '' ]] || exit 1
    else
        [[ "$status" != 0 ]] || exit 1
        case "$mode" in
            render) [[ "$status" == 23 ]] || exit 1 ;;
            copy) [[ "$status" == 29 ]] || exit 1 ;;
            signal) [[ "$status" == 143 ]] || exit 1 ;;
            check) [[ "$status" == 31 ]] || exit 1 ;;
        esac
        if [[ "$mode" == restore ]]; then
            [[ "$status" == 1 && "$(cat "$selected/Cargo.toml")" == 'new manifest' ]] || exit 1
            grep -F 'Metadata restoration failed: Cargo.toml' "$selected/result.log" > /dev/null
            retained=("$selected"/evidence.*/original/Cargo.toml)
            [[ "${#retained[@]}" == 1 ]] || exit 1
            cmp "$selected/original-manifest" "${retained[0]}"
        else
            cmp "$selected/original-manifest" "$selected/Cargo.toml"
        fi
        cmp "$selected/original-notes" "$selected/nested/selected file"
        case "$mode" in
            source-link|parent-link)
                [[ "$(find "$selected" -name 'evidence.*' -print)" == '' ]] || exit 1 ;;
            *) grep -F 'originals retained:' "$selected/result.log" > /dev/null ;;
        esac
    fi
    perl -e 'for (@ARGV) { ((stat $_)[2] & 0777) == 0640 or die "mode changed: $_\n" }' \
        "$selected/Cargo.toml" "$selected/nested/selected file"
done
fixture_complete=true
printf 'Release metadata transaction fixtures passed\n'
