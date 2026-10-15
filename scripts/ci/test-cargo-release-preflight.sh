#!/usr/bin/env bash
# Shared companions: scripts/ci/cargo-release-preflight.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/cargo-preflight.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Cargo preflight fixture retained"' EXIT
mkdir -p "$fixture/bin" "$fixture/tool root" "$fixture/selected source"
printf 'first pin\n' > "$fixture/first pins"
printf 'second pin\n' > "$fixture/second pins"
cat > "$fixture/bin/cargo" <<'CARGO'
#!/usr/bin/env bash
set -euo pipefail
printf 'cargo:%s:%s\n' "$PWD" "$*" >> "$PREFLIGHT_EVENTS"
[[ -z "${IC_METRICS_RELEASE_CACHE_PREPARE+x}" ]] || exit 99
[[ "${PREFLIGHT_FETCH_STATUS:-0}" == 0 ]] || exit "$PREFLIGHT_FETCH_STATUS"
if [[ -n "${PREFLIGHT_CACHE:-}" && ! -e "$PREFLIGHT_CACHE/input" ]]; then
    if [[ "$*" == *' --offline' || "${CARGO_NET_OFFLINE:-false}" == true ||
          "${PREFLIGHT_CONFIG_OFFLINE:-false}" == true ]]; then exit 43; fi
    printf 'prepared locked input\n' > "$PREFLIGHT_CACHE/input"
fi
CARGO
cat > "$fixture/bin/make" <<'MAKE'
#!/usr/bin/env bash
set -euo pipefail
[[ $# == 4 && "$1" == --no-print-directory && "$2" == -C && "$3" == "$PREFLIGHT_TOOL_ROOT" ]] || exit 99
printf 'make:%s\n' "$4" >> "$PREFLIGHT_EVENTS"
if [[ "${PREFLIGHT_CHANGE_PIN:-no}" == yes ]]; then printf changed >> "$PREFLIGHT_SECOND_PIN"; fi
[[ "${PREFLIGHT_MAKE_STATUS:-0}" == 0 ]] || exit "$PREFLIGHT_MAKE_STATUS"
[[ "${PREFLIGHT_FAIL_TARGET:-}" != "$4" ]] || exit 49
if [[ -n "${PREFLIGHT_CACHE:-}" ]]; then
    case "$4" in
        install)
            if [[ ! -e "$PREFLIGHT_CACHE/tool" && "${CARGO_NET_OFFLINE:-false}" == true ]]; then exit 57; fi
            printf 'prepared executable\n' > "$PREFLIGHT_CACHE/tool" ;;
        offline-check) [[ -e "$PREFLIGHT_CACHE/tool" ]] || exit 53 ;;
        *) exit 99 ;;
    esac
fi
MAKE
chmod +x "$fixture/bin/cargo" "$fixture/bin/make"
export PATH="$fixture/bin:$PATH" PREFLIGHT_EVENTS="$fixture/events" PREFLIGHT_TOOL_ROOT="$fixture/tool root" PREFLIGHT_SECOND_PIN="$fixture/second pins"
cd "$fixture/selected source"
run() {
    bash "$ROOT/scripts/ci/cargo-release-preflight.sh" "$PREFLIGHT_TOOL_ROOT" "$1" \
        --pin "$fixture/first pins" --pin "$fixture/second pins" --check offline-check \
        --prepare install --prepare offline-check
}
for mode in 0 1; do
    : > "$PREFLIGHT_EVENTS"
    run "$mode"
    if [[ "$mode" == 0 ]]; then
        printf 'cargo:%s:fetch --locked --offline\nmake:offline-check\n' "$PWD" > "$fixture/expected"
    else
        printf 'cargo:%s:fetch --locked\nmake:install\nmake:offline-check\n' "$PWD" > "$fixture/expected"
    fi
    cmp "$fixture/expected" "$PREFLIGHT_EVENTS"
done
for kind in fetch make pin invalid; do
    : > "$PREFLIGHT_EVENTS"
    status=0
    case "$kind" in
        fetch) PREFLIGHT_FETCH_STATUS=43 run 1 > "$fixture/$kind.log" 2>&1 || status=$?; expected=43 ;;
        make) PREFLIGHT_MAKE_STATUS=49 run 1 > "$fixture/$kind.log" 2>&1 || status=$?; expected=49 ;;
        pin) PREFLIGHT_CHANGE_PIN=yes run 1 > "$fixture/$kind.log" 2>&1 || status=$?; expected=1 ;;
        invalid) run 2 > "$fixture/$kind.log" 2>&1 || status=$?; expected=2 ;;
    esac
    [[ "$status" == "$expected" ]] || exit 1
    case "$kind" in
        fetch) [[ $(wc -l < "$PREFLIGHT_EVENTS") -eq 1 ]] || exit 1 ;;
        invalid) [[ ! -s "$PREFLIGHT_EVENTS" ]] || exit 1 ;;
        *) [[ $(wc -l < "$PREFLIGHT_EVENTS") -eq 2 ]] || exit 1 ;;
    esac
done
# Shared owns simulated cache/tool states. Consumers retain actual Cargo-policy
# admission, preparation-authority routing, selected pins and Git custody.
printf 'unchanged manifest\n' > Cargo.toml
printf 'unchanged lock\n' > Cargo.lock
cp Cargo.toml "$fixture/original.toml"
cp Cargo.lock "$fixture/original.lock"
for scenario in cold standalone-offline environment-offline config-offline fetch-failure warm-offline \
    tool-cold tool-install-failure tool-check-failure tool-standalone-missing tool-offline-missing; do (
    export PREFLIGHT_CACHE="$fixture/$scenario"
    mkdir "$PREFLIGHT_CACHE"
    printf 'old executable\n' > "$PREFLIGHT_CACHE/old-tool"
    printf 'prepared executable\n' > "$PREFLIGHT_CACHE/tool"
    printf 'first pin\n' > "$fixture/first pins"
    printf 'second pin\n' > "$fixture/second pins"
    : > "$PREFLIGHT_EVENTS"
    unset CARGO_NET_OFFLINE PREFLIGHT_CONFIG_OFFLINE PREFLIGHT_FETCH_STATUS PREFLIGHT_FAIL_TARGET
    mode=1 expected=0
    case "$scenario" in
        standalone-offline) mode=0; expected=43 ;;
        environment-offline) export CARGO_NET_OFFLINE=true; expected=43 ;;
        config-offline) export PREFLIGHT_CONFIG_OFFLINE=true; expected=43 ;;
        fetch-failure) export PREFLIGHT_FETCH_STATUS=47; expected=47 ;;
        warm-offline) export CARGO_NET_OFFLINE=true; printf 'prepared locked input\n' > "$PREFLIGHT_CACHE/input" ;;
        tool-*) printf 'prepared locked input\n' > "$PREFLIGHT_CACHE/input" ;;
    esac
    case "$scenario" in
        tool-cold) rm "$PREFLIGHT_CACHE/tool" ;;
        tool-install-failure) export PREFLIGHT_FAIL_TARGET=install; expected=49 ;;
        tool-check-failure) export PREFLIGHT_FAIL_TARGET=offline-check; expected=49 ;;
        tool-standalone-missing) mode=0; rm "$PREFLIGHT_CACHE/tool"; expected=53 ;;
        tool-offline-missing) export CARGO_NET_OFFLINE=true; rm "$PREFLIGHT_CACHE/tool"; expected=57 ;;
    esac
    status=0
    run "$mode" > "$fixture/$scenario.log" 2>&1 || status=$?
    [[ "$status" == "$expected" ]] || exit 1
    expected_fetch='fetch --locked'
    [[ "$mode" != 0 ]] || expected_fetch+=' --offline'
    printf 'cargo:%s:%s\n' "$PWD" "$expected_fetch" > "$fixture/expected"
    case "$scenario" in
        standalone-offline|environment-offline|config-offline|fetch-failure) [[ ! -e "$PREFLIGHT_CACHE/input" ]] || exit 1 ;;
        tool-standalone-missing) printf 'make:offline-check\n' >> "$fixture/expected" ;;
        tool-install-failure|tool-offline-missing) printf 'make:install\n' >> "$fixture/expected" ;;
        *) printf 'make:install\nmake:offline-check\n' >> "$fixture/expected" ;;
    esac
    cmp "$fixture/expected" "$PREFLIGHT_EVENTS"
    if [[ "$expected" == 0 ]]; then
        [[ -f "$PREFLIGHT_CACHE/input" && -f "$PREFLIGHT_CACHE/tool" ]] || exit 1
    fi
    [[ "$(cat "$PREFLIGHT_CACHE/old-tool")" == 'old executable' ]] || exit 1
    cmp "$fixture/original.toml" Cargo.toml
    cmp "$fixture/original.lock" Cargo.lock
); done
fixture_complete=true
echo 'Locked Cargo preparation, ordered tool checks and multi-pin refusal passed'
