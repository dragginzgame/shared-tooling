#!/usr/bin/env bash
# Shared companions: make/tools.mk make/rust-format.mk make/execution.mk scripts/ci/check-format-tools.sh scripts/ci/run-formatting.sh scripts/ci/check-make-execution.sh
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/make-format.XXXXXX")"
# Bash 3.2 can enter EXIT with status zero after nounset; require completion too.
fixture_complete=false
finish() {
    local status=$?
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$fixture"
    else printf "Formatting Make fixture retained: %s\n" "$fixture" >&2; fi
    exit "$status"
}
trap finish EXIT
consumer="$fixture/consumer with spaces"
mkdir -p "$consumer/vendor/make" "$consumer/vendor/scripts/ci" "$consumer/ci" "$consumer/.tools/rust/bin"
cp "$root/make/tools.mk" "$root/make/rust-format.mk" "$root/make/execution.mk" "$consumer/vendor/make/"
cp "$root/scripts/ci/check-format-tools.sh" "$root/scripts/ci/run-formatting.sh" "$root/scripts/ci/check-make-execution.sh" "$consumer/vendor/scripts/ci/"
printf 'export SHARED_TOOLING_CARGO_SORT_VERSION=2.1.4\n' > "$consumer/ci/tool-versions.env"
cat > "$consumer/Makefile" <<'MAKE'
SHARED_TOOLING_ROOT ?= $(CURDIR)/vendor
FORMAT_CARGO := format-fixture-cargo
include vendor/make/tools.mk vendor/make/rust-format.mk
format-tools-check fmt fmt-check: override SHARED_TOOLING_ROOT := $(CURDIR)/vendor
.PHONY: help
help:
	@echo harmless
MAKE
cat > "$consumer/.tools/rust/bin/format-fixture-cargo" <<'CARGO'
#!/usr/bin/env bash
set -eu
if [[ "${JOBSERVER_TEST_REQUIRED:-0}" == 1 ]]; then
    [[ "${MAKEFLAGS:-}" =~ --jobserver-(auth|fds)=([0-9]+),([0-9]+) ]]
    reader="${BASH_REMATCH[2]}"; writer="${BASH_REMATCH[3]}"
    : <&"$reader"
    : >&"$writer"
fi
[[ "$CARGO_NET_OFFLINE" == true && "$RUSTUP_AUTO_INSTALL" == 0 ]]
case "$*" in
    'sort --version') echo "cargo-sort ${FORMAT_TEST_VERSION:-2.1.4}"; exit 0 ;;
    'fmt --version') exit 0 ;;
esac
printf '%s\n' "$*" >> "$FORMAT_TEST_EVENTS"
echo 'Finished: Cargo.toml is sorted already, no changes made'
echo 'fixture stderr details' >&2
[[ "$*" != "${FORMAT_TEST_FAIL:-}" ]]
CARGO
chmod +x "$consumer/.tools/rust/bin/format-fixture-cargo"
export FORMAT_TEST_EVENTS="$fixture/events"
export RUNNER_TEMP="$fixture"
[[ "$(make --no-print-directory -C "$consumer")" == harmless ]]
[[ ! -e "$FORMAT_TEST_EVENTS" ]]
for target in fmt fmt-check; do
    : > "$FORMAT_TEST_EVENTS"
    PATH=/usr/bin:/bin make --no-print-directory -C "$consumer" "$target" > "$fixture/$target.log" 2>&1
    if [[ "$target" == fmt ]]; then
        printf 'sort --workspace\nfmt --all\n' > "$fixture/expected"
        printf 'Formatting... ok\n' > "$fixture/expected-output"
    else
        printf 'sort --workspace --check\nfmt --all -- --check\n' > "$fixture/expected"
        printf 'Checking formatting... ok\n' > "$fixture/expected-output"
    fi
    cmp "$fixture/expected" "$FORMAT_TEST_EVENTS"
    cmp "$fixture/expected-output" "$fixture/$target.log"
done
# Ambient roots cannot select the parse-time helper, including for harmless help.
mkdir -p "$fixture/unselected/scripts/ci"
cat > "$fixture/unselected/scripts/ci/check-make-execution.sh" <<'SENTINEL'
#!/usr/bin/env bash
echo escaped >> "$FORMAT_TEST_EVENTS"
exit 23
SENTINEL
for target in help fmt fmt-check; do
    for source in environment command; do
        : > "$FORMAT_TEST_EVENTS"
        if [[ "$source" == environment ]]; then
            SHARED_TOOLING_ROOT="$fixture/unselected" make --no-print-directory -C "$consumer" "$target" > "$fixture/root-$source.log" 2>&1
        else
            make --no-print-directory -C "$consumer" "$target" "SHARED_TOOLING_ROOT=$fixture/unselected" > "$fixture/root-$source.log" 2>&1
        fi
        case "$target" in
            help) : > "$fixture/expected" ;;
            fmt) printf 'sort --workspace\nfmt --all\n' > "$fixture/expected" ;;
            fmt-check) printf 'sort --workspace --check\nfmt --all -- --check\n' > "$fixture/expected" ;;
        esac
        cmp "$fixture/expected" "$FORMAT_TEST_EVENTS"
    done
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
        grep -Fx 'Formatting... FAILED (exit 1)' "$fixture/$failure.log"
        logs=("$fixture"/formatting.*)
        [[ ${#logs[@]} == 1 ]]
        log="${logs[0]}"
        grep -Fx 'fixture stderr details' "$log"
        grep -Fx 'Finished: Cargo.toml is sorted already, no changes made' "$log"
        if grep -F 'Finished: Cargo.toml' "$fixture/$failure.log"; then exit 1; fi
    else
        [[ ! -s "$FORMAT_TEST_EVENTS" ]]
    fi
    [[ "$failure" != missing ]] || mv "$fixture/cargo" "$consumer/.tools/rust/bin/format-fixture-cargo"
    unset FORMAT_TEST_VERSION FORMAT_TEST_FAIL
done
# Outer Make must reject unsafe modes, even when a prerequisite fails and Make
# would otherwise ignore it. No formatter may run, directly or via inherited flags.
for target in fmt fmt-check; do
    for mode in -i --ignore-errors -n --dry-run --just-print --recon -t --touch -q --question -kin; do
        for source in direct inherited cleared replaced both-hidden; do
            : > "$FORMAT_TEST_EVENTS"
            status=0
            if [[ "$source" == direct ]]; then
                FORMAT_TEST_VERSION=0.0.0 make -C "$consumer" "$mode" "$target" > "$fixture/mode.log" 2>&1 || status=$?
            elif [[ "$source" == inherited ]]; then
                _shared_make_execution_checked=yes MAKEFLAGS="$mode" FORMAT_TEST_VERSION=0.0.0 make -C "$consumer" "$target" > "$fixture/mode.log" 2>&1 || status=$?
            else
                flags=(MAKEFLAGS=)
                [[ "$source" != replaced ]] || flags=(MAKEFLAGS=--no-print-directory)
                [[ "$source" != both-hidden ]] || flags+=(MFLAGS=)
                make -C "$consumer" "$mode" "$target" "${flags[@]}" > "$fixture/mode.log" 2>&1 || status=$?
            fi
            if [[ "$status" != 2 || -s "$FORMAT_TEST_EVENTS" ]]; then
                echo "Formatting admission failed: $target $mode $source (status $status)" >&2
                exit 1
            fi
        done
    done
done
# Normal parallel mode and quoted command variables still reach the formatter.
parallel=(-j2)
if make --help | grep -q -- --jobserver-style; then parallel+=(--jobserver-style=pipe); fi
for target in format-tools-check fmt fmt-check; do
    JOBSERVER_TEST_REQUIRED=1 make "${parallel[@]}" --no-print-directory -C "$consumer" "$target" \
        "AUDIT_SELECTION=owner's selection" > "$fixture/parallel-$target.log" 2>&1
done
# Custom workspace/frontend adapters share presentation without giving this
# wrapper their formatter policy. Arguments and nonzero statuses remain exact.
status=0
bash "$root/scripts/ci/run-formatting.sh" --check bash -c 'printf "%s\n" "$1"; echo formatter-error >&2; exit 23' -- 'selected path with spaces' \
    > "$fixture/custom-output" 2>&1 || status=$?
[[ "$status" == 23 && "$(wc -l < "$fixture/custom-output")" -eq 2 ]]
grep -Fx 'Checking formatting... FAILED (exit 23)' "$fixture/custom-output"
logs=("$fixture"/formatting.*)
[[ ${#logs[@]} == 2 ]]
grep -Fx 'selected path with spaces' "$fixture"/formatting.*
grep -Fx formatter-error "$fixture"/formatting.*
echo 'Shared formatting Make commands passed (substitute Cargo; no installation)'
fixture_complete=true
