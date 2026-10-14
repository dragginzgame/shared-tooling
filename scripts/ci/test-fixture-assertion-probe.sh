#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/ci/fixture-retention-probes.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
# shellcheck source=scripts/ci/fixture-retention-probes.sh
source "$root/scripts/ci/fixture-retention-probes.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/assertion-probe.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Assertion probe retained"' EXIT
cat > "$fixture/owner.sh" <<'OWNER'
#!/usr/bin/env bash
set -euo pipefail
root="${BASH_SOURCE[0]}"
root="${root%/.}"
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(mktemp -d "$TMPDIR/owner.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Owner retained"' EXIT
status=0
[[ "$status" == 0 ]] || exit 1
[[ "$1" == selected ]] || exit 42
fixture_complete=true
OWNER
fixture_probe_assertion "$fixture/owner.sh" "$fixture" "$root" owner selected || exit 1
# Missing layout markers must be refused before any child execution.
for marker in anchor trap assertion; do
    # Match literal shell expressions, not this process's variables.
    # shellcheck disable=SC2016
    case "$marker" in
        anchor) pattern='^root="\${root%/\.}"$' ;;
        trap) pattern='^trap ' ;;
        assertion) pattern='^\[\[ "\$status" == ' ;;
    esac
    awk -v pattern="$pattern" '$0 !~ pattern' "$fixture/owner.sh" > "$fixture/unsupported.sh"
    status=0
    fixture_probe_assertion "$fixture/unsupported.sh" "$fixture" "$root" "$marker" selected || status=$?
    [[ "$status" != 0 && ! -f "$fixture/$marker-assertion.path" ]] || exit 1
done
# An owner that ignores failed assertions must not be admitted conditionally.
sed 's/|| exit 1/|| :/' "$fixture/owner.sh" > "$fixture/ignores.sh"
status=0
fixture_probe_assertion "$fixture/ignores.sh" "$fixture" "$root" ignores selected || status=$?
[[ "$status" == 1 ]] || exit 1
echo 'Assertion probe admission and retention passed'
fixture_complete=true
