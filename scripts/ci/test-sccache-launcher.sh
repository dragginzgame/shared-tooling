#!/usr/bin/env bash
# Shared companions: scripts/ci/run-sccache.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail

ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
FIXTURE="$(fixture_create "${TMPDIR:-/tmp}/sccache-launcher.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE" "Failed sccache fixture retained"' EXIT

mkdir -p "$FIXTURE/repository" "$FIXTURE/result"
cat >"$FIXTURE/fake-sccache" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$SCCACHE_SERVER_UDS" >"$SCCACHE_TEST_RESULT/socket"
printf '%s\n' "$TMPDIR" >"$SCCACHE_TEST_RESULT/tmpdir"
printf '%s\n' "$*" >"$SCCACHE_TEST_RESULT/arguments"
SCRIPT
chmod +x "$FIXTURE/fake-sccache"

# A prepared PATH candidate never supplies the executable implicitly. Refusal
# precedes runtime creation and does not dispatch a relative or directory value.
mkdir "$FIXTURE/bin"
ln -s "$FIXTURE/fake-sccache" "$FIXTURE/bin/sccache"
for selection in unset empty bare relative directory missing non-executable; do
    probe="$FIXTURE/selection-$selection"
    mkdir -p "$probe/repository" "$probe/result"
    case "$selection" in
        unset) unset SCCACHE_BIN ;;
        empty) SCCACHE_BIN='' ;;
        bare) SCCACHE_BIN=sccache ;;
        relative) SCCACHE_BIN=./fake-sccache ;;
        directory) SCCACHE_BIN="$FIXTURE/bin" ;;
        missing) SCCACHE_BIN="$probe/missing" ;;
        non-executable) SCCACHE_BIN="$probe/tool"; printf 'unused\n' > "$SCCACHE_BIN" ;;
    esac
    [[ "$selection" == unset ]] || export SCCACHE_BIN
    if (cd "$FIXTURE" && PATH="$FIXTURE/bin:$PATH" SCCACHE_REPOSITORY_ROOT="$probe/repository" \
        SCCACHE_TEST_RESULT="$probe/result" bash "$ROOT/scripts/ci/run-sccache.sh" \
        rustc --version) > "$probe/refusal.log" 2>&1; then
        echo "accepted $selection cache executable" >&2; exit 1
    else
        [[ $? == 1 ]] || exit 1
    fi
    grep -F 'SCCACHE_BIN must select an absolute executable file' "$probe/refusal.log" >/dev/null
    [[ ! -e "$probe/repository/.tmp" && -z "$(ls -A "$probe/result")" ]] || exit 1
done
unset SCCACHE_BIN

SCCACHE_BIN="$FIXTURE/fake-sccache" \
    SCCACHE_REPOSITORY_ROOT="$FIXTURE/repository" \
    SCCACHE_TEST_RESULT="$FIXTURE/result" \
    bash "$ROOT/scripts/ci/run-sccache.sh" rustc --version

expected_runtime="$FIXTURE/repository/.tmp/sccache-runtime"
[[ "$(<"$FIXTURE/result/socket")" == "$expected_runtime/server.sock" ]] || exit 1
[[ "$(<"$FIXTURE/result/tmpdir")" == "$expected_runtime/tmp" ]] || exit 1
[[ "$(<"$FIXTURE/result/arguments")" == "rustc --version" ]] || exit 1

# Refused symlink selections must not create anything through the link.
for selection in parent root child override trailing dot; do
    probe="$FIXTURE/sccache-$selection"
    mkdir -p "$probe/repository" "$probe/outside" "$probe/result"
    runtime="$probe/repository/.tmp/sccache-runtime"
    case "$selection" in
        parent) ln -s "$probe/outside" "$probe/repository/.tmp" ;;
        root) mkdir "$probe/repository/.tmp"; ln -s "$probe/outside" "$runtime" ;;
        child) mkdir -p "$runtime"; ln -s "$probe/outside" "$runtime/tmp" ;;
        override) runtime="$probe/explicit"; ln -s "$probe/outside" "$runtime" ;;
        trailing) runtime="$probe/explicit"; ln -s "$probe/outside" "$runtime"; runtime="$runtime///" ;;
        dot) runtime="$probe/explicit"; ln -s "$probe/outside" "$runtime"; runtime="$runtime/." ;;
    esac
    if SCCACHE_BIN="$FIXTURE/fake-sccache" SCCACHE_REPOSITORY_ROOT="$probe/repository" \
        SCCACHE_RUNTIME_DIR="$runtime" SCCACHE_TEST_RESULT="$probe/result" \
        bash "$ROOT/scripts/ci/run-sccache.sh" rustc --version > "$probe/refusal.log" 2>&1; then
        echo "accepted symlinked sccache path: $selection" >&2; exit 1
    fi
    [[ -z "$(ls -A "$probe/outside")" && ! -e "$probe/result/arguments" ]] || exit 1
done
SCCACHE_BIN="$FIXTURE/fake-sccache" SCCACHE_REPOSITORY_ROOT="$FIXTURE/repository" \
    SCCACHE_RUNTIME_DIR="$FIXTURE/explicit-runtime" SCCACHE_TEST_RESULT="$FIXTURE/result" \
    bash "$ROOT/scripts/ci/run-sccache.sh" --show-stats
[[ "$(<"$FIXTURE/result/tmpdir")" == "$FIXTURE/explicit-runtime/tmp" ]] || exit 1

# The selected executable owns argv, diagnostics and status, including literal
# empty/newline arguments. A failed adapter is never replayed or replaced.
cat > "$FIXTURE/failed-adapter" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$SCCACHE_TEST_RESULT/argv"
printf 'selected stdout\n'
printf 'selected stderr\n' >&2
exit 37
SCRIPT
chmod +x "$FIXTURE/failed-adapter"
printf '%s\0' 'compiler path' '' $'line\nargument' > "$FIXTURE/expected-argv"
if SCCACHE_BIN="$FIXTURE/failed-adapter" SCCACHE_REPOSITORY_ROOT="$FIXTURE/repository" \
    SCCACHE_TEST_RESULT="$FIXTURE/result" bash "$ROOT/scripts/ci/run-sccache.sh" \
    'compiler path' '' $'line\nargument' > "$FIXTURE/stdout" 2> "$FIXTURE/stderr"; then
    echo 'lost selected executable failure' >&2; exit 1
else
    [[ $? == 37 ]] || exit 1
fi
cmp "$FIXTURE/expected-argv" "$FIXTURE/result/argv"
[[ "$(cat "$FIXTURE/stdout")" == 'selected stdout' && "$(cat "$FIXTURE/stderr")" == 'selected stderr' ]] || exit 1

fixture_complete=true
echo 'Sccache launcher fixtures passed'
