#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd -P)"
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
bash "$root/scripts/ci/check-release-commands.sh" "$root" make/tools.mk
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
