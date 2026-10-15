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
fixture="$(fixture_create "${TMPDIR:-/tmp}/assertion-probe.XXXXXX")"
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
    # Keep regex literals in the program: awk -v interprets backslashes again.
    awk -v marker="$marker" '
        marker == "anchor" && /^root="\$\{root%\/\.\}"$/ { next }
        marker == "trap" && /^trap / { next }
        marker == "assertion" && /^\[\[ "\$status" == / { next }
        { print }
    ' "$fixture/owner.sh" > "$fixture/unsupported.sh"
    status=0
    fixture_probe_assertion "$fixture/unsupported.sh" "$fixture" "$root" "$marker" selected || status=$?
    [[ "$status" != 0 && ! -f "$fixture/$marker-assertion.path" ]] || exit 1
done
# An owner that ignores failed assertions must not be admitted conditionally.
sed 's/|| exit 1/|| :/' "$fixture/owner.sh" > "$fixture/ignores.sh"
status=0
fixture_probe_assertion "$fixture/ignores.sh" "$fixture" "$root" ignores selected || status=$?
[[ "$status" == 1 ]] || exit 1
# A caller can select a literal assertion outside the owner fixture body.
# Quoting and backslashes stay literal through awk on GNU and BSD hosts.
cat > "$fixture/assertions" <<'ASSERTIONS'
    [[ "$selected" == 'right\value' ]] || exit 1
ASSERTIONS
# shellcheck disable=SC2016 # Bindings and the prefix execute/match in the child.
fixture_probe_assertion "$fixture/owner.sh" "$fixture" "$root" selected \
    --selected "$fixture/assertions" '[[ "$selected" ==' 'selected=wrong' || exit 1
for failure in missing duplicate ignored setup early; do
    cp "$fixture/assertions" "$fixture/selected-$failure"
    bindings=selected=wrong
    case "$failure" in
        missing) : > "$fixture/selected-$failure" ;;
        duplicate) cat "$fixture/assertions" >> "$fixture/selected-$failure" ;;
        ignored) sed 's/|| exit 1/|| :/' "$fixture/assertions" > "$fixture/selected-$failure" ;;
        setup) bindings='exit 1' ;;
        early) bindings='exit 0' ;;
    esac
    status=0
    # shellcheck disable=SC2016 # Literal assertion selected by the owner.
    fixture_probe_assertion "$fixture/owner.sh" "$fixture" "$root" "selected-$failure" \
        --selected "$fixture/selected-$failure" '[[ "$selected" ==' "$bindings" || status=$?
    [[ "$status" != 0 ]] || exit 1
    if [[ "$failure" == missing || "$failure" == duplicate ]]; then
        [[ ! -f "$fixture/selected-$failure-assertion.path" ]] || exit 1
    fi
done
# Reject missing initialization anchors in selected mode before execution too.
# shellcheck disable=SC2016 # Match the literal root anchor, not this process.
sed '/^root="${root%\/.}"$/d' "$fixture/owner.sh" > "$fixture/unsupported.sh"
status=0
# shellcheck disable=SC2016
fixture_probe_assertion "$fixture/unsupported.sh" "$fixture" "$root" selected-anchor \
    --selected "$fixture/assertions" '[[ "$selected" ==' 'selected=wrong' || status=$?
[[ "$status" != 0 && ! -f "$fixture/selected-anchor-assertion.path" ]] || exit 1
echo 'Assertion probe admission and retention passed'
fixture_complete=true
