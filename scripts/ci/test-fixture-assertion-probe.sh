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
printf 'unexpected body execution\n' > "$TMPDIR/owner-body"
fixture_complete=true
OWNER
# shellcheck disable=SC2016 # Select the actual owner assertion and contradict it.
fixture_probe_assertion "$fixture/owner.sh" "$fixture" "$root" owner \
    --selected "$fixture/owner.sh" '[[ "$status" ==' 'status=97' || exit 1
[[ ! -e "$fixture/owner-body" ]] || exit 1
# Missing layout markers must be refused before any child execution.
for marker in anchor trap multiline assertion; do
    # Keep regex literals in the program: awk -v interprets backslashes again.
    awk -v marker="$marker" '
        marker == "anchor" && /^root="\$\{root%\/\.\}"$/ { next }
        marker == "trap" && /^trap / { next }
        marker == "multiline" && /^trap / { sub(/fixture_finish/, "\nfixture_finish") }
        marker == "assertion" && /^\[\[ "\$status" == / { next }
        { print }
    ' "$fixture/owner.sh" > "$fixture/unsupported.sh"
    printf 'stale generated probe\n' > "$fixture/assertion-source/$marker.sh"
    status=0
    # shellcheck disable=SC2016 # Literal owner assertion selected by the caller.
    fixture_probe_assertion "$fixture/unsupported.sh" "$fixture" "$root" "$marker" \
        --selected "$fixture/unsupported.sh" '[[ "$status" ==' 'status=97' \
        2> "$fixture/$marker-diagnostic" || status=$?
    [[ "$status" != 0 && ! -f "$fixture/$marker-assertion.path" ]] || exit 1
    [[ ! -s "$fixture/assertion-source/$marker.sh" ]] || exit 1
    grep -F "$fixture/unsupported.sh" "$fixture/$marker-diagnostic" > /dev/null
    if [[ "$marker" == assertion ]]; then
        grep -F 'exactly one line' "$fixture/$marker-diagnostic" > /dev/null
    else
        grep -F 'single-line trap ACTION EXIT' "$fixture/$marker-diagnostic" > /dev/null
    fi
done
# Matching a non-assertion is a caller error, with a diagnostic and no child.
printf 'status=97\n' > "$fixture/not-assertion"
status=0
fixture_probe_assertion "$fixture/owner.sh" "$fixture" "$root" not-assertion \
    --selected "$fixture/not-assertion" 'status=' 'status=97' \
    2> "$fixture/not-assertion-diagnostic" || status=$?
[[ "$status" == 2 && ! -e "$fixture/not-assertion-assertion.path" ]] || exit 1
grep -F 'must contain a [[ assertion' "$fixture/not-assertion-diagnostic" > /dev/null
# An owner that ignores failed assertions must not be admitted conditionally.
sed 's/|| exit 1/|| :/' "$fixture/owner.sh" > "$fixture/ignores.sh"
status=0
# shellcheck disable=SC2016 # An ignored selected assertion must be rejected.
fixture_probe_assertion "$fixture/ignores.sh" "$fixture" "$root" ignores \
    --selected "$fixture/ignores.sh" '[[ "$status" ==' 'status=97' || status=$?
[[ "$status" == 1 ]] || exit 1
# A caller can select a literal assertion outside the owner fixture body.
# Quoting and backslashes stay literal through awk on GNU and BSD hosts.
cat > "$fixture/assertions" <<'ASSERTIONS'
    [[ "$selected" == 'right\value' ]] || exit 1
ASSERTIONS
# shellcheck disable=SC2016 # Bindings and the prefix execute/match in the child.
fixture_probe_assertion "$fixture/owner.sh" "$fixture" "$root" selected \
    --selected "$fixture/assertions" '[[ "$selected" ==' 'selected=wrong' || exit 1
# Function-owned guards retain their return status in the generated child.
sed 's/|| exit 1/|| return 1/' "$fixture/assertions" > "$fixture/function-assertion"
# shellcheck disable=SC2016 # Literal function guard selected by the owner.
fixture_probe_assertion "$fixture/owner.sh" "$fixture" "$root" function-guard \
    --selected "$fixture/function-assertion" '[[ "$selected" ==' 'selected=wrong' || exit 1
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
        --selected "$fixture/selected-$failure" '[[ "$selected" ==' "$bindings" \
        2> "$fixture/selected-$failure-diagnostic" || status=$?
    [[ "$status" != 0 ]] || exit 1
    if [[ "$failure" == missing || "$failure" == duplicate ]]; then
        [[ ! -f "$fixture/selected-$failure-assertion.path" ]] || exit 1
        grep -F 'exactly one line' "$fixture/selected-$failure-diagnostic" > /dev/null
    fi
done
# Reject missing initialization anchors in selected mode before execution too.
# shellcheck disable=SC2016 # Match the literal root anchor, not this process.
sed '/^root="${root%\/.}"$/d' "$fixture/owner.sh" > "$fixture/unsupported.sh"
status=0
# shellcheck disable=SC2016
fixture_probe_assertion "$fixture/unsupported.sh" "$fixture" "$root" selected-anchor \
    --selected "$fixture/assertions" '[[ "$selected" ==' 'selected=wrong' \
    2> "$fixture/selected-anchor-diagnostic" || status=$?
[[ "$status" != 0 && ! -f "$fixture/selected-anchor-assertion.path" ]] || exit 1
grep -F 'single-line trap ACTION EXIT' "$fixture/selected-anchor-diagnostic" > /dev/null
# Missing selection arguments cannot start an owner or allocate its probe tree.
for invalid in omitted incomplete unknown; do
    arguments=()
    case "$invalid" in
        incomplete) arguments=(--selected "$fixture/assertions") ;;
        unknown) arguments=(--guess "$fixture/assertions" prefix bindings) ;;
    esac
    status=0
    fixture_probe_assertion "$fixture/owner.sh" "$fixture/unselected-$invalid" "$root" invalid \
        ${arguments[@]+"${arguments[@]}"} || status=$?
    [[ "$status" == 2 && ! -e "$fixture/unselected-$invalid" && ! -e "$fixture/owner-body" ]] || exit 1
done
echo 'Assertion probe admission and retention passed'
fixture_complete=true
