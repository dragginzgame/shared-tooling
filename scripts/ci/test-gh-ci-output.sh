#!/usr/bin/env bash
# Shared companions: scripts/ci/test-gh-ci.sh scripts/ci/fixture-retention-probes.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(CDPATH='' cd -P -- "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-retention-probes.sh
source "$root/scripts/ci/fixture-retention-probes.sh"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/gh-ci-output.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "CI inspection output fixture retained"' EXIT

# Run the complete semantic matrix once, with no expected-error noise on success.
bash "$root/scripts/ci/test-gh-ci.sh" > "$fixture/stdout" 2> "$fixture/stderr"
printf 'CI inspection selection and failure tests passed\n' > "$fixture/expected"
cmp "$fixture/expected" "$fixture/stdout"
[[ ! -s "$fixture/stderr" ]]

# Exercise the actual initialization/finish boundary, not another finish helper.
# Fail before Git/GitHub substitutes run; all evidence belongs to this fixture.
for scenario in failure premature nounset; do
    # shellcheck disable=SC2016 # Expand only in the rendered child fixture.
    injection='printf "saved observation" > "$fixture/output"; printf "saved command trace" > "$fixture/calls"; '
    expected=1
    # shellcheck disable=SC2016 # All injected expressions expand in the child.
    case "$scenario" in
        failure) injection+='exit 37'; expected=37 ;;
        premature) injection+='exit 0' ;;
        nounset) injection+='unset UNSET_GH_CI_PROBE; printf "%s" "$UNSET_GH_CI_PROBE"' ;;
    esac
    fixture_probe_prefix "$root/scripts/ci/test-gh-ci.sh" "$fixture/probe.sh" ROOT fixture "$injection"
    status=0
    RETENTION_SOURCE_ROOT="$root" RETENTION_EXIT_PATH="$fixture/retained.path" \
        TMPDIR="$fixture" bash "$fixture/probe.sh" > "$fixture/probe.stdout" 2> "$fixture/probe.stderr" || status=$?
    [[ "$status" == "$expected" ]]
    grep -F 'saved observation' "$fixture/probe.stderr" > /dev/null
    grep -F 'saved command trace' "$fixture/probe.stderr" > /dev/null
    grep -F 'CI inspection fixtures retained:' "$fixture/probe.stderr" > /dev/null
    [[ -d "$(cat "$fixture/retained.path")" ]]
done
fixture_complete=true
echo 'CI inspection concise success and retained failure diagnostics passed'
