#!/usr/bin/env bash
# Shared companions: scripts/ci/make-adapter-probes.sh scripts/ci/fixture-retention-probes.sh scripts/ci/collect-native-diagnostics.sh scripts/ci/check-pipe-jobserver.pl make/execution.mk
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
source "$ROOT/scripts/ci/make-adapter-probes.sh"
source "$ROOT/scripts/ci/fixture-retention-probes.sh"
# Exhaustive flag permutations belong to producer qualification only.
make_probe_execution_modes() {
    [[ $# -ge 5 ]] || return 2
    local executable="$1" makefile="$2" directory="$3" events="$4"
    shift 4
    local target mode selection status assignment
    local flags=()
    [[ -f "$makefile" && -d "$directory" ]] || return 2
    for target in "$@"; do
        for mode in -i --ignore-errors -n --dry-run --just-print --recon -t --touch -q --question -kin; do
            for selection in direct inherited cleared replaced both-hidden; do
                : > "$events" || return
                status=0
                if [[ "$selection" == inherited ]]; then
                    _shared_make_execution_checked=yes MAKEFLAGS="$mode" "$executable" --no-print-directory \
                        -f "$makefile" "$target" > "$directory/output" 2>&1 || status=$?
                else
                    flags=()
                    case "$selection" in
                        cleared) flags=(MAKEFLAGS=) ;;
                        replaced) flags=(MAKEFLAGS=--no-print-directory) ;;
                        both-hidden) flags=(MAKEFLAGS= MFLAGS=) ;;
                    esac
                    "$executable" --no-print-directory -f "$makefile" "$mode" "$target" \
                        ${flags[@]+"${flags[@]}"} > "$directory/output" 2>&1 || status=$?
                fi
                if [[ "$status" != 2 || -s "$events" ]]; then
                    printf 'Make admission failed: %s %s %s (status %s)\n' "$target" "$mode" "$selection" "$status" >&2
                    return 1
                fi
            done
        done
    done
    for assignment in 'MFLAGS :=' 'override MFLAGS :='; do
        printf '%s\n' "$assignment" > "$directory/hidden-mflags.mk" || return
        : > "$events" || return
        status=0
        "$executable" --no-print-directory -i -f "$directory/hidden-mflags.mk" -f "$makefile" \
            "$1" MAKEFLAGS= > "$directory/output" 2>&1 || status=$?
        [[ "$status" == 2 && ! -s "$events" ]] || return 1
    done
}

fixture="$(fixture_create "${TMPDIR:-/tmp}/consumer-flows.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Consumer flow probes retained"' EXIT
export FLOW_SOURCE="$ROOT" FLOW_EVENTS="$fixture/events"
# Keep the selected include relative so Make need not parse checkout spaces.
cd "$ROOT"
cat > "$fixture/Makefile" <<'MAKE'
include make/execution.mk
run:
	+@perl "$(FLOW_SOURCE)/scripts/ci/check-pipe-jobserver.pl"
	@printf 'called\n' >> "$(FLOW_EVENTS)"
MAKE
real_make="$(command -v make)"
make_probe_execution_modes "$real_make" "$fixture/Makefile" "$fixture" "$FLOW_EVENTS" run
make_probe_target_admission "$real_make" "$fixture/Makefile" "$fixture" "$FLOW_EVENTS" run
make_probe_parallel_dispatch "$real_make" "$fixture/Makefile" "$fixture" "$FLOW_EVENTS" run
# A permissive Makefile must not be accepted as evidence of safe admission.
# shellcheck disable=SC2016 # Make expands the literal variable in the fixture.
printf 'run:\n\t@printf called >> "$(FLOW_EVENTS)"\n' > "$fixture/bad.mk"
if make_probe_execution_modes "$real_make" "$fixture/bad.mk" "$fixture" "$FLOW_EVENTS" run; then exit 1; fi
if make_probe_target_admission "$real_make" "$fixture/bad.mk" "$fixture" "$FLOW_EVENTS" run; then exit 1; fi
# No-event refusal is independent of a failing status: an effect followed by a
# normal Make error must not qualify as parse-time admission.
# shellcheck disable=SC2016 # Make expands the fixture variable.
printf '$(shell printf called >> "$(FLOW_EVENTS)")\n$(error refused)\nrun:\n' > "$fixture/effect-before-error.mk"
if make_probe_target_admission "$real_make" "$fixture/effect-before-error.mk" "$fixture" "$FLOW_EVENTS" run; then exit 1; fi
cat > "$fixture/effect.sh" <<'CHILD'
#!/usr/bin/env bash
set -euo pipefail
source "$FLOW_SOURCE/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "$TMPDIR/effect.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "fixture retained"' EXIT
printf 'payload\n' > "$fixture/input"
case "$FLOW_EFFECT" in
    failed) echo injected >&2; exit 43 ;;
    success) fixture_complete=true ;;
    wrong) echo injected >&2; exit 0 ;;
esac
CHILD
for effect in success failed; do
    run="$fixture/$effect"
    mkdir -p "$run/tmp"
    expected=0
    [[ "$effect" != failed ]] || expected=43
    FLOW_EFFECT="$effect" fixture_probe_effect "$fixture/effect.sh" "$run" effect "$expected" "$BASH" injected
    if [[ "$effect" == failed ]]; then [[ "$(cat "$fixture_effect_retained/input")" == payload ]] || exit 1; fi
done
mkdir -p "$fixture/wrong/tmp"
if FLOW_EFFECT=wrong fixture_probe_effect "$fixture/effect.sh" "$fixture/wrong" effect 43 "$BASH" injected; then exit 1; fi
# Successful child status cannot hide leftover files, including dangling links.
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/empty-success.sh"
for name in visible .hidden ..hidden; do
    for kind in file link; do
        run="$fixture/leftover-$name-$kind"
        mkdir -p "$run/tmp"
        if [[ "$kind" == file ]]; then printf retained > "$run/tmp/$name"
        else ln -s missing "$run/tmp/$name"; fi
        if fixture_probe_effect "$fixture/empty-success.sh" "$run" effect 0 "$BASH" unused; then exit 1; fi
        [[ -e "$run/tmp/$name" || -L "$run/tmp/$name" ]] || exit 1
    done
done
# Small diagnostics select explicitly named files, never the scratch tree.
mkdir -p "$fixture/checkout" "$fixture/evidence/scratch" "$fixture/formats"
printf 'source identity\n' > "$fixture/evidence/source.txt"
printf 'excluded\n' > "$fixture/evidence/scratch/private"
printf 'formatter stderr\n' > "$fixture/formats/formatting.log"
bash "$ROOT/scripts/ci/collect-native-diagnostics.sh" "$fixture/checkout" "$fixture/evidence" \
    "$fixture/diagnostics.tar.gz" "$fixture/formats" success "$ROOT/ci/tool-versions.env" "$ROOT/ci/ic-tools.tsv" source.txt missing.txt
shasum -a 256 -c "$fixture/diagnostics.tar.gz.sha256" > "$fixture/checksum.log"
tar -tzf "$fixture/diagnostics.tar.gz" > "$fixture/members"
printf './source.txt\n' > "$fixture/expected"
cmp "$fixture/expected" "$fixture/members"
[[ -f "$fixture/evidence/formatting-logs.tar.gz" ]] || exit 1
# Existing output and traversal selections refuse without replacing old bytes.
cp "$fixture/diagnostics.tar.gz" "$fixture/original.tar.gz"
status=0
bash "$ROOT/scripts/ci/collect-native-diagnostics.sh" "$fixture/checkout" "$fixture/evidence" \
    "$fixture/diagnostics.tar.gz" "$fixture/formats" success "$ROOT/ci/tool-versions.env" "$ROOT/ci/ic-tools.tsv" source.txt \
    > "$fixture/conflict.log" 2>&1 || status=$?
[[ "$status" == 2 ]] || exit 1
cmp "$fixture/original.tar.gz" "$fixture/diagnostics.tar.gz"
if bash "$ROOT/scripts/ci/collect-native-diagnostics.sh" "$fixture/checkout" "$fixture/evidence" \
    "$fixture/traversal.tar.gz" "$fixture/formats" success unused unused ../source.txt; then exit 1; fi
[[ ! -e "$fixture/traversal.tar.gz" ]] || exit 1
fixture_complete=true
printf 'Consumer Make, effectful retention and native diagnostic probes passed\n'
