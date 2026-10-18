#!/usr/bin/env bash
# Shared companions: scripts/ci/check-release-commands.sh scripts/ci/check-formatting-hooks.sh scripts/ci/prepare-script-fixture.sh scripts/ci/fixture-retention-probes.sh make/tools.mk make/release.mk make/rust-format.mk .githooks/pre-commit scripts/dev/install-git-hooks.sh ci/tool-versions.env
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/checker-retention.XXXXXX")"
fixture_complete=false
finish() {
    local status=$?
    fixture_finish "$status" "$fixture" 'Checker retention fixture retained'
}
trap finish EXIT
# shellcheck source=scripts/ci/fixture-retention-probes.sh
source "$root/scripts/ci/fixture-retention-probes.sh"
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
export PATH="$root/.tools/host/bin:$root/.tools/rust/common/bin:$PATH"
CHECKER_RETENTION_REAL_CMP="$(command -v cmp)"
export CHECKER_RETENTION_REAL_CMP
consumer="$fixture/consumer with spaces"
mkdir -p "$consumer/src"
inputs=(make/tools.mk make/release.mk make/rust-format.mk make/execution.mk \
    scripts/ci/check-make-execution.sh scripts/ci/check-format-tools.sh \
    scripts/ci/run-formatting.sh scripts/ci/fixture-lifecycle.sh \
    scripts/ci/fixture-retention-probes.sh scripts/dev/install-git-hooks.sh \
    .githooks/pre-commit ci/tool-versions.env)
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$consumer" "${inputs[@]}"
cat > "$consumer/Makefile" <<'MAKE'
.DEFAULT_GOAL := help
override SHARED_TOOLING_ROOT := $(CURDIR)
include make/tools.mk make/release.mk make/rust-format.mk
.PHONY: help
help:
	@echo fixture
MAKE
cat > "$consumer/Cargo.toml" <<'TOML'
[package]
name = "retention-fixture"
version = "0.1.0"
edition = "2024"
TOML
printf 'pub fn record() {}\n' > "$consumer/src/lib.rs"
printf '# Retention fixture\n' > "$consumer/README.md"
(cd "$consumer"; cargo generate-lockfile --offline)
git init --quiet "$consumer"
git -C "$consumer" add -- .
git -C "$consumer" -c user.name=Fixture -c user.email=fixture@example.invalid \
    -c core.hooksPath=/dev/null commit --quiet -m 'Fixture inputs'
for kind in release formatting; do
    for scenario in child assertion; do
        run="$fixture/$kind-$scenario"
        mkdir -p "$run/bin" "$run/tmp"
        executable='make'
        [[ "$scenario" != assertion ]] || executable='cmp'
        printf '#!%s\n' "$BASH" > "$run/bin/$executable"
        if [[ "$scenario" == assertion ]]; then
            cat >> "$run/bin/$executable" <<'CMP'
case "$1" in
    expected|*/sorted-manifest) ;;
    *) exec "$CHECKER_RETENTION_REAL_CMP" "$@" ;;
esac
CMP
        fi
        printf "echo CHECKER_RETENTION_FAILURE >&2\nexit 43\n" >> "$run/bin/$executable"
        chmod +x "$run/bin/$executable"
        status=0
        if [[ "$kind" == release ]]; then
            PATH="$run/bin:$PATH" TMPDIR="$run/tmp" \
                bash "$root/scripts/ci/check-release-commands.sh" "$consumer" "${inputs[@]}" \
                > "$run/result.log" 2>&1 || status=$?
            expected=43
            [[ "$scenario" != child ]] || expected=1
            [[ "$status" == "$expected" ]] || exit 1
            retained="$(sed -n 's/^Release command check failed; fixture and logs retained: //p' "$run/result.log")"
            [[ "$retained" == "$run/tmp/"* && -f "$retained/Makefile" && \
               -f "$retained/events" && -f "$retained/patch-0.log" ]] || exit 1
            if [[ "$scenario" == assertion ]]; then [[ -f "$retained/expected" ]] || exit 1; fi
            grep -Fq CHECKER_RETENTION_FAILURE "$run/result.log" "$retained/patch-0.log"
        else
            PATH="$run/bin:$PATH" TMPDIR="$run/tmp" \
                bash "$root/scripts/ci/check-formatting-hooks.sh" "$consumer" src/lib.rs Cargo.toml \
                --no-dependency-tables "${inputs[@]}" Cargo.lock > "$run/result.log" 2>&1 || status=$?
            [[ "$status" == 43 ]] || exit 1
            retained="$(sed -n 's/^Formatting adoption evidence retained: //p' "$run/result.log")"
            [[ "$retained" == "$run/tmp/"* && -d "$retained/base/.git" && \
               -f "$retained/base/Cargo.toml" && -f "$retained/baseline.log" ]] || exit 1
            if [[ "$scenario" == assertion ]]; then
                [[ -f "$retained/sorted-manifest" && -f "$retained/refresh/src/lib.rs" && \
                   -f "$retained/refresh/.git/formatting.log" ]] || exit 1
                git -C "$retained/refresh" diff --cached --exit-code HEAD -- src/lib.rs > "$run/index.log" && exit 1
            fi
            grep -Fq CHECKER_RETENTION_FAILURE "$run/result.log" "$retained/baseline.log"
        fi
    done
done
# Qualify the formatting checker's own initialization and completion boundary.
for scenario in nounset premature completed; do
    run="$fixture/prefix-$scenario"
    mkdir -p "$run"
    FIXTURE_PROBE_ROOT_VARIABLE=root FIXTURE_PROBE_DIRECTORY_VARIABLE=fixture \
        fixture_probe_exit "$root/scripts/ci/check-formatting-hooks.sh" "$run" "$consumer" \
        formatting "$scenario" "$consumer" src/lib.rs Cargo.toml --no-dependency-tables
done
echo 'Shared checker child/assertion retention and formatting completion passed'
fixture_complete=true
