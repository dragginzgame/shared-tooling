#!/usr/bin/env bash
# Shared companions: scripts/ci/check-release-delivery.sh scripts/ci/prepare-script-fixture.sh make/release.mk scripts/ci/fixture-lifecycle.sh
set -euo pipefail
# Qualify common admission independently of any release runner or Git effects.
root="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/release-delivery.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Release delivery fixture retained"' EXIT
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES RELEASE_DELIVERY RELEASE_DELIVERY_POLICY
helper="$root/scripts/ci/check-release-delivery.sh"
for allowed in direct pr both; do
    case "$allowed" in
        both) printf 'direct\npr\n' > "$fixture/policy" ;;
        *) printf '%s\n' "$allowed" > "$fixture/policy" ;;
    esac
    for selected in direct pr invalid ''; do
        status=0
        bash "$helper" "$fixture/policy" "$selected" > "$fixture/helper.log" 2>&1 || status=$?
        if [[ "$selected" == "$allowed" || ( "$allowed" == both && ( "$selected" == direct || "$selected" == pr ) ) ]]; then
            [[ "$status" == 0 ]] || exit 1
        else [[ "$status" == 2 ]] || exit 1; fi
    done
done
for invalid in '' 'direct direct' $'direct\ndirect' $'direct\ninvalid' $'direct\r' $'direct\n\npr'; do
    printf '%s\n' "$invalid" > "$fixture/policy"
    if bash "$helper" "$fixture/policy" direct > "$fixture/helper.log" 2>&1; then exit 1; fi
done
ln -s policy "$fixture/link"
for path in "$fixture/link" "$fixture/missing" "$fixture"; do
    if bash "$helper" "$path" direct > "$fixture/helper.log" 2>&1; then exit 1; fi
done
for selected in direct pr; do bash "$helper" '' "$selected"; done
printf 'direct' > "$fixture/policy"
bash "$helper" "$fixture/policy" direct
# Exercise the real include and canonical hook roster; effects are only sentinels.
mkdir "$fixture/consumer"
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$fixture/consumer" make/release.mk
cat > "$fixture/consumer/Makefile" <<'MAKE'
.DEFAULT_GOAL := help
SHARED_TOOLING_ROOT := $(CURDIR)
RELEASE_DELIVERY_POLICY := $(CURDIR)/policy
include make/release.mk
help:
	@:
$(filter-out release-patch release-minor release-major release-resume,$(SHARED_RELEASE_TARGETS)):
	@echo dispatched >> events
MAKE
cat > "$fixture/consumer/scripts/ci/run-release.sh" <<'RUNNER'
#!/usr/bin/env bash
printf 'dispatched\n' >> events
RUNNER
printf 'direct\n' > "$fixture/consumer/policy"
targets=(release-patch release-minor release-major release-resume release-version release-preflight release-verify release-prepare-version release-prepared-check release-files release-commit-check release-committed-check release-tagged-check release-push-check release-merged-preflight)
for target in "${targets[@]}"; do
    for selected in pr invalid ''; do
        for source in environment command; do
            : > "$fixture/consumer/events"
            status=0
            if [[ "$source" == environment ]]; then
                RELEASE_DELIVERY="$selected" make --no-print-directory -C "$fixture/consumer" "$target" > "$fixture/make.log" 2>&1 || status=$?
            else
                make --no-print-directory -C "$fixture/consumer" "$target" "RELEASE_DELIVERY=$selected" > "$fixture/make.log" 2>&1 || status=$?
            fi
            [[ "$status" != 0 && ! -s "$fixture/consumer/events" ]] || exit 1
        done
    done
    make --no-print-directory -C "$fixture/consumer" "$target" > "$fixture/make.log" 2>&1
done
printf 'invalid\n' > "$fixture/consumer/policy"
RELEASE_DELIVERY="pr" make --no-print-directory -C "$fixture/consumer" help > "$fixture/make.log" 2>&1
printf 'pr\n' > "$fixture/consumer/policy"
RELEASE_DELIVERY="pr" make --no-print-directory -C "$fixture/consumer" release-preflight > "$fixture/make.log" 2>&1
# Admission follows the selected include even when runtime routing selects a
# different root. A missing companion cannot borrow that root's permissive helper.
mkdir -p "$fixture/unselected/scripts/ci"
printf '#!/bin/sh\necho escaped >> events\n' > "$fixture/unselected/scripts/ci/check-release-delivery.sh"
printf 'direct\n' > "$fixture/consumer/policy"
for source in environment command; do
    : > "$fixture/consumer/events"
    status=0
    if [[ "$source" == environment ]]; then
        RELEASE_DELIVERY=pr SHARED_TOOLING_ROOT="$fixture/unselected" make --no-print-directory -C "$fixture/consumer" release-preflight > "$fixture/make.log" 2>&1 || status=$?
    else
        make --no-print-directory -C "$fixture/consumer" release-preflight "SHARED_TOOLING_ROOT=$fixture/unselected" RELEASE_DELIVERY=pr > "$fixture/make.log" 2>&1 || status=$?
    fi
    [[ "$status" != 0 && ! -s "$fixture/consumer/events" ]] || exit 1
done
rm "$fixture/consumer/scripts/ci/check-release-delivery.sh"
: > "$fixture/consumer/events"
if make --no-print-directory -C "$fixture/consumer" release-preflight "SHARED_TOOLING_ROOT=$fixture/unselected" > "$fixture/make.log" 2>&1; then exit 1; fi
[[ ! -s "$fixture/consumer/events" ]] || exit 1
fixture_complete=true
echo 'Release delivery data, standalone admission and actual Make hook refusal passed'
