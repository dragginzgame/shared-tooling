#!/usr/bin/env bash
# Shared companions: make/tools.mk make/rust-format.mk scripts/ci/check-format-tools.sh
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/make-format.XXXXXX")"
trap 'if [[ $? == 0 ]]; then rm -rf "$fixture"; else printf "Formatting Make fixture retained: %s\n" "$fixture" >&2; fi' EXIT
consumer="$fixture/consumer with spaces"
mkdir -p "$consumer/vendor/make" "$consumer/vendor/scripts/ci" "$consumer/ci" "$consumer/.tools/rust/bin"
cp "$root/make/tools.mk" "$root/make/rust-format.mk" "$consumer/vendor/make/"
cp "$root/scripts/ci/check-format-tools.sh" "$consumer/vendor/scripts/ci/"
printf 'export SHARED_TOOLING_CARGO_SORT_VERSION=2.1.4\n' > "$consumer/ci/tool-versions.env"
cat > "$consumer/Makefile" <<'MAKE'
SHARED_TOOLING_ROOT := $(CURDIR)/vendor
FORMAT_CARGO := format-fixture-cargo
include vendor/make/tools.mk vendor/make/rust-format.mk
.PHONY: help
help:
	@echo harmless
MAKE
cat > "$consumer/.tools/rust/bin/format-fixture-cargo" <<'CARGO'
#!/usr/bin/env bash
set -eu
[[ "$CARGO_NET_OFFLINE" == true && "$RUSTUP_AUTO_INSTALL" == 0 ]]
case "$*" in
    'sort --version') echo "cargo-sort ${FORMAT_TEST_VERSION:-2.1.4}"; exit 0 ;;
    'fmt --version') exit 0 ;;
esac
printf '%s\n' "$*" >> "$FORMAT_TEST_EVENTS"
[[ "$*" != "${FORMAT_TEST_FAIL:-}" ]]
CARGO
chmod +x "$consumer/.tools/rust/bin/format-fixture-cargo"
export FORMAT_TEST_EVENTS="$fixture/events"
[[ "$(make --no-print-directory -C "$consumer")" == harmless ]]
[[ ! -e "$FORMAT_TEST_EVENTS" ]]
for target in fmt fmt-check; do
    : > "$FORMAT_TEST_EVENTS"
    PATH=/usr/bin:/bin make --no-print-directory -C "$consumer" "$target" > "$fixture/$target.log" 2>&1
    if [[ "$target" == fmt ]]; then
        printf 'sort --workspace\nfmt --all\n' > "$fixture/expected"
    else
        printf 'sort --workspace --check\nfmt --all -- --check\n' > "$fixture/expected"
    fi
    cmp "$fixture/expected" "$FORMAT_TEST_EVENTS"
done
# A failed prerequisite or sorter must not run the later formatting operation.
for failure in wrong missing sort; do
    : > "$FORMAT_TEST_EVENTS"
    case "$failure" in
        wrong) export FORMAT_TEST_VERSION=0.0.0 ;;
        missing) mv "$consumer/.tools/rust/bin/format-fixture-cargo" "$fixture/cargo" ;;
        sort) export FORMAT_TEST_FAIL='sort --workspace' ;;
    esac
    if PATH=/usr/bin:/bin make --no-print-directory -C "$consumer" fmt > "$fixture/$failure.log" 2>&1; then exit 1; fi
    if [[ "$failure" == sort ]]; then
        printf 'sort --workspace\n' > "$fixture/expected"
        cmp "$fixture/expected" "$FORMAT_TEST_EVENTS"
    else
        [[ ! -s "$FORMAT_TEST_EVENTS" ]]
    fi
    [[ "$failure" != missing ]] || mv "$fixture/cargo" "$consumer/.tools/rust/bin/format-fixture-cargo"
    unset FORMAT_TEST_VERSION FORMAT_TEST_FAIL
done
echo 'Shared formatting Make commands passed (substitute Cargo; no installation)'
