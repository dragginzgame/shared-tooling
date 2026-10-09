#!/usr/bin/env bash
set -euo pipefail
root="$0"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/release-command-tests.XXXXXX")"
finish() {
    local status=$?
    if [[ "$status" == 0 ]]; then rm -rf "$fixture";
    else echo "Release smoke fixtures retained: $fixture" >&2; fi
}
trap finish EXIT
mkdir "$fixture/consumer" "$fixture/logs"
export TMPDIR="$fixture/logs"
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
unset VALIDATION_REPOSITORY_ROOT VALIDATION_RUNNER_SNAPSHOT_PATH
make_inputs=(make/tools.mk make/release.mk make/execution.mk scripts/ci/check-make-execution.sh)
bash "$root/scripts/ci/check-release-commands.sh" "$root" "${make_inputs[@]}"
# The include preserves defaults and consumer admission/environment even in a
# nested snapshot. Only the runner is substituted; no release effects occur.
mkdir -p "$fixture/included/vendor/make" "$fixture/included/vendor/scripts/ci"
cp "$root/make/release.mk" "$root/make/execution.mk" "$fixture/included/vendor/make/"
cp "$root/scripts/ci/check-make-execution.sh" "$fixture/included/vendor/scripts/ci/"
cat > "$fixture/included/vendor/scripts/ci/run-release.sh" <<'RUNNER'
#!/usr/bin/env bash
set -eu
[[ "$CACHE_PREPARE" == selected && "$RELEASE_DELIVERY" == pr ]]
printf '%s\n' "$@" > "$RELEASE_TEST_EVENTS"
exit "${RELEASE_TEST_STATUS:-0}"
RUNNER
cat > "$fixture/included/Makefile" <<'MAKE'
SHARED_TOOLING_ROOT := $(CURDIR)/vendor
include vendor/make/release.mk
.PHONY: help admit
help:
	@echo harmless
release-patch release-minor release-major release-resume: export CACHE_PREPARE := selected
release-patch release-minor release-major release-resume: export RELEASE_DELIVERY := pr
release-patch release-minor release-major release-resume: admit
admit:
	@test "$(DENY_RELEASE)" != yes
MAKE
export RELEASE_TEST_EVENTS="$fixture/include-events"
[[ "$(make --no-print-directory -C "$fixture/included")" == harmless ]]
[[ ! -e "$RELEASE_TEST_EVENTS" ]]
make --no-print-directory -C "$fixture/included" release-patch
printf 'patch\norigin\nmain\n' > "$fixture/expected"
cmp "$fixture/expected" "$RELEASE_TEST_EVENTS"
rm "$RELEASE_TEST_EVENTS"
if make --no-print-directory -C "$fixture/included" release-patch DENY_RELEASE=yes > "$fixture/admission.log" 2>&1; then exit 1; fi
[[ ! -e "$RELEASE_TEST_EVENTS" ]]
if RELEASE_TEST_STATUS=23 make --no-print-directory -C "$fixture/included" release-resume VERSION=1.2.3 RELEASE_REMOTE=review RELEASE_BRANCH=topic > "$fixture/runner-failure.log" 2>&1; then exit 1; fi
printf 'resume\n1.2.3\nreview\ntopic\n' > "$fixture/expected"
cmp "$fixture/expected" "$RELEASE_TEST_EVENTS"
# All four entrypoints reject unsupported direct and inherited modes before
# runner dispatch, even when the substituted runner would return failure.
for target in release-patch release-minor release-major release-resume; do
    for mode in -i --ignore-errors -n -t -q; do
        for source in direct inherited; do
            : > "$RELEASE_TEST_EVENTS"
            status=0
            if [[ "$source" == direct ]]; then
                RELEASE_TEST_STATUS=23 make -C "$fixture/included" "$mode" "$target" > "$fixture/mode.log" 2>&1 || status=$?
            else
                _shared_make_execution_checked=yes MAKEFLAGS="$mode" RELEASE_TEST_STATUS=23 make -C "$fixture/included" "$target" > "$fixture/mode.log" 2>&1 || status=$?
            fi
            [[ "$status" == 2 && ! -s "$RELEASE_TEST_EVENTS" ]]
        done
    done
done
make -j2 --no-print-directory -C "$fixture/included" release-patch "AUDIT_SELECTION=owner's selection" > "$fixture/parallel.log" 2>&1
printf 'patch\norigin\nmain\n' > "$fixture/expected"
cmp "$fixture/expected" "$RELEASE_TEST_EVENTS"
# The root-snapshot checker must never follow a parent exported root or an
# ordinary consumer assignment to an external runner. The sentinel has no effects
# beyond its marker; the actual release implementation is never installed here.
mkdir -p "$fixture/external/scripts/ci" "$fixture/root-consumer/make"
cp "$root/make/tools.mk" "$root/make/release.mk" "$root/make/execution.mk" "$fixture/root-consumer/make/"
mkdir -p "$fixture/root-consumer/scripts/ci"
cp "$root/scripts/ci/check-make-execution.sh" "$fixture/root-consumer/scripts/ci/"
cat > "$fixture/external/scripts/ci/run-release.sh" <<'SENTINEL'
#!/usr/bin/env bash
echo escaped >> "$RELEASE_TEST_EVENTS"
exit 99
SENTINEL
cat > "$fixture/root-consumer/Makefile" <<'MAKE'
SHARED_TOOLING_ROOT := $(EXTERNAL_ROOT)
include make/tools.mk make/release.mk
MAKE
: > "$RELEASE_TEST_EVENTS"
EXTERNAL_ROOT="$fixture/external" SHARED_TOOLING_ROOT="$fixture/external" \
    bash "$root/scripts/ci/check-release-commands.sh" "$fixture/root-consumer" "${make_inputs[@]}"
[[ ! -s "$RELEASE_TEST_EVENTS" ]]
cat > "$fixture/root-parent.mk" <<'MAKE'
export SHARED_TOOLING_ROOT := $(EXTERNAL_ROOT)
export EXTERNAL_ROOT
test:
	+@bash "$(CHECKER)" "$(CONSUMER)" make/tools.mk make/release.mk make/execution.mk scripts/ci/check-make-execution.sh
MAKE
make -j2 --no-print-directory -f "$fixture/root-parent.mk" test \
    EXTERNAL_ROOT="$fixture/external" CHECKER="$root/scripts/ci/check-release-commands.sh" \
    CONSUMER="$fixture/root-consumer" > "$fixture/root-parent.log" 2>&1
[[ ! -s "$RELEASE_TEST_EVENTS" ]]
cat > "$fixture/consumer/Makefile" <<'MAKE'
include tool-versions.env
ifneq ($(word 2,$(filter release-patch release-minor release-major release-resume,$(MAKECMDGOALS))),)
$(error Select exactly one release target)
endif
release-patch release-minor release-major:
	@bash scripts/ci/run-release.sh "$(@:release-%=%)" "$(RELEASE_REMOTE)" "$(RELEASE_BRANCH)"
release-resume:
	@bash scripts/ci/run-release.sh resume "$(VERSION)" "$(RELEASE_REMOTE)" "$(RELEASE_BRANCH)"
MAKE
printf 'FIXTURE_VERSION := 1\n' > "$fixture/consumer/tool-versions.env"
# A recursive Make must not leak -n, selected command variables or logger identity.
cat > "$fixture/parent.mk" <<'MAKE'
.PHONY: test
export VALIDATION_REPOSITORY_ROOT := /wrong/checkout
export VALIDATION_RUNNER_SNAPSHOT_PATH := /wrong/snapshot
export MAKEFILES := /missing/parent-includes.mk
test:
	+@bash "$(CHECKER)" "$(CONSUMER)" tool-versions.env
MAKE
make --no-print-directory -n -f "$fixture/parent.mk" test \
    CHECKER="$root/scripts/ci/check-release-commands.sh" CONSUMER="$fixture/consumer" \
    RELEASE_REMOTE=wrong RELEASE_BRANCH=wrong VERSION=9.9.9 > "$fixture/nested.log" 2>&1
# Broken adapters must fail and retain their own full fixture/logs.
cp "$fixture/consumer/Makefile" "$fixture/good.mk"
for mode in ignore-failure wrong-version conflict; do
    # Match the literal Make variable, not a shell expansion.
    # shellcheck disable=SC2016
    case "$mode" in
        ignore-failure) sed 's/@bash/-@bash/' "$fixture/good.mk" > "$fixture/consumer/Makefile" ;;
        wrong-version) sed 's/$(VERSION)/9.9.9/' "$fixture/good.mk" > "$fixture/consumer/Makefile" ;;
        conflict) sed '/^ifneq/,/^endif/d' "$fixture/good.mk" > "$fixture/consumer/Makefile" ;;
    esac
    if bash "$root/scripts/ci/check-release-commands.sh" "$fixture/consumer" tool-versions.env \
        > "$fixture/$mode.log" 2>&1; then
        echo "accepted broken adapter: $mode" >&2; exit 1
    fi
    retained="$(sed -n 's/^Release command check failed; fixture and logs retained: //p' "$fixture/$mode.log")"
    [[ -d "$retained" && -f "$retained/patch-0.log" ]]
done
if bash "$root/scripts/ci/check-release-commands.sh" "$fixture/consumer" ../parent.mk > /dev/null 2>&1; then exit 1; fi
echo 'Release command adoption, nested Make and retained failure tests passed'
